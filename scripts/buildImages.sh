#!/bin/bash
set -xe
cd ..
source .env
docker build --build-arg BASEX_ADMIN_PASSWORD=$BASEX_ADMIN_PASSWORD -t transpectui -f docker/Dockerfile .
docker rmi $(docker images -f "dangling=true" -q)
