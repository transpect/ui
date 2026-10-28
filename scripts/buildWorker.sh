#!/bin/bash

WORKERID=$1
SVNPATH=$2
REV=$3
SVNUSER=$4
SVNPW=$5

echo "WORKERID=[$WORKERID]"

set -xe
cd ..
source .env
docker build --build-arg BASEX_ADMIN_PASSWORD=$BASEX_ADMIN_PASSWORD --build-arg WORKER_ID=$WORKERID --build-arg SVNPATH=$SVNPATH --build-arg REV=$REV --build-arg SVNUSER=$SVNUSER --build-arg SVNPW=$SVNPW -t transpectui_$WORKERID -f docker/worker/Dockerfile .
docker rmi $(docker images -f "dangling=true" -q)
