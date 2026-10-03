// Caddy "lite" build: core plugins only.
package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	_ "github.com/caddyserver/caddy/v2/modules/standard"

	_ "github.com/abiosoft/caddy-hmac"
	_ "github.com/caddy-dns/cloudflare"
	_ "github.com/caddyserver/transform-encoder"
	_ "github.com/ewen-lbh/caddy-i18n"
	_ "github.com/fvbommel/caddy-combine-ip-ranges"
	_ "github.com/lolPants/caddy-requestid"
	_ "github.com/mholt/caddy-l4"
	_ "github.com/porech/caddy-maxmind-geolocation"
	_ "pkg.jsn.cam/caddy-defender"
)

func main() {
	caddycmd.Main()
}
