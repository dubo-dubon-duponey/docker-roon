# What

This is a RoonBridge container for armv7, based on debian:stretch-slim

## Run

```
docker run -d \
    --net host \
    --device /dev/snd \
    dubodubonduponey/audio-raat:v1
```

## Notes

### RoonBridge version

Note that the download url of RoonBridge is not versioned, and you will get whatever they put online at that time.

### Alpine

If you want to run this on alpine, I tried and failed.

I first tried using gcompat. Past a linker name mismatch, mono-gen will just SIGBUS.

I then tried to cross-compile mono (qemu). This failed as well with some obscure ARM syscall failing in qemu.

At this time, ncopa just enabled armv7 for mono (https://git.alpinelinux.org/aports/tree/testing/mono/APKBUILD) albeit the package is not yet there
and my own try at compiling it failed (possibly need an additional patch for arm).

If you are interested in trying, I would suggest to get mono to build on armv7 first, then rip out RoonBridge embedded mono.
Whether gcompat would still be necessary is unclear.

### Multi-arch

Ideally, this should be a proper multi-arch image.

The only thing TBD is to map buildx target platform to the appropriate RoonBridge download url.

Something in the line of:

```
FROM --platform=$BUILDPLATFORM alpine:3.9 AS build
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM" > /log
FROM alpine
COPY --from=build /log /log
```

Feel free to submit a PR, as my interest is solely on armv7 for now.

## TODO

 * multi-arch
 * move to alpine
 * store pinned version of RoonBridge
