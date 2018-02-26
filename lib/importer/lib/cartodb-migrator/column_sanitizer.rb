# coding: UTF-8

module CartoDB
  class ColumnSanitizer

    def initialize(db_connection)
      @db_connection = db_connection
    end

    def sanitize(table_name, column_names)
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

      sanitization_map.each do |unsanitized, sanitized|
        @db_connection.alter_table table_name do
          rename_column unsanitized, sanitized
        end
      end
    end

  end
end
