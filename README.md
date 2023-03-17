# System Juliet Logging

This project represents Elasticsearch as run on Kubernetes via Helm, as a part of the overall https://github.com/jvalentino/sys-juliet project. For system details, please see that location.

Prerequisites

- Git
- Helm
- Minikube

All of these you can get in one command using this installation automation (if you are on a Mac): https://github.com/jvalentino/setup-automation

## Stack

Elasticsearch

> Elasticsearch is a search engine based on the Lucene library. It provides a distributed, multitenant-capable full-text search engine with an HTTP web interface and schema-free JSON documents. Elasticsearch is developed in Java and is released as open source under the terms of the Apache License. Official clients are available in Java, .NET (C#), PHP, Python, Apache Groovy, Ruby and many other languages. According to the DB-Engines ranking, Elasticsearch is the most popular enterprise search engine followed by Apache Solr, also based on Lucene.

https://en.wikipedia.org/wiki/Elasticsearch

## Deployment

Prerequisites

- None - You can launch the apps later and they will start logging here

To re-install it, forward ports, and then verify it worked, use:

```bash
./deploy.sh
```

...which automatically runs the verifyication script to forward ports.

### deploy.sh

```bash
#!/bin/sh
minikube addons enable default-storageclass
minikube addons enable storage-provisioner

helm repo add elastic https://helm.elastic.co
helm delete --wait elasticsearch || true

helm install \
    --set replicas=1 \
    --set discovery.type=single-node \
    --wait --timeout=1200s \
    elasticsearch elastic/elasticsearch --values ./config/helm/elastic/values.yaml

sh -x ./verify.sh
```

### verify.sh

```bash
#!/bin/sh
mkdir build || true
kubectl port-forward --namespace default svc/elasticsearch-master 9200:9200 > build/elasticsearch.log 2>&1 &
curl http://localhost:9200

while [ $? -ne 0 ]; do
    kubectl port-forward --namespace default svc/elasticsearch-master 9200:9200 > build/elasticsearch.log 2>&1 &
    curl http://localhost:9200
    sleep 5
done
```

Forwarding ports is not an exact science in k8s, thus the while-loop.

## Configuration

The configuration of Elasticsearch is complicated enough to where I had to provide my own entire configuration, which can be found in `config/helm/elastic/values.yaml`. Consider that this Helm configuration is an abstraction on top of the actual Elasticsearch configuration, where I specifically:

- Run 1 node instead of multiple
- Gave it enough memory to actually run
- Disable login
- Run on HTTP instead of HTTPS
- Change health to allow yellow, because a single node will never show as green because of sharding and replication magic

The result is:

**values.yml**

The result is:

```yaml
# Permit co-located instances for solitary minikube virtual machines.
antiAffinity: "soft"

# Shrink default JVM heap.
esJavaOpts: "-Xmx1g -Xms1g"

clusterHealthCheckParams: "wait_for_status=yellow&timeout=1s"

esConfig:
  elasticsearch.yml: |
    xpack.security.enabled: false
    xpack.security.enrollment.enabled: false


createCert: false
secret:
  enabled: true
  password: "password" 
protocol: http

networkPolicy:
  http:
    enabled: true


# Allocate smaller chunks of memory per pod.
resources:
  requests:
    cpu: "100m"
    memory: "1024M"
  limits:
    cpu: "1000m"
    memory: "2048M"

# Request smaller persistent volumes.
volumeClaimTemplate:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: "standard"
  resources:
    requests:
      storage: 1024M
```

## Runtime

### Kubernetes Dashboard

Since ES involves storage, it will show as a Stateful Set if it is working:[
![01](https://github.com/jvalentino/sys-golf/raw/main/wiki/09.png)](https://github.com/jvalentino/sys-golf/blob/main/wiki/09.png)

### Cluster Health

The health endpoint can be reached at http://localhost:9200/_cluster/health?pretty, where we expect it to be yellow because we only have one instance:

```json
{
  "cluster_name" : "elasticsearch",
  "status" : "yellow",
  "timed_out" : false,
  "number_of_nodes" : 1,
  "number_of_data_nodes" : 1,
  "active_primary_shards" : 12,
  "active_shards" : 12,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 3,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 80.0
}
```

### General Information

The root page will also give you general cluster information at [http://localhost:9200](http://localhost:9200/)

```json
{
  "name" : "elasticsearch-master-0",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "I8YhfPVWQ5iik9D7zVOiKA",
  "version" : {
    "number" : "8.5.1",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "c1310c45fc534583afe2c1c03046491efba2bba2",
    "build_date" : "2022-11-09T21:02:20.169855900Z",
    "build_snapshot" : false,
    "lucene_version" : "9.4.1",
    "minimum_wire_compatibility_version" : "7.17.0",
    "minimum_index_compatibility_version" : "7.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

### Index Health

http://localhost:9200/_cat/indices is useful to see what all index information is being put in elastic search, which when all the applications are running will look like this:

```
yellow open sys-rest-doc  8WyyN3YGSFCSRj8cm8iyQg 1 1 320634 0  24.3mb  24.3mb
yellow open sys-ui-bff    CyfNZhXpRJKwJLknRrex2A 1 1  63185 0   6.6mb   6.6mb
yellow open sys-rest-user rABrzJhHSTWtnOzPp_TAIA 1 1    930 0     2mb     2mb
yellow open sys-etl       WrL-Ma9JQEuU697zS0nRRg 1 1   1095 0   3.7mb   3.7mb
yellow open sys-ui        mm-1egv7R5ehRKAayJjNbA 1 1  12364 0 609.6kb 609.6kb
```

