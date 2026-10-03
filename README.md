# caddy

Custom [Caddy](https://caddyserver.com) builds with plugins, published to `ghcr.io/channinghe/caddy`.

- Distroless (`gcr.io/distroless/static-debian13:nonroot`), runs as uid/gid `65532`
- `linux/amd64` + `linux/arm64`
- Every input pinned (Go modules via `go.sum`, images by digest, actions by SHA) and kept fresh by Renovate
- SBOM + SLSA provenance attached to every pushed image

## Tags

| Variant | Release | Debug (busybox shell) |
|---|---|---|
| full | `latest` `2.11.6` `2.11` `2` `sha-abc1234` | `latest-debug` `2.11.6-debug` … |
| lite | `latest-lite` `2.11.6-lite` `2.11-lite` `2-lite` `sha-abc1234-lite` | `latest-lite-debug` … |

Version tags follow the bundled Caddy version and are re-pushed when plugins change; use `sha-*` or a digest for immutability.

## Plugins

| Plugin | lite | full |
|---|:-:|:-:|
| [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare) | ✓ | ✓ |
| [abiosoft/caddy-hmac](https://github.com/abiosoft/caddy-hmac) | ✓ | ✓ |
| [lolPants/caddy-requestid](https://github.com/lolPants/caddy-requestid) | ✓ | ✓ |
| [porech/caddy-maxmind-geolocation](https://github.com/porech/caddy-maxmind-geolocation) | ✓ | ✓ |
| [fvbommel/caddy-combine-ip-ranges](https://github.com/fvbommel/caddy-combine-ip-ranges) | ✓ | ✓ |
| [mholt/caddy-l4](https://github.com/mholt/caddy-l4) | ✓ | ✓ |
| [caddyserver/transform-encoder](https://github.com/caddyserver/transform-encoder) | ✓ | ✓ |
| [JasonLovesDoggo/caddy-defender](https://github.com/JasonLovesDoggo/caddy-defender) | ✓ | ✓ |
| [ewen-lbh/caddy-i18n](https://github.com/ewen-lbh/caddy-i18n) | ✓ | ✓ |
| [mholt/caddy-webdav](https://github.com/mholt/caddy-webdav) | | ✓ |
| [WeidiDeng/caddy-cloudflare-ip](https://github.com/WeidiDeng/caddy-cloudflare-ip) | | ✓ |
| [hslatman/caddy-crowdsec-bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer) (http + layer4) | | ✓ |
| [caddyserver/cache-handler](https://github.com/caddyserver/cache-handler) + [otter storage](https://github.com/darkweak/storages) | | ✓ |
| [lucaslorentz/caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) | | ✓ |

## Usage

The process is non-root, so Caddy listens on **8080/8443**. Map host ports and keep the
`http_port`/`https_port` global options in your Caddyfile (ACME challenges depend on them):

```caddyfile
{
	http_port 8080
	https_port 8443
}

example.com {
	reverse_proxy app:3000
}
```

```yaml
services:
  caddy:
    image: ghcr.io/channinghe/caddy:latest
    ports: ["80:8080", "443:8443", "443:8443/udp"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
volumes:
  caddy_data:
  caddy_config:
```

Bind-mounted host directories for `/data` and `/config` must be writable by uid `65532`.

### docker-proxy (full only)

The default command is `caddy run`. To generate sites from container labels, override the
command; the base Caddyfile is merged with label-generated config:

```yaml
    command: ["docker-proxy", "--caddyfile-path", "/etc/caddy/Caddyfile"]
    group_add: ["${DOCKER_GID}"]   # stat -c %g /var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

Socket access is effectively root on the host. When combined with crowdsec, keep the
docker-proxy event throttle interval at 2s or more ([crowdsec-bouncer#61](https://github.com/hslatman/caddy-crowdsec-bouncer/issues/61)).

### MaxMind

GeoLite2 databases cannot be redistributed; mount your own `.mmdb` and point `db_path` at it.

### Debugging

`*-debug` tags add busybox (`/busybox/sh`, `wget`), e.g. for a healthcheck:

```yaml
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:8080/"]
```

## Development

```
variants/{full,lite}/   main.go + go.mod/go.sum per variant (one source of truth for plugins)
tools/                  pinned govulncheck (go tool)
test/                   expected modules, plugin Caddyfiles, run.sh
```

Add a plugin: add the blank import to `variants/<v>/main.go`, run `go mod tidy` in that
directory with the same Go version as the Dockerfile, and list its module ID in `test/<v>.modules`.

```sh
docker buildx build --build-arg VARIANT=full --target vulncheck .   # govulncheck
docker buildx build --build-arg VARIANT=full -t caddy:full --load .
test/run.sh full caddy:full
```

CI (`.github/workflows/build.yml`): every PR runs govulncheck and `test/run.sh` for both
variants; pushes to `main` build and push all four images. Renovate automerges once CI is
green (majors excluded); indirect Go deps are batched weekly.
