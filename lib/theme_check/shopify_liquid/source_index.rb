# frozen_string_literal: true

require 'json'
require 'pathname'

require_relative 'source_index/base_entry'
require_relative 'source_index/filter_entry'
require_relative 'source_index/object_entry'
require_relative 'source_index/parameter_entry'
require_relative 'source_index/property_entry'
require_relative 'source_index/return_type_entry'
require_relative 'source_index/tag_entry'

module ThemeCheck
  module ShopifyLiquid
    class SourceIndex
      TYPE_SOURCE = Pathname.new("#{__dir__}/../../../data/shopify_liquid/documentation")

      class << self
        def filters
          @filters ||= load_file(:filters)
            .map { |hash| SourceIndex::FilterEntry.new(hash) }
        end

        def objects
          @objects ||= load_file(:objects)
            .concat(built_in_objects)
            .map { |hash| SourceIndex::ObjectEntry.new(hash) }
        end

        def tags
          @tags ||= load_file(:tags)
            .map { |hash| SourceIndex::TagEntry.new(hash) }
        end

        private

        def load_file(file_name)
          read_json(file_path(file_name))
        end

        def read_json(path)
          download_files unless has_files?

          JSON.parse(path.read)
        end

        def download_files
          # TODO: (1/X): https://github.com/shopify/theme-check/issues/n
          # -
          # Remove this implementation in favor of a proper/stable approach to
          # download/update theme-liquid-docs files.
          # -
          commands = [
            'wget https://github.com/Shopify/theme-liquid-docs/raw/main/data/filters.json',
            'wget https://github.com/Shopify/theme-liquid-docs/raw/main/data/objects.json',
            'wget https://github.com/Shopify/theme-liquid-docs/raw/main/data/tags.json',
            "mkdir -p #{__dir__}/../../../data/shopify_liquid/documentation",
            "mv filters.json #{__dir__}/../../../data/shopify_liquid/documentation",
            "mv objects.json #{__dir__}/../../../data/shopify_liquid/documentation",
            "mv tags.json #{__dir__}/../../../data/shopify_liquid/documentation",
          ].join(' && ')

          Kernel.exec(commands)
        end

        def has_files?
          [:filters, :objects, :tags].all? { |file_name| file_path(file_name).exist? }
        end

        def file_path(file_name)
          TYPE_SOURCE + "#{file_name}.json"
        end

        def built_in_objects
          # TODO: (1/X): https://github.com/shopify/theme-check/issues/n
          # -
          # Manualy create an 'built_in_objects.json' file at 'Shopify/theme-liquid-docs'
          # to hold primitive types, and consume it here.
          #
          # In the future, we may generate this files, but consiering how frequent
          # they change, the goal is to just manually create this file for now.
          # -
          [
            {
              'properties' => [
                { 'name' => 'first', 'description' => 'Returns the first item of an array.' },
                { 'name' => 'size', 'description' => 'Returns the number of items in an array.' },
                { 'name' => 'last', 'description' => 'Returns the last item of an array.' },
              ],
              'name' => 'array',
              'description' => 'Arrays hold lists of variables of any type.',
            },
            {
              'properties' => [
                {
                  'name' => 'size',
                  'description' => 'Returns the number of characters in a string.',
                },
              ],
              'name' => 'string',
              'description' => 'Strings are sequences of characters wrapped in single or double quotes.',
            },
          ]
        end
      end
    end
  end
end
