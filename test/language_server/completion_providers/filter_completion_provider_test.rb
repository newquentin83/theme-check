# frozen_string_literal: true
require "test_helper"

module ThemeCheck
  module LanguageServer
    class FilterCompletionProviderTest < Minitest::Test
      include CompletionProviderTestHelper

      def setup
        @provider = FilterCompletionProvider.new
        @filter_compatible_with_the_array_type = "compact"
        @filter_compatible_with_the_string_type = "url_decode"
      end

      def test_can_complete?
        assert_can_complete(@provider, "{{ 'foo.js' | ")
        assert_can_complete(@provider, "{{ 'foo.js' | asset")
        assert_can_complete(@provider, "{{ 'foo.js' | asset_url | ")
        assert_can_complete(@provider, "{{ 'foo.js' | asset_url | image")

        refute_can_complete(@provider, "{{ 'foo.js' ")
        refute_can_complete(@provider, "{% if foo")
      end

      def test_completions
        assert_can_complete_with(@provider, "{{ 'foo.js' | ", "asset_url")
        assert_can_complete_with(@provider, "{{ 'foo.js' | asset", "asset_url")
        assert_can_complete_with(@provider, "{{ 'foo.js' | asset_url | image", "image_url")
      end

      def test_all_filters_when_no_assignment
        assert_can_complete_with(@provider, "{{ 'test%40test.com' | ", @filter_compatible_with_the_array_type)
        assert_can_complete_with(@provider, "{{ current_tags | ", @filter_compatible_with_the_string_type)
      end

      def test_filters_compatible_with_the_array_type_for_object
        token = "{% assign ct = current_tags | "
        assert_can_complete_with(@provider, token, @filter_compatible_with_the_array_type)
        refute_can_complete_with(@provider, token, @filter_compatible_with_the_string_type)
      end

      def test_filters_compatible_with_the_array_type_for_attribute
        token = "{% assign c = product.collections | "
        assert_can_complete_with(@provider, token, @filter_compatible_with_the_array_type)
        refute_can_complete_with(@provider, token, @filter_compatible_with_the_string_type)
      end

      def test_filters_compatible_with_the_string_type
        token = "{% assign t = product.title | "
        assert_can_complete_with(@provider, token, @filter_compatible_with_the_string_type)
        refute_can_complete_with(@provider, token, @filter_compatible_with_the_array_type)
      end

      def test_does_not_complete_deprecated_filters
        deprecated_filter = "hex_to_rgba"
        refute_can_complete_with(@provider, "{{ 'foo.js' | hex_to", deprecated_filter)
        refute_can_complete_with(@provider, "{% assign t = product.title | ", deprecated_filter)
      end
    end
  end
end
