#!/bin/bash

set -xe
cd ..
source .env
DOCKER_BUILDKIT=0 docker build --build-arg BASEX_ADMIN_PASSWORD=$BASEX_ADMIN_PASSWORD -t transpectui_floormanager -f docker/floormanager/Dockerfile .
docker rmi $(docker images -f "dangling=true" -q)
