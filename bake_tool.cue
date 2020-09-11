package bake

command: {
  bridge: #Dubo & {
    target: "runtime-bridge"
    args: {
      BUILD_TITLE: "Roon Bridge"
      BUILD_DESCRIPTION: "A dubo image for Roon Bridge based on \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
    }

    platforms: [
      AMD64,
      ARM64,
      V7,
    ]
  }

  server: #Dubo & {
    target: "runtime-server"
    args: {
      BUILD_TITLE: "Roon Server"
      BUILD_DESCRIPTION: "A dubo image for Roon Server based on \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
    }

    platforms: [
      AMD64,
    ]
  }
}
