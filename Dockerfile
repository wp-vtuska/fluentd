FROM fluent/fluentd:latest
WORKDIR /home/fluent
ENV PATH /home/fluent/.gem/ruby/2.3.0/bin:$PATH

USER root

RUN apk --no-cache --update add sudo build-base ruby-dev libffi-dev && \
    sudo -u fluent gem install fluent-plugin-record-reformer fluent-plugin-kubernetes_metadata_filter && \
    rm -rf /home/fluent/.gem/ruby/2.3.0/cache/*.gem && sudo -u fluent gem sources -c && \
    apk del sudo build-base ruby-dev && rm -rf /var/cache/apk/*

RUN mkdir -p /mnt/pos
EXPOSE 24284

RUN mkdir -p /fluentd/conf.d && \
    mkdir -p /fluentd/etc && \
    mkdir -p /fluentd/plugins

# Default settings
ENV SUMO_LOG_FORMAT "json"
ENV SUMO_FLUSH_INTERVAL "30s"
ENV SUMO_NUM_THREADS "1"
ENV SUMO_SOURCE_CATEGORY "%{namespace}/%{pod_name}"
ENV SUMO_SOURCE_CATEGORY_PREFIX "kubernetes/"
ENV SUMO_SOURCE_CATEGORY_REPLACE_DASH "/"
ENV SUMO_SOURCE_NAME "%{namespace}.%{pod}.%{container}"

COPY ./conf.d/* /fluentd/conf.d/
COPY ./etc/* /fluentd/etc/
COPY ./plugins/* /fluentd/plugins/

CMD exec fluentd -c /fluentd/etc/$FLUENTD_CONF -p /fluentd/plugins $FLUENTD_OPT
