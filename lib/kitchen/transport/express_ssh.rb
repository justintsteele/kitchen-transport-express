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

require_relative "express/base"
require "kitchen/transport/ssh"

module Kitchen
  module Transport
    class ExpressSsh < Kitchen::Transport::Ssh
      kitchen_transport_api_version 1
      plugin_version Express::VERSION

      include Express::Base

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
        include Express::Base

        def archive_locally(path)
          archive_basename = ::File.basename(path) + ".tgz"
          archive = ::File.join(::File.dirname(path), archive_basename)

          file_count = ::Dir.glob(::File.join(path, "**/*")).size
          logger.debug("[#{LOG_PREFIX}] #{path} contains #{file_count} files.")
          tar_archive(path, archive)
          archive
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

        def dearchive_remotely(archive_basename, remote)
          logger.debug("[#{LOG_PREFIX}] Unpacking archive #{archive_basename} in #{remote}")
          execute("tar -xzf #{::File.join(remote, archive_basename)} -C #{remote}")
          execute("rm -f #{::File.join(remote, archive_basename)}")
        end
      end
    end
  end
end
