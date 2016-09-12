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
      parts = tag.split('_')
      # gives you: ["containers.mnt.log.containers.rabbitmq-2862264727-393n0", "td-integration", "master-7c9d336c240d2238c8030c06310a2a0579d69d906f73ff06731373b1f820b99b.log"]
      pod = parts[0].split('.').last
      namespace = parts[1]
      container_name = parts[0].split('-')[0..-2].join('-') 
      replica_set = pod.split('-')[0..-2].join('-')
      tag = "kubernetes.#{namespace}.#{replica_set}.#{container_name}.#{pod}"

      es.each do |time, record|
        data = {
          'namespace' => namespace,
          'container_name' => container_name,
          'replica_set' => replica_set
        }.merge(record)

        data['log'].strip!
        data['message'] = data.delete('log')

        if not data['message'] == '' then
          # We only care about non-empty logs
          router.emit(tag, time, data)
        end
      end

      chain.next
    end
  end
end
