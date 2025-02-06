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
require "concurrent-ruby"
require_relative "express/version"
require_relative "express/archiver"

module Kitchen
  module Transport
    class Express
      # A constant that gets prepended to debugger messages
      LOG_PREFIX = "EXPRESS"
    end

    class ExpressSsh < Kitchen::Transport::Ssh
      kitchen_transport_api_version 1
      plugin_version Express::VERSION

      def create_new_connection(options, &block)
        if @connection
          logger.debug("[#{Express::LOG_PREFIX}] Shutting previous connection #{@connection}")
          @connection.close
        end

        @connection_options = options
        @connection = self.class::Connection.new(options, &block)
      end

      def verifier_defined?(instance)
        defined?(Kitchen::Verifier::Inspec) && instance.verifier.is_a?(Kitchen::Verifier::Inspec)
      end

      def finalize_config!(instance)
        super.tap do
          if verifier_defined?(instance)
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

          execute("mkdir -p #{remote}")
          processed_locals = process_locals(locals)
          pool = Concurrent::FixedThreadPool.new([processed_locals.length, 10].min)
          processed_locals.each do |local|
            pool.post { transfer(local, remote, session.options) }
          end
          pool.shutdown
          pool.wait_for_termination
        end

        def valid_remote_requirements?
          execute("(which tar && which gzip) > /dev/null")
          true
        rescue => e
          logger.debug("[#{Express::LOG_PREFIX}] Requirements not met on remote host for Express transport.")
          logger.debug(e)
          false
        end

        private

        def process_locals(locals)
          processed_locals = []
          Array(locals).each do |local|
            if ::File.directory?(local)
              archive_name = archive(local)
              processed_locals.push archive_name
            else
              processed_locals.push local
            end
          end
          processed_locals
        end

        def transfer(local, remote, opts = {})
          logger.debug("[#{Express::LOG_PREFIX}] Transferring #{local} to #{remote}")

          Net::SSH.start(session.host, opts[:user], **opts) do |ssh|
            ssh.scp.upload!(local, remote, opts)
            extract(ssh, local, remote)
          end
        end
      end
    end
  end
end
