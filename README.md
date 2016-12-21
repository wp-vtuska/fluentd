# fluentd
This is a [fluentd](http://www.fluentd.org/) container, designed to run as a kubernetes [DaemonSet](http://kubernetes.io/docs/admin/daemons/). It will run an instance of this container on each physical underlying host in the cluster. The goal is to pull all the kubelet, docker daemon and container logs from the host then to ship them off to [SumoLogic](https://www.sumologic.com/) in json or text format.

# THIS REPOSITORY HAS MOVED
This repository is now hosted under SumoLogic's GitHub Community.

Located here [https://github.com/SumoLogic/fluentd-kubernetes-sumologic](https://github.com/SumoLogic/fluentd-kubernetes-sumologic)
