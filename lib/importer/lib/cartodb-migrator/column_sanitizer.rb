# coding: UTF-8

module CartoDB
  class ColumnSanitizer

    def initialize(db_connection)
      @db_connection = db_connection
    end

    # Sanitize columns by renaming them according to the value
    # of `String#sanitize_column_name`. If `column_names` is `nil`,
    # all columns are sanitized. No modifications to the column are
    # made if the column is already `sanitary`.
    def sanitize(table_name, table_schema, column_names = nil)
      column_names ||= get_column_names(table_name, table_schema)

      columns_to_sanitize = column_names.select do |column_name|
        column_name != column_name.sanitize_column_name
      end

      correct_columns = column_names - columns_to_sanitize

      sanitization_map = Hash[
        columns_to_sanitize.map { |column_name|
          [column_name, column_name.sanitize_column_name]
        }
      ]

      sanitization_count = 0

      sanitization_map = sanitization_map.inject({}) { |memo, pair|
        if memo.values.include?(pair.last) || correct_columns.include?(pair.last)
          sanitization_count += 1
          memo.merge(pair.first => "#{pair.last}_#{sanitization_count}")
        else
          memo.merge(pair.first => pair.last)
        end
      }

      @db_connection.alter_table table_name do
        sanitization_map.each do |unsanitized, sanitized|
          rename_column unsanitized, sanitized
        end
      end
    end

    private

    # Get all columns for a table
    def get_column_names(table_name, table_schema)
      @db_connection.schema(table_name, {schema: table_schema}).map do |col|
        # Column definitions are an array, the first element of
        # which is the column name as a Symbol
        col.first.to_s
      end
    end

  end
end
