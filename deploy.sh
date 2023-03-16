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
