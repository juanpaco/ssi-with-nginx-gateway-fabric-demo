#!/bin/bash

pushd application

docker build -t localhost:5001/efferent-web:latest .
docker push localhost:5001/efferent-web:latest

popd
pushd helm

helm upgrade --install efferent-web . --namespace default && kubectl rollout restart deployment efferent-web

