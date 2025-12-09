#!/bin/bash

pushd application

docker build -t localhost:5001/layout-web:latest .
docker push localhost:5001/layout-web:latest

popd
pushd helm

helm upgrade --install layout-web . --namespace default && kubectl rollout restart deployment layout-web

