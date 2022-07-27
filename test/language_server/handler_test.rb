# frozen_string_literal: true

require "test_helper"

module ThemeCheck
  module LanguageServer
    class HandlerTest < Minitest::Test
      include URIHelper

      def setup
        @mock_messenger = MockMessenger.new
        @bridge = Bridge.new(@mock_messenger)
        @handler = Handler.new(@bridge)
        @storage = make_file_system_storage(
          "layout/theme.liquid" => "<html>hello world</html>",
          "snippets/error.liquid" => "{% if unclosed %}",
          ".theme-check.yml" => <<~YAML,
            extends: nothing
            SyntaxError:
              enabled: true
          YAML
        )
      end

      def test_handle_initialize_no_path
        initialize!(1, nil, nil)
        assert_includes(@mock_messenger.sent_messages, {
          jsonrpc: "2.0",
          id: 1,
          result: {
            capabilities: {},
          },
        })
      end

      def test_handle_initialize_with_root_uri
        initialize!(1, @storage.root)
        assert_includes(@mock_messenger.sent_messages, {
          jsonrpc: "2.0",
          id: 1,
          result: {
            capabilities: Handler::CAPABILITIES,
            serverInfo: Handler::SERVER_INFO,
          },
        })
      end

      def test_handle_initialize_with_root_path
        initialize!(1, nil, @storage.root)
        assert_includes(@mock_messenger.sent_messages, {
          jsonrpc: "2.0",
          id: 1,
          result: {
            capabilities: Handler::CAPABILITIES,
            serverInfo: Handler::SERVER_INFO,
          },
        })
      end

      def test_handle_document_did_open_does_not_crash
        initialize!(1, nil, @storage.root)
        did_open!('layout/theme.liquid')
      end

      def test_handle_document_did_open_checks_by_default
        initialize!(1, nil, @storage.root)
        did_open!('snippets/error.liquid')
        assert_notification_received('textDocument/publishDiagnostics') do |params|
          params[:diagnostics].find do |diagnostic|
            diagnostic[:code] == "SyntaxError"
          end
        end
      end

      # issue 588
      def test_handle_document_did_close_deleted_file_should_not_crash_server
        initialize!(1, nil, @storage.root)
        @handler.on_text_document_did_close(nil, {
          textDocument: {
            uri: file_uri(@storage.path('file/does-not-exist.liquid')),
          },
        })
      end

      # Not guaranteed to get those, but useful when they happen.
      # Could be because of a git checkout, etc.
      def test_handle_workspace_did_create_files
        initialize!(1, nil, @storage.root)

        new_file_path = 'snippets/new.liquid'

        # here, we write to the file system without the handler knowing
        @storage.write(new_file_path, 'hello')

        # we make sure the handler doesn't know
        refute(handler_storage.read(new_file_path))

        # we notify the handler that a file was created with a
        # workspace/didCreateFiles notification
        @handler.on_workspace_did_create_files(nil, {
          files: [
            { uri: file_uri(@storage.path(new_file_path)) },
          ],
        })

        # we make sure our handler now knows
        assert(handler_storage.read(new_file_path))
        assert_equal(handler_storage.read(new_file_path), 'hello')
      end

      def test_handle_workspace_did_delete_files
        initialize!(1, nil, @storage.root)

        old_file_path = 'layout/theme.liquid'

        # here, we delete the file from the file system without the handler knowing
        @storage.write(old_file_path, 'hello')

        # we make sure the handler doesn't know
        assert(handler_storage.read(old_file_path))

        # we notify the handler that a file was deleted with a
        # workspace/didDeleteFiles notification
        @handler.on_workspace_did_delete_files(nil, {
          files: [
            { uri: file_uri(@storage.path(old_file_path)) },
          ],
        })

        # we make sure our handler now knows
        refute(handler_storage.read(old_file_path))
      end

      def test_handle_workspace_will_rename_files
        initialize!(1, nil, @storage.root)

        old_file_path = 'layout/theme.liquid'
        new_file_path = 'layout/theme2.liquid'

        # We send a workspace/willRenameFiles request to the server
        # and ask for potential WorkspaceEdits in response
        will_rename!(old_file_path, new_file_path)

        # We respond nil here because we're not doing a
        # WorkspaceEdit in response to the rename.
        assert_includes(@mock_messenger.sent_messages, {
          jsonrpc: '2.0',
          result: nil,
          id: 2,
        })

        # we make sure our handler now knows
        refute(handler_storage.read(old_file_path))
        assert(handler_storage.read(new_file_path))
        assert_equal(handler_storage.read(new_file_path), '<html>hello world</html>')
      end

      def test_handle_workspace_will_rename_files_diagnostics_handling
        initialize!(1, nil, @storage.root)
        old_file_path = "snippets/error.liquid"
        new_file_path = "snippets/error2.liquid"

        # opening the file
        did_open!(old_file_path)

        # expecting diagnostics to be received
        assert_notification_received("textDocument/publishDiagnostics") do |params|
          params[:uri] == file_uri(@storage.path(old_file_path)) &&
            !params[:diagnostics].empty?
        end

        # renaming file
        will_rename!(old_file_path, new_file_path)

        # expecting diagnostics to be flushed for old file
        assert_notification_received("textDocument/publishDiagnostics") do |params|
          params[:uri] == file_uri(@storage.path(old_file_path)) &&
            params[:diagnostics].empty?
        end

        # expecting diagnostics to be added to new file
        assert_notification_received("textDocument/publishDiagnostics") do |params|
          params[:uri] == file_uri(@storage.path(new_file_path)) &&
            !params[:diagnostics].empty?
        end
      end

      private

      def handler_storage
        @handler.instance_variable_get('@storage')
      end

      def initialize!(id, root_uri_path, root_path = nil)
        @handler.on_initialize(id, {
          rootUri: file_uri(root_uri_path),
          rootPath: root_path,
        })
      end

      def did_open!(relative_path)
        @handler.on_text_document_did_open(nil, {
          textDocument: {
            text: @storage.read(relative_path),
            uri: file_uri(@storage.path(relative_path)),
            version: 1,
          },
        })
      end

      def will_rename!(old_file_path, new_file_path)
        # here, we rename the file
        @storage.write(new_file_path, @storage.read(old_file_path))
        @storage.remove(old_file_path)

        # we make sure the handler doesn't know
        assert(handler_storage.read(old_file_path))
        refute(handler_storage.read(new_file_path))

        @handler.on_workspace_will_rename_files(2, {
          files: [
            {
              oldUri: file_uri(@storage.path(old_file_path)),
              newUri: file_uri(@storage.path(new_file_path)),
            },
          ],
        })
      end

      # @param method [String]
      # @param &pred [Block] - a predicate (params) => Boolean
      def assert_notification_received(method, &pred)
        notifications = @mock_messenger.sent_messages
          .filter { |message| message[:method] == method }
        refute_empty(notifications)

        return unless pred

        notification = notifications
          .map { |message| message[:params] }
          .reverse!
          .find(&pred)
        assert(notification, "Did not find message matching predicate in #{JSON.pretty_generate(notifications)}")
      end
    end
  end
end
