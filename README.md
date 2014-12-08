##DESCRIPTION:

Provides a Chef handler which can report run status, including any changes that were made, to a rabbit server. In the case of failed runs a backtrace will be included in the details reported. Based on the Graylog Gelf handler by Jon Wood (<jon@blankpad.net>) https://github.com/jellybob/chef-gelf

##REQUIREMENTS:
A Rabbit server running somewhere.

##USAGE
This example makes of the chef_handler cookbook, place some thing like this in cookbooks/chef_handler/recipes/rabbit.rb and add it to your run list. 

```
  include_recipe "chef_handler::default"

  gem_package "chef-rabbit" do
    action :nothing
  end.run_action(:install)
  
  # Make sure the newly installed Gem is loaded.
  Gem.clear_paths
  require 'chef/rabbit'
  
  chef_handler "Chef::RABBIT::Handler" do
    source "chef/rabbit"
    arguments({
      :connection => {
        :host => "your_rabbit_server",
        :user => "rabbit_user",
        :pass => "rabbit_pass",
        :vhost => "/stuff"
      }
      :queue => {
        :name => "some_queue",
        :params => {
          :durable => true,
          ...
        }
      },
      :exchange => {
        :name => "some_exchange",
        :params => {
          :durable => true,
          ...
        }
      },
      :timestamp_tag => "@timestamp"
    })

    supports :exception => true, :report => true
  end.run_action(:enable)
```

Arguments take the form of an options hash, with the following options:

* :connection             - http://rubybunny.info/articles/connecting.html
* :queue                  - rabbit queue info to use. name is set to "chef-client" + durable = true by default
* :exchange               - rabbit exchange to use .default_exchange + durable = true by default 
* :timestamp_tag          - tag for timestamp "timestamp" by default
* :blacklist ({})         - A hash of cookbooks, resources and actions to ignore in the change list.

##BLACKLISTING:

Some resources report themselves as having updated on every run even if nothing changed, or are just things you don't care about. To reduce the amount of noise in your logs these can be ignored by providing a blacklist. In this example we don't want to be told about the GELF handler being activated:

```
chef_handler "Chef::RABBIT::Handler" do
  source "chef/rabbit"
  arguments({
    :blacklist => {
      "chef_handler" => {
        "chef_handler" => [ "nothing", "enable" ]
      }
    }
  })

  supports :exception => true, :report => true
end.run_action(:enable)
```

##LICENSE and AUTHOR:

Copyright 2014 by MTN Satellite Communications

Licensed under the Apache License, Version 2.0 (the “License”); you may not use this file except in compliance with the License. You may obtain a copy of the License at 

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
See the License for the specific language governing permissions and limitations under the License.
