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
      module Archiver
        def archive(path)
          archive_basename = ::File.basename(path) + ".tgz"
          archive_full_name = ::File.join(::File.dirname(path), archive_basename)

          file_count = ::Dir.glob(::File.join(path, "**/*")).size
          logger.debug("[#{LOG_PREFIX}] #{path} contains #{file_count} files.")
          create_archive(path, archive_full_name)
          archive_full_name
        end

        def extract(archive_basename, remote)
          logger.debug("[#{LOG_PREFIX}] Unpacking archive #{archive_basename} in #{remote}")
          execute("tar -xzf #{::File.join(remote, archive_basename)} -C #{remote}")
          execute("rm -f #{::File.join(remote, archive_basename)}")
        end

        private

        def create_archive(path, archive_path)
          Archive.write_open_filename(archive_path, Archive::COMPRESSION_GZIP,
                                      Archive::FORMAT_TAR_PAX_RESTRICTED) do |tar|
                                        write_content(tar, path)
                                      end
        end

        def write_content(tar, path)
          all_files = Dir.glob("#{path}/**/*")
          all_files.each do |f|
            tar.new_entry do |e|
              entry(e, f, path)
              tar.write_header e
              tar.write_data content(f) if File.file? f
            end
          end
        end

        def entry(ent, file, path)
          ent.pathname = path_name(file, path)
          ent.size = size(file) if File.file? file
          ent.mode = mode(file)
          ent.filetype = file_type(file)
          ent.atime = timestamp
          ent.mtime = timestamp
        end

        def path_name(file, path)
          file.gsub(%r{#{File.dirname(path)}/}, "")
        end

        def file_type(file)
          if File.file? file
            Archive::Entry::FILE
          elsif File.directory? file
            Archive::Entry::DIRECTORY
          end
        end

        def content(file)
          File.read file unless File.directory? file
        end

        def size(file)
          content(file).size
        end

        def mode(file)
          f = File.stat(file)
          f.mode
        end

        def timestamp
          Time.now.to_i
        end
      end
    end
  end
end
