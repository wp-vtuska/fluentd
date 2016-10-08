require 'fluent/filter'

module Fluent
  class SumoContainerFilter < Filter
    # Register type
    Fluent::Plugin.register_filter('kubernetes_sumo', self)

    config_param :source_category, :string, :default => '%{namespace}/%{pod_name}'
    config_param :source_category_replace_dash, :string, :default => '/'
    config_param :source_category_prefix, :string, :default => 'kubernetes/'
    config_param :source_name, :string, :default => '%{namespace}.%{pod}.%{container}'
    
    def configure(conf)
      super
    end

    def is_number?(string)
      true if Float(string) rescue false
    end

    def filter(tag, time, record)
      
      unless record.fetch('kubernetes').nil?
        metadata = {
          :namespace => record['kubernetes']['namespace_name'],
          :pod => record['kubernetes']['pod_name'],
          :container => record['kubernetes']['container_name'],
          :source_host => record['kubernetes']['host'],
        }

        # Strip out dynamic bits from pod name. Deployments append a template hash.
        pod_parts = metadata[:pod].split('-')
        if is_number?(pod_parts[-2])
          metadata[:pod_name] = pod_parts[0..-3].join('-')
        else
          metadata[:pod_name] = pod_parts[0..-2].join('-')
        end

        annotations = record['kubernetes'].fetch('annotations', {})

        sumo = record[:sumo] = {}
        sumo[:host] = metadata[:source_host]
        sumo[:source] = (annotations['sumologic.com/sourceName'] || @source_name) % metadata
        sumo[:category] = ((annotations['sumologic.com/sourceCategory'] || @source_category) % metadata).prepend(@source_category_prefix)
        sumo[:category].gsub!('-', @source_category_replace_dash)
        sumo[:log_format] = annotations['sumologic.com/format']

      end
      
      record
    end
  end
end
