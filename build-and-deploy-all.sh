#!/bin/bash

set -e

pushd efferent-web
./build-and-deploy.sh
popd

pushd layout-web
./build-and-deploy.sh
popd

pushd social-feed-web
./build-and-deploy.sh
popd

pushd gateway
kubectl apply -f gateway.yaml
kubectl apply -f snippets-filter.yaml
popd

kubectl rollout restart deployment ngf-nginx-gateway-fabric
kubectl rollout restart deployment web-gw-nginx
