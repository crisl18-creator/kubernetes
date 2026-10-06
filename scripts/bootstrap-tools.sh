#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIND_VERSION="${KIND_VERSION:-v0.27.0}"

if ! command -v kind >/dev/null 2>&1; then
  curl -fsSL "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" -o /tmp/kind
  sudo install -m 0755 /tmp/kind /usr/bin/kind 2>/dev/null || sudo install -m 0755 /tmp/kind /usr/local/bin/kind
fi

echo "Herramientas listas:"
command -v docker
command -v kubectl
command -v helm
command -v kind
docker info >/dev/null
bash "$ROOT/scripts/kind-net-fix.sh" || true
echo "OK bootstrap"
