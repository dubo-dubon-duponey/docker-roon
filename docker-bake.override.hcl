group "default" {
  targets = ["bridge", "server"]
}

target "bridge" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Roon Bridge"
    BUILD_DESCRIPTION = "A dubo image for Roon Bridge"
  }
  tags = [
    "dubodubonduponey/roon-bridge",
  ]
  platforms = [
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
  ]
  target = "runtime-bridge"
}

target "server" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Roon Server"
    BUILD_DESCRIPTION = "A dubo image for Roon Server"
  }
  tags = [
    "dubodubonduponey/roon-server",
  ]
  # No v6 with Plex
  platforms = [
    "linux/amd64",
  ]
  target = "runtime-server"
}
