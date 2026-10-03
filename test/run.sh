#!/usr/bin/env bash
# Usage: test/run.sh <variant> <image>
# Asserts plugin presence, version consistency, config validity and a live smoke test.
set -euo pipefail

VARIANT=${1:?variant (full|lite) required}
IMAGE=${2:?image required}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SMOKE_PORT=18080
# Cloudflare provider rejects malformed tokens at provision time; 40 chars passes the shape check.
DUMMY_CF_TOKEN=$(printf 'x%.0s' {1..40})

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "--- $*"; }

step "required modules"
actual=$(docker run --rm "$IMAGE" list-modules --skip-standard | sed 's/^[[:space:]]*//' | sort -u)
missing=$(comm -23 <(sort -u "$ROOT/test/$VARIANT.modules") <(echo "$actual"))
[ -z "$missing" ] || fail "missing modules:"$'\n'"$missing"

step "caddy version matches go.mod"
want=$(awk '$1 == "github.com/caddyserver/caddy/v2" { print $2 }' "$ROOT/variants/$VARIANT/go.mod")
got=$(docker run --rm "$IMAGE" version | awk '{ print $1 }')
[ "$want" = "$got" ] || fail "version: go.mod=$want binary=$got"

step "runs as non-root"
user=$(docker image inspect -f '{{.Config.User}}' "$IMAGE")
case "$user" in root | 0 | 0:* | "") fail "image user is '$user'" ;; esac

step "validate plugin Caddyfile"
docker run --rm -e CF_API_TOKEN="$DUMMY_CF_TOKEN" \
  -v "$ROOT/test/$VARIANT.Caddyfile:/etc/caddy/Caddyfile:ro" \
  "$IMAGE" validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 ||
  fail "caddy validate rejected test/$VARIANT.Caddyfile"

step "smoke test default config"
cid=$(docker run -d -p "127.0.0.1:$SMOKE_PORT:8080" "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null' EXIT
for _ in $(seq 1 20); do
  body=$(curl -fsS "http://127.0.0.1:$SMOKE_PORT/" 2>/dev/null) && break
  sleep 0.5
done
[ "${body:-}" = "Caddy is running" ] || { docker logs "$cid" >&2; fail "unexpected response '${body:-}'"; }

echo "PASS: $VARIANT ($IMAGE)"
