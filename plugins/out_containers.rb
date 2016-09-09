require 'fluent/filter'

module Fluent
  class ContainerOutput < Output
    # Register type
    Fluent::Plugin.register_output('container_format', self)

    def configure(conf)
      super
    end

    def emit(tag, es, chain)
      $stdout.puts tag
      #tag = kubernetes.${tag_suffix[4].split('-')[0..-2].join('-')}
      es.each do |time, record|
        record.log = record.log.strip
        Engine.emit(tag, time, record)
      end

      chain.next
    end
  end
end
