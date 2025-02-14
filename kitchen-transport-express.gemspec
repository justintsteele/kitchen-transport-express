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

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "kitchen/transport/express/version"

Gem::Specification.new do |spec| # rubocop: disable Metrics/BlockLength
  spec.name          = "kitchen-transport-express"
  spec.version       = Kitchen::Transport::Express::VERSION
  spec.authors       = ["Justin Steele"]
  spec.email         = ["justin.steele@oracle.com"]
  spec.summary       = %q{Skip the long lines in Kitchen Transport!}
  spec.description   = %q{A Test Kitchen Transport plugin that streamlines the file transfer phase to Linux hosts.}
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.homepage      = "https://github.com/justintsteele/kitchen-transport-express.git"
  spec.metadata["github_repo"] = "https://github.com/justintsteele/kitchen-transport-express"
  spec.license       = "Apache-2.0"
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.4"
  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/justintsteele/kitchen-transport-express/issues",
    "changelog_uri"     => "https://github.com/justintsteele/kitchen-transport-express/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://github.com/justintsteele/kitchen-transport-express/blob/main/README.md",
    "homepage_uri"      => "https://github.com/justintsteele/kitchen-transport-express",
    "source_code_uri"   => "https://github.com/justintsteele/kitchen-transport-express",
  }
  spec.add_dependency "test-kitchen"
  spec.add_dependency "ffi-libarchive"
  spec.add_dependency "concurrent-ruby"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "chefstyle"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "yard"
end  # rubocop: enable Metrics/BlockLength
