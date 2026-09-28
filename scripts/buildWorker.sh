#!/bin/bash

WORKERID=$1

echo "WORKERID=[$WORKERID]"

set -xe
cd ..
source .env
DOCKER_BUILDKIT=0 docker build --build-arg CONVERTER_XML=$(find code/$WORKERID -name converter.xml) --build-arg BASEX_ADMIN_PASSWORD=$BASEX_ADMIN_PASSWORD --build-arg WORKER_ID=$WORKERID -t transpectui_$WORKERID -f docker/worker/Dockerfile .
docker rmi $(docker images -f "dangling=true" -q)
