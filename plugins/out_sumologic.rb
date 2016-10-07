require 'fluent/output'
require 'net/https'
require 'yajl'

class SumologicConnection
  def initialize(endpoint, collector_id)
    @endpoint_uri = URI.join(endpoint.strip, collector_id.strip)
  end

  def publish(raw_data, sumo_name, sumo_category)
    http.request(request_for(raw_data, sumo_name, sumo_category))
  end

  private
  def request_for(raw_data, sumo_name, sumo_category)
    request = Net::HTTP::Post.new(@endpoint_uri.request_uri)
    request.body = raw_data
    request['X-Sumo-Name'] = sumo_name
    request['X-Sumo-Category'] = sumo_category
    request['Content-Type'] = 'application/json'
    request
  end

  def http
    # Rubys HTTP is not thread safe, so we need a new instance for each request
    client = Net::HTTP.new(@endpoint_uri.host, @endpoint_uri.port)
    client.use_ssl = true
    client.verify_mode = OpenSSL::SSL::VERIFY_NONE
    client
  end
end

class Sumologic < Fluent::Output
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('sumologic', self)

  config_param :endpoint, :string
  config_param :collector_id, :string
  config_param :log_format, :string, :default => 'json'

  # This method is called before starting.
  def configure(conf)
    @sumo_conn = SumologicConnection.new(conf['endpoint'], conf['collector_id'])
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

  def emit(tag, es, chain)
    chain.next
    es.each do |time, record|
      sumo_name = nil
      sumo_category = nil
      
      if record.key?(:kubernetes)
        annotations = record['kubernetes'].fetch('annotations', {})

        namespace_name = record['kubernetes']['namespace_name']
        pod_name = record['kubernetes']['pod_name']
        container_name = record['kubernetes']['container_name']
        
        sumo_name = annotations.fetch('sumologic.com/source', "#{namespace_name}.#{pod_name}.#{container_name}")
        sumo_category = annotations.fetch('sumologic.com/category', "#{namespace_name}/#{pod_name}/#{container_name}")
        sumo_category.sub('-', '/')
      end
      
      case @log_format
        when 'json'
          data = Yajl.dump({
            'tag' => tag,
            'time' => time
          }.merge(record))
        when 'text'
          # Replace JSON encoded string
          data = record['log'].strip!
          unless data.nil?
            data = data.gsub(/[\\]" | ["]/x, '\"' => '"', '"' => '')
          end
      end
      unless data.nil?
        begin
          @sumo_conn.publish data, sumo_name, sumo_category
        rescue StandardError => e
          $stderr.puts('Failed to write to Sumo!')
          $stderr.puts(e)
          $stderr.puts(data)
        end
      end
    end
  
  end
end
