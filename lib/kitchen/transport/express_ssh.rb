# frozen_string_literal: true

# Copyright:: 2025 Justin Steele <justin.steele@oracle.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require "kitchen/transport/ssh"
require_relative "express/version"
require_relative "express/archiver"

module Kitchen
  module Transport
    LOG_PREFIX = "EXPRESS"

    class ExpressSsh < Kitchen::Transport::Ssh
      kitchen_transport_api_version 1
      plugin_version Express::VERSION

      def create_new_connection(options, &block)
        if @connection
          logger.debug("[#{LOG_PREFIX}] Shutting previous connection #{@connection}")
          @connection.close
        end

        @connection_options = options
        @connection = self.class::Connection.new(options, &block)
      end

      def finalize_config!(instance)
        super.tap do
          if defined?(Kitchen::Verifier::Inspec) && instance.verifier.is_a?(Kitchen::Verifier::Inspec)
            instance.verifier.send(:define_singleton_method, :runner_options_for_expressssh) do |config_data|
              runner_options_for_ssh(config_data)
            end
          end
        end
      end

      class Connection < Kitchen::Transport::Ssh::Connection
        include Express::Archiver

        def upload(locals, remote)
          return super unless valid_remote_requirements?

          Array(locals).each do |local|
            if ::File.directory?(local)
              archive = archive_files(local)
              ensure_remotedir_exists(remote)
            end
            logger.debug("[#{LOG_PREFIX}] Uploading #{File.basename(archive || local)} to #{remote}")
            super(archive || local, remote)
            dearchive(File.basename(archive), remote) if archive
          end
        end

        def valid_remote_requirements?
          execute("(which tar && which gzip) > /dev/null")
          true
        rescue => e
          logger.debug("[#{LOG_PREFIX}] Requirements not met on remote host for Express transport.")
          logger.debug(e)
          false
        end

        def ensure_remotedir_exists(remote)
          execute("mkdir -p #{remote}")
        end
      end
    end
  end
end
