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

require "spec_helper"
require "kitchen/transport/express_ssh"

describe Kitchen::Transport::ExpressSsh do
  let(:logger) { instance_double("Logger", debug: nil) }
  let(:options) { { hostname: "example.com", username: "user", password: "password" } }
  let(:instance) { instance_double("Kitchen::Instance", verifier: verifier) }
  let(:verifier) { instance_double("Kitchen::Verifier::Inspec") }
  let(:connection) { instance_double("Kitchen::Transport::Ssh::Connection", close: nil) }
  let(:express_ssh) { described_class.new }

  before do
    allow(express_ssh).to receive(:logger).and_return(logger)
  end

  describe "#create_new_connection" do
    it "closes the previous connection if it exists" do
      express_ssh.instance_variable_set(:@connection, connection)
      expect(connection).to receive(:close)
      express_ssh.create_new_connection(options)
    end

    it "creates a new connection with the given options" do
      expect(Kitchen::Transport::Ssh::Connection).to receive(:new).with(options).and_return(connection)
      express_ssh.create_new_connection(options)
    end
  end

  describe "#finalize_config!" do
    context "when the verifier is an instance of Kitchen::Verifier::Inspec" do
      before do
        allow(express_ssh).to receive(:verifier_defined?).with(instance).and_return(true)
      end

      it "defines a custom runner options method for the verifier" do
        expect(instance.verifier).to receive(:define_singleton_method).with(:runner_options_for_expressssh)
        express_ssh.finalize_config!(instance)
      end
    end

    context "when the verifier is not an instance of Kitchen::Verifier::Inspec" do
      before do
        allow(express_ssh).to receive(:verifier_defined?).and_return(false)
      end

      it "does not define a custom runner options method" do
        expect(instance.verifier).not_to receive(:define_singleton_method)
        express_ssh.finalize_config!(instance)
      end
    end
  end

  describe Kitchen::Transport::ExpressSsh::Connection do
    let(:options) { { hostname: "example.com", username: "user" } }
    let(:connection) { described_class.new(options) }
    let(:remote) { "/remote/path" }
    let(:local_file) { "/local/file.txt" }
    let(:local_dir) { "/local/dir" }
    let(:archive_file) { "/local/dir.tgz" }
    let(:logger) { instance_double("Logger", debug: nil) }
    let(:session) { instance_double("Net::SSH::Connection::Session") }
    let(:ssh) { instance_double("Net::SSH::Connection::Session") }
    let(:channel) { instance_double("Net::SSH::Connection::Channel") }
    let(:scp) { instance_double("Net::SCP") }
    let(:session_opts) { { user: "test_user" } }
    let(:session_host) { "example.com" }

    describe "#upload" do
      before do
        allow(::File).to receive(:directory?).and_call_original
        allow(connection).to receive(:logger).and_return(logger)
        allow(connection).to receive(:session).and_return(session)
        allow(connection).to receive(:archive).with(local_dir).and_return(archive_file)
        allow_any_instance_of(Kitchen::Transport::Ssh::Connection).to receive(:execute)
      end

      context "when remote requirements are valid" do
        before do
          allow(connection).to receive(:valid_remote_requirements?).and_return(true)
        end

        it "archives directories and uploads them" do
          allow(::File).to receive(:directory?).with(local_dir).and_return(true)
          allow(::File).to receive(:directory?).with(archive_file).and_return(false)

          expect(connection).to receive(:execute).with("mkdir -p #{remote}")
          expect(connection).to receive(:archive).with(local_dir)
          connection.upload([local_dir], remote)
        end

        it "uploads files directly if they are not directories" do
          allow(::File).to receive(:directory?).with(local_file).and_return(false)
          expect(connection).to receive(:execute).with("mkdir -p #{remote}")
          expect(connection).to_not receive(:archive).with(local_dir)
          connection.upload(local_file, remote)
        end
      end
    end
    describe "#transfer" do
      before do
        allow(connection).to receive(:session).and_return(instance_double("Session", host: session_host, options: session_opts))
        allow(connection).to receive(:extract)
        allow(Net::SSH).to receive(:start).with(session_host, session_opts[:user], session_opts).and_yield(ssh)
        allow(ssh).to receive(:scp).and_return(scp)
        allow(scp).to receive(:upload!)
      end

      it "uploads the file and extracts it on the remote" do
        connection.send(:transfer, archive_file, remote, session_opts)
        expect(scp).to have_received(:upload!).with(archive_file, remote, session_opts)
        expect(connection).to have_received(:extract).with(ssh, archive_file, remote)
      end
    end

    describe "#extract" do
      before do
        allow(ssh).to receive(:open_channel).and_yield(channel)
        allow(channel).to receive(:request_pty)
        allow(channel).to receive(:exec)
        allow(ssh).to receive(:loop)
      end

      it "extracts the file on the remote host" do
        connection.send(:extract, ssh, archive_file, remote)
        expect(channel).to have_received(:exec).with("tar -xzf #{remote}/#{File.basename(archive_file)} -C #{remote}")
        expect(channel).to have_received(:exec).with("rm -f #{remote}/#{File.basename(archive_file)}")
      end
    end
  end
end

describe Kitchen::Plugin do
  describe "kitchen can load the plugin" do
    # simulate the transport plugin load
    #
    # transport:
    #   name: express_ssh
    #

    it "loads the express_ssh plugin" do
      expect {
        described_class.load(Kitchen::Transport, "express_ssh", {})
      }.not_to raise_error
    end
  end
end
