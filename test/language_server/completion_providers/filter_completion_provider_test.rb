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
        token = "{% assign ct = current_tags | "
        assert_can_complete_with(@provider, token, "compact")
        refute_can_complete_with(@provider, token, "url_decode")
      end

      def test_suggest_filters_compatible_with_the_string_type
        assert_can_complete_with(@provider, "{% assign t = product.title | ", "url_decode")
        # TODO: refute_can_complete_with(@provider, "{{ image_url | ", "url_decode")
        # TODO: assert_can_complete_with(@provider, "{{ 'test%40test.com' | ", "url_decode")
      end

      # TODO: Add test for "assign c = product.collections | "

      # TODO: In order to keep this implementation backward compatible, when we can't guess the current context type, the default behavior is keeping suggesting all filters.

      def test_does_not_complete_deprecated_filters
        refute_can_complete_with(@provider, "{{ 'foo.js' | hex_to", "hex_to_rgba")
      end
    end
  end
end
