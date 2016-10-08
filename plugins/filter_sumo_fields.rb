require 'fluent/filter'

module Fluent
  class SumoFieldFilter < Filter
    # Register type
    Fluent::Plugin.register_filter('sumo_fields', self)

    config_param :source_category, :string, :default => nil
    config_param :source_name, :string, :default => nil
    config_param :source_host, :string, :default => nil

    def configure(conf)
      super
    end

    def filter(tag, time, record)
      sumo = record[:sumo] = {}
      
      unless @source_category.nil?
        sumo[:category] = @source_category
      end

      unless @source_name.nil?
        sumo[:source] = @source_name
      end

      unless @source_host.nil?
        sumo[:host] = @source_host
      end

      record
    end
  end
end
