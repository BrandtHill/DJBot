FROM elixir:1.19-alpine AS build

ENV MIX_ENV=prod
WORKDIR /app

RUN apk add --no-cache git

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY . .

RUN mix release --overwrite

FROM elixir:1.19-alpine

WORKDIR /app

RUN apk add --no-cache \
    openssl \
    libgcc \
    libstdc++ \
    ncurses-libs \
    ffmpeg \
    python3 \
    bash \
    pipx

RUN pipx ensurepath && \
    pipx install streamlink && \
    pipx install yt-dlp

ENV PATH="/root/.local/bin:${PATH}"
ENV MIX_ENV=prod

COPY --from=build /app/_build/prod/rel/djbot ./

ENTRYPOINT ["./bin/djbot"]
CMD ["start"]
