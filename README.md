# fluentd
This is a [fluentd](http://www.fluentd.org/) container, designed to be run on a kubernetes [DaemonSet](http://kubernetes.io/docs/admin/daemons/).  This means we will run an instance of this container on each physical underlying host.  The goal is to pull all the kubelet, docker daemon and container logs from the host then to ship them off to [SumoLogic](https://www.sumologic.com/) in json format.

## Setup
### SumoLogic
First things first, you need a HTTP collector in SumoLogic that the container can send logs to.  I'm presuming a certain level of SumoLogic knowledge here:

In Sumo, `Manage -> Collection -> Add Collector -> Hosted Collector`

Then you need to add a source to that collector, which would be a new `HTTP source`. This will give you a unique URL that you can use to send logs to.

We're interested in the last bit:

For Example: https://endpoint1.collection.us2.sumologic.com/receiver/v1/http/**somelongbase64hashthingthatgetsgenerated**

### Kubernetes
We need to then save that secret, as a secret, into kubernetes.

```
echo -n "somelongbase64hashthingthatgetsgenerated" > collector-id
kubectl create secret generic sumologic-credentials --from-file=collector-id
```

And finally, you need to deploy the container.  I will presume you have your own CI/CD setup, and you can use the kubernetes example in [kubernetes/fluentd.daemon.yml](kubernetes/fluentd.daemon.yml)

## Logs, Yay
Simple as that really, your logs should be getting streamed to SumoLogic in JSON format.  Use the `json` parser to extract the fields, for example `_collector=gcp-test-collector | json auto`

### Docker
![Docker Logs](/screenshots/docker.png)

### Kubelet
![Docker Logs](/screenshots/kubelet.png)

### Containers
![Docker Logs](/screenshots/container.png)