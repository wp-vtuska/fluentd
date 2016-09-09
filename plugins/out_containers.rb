require 'fluent/filter'

module Fluent
  class ContainerOutput < Output
    # Register type
    Fluent::Plugin.register_output('container_format', self)

    # To support Fluentd v0.10.57 or earlier
    unless method_defined?(:router)
      define_method("router") { Fluent::Engine }
    end

    def configure(conf)
      super
    end

    def emit(tag, es, chain)
      # tag example: containers.mnt.log.containers.rabbitmq-2862264727-393n0_td-integration_master-7c9d336c240d2238c8030c06310a2a0579d69d906f73ff06731373b1f820b99b.log
      tag = tag.split('.')[4].split('-')[0..-2].join('-')
      es.each do |time, record|
        record['log'] = record['log'].strip
        router.emit(tag, time, record)
      end

      chain.next
    end
  end
end
