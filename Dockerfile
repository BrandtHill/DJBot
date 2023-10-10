FROM alpine

RUN apk upgrade --no-cache && \
    apk add --no-cache bash openssl libgcc libstdc++ ncurses-libs ffmpeg python3 && \
    python3 -m ensurepip && \
    pip3 install --no-cache --upgrade pip && \
    pip3 install --user -U streamlink && \
    pip3 install --user -U yt-dlp

WORKDIR /app
COPY ./_build/prod/rel/djbot ./

ENTRYPOINT [ "./bin/djbot" ]
CMD ["start"]