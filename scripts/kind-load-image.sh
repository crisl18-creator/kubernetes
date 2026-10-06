#!/usr/bin/env bash
# Carga una imagen del daemon Docker del Codespace en los nodos kind.
# `kind load docker-image` falla en Docker 29+ (containerd image store):
#   ctr: content digest sha256:…: not found
# porque exporta el índice multi-arch y ctr --all-platforms pide capas que no están.
set -euo pipefail

IMAGE="${1:?uso: $0 imagen[:tag] [nombre-cluster]}"
CLUSTER="${2:-k8s-ops}"
PLATFORM="${KIND_LOAD_PLATFORM:-linux/amd64}"

if ! command -v kind >/dev/null 2>&1; then
  echo "ERROR: kind no está en PATH" >&2
  exit 1
fi

if docker image save --help 2>&1 | grep -q -- '--platform'; then
  tar="$(mktemp /tmp/kind-img.XXXXXX.tar)"
  trap 'rm -f "$tar"' EXIT
  echo "Exportando ${IMAGE} (${PLATFORM})…"
  docker image save --platform "$PLATFORM" --output "$tar" "$IMAGE"
  kind load image-archive "$tar" --name "$CLUSTER"
else
  echo "Importando ${IMAGE} con ctr (sin --all-platforms)…"
  for node in $(kind get nodes --name "$CLUSTER"); do
    echo "  → ${node}"
    docker save "$IMAGE" | docker exec -i "$node" ctr --namespace=k8s.io images import --digests -
  done
fi

echo "OK. Si el Pod sigue en ImagePullBackOff: kubectl rollout restart deploy/NOMBRE"
