require 'fluent/output'
require 'net/https'
require 'yajl'

class SumologicConnection
  def initialize(endpoint)
    @endpoint_uri = URI.parse(endpoint.strip)
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

class Sumologic < Fluent::BufferedOutput
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('sumologic', self)

  config_param :endpoint, :string
  config_param :log_format, :string, :default => 'json'

  # This method is called before starting.
  def configure(conf)
    @sumo_conn = SumologicConnection.new(conf['endpoint'])
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

  def sumo_metadata(kube_metadata)
    sumo_name = nil
    sumo_category = nil
    log_format = nil

    unless kube_metadata.nil?
      namespace_name = kube_metadata['namespace_name']
      pod_name = kube_metadata['pod_name']
      container_name = kube_metadata['container_name']

      annotations = kube_metadata.fetch('annotations', {})
      sumo_name = annotations.fetch('sumologic.com/sourceName', "#{namespace_name}.#{pod_name}.#{container_name}")
      sumo_category = annotations.fetch('sumologic.com/sourceCategory', "#{namespace_name}/#{pod_name}/#{container_name}")
      sumo_category.sub('-', '/')

      log_format = annotations['sumologic.com/format']
      if log_format.nil?
        log_format = @log_format
      end
    end

    return sumo_name, sumo_category, log_format
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack
  end

  # This method is called every flush interval. Write the buffer chunk
  def write(chunk)
    messages_list = {}

    chunk.msgpack_each do |tag, time, record|
      log = record['log'].strip! || record['log'] if record['log']
      # Skip invalid records
      if log.nil?
        next
      end

      sumo_name, sumo_category, log_format = sumo_metadata(record['kubernetes'])
      key = "#{sumo_name}:#{sumo_category}"

      if log_format == 'json'
        log = Yajl.dump({'tag' => tag, 'time' => time}.merge(record))
      end

      if messages_list.key?(key)
        messages_list[key].push(log)
      else
        messages_list[key] = [log]
      end

      # Push data so sumo
      messages_list.each do |key, messages|
        begin
          sumo_name, sumo_category = key.split(':')
          @sumo_conn.publish(messages.join("\n"), sumo_name, sumo_category)
        rescue StandardError => e
          $stderr.puts('Failed to write to Sumo!')
          $stderr.puts(e)
        end
      end
      
    end
  end
end

