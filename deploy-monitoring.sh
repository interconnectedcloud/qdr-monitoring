#!/bin/bash

# Change the namespace to that of your project
NAMESPACE=myproject

# Get the current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Prometheus / Alertmanager
kubectl apply -f $DIR/monitoring/alerting-interconnect.yaml -n $NAMESPACE
kubectl apply -f $DIR/monitoring/prometheus.yaml -n $NAMESPACE
kubectl apply -f $DIR/monitoring/alertmanager.yaml -n $NAMESPACE
kubectl expose service/prometheus -n $NAMESPACE

echo "Waiting for Prometheus server to be ready..."
kubectl rollout status deployment/prometheus -w -n $NAMESPACE
kubectl rollout status deployment/alertmanager -w -n $NAMESPACE
echo "...Prometheus server ready"
kubectl create -f $DIR/monitoring/route-alertmanager.yaml -n $NAMESPACE
kubectl create -f $DIR/monitoring/route-prometheus.yaml -n $NAMESPACE

# Preparing Grafana datasource and dashboards
kubectl create configmap grafana-config \
    --from-file=datasource.yaml=$DIR/monitoring/dashboards/datasource.yaml \
    --from-file=grafana-dashboard-provider.yaml=$DIR/monitoring/grafana-dashboard-provider.yaml \
    --from-file=interconnect-dashboard.json=$DIR/monitoring/dashboards/interconnect-raw.json \
    --from-file=interconnect-dashboard-delayed.json=$DIR/monitoring/dashboards/interconnect-delayed.json \
    -n $NAMESPACE

# Grafana
kubectl apply -f $DIR/monitoring/grafana.yaml -n $NAMESPACE
kubectl expose service/grafana -n $NAMESPACE

echo "Waiting for Grafana server to be ready..."
kubectl rollout status deployment/grafana -w -n $NAMESPACE
kubectl create -f $DIR/monitoring/route-grafana.yaml -n $NAMESPACE

echo "...Grafana server ready"
