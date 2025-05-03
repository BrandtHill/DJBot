FROM alpine

RUN apk upgrade --no-cache && \
    apk add --no-cache bash openssl libgcc libstdc++ ncurses-libs ffmpeg python3 && \
    apk add pipx && \
    pipx ensurepath && \
    pipx install streamlink && \
    pipx install yt-dlp

ENV PATH="${PATH}:/root/.local/bin"

WORKDIR /app
COPY ./_build/prod/rel/djbot ./

ENTRYPOINT [ "./bin/djbot" ]
CMD ["start"]
