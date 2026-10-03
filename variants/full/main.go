// Caddy "full" build: lite plugins plus caching, crowdsec, webdav and docker-proxy.
package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	_ "github.com/caddyserver/caddy/v2/modules/standard"

	_ "github.com/WeidiDeng/caddy-cloudflare-ip"
	_ "github.com/abiosoft/caddy-hmac"
	_ "github.com/caddy-dns/cloudflare"
	_ "github.com/caddyserver/cache-handler"
	_ "github.com/caddyserver/transform-encoder"
	_ "github.com/darkweak/storages/otter/caddy"
	_ "github.com/ewen-lbh/caddy-i18n"
	_ "github.com/fvbommel/caddy-combine-ip-ranges"
	_ "github.com/hslatman/caddy-crowdsec-bouncer/http"
	_ "github.com/hslatman/caddy-crowdsec-bouncer/layer4"
	_ "github.com/lolPants/caddy-requestid"
	_ "github.com/lucaslorentz/caddy-docker-proxy/v2"
	_ "github.com/mholt/caddy-l4"
	_ "github.com/mholt/caddy-webdav"
	_ "github.com/porech/caddy-maxmind-geolocation"
	_ "pkg.jsn.cam/caddy-defender"
)

func main() {
	caddycmd.Main()
}
