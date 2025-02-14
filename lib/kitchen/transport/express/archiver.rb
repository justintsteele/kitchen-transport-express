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

require "ffi-libarchive"

module Kitchen
  module Transport
    class Express
      # Mixin module that provides methods for creating and extracting archives locally and on the remote host.
      #
      # @author Justin Steele <justin.steele@oracle.com>
      module Archiver
        # Creates the archive locally in the Kitchen cache location.
        #
        # @param path [String] the path of the top-level directory to be arvhied.
        # @return [String] the name of the archive.
        def archive(path)
          archive_basename = ::File.basename(path) + ".tgz"
          archive_full_name = ::File.join(::File.dirname(path), archive_basename)

          file_count = ::Dir.glob(::File.join(path, "**/*")).size
          logger.debug("[#{Express::LOG_PREFIX}] #{path} contains #{file_count} files.")
          create_archive(path, archive_full_name)
          archive_full_name
        end

        # Extracts the archive on the remote host.
        #
        # @param session [Net::SSH::Connection::Session] The SSH session used to connect to the remote host and execute the extract and cleanup commands.
        def extract(session, local, remote)
          return unless local.match(/.*\.tgz/)

          archive_basename = File.basename(local)
          logger.debug("[#{Express::LOG_PREFIX}] Extracting #{::File.join(remote, archive_basename)}")
          session.open_channel do |channel|
            channel.request_pty
            channel.exec("tar -xzf #{::File.join(remote, archive_basename)} -C #{remote} && rm -f #{File.join(remote, archive_basename)}")
          end
          session.loop
        end

        private

        # Creats a archive of the directory provided.
        #
        # @param path [String] the path to the directory that will be archived.
        # @param archive_path [String] the fully qualified path to the archive that will be created.
        # @api private
        def create_archive(path, archive_path)
          Archive.write_open_filename(archive_path, Archive::COMPRESSION_GZIP,
                                      Archive::FORMAT_TAR_PAX_RESTRICTED) do |tar|
                                        write_content(tar, path)
                                      end
        end

        # Appends the content of each item in the expanded directory path.
        #
        # @param tar [Archive::Writer] the instance of the archive class.
        # @param path [String] the path to the directory that will be archived.
        # @api private
        def write_content(tar, path)
          all_files = Dir.glob("#{path}/**/*")
          all_files.each do |f|
            if File.file? f
              tar.new_entry do |e|
                entry(e, f, path)
                tar.write_header e
                tar.write_data content(f)
              end
            end
          end
        end

        # Creates the entry in the Archive for each item.
        #
        # @param ent [Archive::Entry] the current entry being added to the archive.
        # @param file [String] the current file or directory being added to the archive.
        # @param path [String] the path to the directory being archived.
        # @api private
        def entry(ent, file, path)
          ent.pathname = file.gsub(%r{#{File.dirname(path)}/}, "")
          ent.size = size(file)
          ent.mode = mode(file)
          ent.filetype = Archive::Entry::FILE
          ent.atime = Time.now.to_i
          ent.mtime = Time.now.to_i
        end

        # The content of the file in binary format. Directories have no content.
        #
        # @param file [String] the path to the file.
        # @return [String] the content of the file.
        # @api private
        def content(file)
          File.read(file, mode: "rb")
        end

        # The size of the file. Directories have no size.
        #
        # @param file [String] the path to the file.
        # @return [Integer] the size of the file.
        # @api private
        def size(file)
          content(file).size
        end

        # The file permissions of the file.
        #
        # @param file [String] the path to the file or directory.
        # @return [Integer] the mode of the file or directory.
        # @api private
        def mode(file)
          f = File.stat(file)
          f.mode
        end
      end
    end
  end
end
