# What

Two Docker images for Roon Bridge & Roon Server

## Image features

 * multi-architecture:
    * [x] linux/amd64
    * [ ] linux/arm64 (bridge only)
    * [ ] linux/arm/v7 (bridge only)
    * [ ] ~~linux/arm/v6~~
 * hardened:
    * [x] image runs read-only
    * [x] image runs with no capabilities
    * [x] process runs as a non-root user, disabled login, no shell
 * lightweight
    * [x] based on `debian:buster-slim`
    * [x] simple entrypoint script
    * [ ] multi-stage build with no installed dependencies for the Bridge runtime image, one dependency for Server:
      * ffmpeg
 * observable
    * [ ] healthcheck (server only)
    * [✓] log to stdout
    * [ ] ~~prometheus endpoint~~


## Run

```bash
docker run -d \
    --net host \
    --device /dev/snd \
    dubodubonduponey/roon-bridge:v1

docker run -d \
    --net host \
    --device /dev/snd \
    dubodubonduponey/roon-server:v1
```

## GOTCHA

Debian by default limits inotify watches to 8192, which might turns out to be too little.

You probably want to bump that up to prevent your system from crashing / rebooting...

Typically, on the host:

```bash
echo "fs.inotify.max_user_watches = 1048576" > /etc/sysctl.conf
echo 1048576 > /proc/sys/fs/inotify/max_user_watches
```

## Notes

### Building your own

```bash
# In case you want to download the latest from Roon servers
# ./refresh.sh

# Build & push
VENDOR=you ./build.sh
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
