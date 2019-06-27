# What

Docker images for Roon Bridge (armv7, arm64 and amd64) & Roon Server (amd64), based on debian:buster-slim

## Run

```
docker run -d \
    --net host \
    --device /dev/snd \
    dubodubonduponey/audio-roon-bridge:v1

docker run -d \
    --net host \
    --device /dev/snd \
    dubodubonduponey/audio-roon-server:v1
```

## Notes

### Building your own

```
# In case you want to download the latest from Roon servers
# ./refresh.sh

# Build & push
IMAGE_OWNER=you ./build.sh
```

### Roon packages version

The builder uses the packages stored under `cache`.

If you want to rebuild with fresh versions, call the `./refresh.sh` script first 
to redownload from Roon servers.

### Alpine

This is currently running on Debian.

Moving to Alpine presents a serie of challenges.

 * I first tried using gcompat. Past a linker name mismatch, mono-gen will just SIGBUS.
 * I then tried to cross-compile mono (using qemu). This failed as well with some obscure ARM syscall apparently being not implemented in qemu.

At this time, ncopa just enabled armv7 for mono (https://git.alpinelinux.org/aports/tree/testing/mono/APKBUILD): https://pkgs.alpinelinux.org/package/edge/testing/armv7/mono

Whether you can use it as a drop-in replacement for Roon embedded Mono is yet to be determined.
Assuming this would work, it's unclear also if gcompat would still be necessary.
