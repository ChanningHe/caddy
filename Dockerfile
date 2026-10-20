# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

# VARIANT selects the plugin set under variants/ (full | lite).
# FLAVOR selects the runtime base (release = distroless, debug = distroless + busybox).
ARG VARIANT=full
ARG FLAVOR=release

FROM --platform=$BUILDPLATFORM golang:1.27.2-alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS build
ARG VARIANT
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0 GOTOOLCHAIN=local
WORKDIR /src
COPY variants/${VARIANT}/go.mod variants/${VARIANT}/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY variants/${VARIANT}/main.go ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags='-s -w' -o /out/usr/bin/caddy . \
 && mkdir -p /out/data /out/config

# CI-only target: reachability-based vulnerability scan of the exact module graph.
FROM build AS vulncheck
COPY tools/go.mod tools/go.sum /tools/
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go -C /tools tool govulncheck -C /src ./...

FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS base-release
FROM gcr.io/distroless/static-debian13:debug-nonroot@sha256:95edb51e0d0fc20b21e50ddcf747338172aea87874f66a6a6bce1275367ccdc1 AS base-debug

FROM base-${FLAVOR}
COPY --from=build /out/usr/bin/caddy /usr/bin/caddy
COPY --from=build --chown=nonroot:nonroot /out/data /data
COPY --from=build --chown=nonroot:nonroot /out/config /config
COPY Caddyfile /etc/caddy/Caddyfile
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data
USER nonroot:nonroot
WORKDIR /srv
EXPOSE 8080 8443 8443/udp
VOLUME ["/data", "/config"]
ENTRYPOINT ["/usr/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
