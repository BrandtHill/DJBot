#!/usr/bin/env bash

# docker run --rm -i -v "`pwd`/:/app" -w "/app" elixir:1.19-alpine3.19 sh -c "apk add git && mix local.hex --force && mix local.rebar --force && mix deps.get && mix deps.compile && MIX_ENV=prod mix release --overwrite"

docker build --no-cache -t "brandt/djbot:latest" .
