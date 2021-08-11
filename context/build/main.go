package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	_ "github.com/caddyserver/replace-response"
)

func main() {
	caddycmd.EnableTelemetry = false
	caddycmd.Run()
}
