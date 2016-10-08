require 'fluent/output'
require 'net/https'
require 'yajl'
require 'benchmark'

class SumologicConnection
  def initialize(endpoint)
    @endpoint_uri = URI.parse(endpoint.strip)
  end

  def publish(raw_data, source_host=nil, source_category=nil, source_name=nil)
    http.request(request_for(raw_data, source_host, source_category, source_name))
  end

  private
  def request_for(raw_data, source_host, source_category, source_name)
    request = Net::HTTP::Post.new(@endpoint_uri.request_uri)
    request.body = raw_data
    request['X-Sumo-Name'] = source_name
    request['X-Sumo-Category'] = source_category
    request['X-Sumo-Host'] = source_host
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
  config_param :source_category, :string, :default => '%{namespace}/%{pod_name}'
  config_param :source_category_replace_dash, :string, :default => '/'
  config_param :source_name, :string, :default => '%{namespace}.%{pod}.%{container}'

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

  def is_number?(string)
    true if Float(string) rescue false
  end

  def sumo_metadata(kube_metadata)
    metadata = {
      :namespace => kube_metadata['namespace_name'],
      :pod => kube_metadata['pod_name'],
      :container => kube_metadata['container_name'],
      :source_host => kube_metadata['host'],
    }

    # Strip out dynamic bits from pod name. Deployments append a template hash.
    pod_parts = metadata[:pod].split('-')
    if is_number?(pod_parts[-2])
      metadata[:pod_name] = pod_parts[0..-3].join('-')
    else
      metadata[:pod_name] = pod_parts[0..-2].join('-')
    end

    annotations = kube_metadata.fetch('annotations', {})

    source_host = metadata[:source_host]
    log_format = annotations['sumologic.com/format'] || @log_format
    source_name = (annotations['sumologic.com/sourceName'] || @source_name) % metadata
    source_category = (annotations['sumologic.com/sourceCategory'] || @source_category) % metadata
    source_category.gsub!('-', @source_category_replace_dash)

    return source_name, source_category, source_host, log_format
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack
  end

  # This method is called every flush interval. Write the buffer chunk
  def write(chunk)
    messages_list = {}

    # Sort messages by metadata
    chunk.msgpack_each do |tag, time, record|
      log = record['log'].strip! || record['log'] if record['log']
      # Skip invalid records
      if log.nil?
        next
      end

      source_name, source_category, source_host, log_format = sumo_metadata(record['kubernetes'])
      key = "#{source_name}:#{source_category}:#{source_host}"

      if log_format == 'json'
        log = Yajl.dump({'tag' => tag, 'time' => time}.merge(record))
      end

      if messages_list.key?(key)
        messages_list[key].push(log)
      else
        messages_list[key] = [log]
      end
    end

    # Push logs to sumo
    messages_list.each do |key, messages|
      source_name, source_category, source_host = key.split(':')
      @sumo_conn.publish(
        messages.join("\n"),
        source_host=source_host,
        source_category=source_category,
        source_name=source_name
      )
    end

  end
end
  
