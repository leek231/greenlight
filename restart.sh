#!/bin/bash

docker-compose down
./scripts/image_build.sh webinar release-v2
docker-compose up -d