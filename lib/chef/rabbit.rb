#--

# Copyright 2014 by MTN Sattelite Communications
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#++

require "chef/rabbit/version"
require 'bunny'
require 'chef/log'

class Chef
  module RABBIT
    class Handler < Chef::Handler
      attr_reader :connection
      attr_reader :options
      
      def options=(value = {})
        @options = {
          :host => "127.0.0.1",
          :port => 5672,
          :ssl => false,
          :vhost => "/",
          :user => "guest",
          :pass => "guest",
          :queue => "chef-rabbit",
          :heartbeat => :server, # will use RabbitMQ setting
          :frame_max => 131072
        }.merge(value)
      end

      def initialize(options = {})
        self.options = options
        
        Chef::Log.debug "Initialised RABBIT handler for amqp://#{self.options[:server]}:#{self.options[:server]}@#{self.options[:server]}:#{self.options[:port]}/#{self.options[:vhost]}"
        @connection = Bunny.new(self.options)
        @connection.start
      end

      def report
        Chef::Log.debug "Reporting #{run_status.inspect}"

        channel = @connection.create_channel
        exchange = (@options[:exchange] == nil) ? channel.default_echange : channel.direct(@options[:exchange], { :durable => true })
        channel.queue(@options[:queue], { :durable => true } ).bind(exch)

        timestamp = (@options[:timestamp_tag] == nil) ? "timestamp" : @options[:timestamp_tag]

        if run_status.failed?
          Chef::Log.debug "Notifying Rabbit server of failure."
          exchange.publish( 
            { 
              timestamp.to_sym => Time.now.getutc.to_s,
              :short_message => "Chef run failed on #{node.name}. Updated #{changes[:count]} resources.",
              :full_message => run_status.formatted_exception + "\n" + Array(backtrace).join("\n") + changes[:message]
            }.to_json, 
            :routing_key => @options[:queue])
        else
          Chef::Log.debug "Notifying Rabbit server of success."
          exchange.publish(
            {
              timestamp.to_sym => Time.now.getutc.to_s,
              :short_message => "Chef run completed on #{node.name} in #{elapsed_time}. Updated #{changes[:count]} resources.",
              :full_message => changes[:message]
            }.to_json,
            :routing_key => @options[:queue])
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

      def sanitised_changes
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
