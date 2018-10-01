FROM alpine:latest
RUN apk --update add curl gcc libc-dev lua5.1 lua5.1-dev luarocks5.1 p7zip
RUN luarocks-5.1 install penlight
WORKDIR /src
