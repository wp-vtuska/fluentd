# fluentd
This is a [fluentd](http://www.fluentd.org/) container, designed to run as a kubernetes [DaemonSet](http://kubernetes.io/docs/admin/daemons/). This means it will run an instance of this container on each physical underlying host in the cluster. The goal is to pull all the kubelet, docker daemon and container logs from the host then to ship them off to [SumoLogic](https://www.sumologic.com/) in json or text format.

## Setup
### SumoLogic
First things first, you need a HTTP collector in SumoLogic that the container can send logs to.  I'm presuming a certain level of SumoLogic knowledge here:

In Sumo, `Manage -> Collection -> Add Collector -> Hosted Collector`

Then you need to add a source to that collector, which would be a new `HTTP source`. This will give you a unique URL that can receive logs.

More details here: http://help.sumologic.com/Send_Data/Sources/HTTP_Source

### Kubernetes
We need to then save that url as a secret in kubernetes.

```
kubectl create secret generic sumologic-endpoint --from-literal=endpoint=<INSERT_HTTP_URL>
```

And finally, you need to deploy the container.  I will presume you have your own CI/CD setup, and you can use the kubernetes example in [kubernetes/fluentd.daemon.yml](kubernetes/fluentd.daemon.yml)

## Options

The following options environment settings are available on the daemonset container

* `LOG_FORMAT` - Format to post logs into Sumo. `json` or `text` (default `json`)
  * text - logs will appear in SumoLogic in text format
  * json - Logs will appear in SumoLogic in json format IE
  * merge_json_log - Send the log in json format but merge the keys from `log` at the root level and delete `log` (Useful if your app logs in json format)
* `FLUSH_INTERVAL` - How frequently to push logs to SumoLogic (default `5s`)
* `NUM_THREADS` - Increase number of threads in heavy logging clusters (default `1`)
* `SOURCE_NAME` - Set the `_sourceName` metadata field in SumoLogic. (Default `"%{namespace}.%{pod}.%{container}"`)
* `SOURCE_CATEGORY` - Can be used to pass the access ID instead of passing it in as a commandline argument.
* `SOURCE_CATEGORY_REPLACE_DASH` - Can be used to pass the access ID instead of passing it in as a commandline argument.

The `LOG_FORMAT`, `SOURCE_CATEGORY` and `SOURCE_NAME` can be overridden per pod using [annotations](http://kubernetes.io/v1.0/docs/user-guide/annotations.html). For example

```
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    app: mywebsite
  template:
    metadata:
      name: nginx
      labels:
        app: mywebsite
      annotations:
        sumologic.com/format: "text"
        sumologic.com/sourceCategory: "mywebsite/nginx"
        sumologic.com/sourceName: "mywebsite_nginx"
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

## Logs, Yay
Simple as that really, your logs should be getting streamed to SumoLogic in json or text format with the approipate metadata. If using `json` format you can auto extract fields, for example `_sourceCategory=some/app | json auto`

### Docker
![Docker Logs](/screenshots/docker.png)

### Kubelet
![Docker Logs](/screenshots/kubelet.png)

### Containers
![Docker Logs](/screenshots/container.png)
