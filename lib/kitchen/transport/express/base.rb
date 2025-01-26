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

require "kitchen"
require "concurrent-ruby"
require_relative "version"
require_relative "archiver"

module Kitchen
  module Transport
    class Express
      module Base
        include Kitchen::Transport::Express::Archiver

        LOG_PREFIX = "EXPRESS"

        def valid_remote_requirements?
          raise NotImplementedError
        end

        def dearchive_remotely(archive_basename, remote)
          raise NotImplementedError
        end

        def create_new_connection(options, &block)
          if @connection
            logger.debug("[#{LOG_PREFIX}] Shutting previous connection #{@connection}")
            @connection.close
          end

          @connection_options = options
          @connection = self.class::Connection.new(options, &block)
        end

        def upload(locals, remote)
          return super unless valid_remote_requirements?

          Array(locals).each do |local|
            if ::File.directory?(local)
              archive = archive_locally(local)
              ensure_remotedir_exists(remote)
            end
            logger.debug("[#{LOG_PREFIX}] Uploading #{File.basename(archive || local)} to #{remote}")
            super(archive || local, remote)
            dearchive_remotely(File.basename(archive), remote) if archive
          end
        end
      end
    end
  end
end
