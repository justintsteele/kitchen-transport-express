# Kitchen::Transport::Express

[![Gem Version](https://badge.fury.io/rb/kitchen-transport-express.svg)](https://badge.fury.io/rb/kitchen-transport-express)

`kitchen-transport-express` is a plugin for `Kitchen::Transport` that is designed to dramatically improve the time to converge  nodes over SSH. This gem was inspired by projects 
like [kitchen-transport-speedy](https://github.com/criteo/kitchen-transport-speedy) and [kitchen-sync](https://github.com/coderanger/kitchen-sync).

The main improvement that `kitchen-transport-express` offers is it does not use native commands like `tar`, `rsync`, `stfp`, etc. to package and transfer the files.  By using the libraries
included in a `chef-workstation` installation to create the tarballs, `kitchen-transport-express` is able to provide the same performance improvement to developers who are working on either a
Linux/Mac-based system or on a Windows system.

# Installation

To get started, run `chef gem install kitchen-transport-express`.

Modify the `transport` section of the `kitchen.yml` for your Linux hosts to reference the `express_ssh` module.

```yaml
transport:
  name: express_ssh
```

Verify that everything has loaded correctly with `kitchen list`.  You should see `ExpressSsh` as the transport.

```bash
> kitchen list                                                                                                                                                                                                                                             ─╯
Instance            Driver  Provisioner  Verifier  Transport   Last Action    Last Error
default-linux       Oci     ChefInfra    Inspec    ExpressSsh  <Not Created>  <None>
```

# Windows Kitchen Instances

Windows kitchen instances natively uses the `WinRM::FS::Core::FileTransporter` class to transfer files and it already performs the same zip-and-ship process that `kitchen-transport-express` offers
to SSH instances. As such, there is no module in this gem for `WinRM`. You should continue using the built-in transport for your Windows instances.

```yaml
transport:
  name: winrm
```

# Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/justintsteele/kitchen-transport-express.git)

# License

Copyright 2025, Justin Steele

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
See the License for the specific language governing permissions and limitations under the License.
