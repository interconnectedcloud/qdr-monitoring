#!/bin/bash

# Change the namespace to that of your project
NAMESPACE=${1:-myproject}
ISOCP=false

# Get the current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Test if running against an OpenShift cluster
kubectl get route > /dev/null 2>&1
[[ $? -eq 0 ]] && ISOCP=true

# Prometheus / Alertmanager
kubectl apply -f $DIR/monitoring/alerting-interconnect.yaml -n $NAMESPACE
cat $DIR/monitoring/prometheus.yaml | sed "s/myproject/${NAMESPACE}/g" | kubectl apply -n $NAMESPACE -f -
kubectl apply -f $DIR/monitoring/alertmanager.yaml -n $NAMESPACE
kubectl expose service/prometheus -n $NAMESPACE

echo "Waiting for Prometheus server to be ready..."
kubectl rollout status deployment/prometheus -w -n $NAMESPACE
kubectl rollout status deployment/alertmanager -w -n $NAMESPACE
echo "...Prometheus server ready"
if $ISOCP; then
    kubectl create -f $DIR/monitoring/route-alertmanager.yaml -n $NAMESPACE
    kubectl create -f $DIR/monitoring/route-prometheus.yaml -n $NAMESPACE
fi

# Preparing Grafana datasource and dashboards
sed -e "s/myproject/${NAMESPACE}/g" $DIR/monitoring/grafana-dashboard-provider.yaml > $DIR/monitoring/grafana-dashboard-provider.yaml.updated
kubectl create configmap grafana-config \
    --from-file=datasource.yaml=$DIR/monitoring/dashboards/datasource.yaml \
    --from-file=grafana-dashboard-provider.yaml=$DIR/monitoring/grafana-dashboard-provider.yaml.updated \
    --from-file=interconnect-dashboard.json=$DIR/monitoring/dashboards/interconnect-raw.json \
    --from-file=interconnect-dashboard-delayed.json=$DIR/monitoring/dashboards/interconnect-delayed.json \
    -n $NAMESPACE

# Grafana
kubectl apply -f $DIR/monitoring/grafana.yaml -n $NAMESPACE
kubectl expose service/grafana -n $NAMESPACE

echo "Waiting for Grafana server to be ready..."
kubectl rollout status deployment/grafana -w -n $NAMESPACE
if $ISOCP; then
    kubectl create -f $DIR/monitoring/route-grafana.yaml -n $NAMESPACE
fi

echo "...Grafana server ready"
