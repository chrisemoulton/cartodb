# encoding: utf-8
require 'sequel'
require 'rack/test'
require 'json'
require 'uri'

require_relative '../../spec_helper'
require_relative '../../../app/controllers/api/json/synchronizations_controller'
require_relative '../../../services/data-repository/backend/sequel'

include CartoDB

def app
  CartoDB::Application.new
end

describe Api::Json::SynchronizationsController do
  include Rack::Test::Methods

  before(:all) do

    @user = create_user(
      sync_tables_enabled: true
    )
    @api_key = @user.api_key
  end

  before(:each) do
    @db = Rails::Sequel.connection
    Sequel.extension(:pagination)

    CartoDB::Synchronization.repository = DataRepository::Backend::Sequel.new(@db, :synchronizations)

    bypass_named_maps
    delete_user_data @user
    @headers = {
      'CONTENT_TYPE' => 'application/json'
    }
    host! CartoDB.base_url(@user.username).sub!(/^https?\:\/\//, '')
  end

  after(:all) do
    bypass_named_maps
    @user.destroy
  end

  let(:params) { { :api_key => @api_key } }

  describe 'POST /api/v1/synchronizations' do
    it 'creates a synchronization' do
      payload = {
        table_name: 'table_1',
        interval:   3600,
        url:        'http://www.foo.com'
      }

      post api_v1_synchronizations_index_url(params), payload.to_json, @headers
      last_response.status.should == 200

      response = JSON.parse(last_response.body)
      response.fetch('id').should_not be_empty
      response.fetch('name').should_not be_empty
    end

    it 'respond error 400 if interval is beneath 15 minutes' do
      payload = {
        table_name: 'table_1',
        interval: 60,
        url: 'http://www.foo.com'
      }

      post api_v1_synchronizations_index_url(params), payload.to_json, @headers
      last_response.status.should eq 400
      last_response.body.to_str.should match /15 minutes/
    end

    it 'schedules an import' do
      payload = {
        table_name: 'table_1',
        interval:   3600,
        url:        'http://www.foo.com'
      }

      post api_v1_synchronizations_index_url(params), payload.to_json, @headers
      last_response.status.should == 200

      response = JSON.parse(last_response.body)
      response.fetch('data_import').should_not be_empty
    end

  end

  describe "Running synchronizations" do
    before(:each) do
      @table_name = 'sync_test'
      @tmpfile = "/tmp/#{@table_name}.csv"
      @common_data_user = FactoryGirl.create(
        :carto_user,
        username: Cartodb.config[:common_data]['username'],
        sync_tables_enabled: true
      )
      host! CartoDB.base_url(@common_data_user.username).sub!(/^https?\:\/\//, '')
      Synchronization::Member.any_instance.stubs(:can_manually_sync?).returns true
    end

    after(:each) do
      @common_data_user.destroy
      File.delete(@tmpfile) if File.exist?(@tmpfile)
      Synchronization::Member.any_instance.unstub(:can_manually_sync?)
    end

    let(:headers) { {'CONTENT_TYPE' => 'application/json'} }

    def write_tmp_csv(filepath, column_names, rows)
      CSV.open(filepath, 'w') do |csv|
        header = column_names.map { |c| "\"#{c}\"" }
        csv << header
        rows.each do |r|
          csv << r
        end
      end
    end

    def create_common_data_sync(url, table_name, opts = {})
      payload = {
        url: url,
        interval: 360000000
      }.merge(opts)
      params = {api_key: @common_data_user.api_key}
      post api_v1_synchronizations_create_url(params), payload.to_json, headers
      last_response.status.should == 200

      response = JSON.parse(last_response.body)
      response.fetch('id').should_not be_empty
      response.fetch('data_import').should_not be_empty
      data_import_id = response.fetch('data_import').fetch('item_queue_id')
      data_import_id.should_not be_empty
      data_import = DataImport.where(id: data_import_id).first
      data_import.should_not be_nil
      data_import.state.should eq 'complete'
      sync = Synchronization::Member.new(id: response.fetch('id')).fetch
      sync.should_not be_nil
      sync.name = table_name
      sync.store
      sync
    end

    def rerun_sync(sync)
      params = {
        api_key: @common_data_user.api_key,
        id: sync.id
      }
      put api_v1_synchronizations_sync_now_url(params)

      last_response.status.should eq 200
      response = JSON.parse(last_response.body)
      response.fetch('enqueued').should eq true

      # Manually run queued sync
      sync = Synchronization::Member.new(id: response.fetch('synchronization_id')).fetch
      sync.should_not be_nil
      sync.state.should eq 'queued'
      sync.run
      sync.state.should eq 'success'
    end

    def create_view_dataset(name, sql)
      params = {
        api_key: @common_data_user.api_key
      }
      payload = {
        relation_type: 'view',
        sql: sql,
        table_name: name
      }
      post api_v1_imports_create_url(params), payload.to_json, headers
      last_response.status.should eq 200
      body = JSON.parse(last_response.body)
      data_import_id = body['item_queue_id']
      data_import = DataImport.where(id: data_import_id).first
      data_import.should_not be_nil
      data_import.state.should eq 'complete'
    end

    it "creates new table" do
      column_names = %w{a b c d e}
      rows = [[123, 'abc', 'bar', 'a', 1], [456, 'def', 'baz', 'b', 2]]

      url = @tmpfile
      write_tmp_csv(url, column_names, rows)
      sync = create_common_data_sync(url, @table_name)

      @common_data_user.in_database.execute(
        "select a, b, c, d, e from \"#{@common_data_user.database_schema}\".#{@table_name}"
      ).values.should eq rows.map { |r| r.map { |c| c.to_s } }
    end

    it "syncs exisiting dataset" do
      column_names = %w{a b c d e}
      orig_rows = [[123, 'abc', 'bar', 'a', 1], [456, 'def', 'baz', 'b', 2]]

      # Write orig file
      url = @tmpfile
      write_tmp_csv(url, column_names, orig_rows)
      sync = create_common_data_sync(url, @table_name)

      # Update file and sync
      new_rows = [[234, 'blah', 'blah', 'f', 5], [567, 'def', 'baz', 'h', 3]]
      url = @tmpfile
      write_tmp_csv(url, column_names, new_rows)
      rerun_sync(sync)

      @common_data_user.in_database.execute(
        "select a, b, c, d, e from \"#{@common_data_user.database_schema}\".#{@table_name}"
      ).values.should eq new_rows.map { |r| r.map { |c| c.to_s } }
    end

    it "syncs exisiting dataset with unsanitary columns" do
      column_names = [
        'i has spaces', 'i also has spaces', 'i h@s $ymbol$', 'i has-a dash', 'i_is_noraml'
      ]
      orig_rows = [[123, 'abc', 'bar', 'a', 1], [456, 'def', 'baz', 'b', 2]]

      # Write orig file
      url = @tmpfile
      write_tmp_csv(url, column_names, orig_rows)
      sync = create_common_data_sync(url, @table_name)

      # Update file and sync
      new_rows = [[234, 'blah', 'blah', 'f', 5], [567, 'def', 'baz', 'h', 3]]
      url = @tmpfile
      write_tmp_csv(url, column_names, new_rows)
      rerun_sync(sync)

      @common_data_user.in_database.execute(%Q{
        select #{column_names.map(&:sanitize_column_name).join(',')}
        from \"#{@common_data_user.database_schema}\".#{@table_name}
      }).values.should eq new_rows.map { |r| r.map { |c| c.to_s } }
    end

    it "syncs exisiting dataset with unsanitary columns and view dataset" do
      # The sync logic for a dataset which is referenced by views differs from that
      # of a normal dataset.  Since the dataset cannot be dropped and replaced with
      # its newly imported version, a truncate insert is performed.  This led to an
      # issue when columns were not sanitized prior to the sync, as the columns of
      # the imported table did not match those of the existing table.

      column_names = [
        'i has spaces', 'i also has spaces', 'i h@s $ymbol$', 'i has-a dash', 'i_is_noraml'
      ]
      orig_rows = [[123, 'abc', 'bar', 'a', 1], [456, 'def', 'baz', 'b', 2]]

      # Write orig file
      url = @tmpfile
      write_tmp_csv(url, column_names, orig_rows)
      sync = create_common_data_sync(url, @table_name)

      # Create view dataset referencing dataset
      view_name = 'test_view_dataset'
      sql = "select * from \"#{@common_data_user.database_schema}\".#{@table_name}"
      create_view_dataset(view_name, sql)

      # Update file and sync
      new_rows = [[234, 'blah', 'blah', 'f', 5], [567, 'def', 'baz', 'h', 3]]
      url = @tmpfile
      write_tmp_csv(url, column_names, new_rows)
      rerun_sync(sync)

      @common_data_user.in_database.execute(%Q{
        select #{column_names.map(&:sanitize_column_name).join(',')}
        from \"#{@common_data_user.database_schema}\".#{@table_name}
      }).values.should eq new_rows.map { |r| r.map { |c| c.to_s } }
    end
  end
end
