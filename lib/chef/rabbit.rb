#--
# Copyright 2014 by MTN Sattelite Communications
#
# Licensed under the Apache License, Version 2.0 (the “License”); you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an 
# “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and limitations under the License.
#++

require "chef/rabbit/version"
require 'bunny'
require 'chef/log'
require "chef/handler"

class Chef
  module RABBIT
    class Handler < Chef::Handler
      attr_reader :connection
      attr_reader :options
      
      def options=(value = {})
        @options = {
          :connection => {
            :host => "127.0.0.1",
            :port => 5672,
            :ssl => false,
            :vhost => "/",
            :user => "guest",
            :pass => "guest",
            :heartbeat => :server, # will use RabbitMQ setting
            :frame_max => 131072
          },
          :queue => {
            :name => "chef-rabbit",
            :params => {
              :durable => true
            }
          }
        }.merge(value)
      end

      def initialize(options = {})
        self.options = symbolize_keys(options)
        
        Chef::Log.debug "Initialised RABBIT handler for amqp://#{self.options[:connection][:user]}:#{self.options[:connection][:pass]}@#{self.options[:connection][:host]}:#{self.options[:connection][:port]}/#{self.options[:connection][:vhost]}"
        @connection = Bunny.new(self.options[:connection])
        @connection.start
      end

      def report
        Chef::Log.debug "Reporting #{run_status.inspect}"
        Chef::Log.debug "Options for RABBIT handler are: #{@options.pretty_inspect}"

        channel = @connection.create_channel
        exchange = (@options[:exchange] == nil) ? channel.default_exchange : channel.direct(@options[:exchange][:name], @options[:exchange][:params])
        channel.queue(@options[:queue][:name], @options[:queue][:params]).bind(exchange)

        timestamp = (@options[:timestamp_tag] == nil) ? "timestamp" : @options[:timestamp_tag]

        if run_status.failed?
          Chef::Log.debug "Notifying Rabbit server of failure."
          exchange.publish( 
            { 
              timestamp.to_sym => Time.now.getutc.to_s,
              :short_message => "Chef run failed on #{node.name}. Updated #{changes[:count]} resources.",
              :full_message => run_status.formatted_exception + "\n" + Array(backtrace).join("\n") + changes[:message]
            }.to_json, 
            :routing_key => @options[:queue][:name])
        else
          Chef::Log.debug "Notifying Rabbit server of success."
          exchange.publish(
            {
              timestamp.to_sym => Time.now.getutc.to_s,
              :short_message => "Chef run completed on #{node.name} in #{elapsed_time}. Updated #{changes[:count]} resources.",
              :full_message => changes[:message]
            }.to_json,
            :routing_key => @options[:queue][:name])
        end
      end
      
      def changes
        @changes unless @changes.nil?
        
        lines = sanitised_changes.collect do |resource|
          "recipe[#{resource.cookbook_name}::#{resource.recipe_name}] ran '#{resource.action}' on #{resource.resource_name} '#{resource.name}'"
        end

        count = lines.size

        message = if count > 0
          "Updated #{count} resources:\n\n#{lines.join("\n")}"
        else
          "No changes made."
        end

        @changes = { :lines => lines, :count => count, :message => message }
      end

      def symbolize_keys(hash)
        hash.inject({}) {|result, (key, value)|
          new_key = case key
                    when String then key.to_sym
                    else key
                    end
          new_value = case value
                      when Hash then symbolize_keys(value)
                      else value
                      end
          result[new_key] = new_value
          result
        }
      end

      def sanitised_changes
        return run_status.updated_resources if @options[:blacklist].nil?

        run_status.updated_resources.reject do |updated|
          cookbook = @options[:blacklist][updated.cookbook_name]
          if cookbook
            resource = cookbook[updated.resource_name.to_s] || []
          else
            resource = []
          end
          cookbook && resource.include?(updated.action.to_s)
        end
      end
    end
  end
end
