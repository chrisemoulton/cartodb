# coding: UTF-8
require 'spec_helper'
require_relative '../../../lib/carto/column_sanitizer'

describe Carto::ColumnSanitizer do
  before(:each) do
    @user = create_user :email => 'blah@example.com', :username => 'blah', :password => '3456123'
    @table_name = 'test_table'
    @table_schema = @user.database_schema
    @db_conn = @user.in_database
  end

  after(:each) do
    @table_name = nil
    @user.destroy
  end

  def import_table(table_name, column_names, rows)
    filepath = "/tmp/#{table_name}.csv"
    CSV.open(filepath, 'w') do |csv|
      header = column_names.map { |c| "\"#{c}\"" }
      csv << header
      rows.each do |r|
        csv << r
      end
    end

    data_import = DataImport.create(
      :user_id       => @user.id,
      :data_source   => filepath,
      :updated_at    => Time.now,
      :append        => false
    )
    data_import.values[:data_source] = filepath

    data_import.run_import!

    File.delete(filepath)
  end

  def create_table_from_data(table_name, table_schema, column_names, rows)
    types = rows[0].map { |c| c.is_a?(Integer) ? 'int' : 'text' }
    vals = rows.map { |r|
      r.each_with_index.map { |v, i| {
          name: column_names[i],
          val: (types[i] == 'int' ? "#{v}" : "'#{v}'") + "::#{types[i]}"
      }}
    }

    vals_clause = vals.map { |vs|
      vs.map { |v| "#{v[:val]} AS \"#{v[:name]}\"" }.join(',')
    }.join (' UNION ALL SELECT ')

    @db_conn.run(%Q{
      CREATE TABLE "#{table_schema}"."#{table_name}" AS
        SELECT #{vals_clause};
    })
  end

  def sanitize(table_name, table_schema, column_names)
    Carto::ColumnSanitizer.new(@db_conn).sanitize(
      table_name,
      table_schema,
      column_names
    )
  end

  def get_data_column_names(table_name)
    all_cols = @db_conn.schema(
      table_name, {schema: @user.database_schema}
    ).map(&:first)

    (all_cols - [:the_geom, :the_geom_webmercator, :cartodb_id])
      .map(&:to_s)
      .sort
  end

  it "should sanitize unsanitary columns" do
    column_names = [
      'i have spaces',
      'I_HAVE_CAPS',
      'i-has**symbols**!!',
      'i_am_sanitary'
    ]
    rows = [[123, 'abc', 'bar', 'clean'], [456, 'def', 'baz', 'sanitary']]

    create_table_from_data(@table_name, @table_schema, column_names, rows)
    sanitize(@table_name, @table_schema, column_names)

    sanitized_column_names = column_names.map { |c| c.sanitize_column_name }.sort
    actual_column_names = get_data_column_names(@table_name)
    actual_column_names.should eq sanitized_column_names
  end

  it "should ignore columns not in column_names" do
    unsanitary_column_names = [
      'i have spaces',
      'I_HAVE_CAPS',
      'i-has**symbols**!!',
    ]
    sanitary_column_names = [
      'i_am_sanitary',
      'me_too'
    ]
    column_names = unsanitary_column_names + sanitary_column_names
    rows = [[123, 'abc', 'bar', 'a', 1], [456, 'def', 'baz', 'b', 2]]

    create_table_from_data(@table_name, @table_schema, column_names, rows)
    sanitize(@table_name, @table_schema, column_names)

    sanitized_column_names = column_names.map(&:sanitize_column_name).sort
    actual_column_names = get_data_column_names(@table_name)

    unsanitary_column_names.each { |c| c.sanitize_column_name.should_not eq c }
    sanitary_column_names.each { |c| c.sanitize_column_name.should eq c }
    actual_column_names.should eq sanitized_column_names
  end

  it "should not fail when columns are sanitary" do
    column_names = [
      'i_am_sanitary',
      'me_too'
    ]
    rows = [['a', 1], ['b', 2]]

    create_table_from_data(@table_name, @table_schema, column_names, rows)
    sanitize(@table_name, @table_schema, column_names)

    sanitized_column_names = column_names.map(&:sanitize_column_name).sort
    actual_column_names = get_data_column_names(@table_name)

    sanitized_column_names.should eq column_names.sort
    actual_column_names.should eq sanitized_column_names
  end

  it "should only sanitize specified column names" do
    unsanitary_column_names = [
      'i have spaces',
      'I_HAVE_CAPS',
      'i-has**symbols**!!'
    ]
    column_names_to_be_sanitized = unsanitary_column_names.take(2)
    column_names_to_be_skipped = unsanitary_column_names.drop(2)
    column_names = unsanitary_column_names
    rows = [[123, 'abc', 'bar'], [456, 'def', 'baz']]

    create_table_from_data(@table_name, @table_schema, column_names, rows)
    sanitize(@table_name, @table_schema, column_names_to_be_sanitized)

    expected_column_names = (
      column_names_to_be_sanitized.map(&:sanitize_column_name) +
      column_names_to_be_skipped
    ).sort
    actual_column_names = get_data_column_names(@table_name)

    unsanitary_column_names.each { |c| c.sanitize_column_name.should_not eq c }
    actual_column_names.should eq expected_column_names
  end

  it "should sanitize all unsanitary columns when no column names are specifed" do
    column_names = [
      'i have spaces',
      'I_HAVE_CAPS',
      'i-has**symbols**!!',
      'i_am_sanitary'
    ]
    rows = [[123, 'abc', 'bar', 'clean'], [456, 'def', 'baz', 'sanitary']]

    create_table_from_data(@table_name, @table_schema, column_names, rows)
    sanitize(@table_name, @table_schema, nil)

    sanitized_column_names = column_names.map { |c| c.sanitize_column_name }.sort
    actual_column_names = get_data_column_names(@table_name)
    actual_column_names.should eq sanitized_column_names
  end

  it "numbers multiple columns of the same name" do
    column_names = [
      'i have spaces',
      'i have spaces ',
      'I_HAVE_CAPS',
      'i-has**symbols**!!',
      'i-has**symbols**!! ',
      'i-has**symbols**!!  ',
      'i_am_sanitary',
      'i_am_sanitary '
    ]
    expected_column_names = [
      'i have spaces'.sanitize_column_name,
      'i have spaces '.sanitize_column_name + '_1',
      'I_HAVE_CAPS'.sanitize_column_name,
      'i-has**symbols**!!'.sanitize_column_name,
      'i-has**symbols**!! '.sanitize_column_name + '_2',
      'i-has**symbols**!!  '.sanitize_column_name + '_3',
      'i_am_sanitary'.sanitize_column_name,
      'i_am_sanitary '.sanitize_column_name + '_4'
    ].sort
    rows = [['foo'] * column_names.length]

    # Ensure overlap of sanitized name for columns
    column_names[0].sanitize_column_name.should eq column_names[1].sanitize_column_name
    column_names[3].sanitize_column_name.should eq column_names[4].sanitize_column_name
    column_names[3].sanitize_column_name.should eq column_names[5].sanitize_column_name
    column_names[4].sanitize_column_name.should eq column_names[5].sanitize_column_name
    column_names[6].sanitize_column_name.should eq column_names[7].sanitize_column_name

    create_table_from_data(@table_name, @table_schema, column_names, rows)
    sanitize(@table_name, @table_schema, nil)

    actual_column_names = get_data_column_names(@table_name)
    actual_column_names.should eq expected_column_names

  end
end
