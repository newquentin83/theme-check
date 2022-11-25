# frozen_string_literal: true
require "test_helper"

module ThemeCheck
  module LanguageServer
    class FilterCompletionProviderTest < Minitest::Test
      include CompletionProviderTestHelper

      def setup
        @provider = FilterCompletionProvider.new
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

      def test_suggest_filters_compatible_with_the_array_type
        assert_can_complete_with(@provider, "{{ current_tags | ", "compact")
        refute_can_complete_with(@provider, "{{ current_tags | ", "url_decode")
      end

      def test_suggest_filters_compatible_with_the_string_type
        assert_can_complete_with(@provider, "{{ image_url | ", "url_decode")
        refute_can_complete_with(@provider, "{{ image_url | ", "compact")
        # TODO: assert_can_complete_with(@provider, "{{ 'test%40test.com' | ", "url_decode")
      end

      # TODO: Add test for "assign c = product.collections | "

      def test_does_not_complete_deprecated_filters
        refute_can_complete_with(@provider, "{{ 'foo.js' | hex_to", "hex_to_rgba")
      end
    end
  end
end
