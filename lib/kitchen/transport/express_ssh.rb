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
    # Kitchen Transport Express
    #
    # @author Justin Steele <justin.steele@oracle.com>
    class Express
      # A constant that gets prepended to debugger messages
      LOG_PREFIX = "EXPRESS"
    end

    # Express SSH Transport Error class
    #
    # @author Justin Steele <justin.steele@oracle.com>
    class ExpressFailed < StandardError
      def initialize(message, exit_code = nil)
        super("#{Express::LOG_PREFIX} file transfer failed. #{message}.")
      end
    end

    # Express SSH Transport plugin for Test Kitchen
    #
    # @author Justin Steele <justin.steele@oracle.com>
    class ExpressSsh < Kitchen::Transport::Ssh
      kitchen_transport_api_version 1
      plugin_version Express::VERSION

      # Override the method in the super class to start the connection with our connection class
      #
      # @param options [Hash] connection options
      # @return [Ssh::Connection] an instance of Kitchen::Transport::ExpressSsh::Connection
      def create_new_connection(options, &block)
        if @connection
          logger.debug("[#{Express::LOG_PREFIX}] Shutting previous connection #{@connection}")
          @connection.close
        end

        @connection_options = options
        @connection = self.class::Connection.new(options, &block)
      end

      # Determines if the Kitchen instance is attempting a Verify stage
      #
      # @param instance [Kitchen::Instance] the instance passed in from Kitchen
      # @return [Boolean]
      def verifier_defined?(instance)
        defined?(Kitchen::Verifier::Inspec) && instance.verifier.is_a?(Kitchen::Verifier::Inspec)
      end

      # Finalizes the Kitchen config by executing super and parsing the options provided by the kitchen.yml
      # The only difference here is we layer in our ssh options so the verifier can use our transport
      # (see Kitchen::Transport::Ssh#finalize_config!)
      def finalize_config!(instance)
        super.tap do
          if verifier_defined?(instance)
            instance.verifier.send(:define_singleton_method, :runner_options_for_expressssh) do |config_data|
              runner_options_for_ssh(config_data)
            end
          end
        end
      end

      # This connection instance overrides the default behavior of the upload method in
      # Kitchen::Transport::Ssh::Connection to provide the zip-and-ship style transfer of files
      # to the kitchen instances. All other behavior from the superclass is default.
      #
      # @author Justin Steele <justin.steele@oracle.com>
      class Connection < Kitchen::Transport::Ssh::Connection
        include Express::Archiver

        # (see Kitchen::Transport::Base::Connection#upload)
        # Overrides the upload method in Kitchen::Transport::Ssh::Connection
        # The special sauce here is that we create threaded executions of uploading our archives
        #
        # @param locals [Array] the top-level list of directories and files to be transfered
        # @param remote [String] the remote directory config[:kitchen_root]
        # @raise [ExpressFailed] if any of the threads raised an exception
        # rubocop: disable Metrics/MethodLength
        def upload(locals, remote)
          return super unless valid_remote_requirements?(remote)

          processed_locals = process_locals(locals)
          pool, exceptions = thread_pool(processed_locals)
          processed_locals.each do |local|
            pool.post do
              transfer(local, remote, session.options)
            rescue => e
              exceptions << e.cause
            end
          end
          pool.shutdown
          pool.wait_for_termination

          raise ExpressFailed, exceptions.pop unless exceptions.empty?
        end
        # rubocop: enable Metrics/MethodLength

        private

        # Creates the thread pool and exceptions queue
        #
        # @param processed_locals [Array] list of files and archives to be uploaded
        # @return [Array(Concurrent::FixedThreadPool, Queue)]
        # @api private
        def thread_pool(processed_locals)
          [Concurrent::FixedThreadPool.new([processed_locals.length, 10].min), Queue.new]
        end

        # Ensures the remote host has the minimum-required executables to extract the archives.
        #
        # @param remote [String] the remote directory config[:kitchen_root]
        # @return [Boolean]
        # @api private
        def valid_remote_requirements?(remote)
          execute("(which tar && which gzip) > /dev/null")
          execute("mkdir -p #{remote}")
          true
        rescue => e
          logger.debug("[#{Express::LOG_PREFIX}] Requirements not met on remote host for Express transport.")
          logger.debug("[#{Express::LOG_PREFIX}] #{e}")
          false
        end

        # Builds an array of files we want to ship. If the top-level item is a directory, archive it and
        # add the archive name to the array.
        #
        # @param locals [Array] the top-level list of directories and files to be transfered
        # @return [Array] the paths to the files and archives that will be transferred
        # @api private
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

        # Uploads the archives or files to the remote host.
        #
        # @param local [String] a single top-level item from the upload method
        # @param remote [String] path to remote destination
        # @param opts [Hash] the ssh options that came in from the Kitchen instance
        # @raise [StandardError] if the files could not be uploaded successfully
        # @api private
        def transfer(local, remote, opts = {})
          logger.debug("[#{Express::LOG_PREFIX}] Transferring #{local} to #{remote}")

          Net::SSH.start(session.host, opts[:user], **opts) do |ssh|
            ssh.scp.upload!(local, remote, opts)
            extract(ssh, local, remote)
          rescue Net::SCP::Error => ex
            logger.debug("[#{Express::LOG_PREFIX}] upload failed with #{ex.message.strip}")
            raise "(#{ex.message.strip})"
          end
        end
      end
    end
  end
end
