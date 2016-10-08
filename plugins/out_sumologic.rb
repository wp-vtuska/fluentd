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
  config_param :merge_json_log, :bool, default: true

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
  
  def merge_json_log(record)
    if record.has_key?('log')
      log = record['log'].strip
      if log[0].eql?('{') && log[-1].eql?('}')
        begin
          record = JSON.parse(log).merge(record)
          record.delete('log')
        rescue JSON::ParserError
        end
      end
    end
    record
  end

  # Strip annotations and sumo
  def dump_log(log)
    if log['kubernetes'] and log['kubernetes']['annotations']
      log['kubernetes'] = Yajl.load(Yajl.dump(log['kubernetes']))
      log['kubernetes'].delete('annotations')
    end
    log.delete('sumo')
    Yajl.dump(log)
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack
  end

  def sumo_key(sumo)
    source_name = sumo['source']
    source_category = sumo['category']
    source_host = sumo['host']
    "#{source_name}:#{source_category}:#{source_host}"
  end

  # This method is called every flush interval. Write the buffer chunk
  def write(chunk)
    messages_list = {}

    # Sort messages
    chunk.msgpack_each do |tag, time, record|
      sumo = record.fetch('sumo', {})
      key = sumo_key(sumo)
      log_format = sumo['log_format'] || @log_format
      
      case log_format
        when 'text'
          log = record['log']
          unless log.nil?
            log.strip!
          end
        when 'merge_json_log'
          log = dump_log(merge_json_log({:time => time}.merge(record)))
        else
          log = dump_log({:time => time}.merge(record))
      end

      unless log.nil?
        if messages_list.key?(key)
          messages_list[key].push(log)
        else
          messages_list[key] = [log]
        end
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
  
