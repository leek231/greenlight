#!/bin/bash

docker-compose down
./scripts/image_build.sh bigbluebutton release-v2
docker-compose up -d