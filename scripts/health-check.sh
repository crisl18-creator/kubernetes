#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="k8s-ops"
ok=0
warn=0
fail=0

check_ok() { echo "OK: $1"; ok=$((ok + 1)); }
check_warn() { echo "AVISO: $1"; warn=$((warn + 1)); }
check_fail() { echo "FALTA: $1"; fail=$((fail + 1)); }

if docker info >/dev/null 2>&1; then
  check_ok "Docker responde"
else
  check_fail "Docker no responde"
fi

for cmd in kubectl helm kind; do
  if command -v "$cmd" >/dev/null 2>&1; then
    check_ok "$cmd en PATH"
  else
    check_fail "$cmd no está en PATH"
  fi
done

if command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  check_ok "clúster kind $CLUSTER_NAME existe"
else
  check_warn "clúster $CLUSTER_NAME no creado (ejecuta ./scripts/cluster-up.sh)"
fi

if command -v kubectl >/dev/null 2>&1; then
  ctx="$(kubectl config current-context 2>/dev/null || true)"
  if [[ "$ctx" == "kind-${CLUSTER_NAME}" ]]; then
    check_ok "contexto kubectl $ctx"
  else
    check_warn "contexto kubectl es '${ctx:-ninguno}' (esperado kind-${CLUSTER_NAME})"
  fi

  if kubectl get nodes >/dev/null 2>&1; then
    not_ready="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" {print $1}' | wc -l | tr -d ' ')"
    total="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$not_ready" == "0" && "$total" -ge 3 ]]; then
      check_ok "nodos Ready ($total)"
    elif [[ "$total" -gt 0 ]]; then
      check_warn "nodos Ready incompletos ($total total, $not_ready no Ready)"
    fi

    if kubectl get ns calico-system >/dev/null 2>&1 || kubectl get ds -n kube-system calico-node >/dev/null 2>&1; then
      check_ok "Calico instalado"
    else
      check_warn "Calico no detectado"
    fi

    if kubectl -n ingress-nginx get deploy ingress-nginx-controller >/dev/null 2>&1; then
      check_ok "ingress-nginx instalado"
    else
      check_warn "ingress-nginx no detectado"
    fi

    if kubectl get sc local-path >/dev/null 2>&1; then
      check_ok "StorageClass local-path"
    else
      check_warn "StorageClass local-path no detectada"
    fi
  fi
fi

echo
echo "Resumen: $ok OK · $warn avisos · $fail faltas"
if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
