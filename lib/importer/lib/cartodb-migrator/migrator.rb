# coding: UTF-8
require_relative 'column_sanitizer'

module CartoDB
  class Migrator
    class << self
      attr_accessor :debug
    end
    @@debug = true

    attr_accessor :current_name, :suggested_name, :db_configuration, :db_connection

    attr_reader :table_created, :force_name

    def initialize(options = {})
      @@debug = options[:debug] if options[:debug]
      @table_created = nil

      # Handle name of table and target name of table
      @suggested_name = options[:current_name]
      @current_name = options[:current_name]

      @target_schema = options[:schema]

      raise "current_table value can't be nil" if @current_name.nil?

      # Handle DB connection
      @db_configuration = options.slice :database, :username, :password, :host, :port
      @db_configuration = {:port => 5432, :host => '127.0.0.1'}.merge @db_configuration
      @db_connection = Sequel.connect("postgres://#{@db_configuration[:username]}:#{@db_configuration[:password]}@#{@db_configuration[:host]}:#{@db_configuration[:port]}/#{@db_configuration[:database]}")

      #handle suggested_name
      unless options[:suggested_name].nil? || options[:suggested_name].blank?
        @force_name = true
        @suggested_name = options[:suggested_name]
      else
        @force_name = false
      end

    rescue => e
      log $!
      log e.backtrace
      raise e
    end

    def migrate!
      # # Check if the file had data, if not rise an error because probably something went wrong

      # Sanitize column names where needed
      column_names = @db_connection.schema(@current_name, {:schema => @target_schema}).map{ |s| s[0].to_s }

      sanitize(column_names)

      # Rename our table
      if @current_name != @suggested_name
        @db_connection.run("ALTER TABLE #{@current_name} RENAME TO #{@suggested_name}")
        @current_name = @suggested_name
      end

      # attempt to transform the_geom to 4326
      if column_names.include? "the_geom"
        begin
          if srid = @db_connection["select st_srid(the_geom::geometry) from #{@suggested_name} limit 1"].first
            srid = srid[:st_srid] if srid.is_a?(Hash)
            begin
              if srid.to_s != "4326"
                # move original geometry column around
                @db_connection.run("UPDATE #{@suggested_name} SET the_geom = ST_Transform(the_geom, 4326);")
              end
            rescue => e
              @runlog.err << "Failed to transform the_geom from #{srid} to 4326 #{@suggested_name}. #{e.inspect}"
            end
          end
        rescue => e
          # if no SRID or invalid the_geom, we need to remove it from the table
          begin
            @db_connection.run("ALTER TABLE #{@suggested_name} RENAME COLUMN the_geom TO invalid_the_geom")
            column_names.delete("the_geom")
          rescue => exception
          end
        end
      end

      @table_created = true
      rows_imported = @db_connection["SELECT count(*) as count from #{@suggested_name}"].first[:count]

      payload = OpenStruct.new({
                              :name => @suggested_name,
                              :rows_imported => rows_imported,
                              :import_type => "external_table",
                              :log => @runlog
                              })

      # construct return variables
      return payload

    rescue => e
      log "====================="
      log $!
      log e.backtrace
      log "====================="
      unless @table_created.nil?
        @db_connection.drop_table(@suggested_name)
      end
      raise e
    ensure
      @db_connection.disconnect
    end

    private

    def log(str)
      if @@debug
        puts str
      end
    end

    def sanitize(column_names)
      CartoDB::ColumnSanitizer.new(@db_connection).sanitize(@current_name, column_names)
    end
  end
end
