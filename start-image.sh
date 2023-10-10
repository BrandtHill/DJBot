#!/usr/bin/env bash

docker stop djbot

docker rm djbot

sed -e 's/^export //g' -e '/"//g' .env > .env.docker

docker run -d --log-opt max-size=5m --network host --volume /home/brandt/music:/mus --env-file .env.docker --restart always --name djbot brandt/djbot
