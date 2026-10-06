#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="k8s-ops"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  kind delete cluster --name "$CLUSTER_NAME"
  echo "Clúster $CLUSTER_NAME eliminado."
else
  echo "No existe el clúster $CLUSTER_NAME."
fi

if docker network inspect kind >/dev/null 2>&1; then
  n="$(docker network inspect kind -f '{{len .Containers}}' 2>/dev/null || echo 1)"
  if [ "${n}" = "0" ]; then
    docker network rm kind >/dev/null 2>&1 || true
  fi
fi
