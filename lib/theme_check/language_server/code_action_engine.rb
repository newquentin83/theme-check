# frozen_string_literal: true

module ThemeCheck
  module LanguageServer
    class CodeActionEngine
      include PositionHelper

      def initialize(storage, diagnostics_manager)
        @storage = storage
        @providers = CodeActionProvider.all.map { |c| c.new(storage, diagnostics_manager) }
      end

      def code_actions(absolute_path, start_position, end_position)
        relative_path = @storage.relative_path(absolute_path)
        buffer = @storage.read(relative_path)
        start_index = from_row_column_to_index(buffer, start_position[0], start_position[1])
        end_index = from_row_column_to_index(buffer, end_position[0], end_position[1])
        range = (start_index...end_index)

        @providers
          .flat_map do |p|
            p.code_actions(relative_path, range)
          end
      end
    end
  end
end
