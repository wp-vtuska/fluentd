require 'fluent/output'
require 'net/https'
require 'yajl'

class SumologicConnection
  def initialize(endpoint, collector_id)
    @endpoint_uri = URI.join(endpoint.strip, collector_id.strip)
  end

  def publish(raw_data)
    http.request(request_for(raw_data))
  end

  private
  def request_for(raw_data)
    request = Net::HTTP::Post.new(@endpoint_uri.request_uri)
    request.body = Yajl.dump(raw_data)
    request['Content-Type'] = 'application/json'
    request
  end

  def http
    unless @http
      @http = Net::HTTP.new(@endpoint_uri.host, @endpoint_uri.port)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    @http
  end
end

class Sumologic < Fluent::Output
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('sumologic', self)

  config_param :endpoint, :string
  config_param :collector_id, :string

  # This method is called before starting.
  def configure(conf)
    @sumo_conn = SumologicConnection.new conf['endpoint'], conf['collector_id']
    super
  end

  # This method is called when starting.
  def start
    super
  end

  # This method is called when shutting down.
  def shutdown
    super
  end

  # This method is called when an event reaches Fluentd.
  # 'es' is a Fluent::EventStream object that includes multiple events.
  # You can use 'es.each {|time,record| ... }' to retrieve events.
  # 'chain' is an object that manages transactions. Call 'chain.next' at
  # appropriate points and rollback if it raises an exception.
  #
  # NOTE! This method is called by Fluentd's main thread so you should not write slow routine here. It causes Fluentd's performance degression.
  def emit(tag, es, chain)
    chain.next
    es.each do |time,record|
       @sumo_conn.publish record
    end
  end
end
