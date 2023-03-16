#!/bin/sh
mkdir build || true
kubectl port-forward --namespace default svc/elasticsearch-master 9200:9200 > build/elasticsearch.log 2>&1 &
curl http://localhost:9200

while [ $? -ne 0 ]; do
    kubectl port-forward --namespace default svc/elasticsearch-master 9200:9200 > build/elasticsearch.log 2>&1 &
    curl http://localhost:9200
    sleep 5
done
