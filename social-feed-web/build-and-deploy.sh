#!/bin/bash

pushd application

docker build -t localhost:5001/social-feed-web:latest .
docker push localhost:5001/social-feed-web:latest

popd
pushd helm

helm upgrade --install social-feed-web . --namespace default && kubectl rollout restart deployment social-feed-web

