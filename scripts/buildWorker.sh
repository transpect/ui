#!/bin/bash

WORKERID=$1

set -xe
cd ..
source .env
docker build --build-arg CONVERTER_XML=$(find code/${WORKDERID} -name converter.xml) --build-arg BASEX_ADMIN_PASSWORD=$BASEX_ADMIN_PASSWORD --build-arg WORKER_ID=$WORKERID -t transpectui_$WORKERID -f docker/worker/Dockerfile .
docker rmi $(docker images -f "dangling=true" -q)
