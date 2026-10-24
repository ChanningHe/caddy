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

The process runs as uid `65532`. Linux only lets non-root processes bind ports at or above
`net.ipv4.ip_unprivileged_port_start` (default `1024`), so how you expose 80/443 depends on
the network mode.

| Network mode | Caddy listens on | Sysctl needed |
|---|---|---|
| Bridge + port mapping (default) | 8080/8443 | No |
| `network_mode: host` | 80/443 | **Yes, on the host** |

### Bridge network (default)

Map host ports to 8080/8443 and keep the `http_port`/`https_port` global options in your
Caddyfile (ACME challenges depend on them):

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

### Host network

With `network_mode: host` the container shares the host's network namespace and inherits
the host's `ip_unprivileged_port_start` (`1024`), so binding 80/443 fails with
`bind: permission denied`. Lower it on the host:

```sh
echo 'net.ipv4.ip_unprivileged_port_start = 80' | sudo tee /etc/sysctl.d/99-unprivileged-ports.conf
sudo sysctl --system
```

Then drop the `http_port`/`https_port` overrides (Caddy defaults to 80/443) and remove `ports:`:

```yaml
services:
  caddy:
    image: ghcr.io/channinghe/caddy:latest
    network_mode: host
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
```

Notes:

- The setting is host-wide: any non-root process on the host can then bind ports 80–1023.
- Ports below 80, such as a layer4 listener on 53, need a lower value.
- Compose `sysctls:` cannot be used with `network_mode: host`; set it on the host.
- Bridge mode needs none of this: Docker already sets the value to `0` inside the container's
  own network namespace.
- Kubernetes: set it per pod via `securityContext.sysctls` (a safe sysctl), or on the node
  when using `hostNetwork: true`.

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
