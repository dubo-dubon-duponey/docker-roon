package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)


cakes: {
  bridge: scullery.#Cake & {
		recipe: {
			input: {
				from: {
					registry: * "ghcr.io/dubo-dubon-duponey" | string
				}
			}

			process: {
		    target: "runtime-bridge"
				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
					types.#Platforms.#V7,
				]
			}

			output: {
				images: {
					names: [...string] | * ["roon"],
					tags: [...string] | * ["bridge-latest"]
				}
			}

			metadata: {
				title: string | * "Dubo Roon Bridge",
				description: string | * "A dubo image for Roon Bridge",
			}
		}
  }

  server: scullery.#Cake & {
		recipe: {
			input: {
				from: {
					registry: * "ghcr.io/dubo-dubon-duponey" | string
				}
			}

			process: {
		    target: "runtime-server"
				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
				]
			}

			output: {
				images: {
					names: [...string] | * ["roon"],
					tags: [...string] | * ["server-latest"]
				}
			}

			metadata: {
				title: string | * "Dubo Roon Server",
				description: string | * "A dubo image for Roon Server",
			}
		}
  }
}

injectors: {
	suite: * "bullseye" | =~ "^(?:jessie|stretch|buster|bullseye|sid)$" @tag(suite, type=string)
	date: * "2021-08-01" | =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" @tag(date, type=string)
	platforms: string @tag(platforms, type=string)
	registry: * "registry.local" | string @tag(registry, type=string)
}

override: {
	input: from: registry: injectors.registry


	metadata: ref_name: injectors.suite + "-" + injectors.date
}

cakes: bridge: recipe: override
cakes: server: recipe: override

if injectors.platforms != _|_ {
	cakes: bridge: recipe: process: platforms: strings.Split(injectors.platforms, ",")
}

cakes: bridge: recipe: output: images: tags: ["bridge-" + injectors.suite + "-" + injectors.date, "bridge-" + injectors.suite + "-latest", "bridge-latest"]
cakes: server: recipe: output: images: tags: ["server-" + injectors.suite + "-" + injectors.date, "server-" + injectors.suite + "-latest", "server-latest"]

// Allow hooking-in a UserDefined environment as icing
UserDefined: scullery.#Icing

cakes: bridge: icing: UserDefined
cakes: server: icing: UserDefined
