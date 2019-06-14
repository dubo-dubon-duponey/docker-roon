FROM debian:stretch-slim AS raat-debian
MAINTAINER dubo-dubon-duponey

RUN apt-get update -y && apt-get install -y curl bzip2 libasound2

RUN mkdir /build
WORKDIR /build

RUN curl -fsSL -o rb.tar.bz2  "http://download.roonlabs.com/builds/RoonBridge_linuxarmv7hf.tar.bz2"
RUN tar -xjf rb.tar.bz2

WORKDIR /build/RoonBridge

ENTRYPOINT [ "./Bridge/RoonBridge" ]
