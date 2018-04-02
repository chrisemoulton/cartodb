# encoding: utf-8

require 'sequel'
require 'rack/test'
require_relative '../../../spec_helper'
require_relative '../../api/json/synchronizations_controller_shared_examples'
require_relative '../../../../app/controllers/carto/api/synchronizations_controller'

describe Carto::Api::SynchronizationsController do
  include Rack::Test::Methods
  include Warden::Test::Helpers
  include CacheHelper

  it_behaves_like 'synchronization controllers' do
  end

  describe 'main behaviour' do
    # INFO: this tests come from spec/requests/api/json/synchronizations_controller_spec.rb

    before(:all) do
      @old_resque_inline_status = Resque.inline
      Resque.inline = false
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
      Resque.inline = @old_resque_inline_status
      bypass_named_maps
      @user.destroy
    end

    let(:params) { { api_key: @api_key } }

    describe 'GET /api/v1/synchronizations/:id' do
      it 'returns a synchronization record' do
        payload = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.foo.com'
        }

        post api_v1_synchronizations_index_url(params), payload.to_json, @headers
        id = JSON.parse(last_response.body).fetch('id')

        get api_v1_synchronizations_show_url(params.merge(id: id)), nil, @headers
        last_response.status.should == 200

        response = JSON.parse(last_response.body)
        response.fetch('id').should == id
        response.fetch('url').should == payload.fetch(:url)
      end

      it 'returns 404 for unknown synchronizations' do
        get api_v1_synchronizations_show_url(params.merge(id: "56b40691-541b-4ef3-96da-f2be29563566")), nil, @headers
        last_response.status.should == 404
      end
    end

    describe 'GET /api/v1/synchronizations/' do
      # Need to use our own user to be sure we don't conflict with the other steps
      before(:all) do
        @user = create_user(
          sync_tables_enabled: true
        )
        @api_key = @user.api_key
        host! "#{@user.username}.localhost.lan"
      end

      after(:all) do
        @user.destroy
      end

      let(:params) { { api_key: @api_key } }

      it 'returns no synchronization records' do
        get api_v1_synchronizations_index_url(params), nil, @headers
        last_response.status.should == 200

        response = JSON.parse(last_response.body)
        expect(response.fetch('total_entries')).to eq 0
        synchronizations = response.fetch('synchronizations')
        expect(synchronizations.count).to eq 0
      end

      it 'returns synchronization records' do
        payload = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.foo.com/table_1.csv'
        }

        post api_v1_synchronizations_index_url(params), payload.to_json, @headers
        id = JSON.parse(last_response.body).fetch('id')

        payload2 = {
          table_name: 'table_2',
          interval:   3600,
          url:        'http://www.foo.com/table_2.csv'
        }

        post api_v1_synchronizations_index_url(params), payload2.to_json, @headers
        expect(last_response.status).to eq 200
        id2 = JSON.parse(last_response.body).fetch('id')

        get api_v1_synchronizations_index_url(params), nil, @headers
        last_response.status.should == 200

        response = JSON.parse(last_response.body)
        expect(response.fetch('total_entries')).to eq 2
        synchronizations = response.fetch('synchronizations')
        expect(synchronizations.count).to eq 2
        expect(synchronizations.first.fetch('id')).to eq id
        expect(synchronizations.first.fetch('url')).to eq payload.fetch(:url)
        expect(synchronizations.last.fetch('id')).to eq id2
        expect(synchronizations.last.fetch('url')).to eq payload2.fetch(:url)
      end
    end

    describe 'GET /api/v1/synchronizations/search/:name' do
      # Need to use our own user to be sure we don't conflict with the other steps
      before(:each) do
        @user2 = create_user(
          sync_tables_enabled: true
        )
        host! "#{@user2.username}.localhost.lan"
      end

      after(:each) do
        @user2.destroy
      end

      it 'returns a synchronization record' do
        params = { api_key: @user2.api_key }
        payload = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.foo.com/table_1.csv'
        }

        post api_v1_synchronizations_index_url(params), payload.to_json, @headers
        expect(last_response.status).to eq 200
        id = JSON.parse(last_response.body).fetch('id')

        payload2 = {
          table_name: 'table_2',
          interval:   3600,
          url:        'http://www.foo.com/table_2.csv'
        }

        post api_v1_synchronizations_index_url(params), payload2.to_json, @headers
        expect(last_response.status).to eq 200

        get api_v1_synchronizations_search_url(params.merge(name: 'table_1')), nil, @headers
        expect(last_response.status).to eq 200

        response = JSON.parse(last_response.body)
        expect(response.fetch('total_entries')).to eq 1
        synchronizations = response.fetch('synchronizations')
        expect(synchronizations.count).to eq 1
        expect(synchronizations.first.fetch('id')).to eq id
        expect(synchronizations.first.fetch('url')).to eq payload.fetch(:url)
      end

      it 'returns synchronization records for other file extensions' do
        params = { api_key: @user2.api_key }
        payload = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.foo.com/table_1.csv'
        }

        post api_v1_synchronizations_index_url(params), payload.to_json, @headers
        expect(last_response.status).to eq 200
        id = JSON.parse(last_response.body).fetch('id')

        payload2 = {
          table_name: 'table_2',
          interval:   3600,
          url:        'http://www.foo.com/table_2.csv'
        }

        post api_v1_synchronizations_index_url(params), payload2.to_json, @headers
        expect(last_response.status).to eq 200

        payload3 = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.foo.com/table_1.zip'
        }

        post api_v1_synchronizations_index_url(params), payload3.to_json, @headers
        expect(last_response.status).to eq 200
        id3 = JSON.parse(last_response.body).fetch('id')

        # Make sure it handles extensions with multiple '.'
        payload4 = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.foo.com/table_1.geojson.gz'
        }

        post api_v1_synchronizations_index_url(params), payload4.to_json, @headers
        expect(last_response.status).to eq 200
        id4 = JSON.parse(last_response.body).fetch('id')

        get api_v1_synchronizations_search_url(params.merge(name: 'table_1')), nil, @headers
        expect(last_response.status).to eq 200

        response = JSON.parse(last_response.body)
        expect(response.fetch('total_entries')).to eq 3
        synchronizations = response.fetch('synchronizations')
        expect(synchronizations.count).to eq 3
        expect(synchronizations[0].fetch('id')).to eq id
        expect(synchronizations[0].fetch('url')).to eq payload.fetch(:url)
        expect(synchronizations[1].fetch('id')).to eq id3
        expect(synchronizations[1].fetch('url')).to eq payload3.fetch(:url)
        expect(synchronizations[2].fetch('id')).to eq id4
        expect(synchronizations[2].fetch('url')).to eq payload4.fetch(:url)
      end

      it 'returns empty json for unknown synchronization' do
        params = { api_key: @user2.api_key }
        payload = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.foo.com/table_1.csv'
        }

        post api_v1_synchronizations_index_url(params), payload.to_json, @headers
        expect(last_response.status).to eq 200

        payload2 = {
          table_name: 'table_2',
          interval:   3600,
          url:        'http://www.foo.com/table_2.csv'
        }

        post api_v1_synchronizations_index_url(params), payload2.to_json, @headers
        expect(last_response.status).to eq 200

        get api_v1_synchronizations_search_url(params.merge(name: 'table')), nil, @headers
        expect(last_response.status).to eq 200

        response = JSON.parse(last_response.body)
        expect(response.fetch('total_entries')).to eq 0
        synchronizations = response.fetch('synchronizations')
        expect(synchronizations.count).to eq 0

        get api_v1_synchronizations_search_url(params.merge(name: 'able_1')), nil, @headers
        expect(last_response.status).to eq 200

        response = JSON.parse(last_response.body)
        expect(response.fetch('total_entries')).to eq 0
        synchronizations = response.fetch('synchronizations')
        expect(synchronizations.count).to eq 0
      end

      it 'only matches the file name (not url)' do
        params = { api_key: @user2.api_key }
        payload = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.table_1.com/table_1.csv'
        }

        post api_v1_synchronizations_index_url(params), payload.to_json, @headers
        expect(last_response.status).to eq 200
        id = JSON.parse(last_response.body).fetch('id')

        payload2 = {
          table_name: 'table_2',
          interval:   3600,
          url:        'http://www.table_1.com/table_2.csv'
        }

        post api_v1_synchronizations_index_url(params), payload2.to_json, @headers
        expect(last_response.status).to eq 200

        payload3 = {
          table_name: 'table_3',
          interval:   3600,
          url:        'http://www.table_1.com/table_1/table_2.csv'
        }

        post api_v1_synchronizations_index_url(params), payload3.to_json, @headers
        expect(last_response.status).to eq 200

        get api_v1_synchronizations_search_url(params.merge(name: 'table')), nil, @headers
        expect(last_response.status).to eq 200

        response = JSON.parse(last_response.body)
        expect(response.fetch('total_entries')).to eq 0
        synchronizations = response.fetch('synchronizations')
        expect(synchronizations.count).to eq 0

        get api_v1_synchronizations_search_url(params.merge(name: 'table_1')), nil, @headers
        expect(last_response.status).to eq 200

        response = JSON.parse(last_response.body)
        expect(response.fetch('total_entries')).to eq 1
        synchronizations = response.fetch('synchronizations')
        expect(synchronizations.count).to eq 1
        expect(synchronizations.first.fetch('id')).to eq id
        expect(synchronizations.first.fetch('url')).to eq payload.fetch(:url)
      end

    end

    describe 'GET /api/v1/synchronizations/:id/sync_now' do
      it 'returns sync status' do
        payload = {
          table_name: 'table_1',
          interval:   3600,
          url:        'http://www.foo.com'
        }

        post api_v1_synchronizations_index_url(params), payload.to_json, @headers
        id = JSON.parse(last_response.body).fetch('id')

        get api_v1_synchronizations_syncing_url(params.merge(id: id)), nil, @headers
        last_response.status.should == 200

        response = JSON.parse(last_response.body)
        response.fetch('state').should == 'queued'
      end
    end

    describe 'GET /api/v1/synchronizations/' do
      it 'returns sync list' do
        get api_v1_synchronizations_index_url(params), nil, @headers
        last_response.status.should == 200
      end
    end
  end

end
