# What

Two Docker images for Roon Bridge & Roon Server.

Bonus / extra features:
 * roon display is served over TLS and announced under mDNS
 * logs are exposed on stdout

## DISCLAIMER

* this is an UNOFFICIAL image, and is NOT produced, endorsed nor supported by [Roon Labs](https://roonlabs.com/)
* if you are a newcomer, if you expect any kind of support, or simply any guarantee that Roon will work, do yourself a huge favor: just use one of the [official Roon downloads](https://roonlabs.com/downloads)
* if you are using this and have an issue with it, you are on your own
* if you are still here, and plan on using this, and while we try to make this simple to use, you should still have some reasonable understanding and familiarity with:
  * docker overall
  * linux sound sub-system
  * networking

## Image features

 * multi-architecture:
    * [x] linux/amd64
    * [x] linux/arm64 (bridge only)
    * [x] linux/arm/v7 (bridge only)
 * hardened:
    * [x] image runs read-only
    * [x] image runs with no capabilities
    * [x] process runs as a non-root user, disabled login, no shell
 * lightweight
    * [x] based on our slim [Debian Bullseye](https://github.com/dubo-dubon-duponey/docker-debian)
    * [x] simple entrypoint script
    * [ ] multi-stage build with no installed dependencies for the Bridge runtime image, one dependency for Server (ffmpeg)
 * observable
    * [ ] healthcheck (server only)
    * [x] log to stdout

## Run

```bash
docker run -d \
    --net host \
    --name bridge \
    --read-only \
    --cap-drop ALL \
    --group-add audio \
    --device /dev/snd \
    --rm \
    docker.io/dubodubonduponey/roon:bridge-latest

docker run -d \
    --net host \
    --name server \
    --read-only \
    --cap-drop ALL \
    --cap-add NET_BIND_SERVICE \
    --rm \
    docker.io/dubodubonduponey/roon:server-latest
```

## GOTCHA

Debian by default limits inotify watches to 8192, which might turns out to be too little.

You probably want to bump that up to prevent your system from crashing / rebooting...

Typically, **on the host**:

```bash
echo "fs.inotify.max_user_watches = 1048576" > /etc/sysctl.conf
echo 1048576 > /proc/sys/fs/inotify/max_user_watches
```

## Notes

### Roon packages version

The builder uses the packages stored under `cache`.

If you want to rebuild with fresh versions, call the `./refresh.sh` script first 
to (re)-download from Roon servers.

### Alpine

This is currently running on Debian, and I have no intention in trying again to make this work on Alpine.

If you do, here are some notes:

 * I first tried using gcompat. Past a linker name mismatch, mono-gen will just SIGBUS.
 * I then tried to cross-compile mono (using qemu). This failed as well with some obscure ARM syscall apparently being not implemented in qemu.

At this time, ncopa just enabled armv7 for mono (https://git.alpinelinux.org/aports/tree/testing/mono/APKBUILD): https://pkgs.alpinelinux.org/package/edge/testing/armv7/mono

Whether you can use it as a drop-in replacement for Roon embedded Mono is yet to be determined.
Assuming this would work, it's unclear also if gcompat would still be necessary.

## Moar?

See [DEVELOP.md](DEVELOP.md)
