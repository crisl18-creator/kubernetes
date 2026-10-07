#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/infra/kind/cluster.yaml"
CLUSTER_NAME="k8s-ops"
ADDONS="$ROOT/infra/addons"

wait_for_runtime() {
  local i
  for i in $(seq 1 60); do
    if command -v kind >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      return 0
    fi
    echo "Esperando Docker/kind (el Codespace aún está en el bootstrap)…"
    sleep 5
  done
  echo "ERROR: kind no instalado. Ejecuta scripts/bootstrap-tools.sh o espera a que termine el Codespace."
  exit 1
}

wait_for_runtime
bash "$ROOT/scripts/kind-net-fix.sh" || true

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Creando clúster $CLUSTER_NAME (1 control-plane + 2 workers)…"
  # Sin HTTP_PROXY aquí: kubeadm join lo cogería y se queda pillado en "Joining worker nodes".
  # El proxy de pull lo aplica kind-net-fix.sh en containerd cuando los nodos ya existen.
  # Docker 29 puede reactivar br_netfilter al arrancar los nodos (mismo hang).
  bridge_keep=""
  cleanup_bridge_keep() {
    if [ -n "${bridge_keep:-}" ]; then
      kill "$bridge_keep" 2>/dev/null || true
      wait "$bridge_keep" 2>/dev/null || true
      bridge_keep=""
    fi
  }
  trap cleanup_bridge_keep EXIT
  if [ -e /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
    (
      while true; do
        if [ -w /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
          echo 0 >/proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null || true
        elif command -v sudo >/dev/null 2>&1; then
          echo 0 | sudo -n tee /proc/sys/net/bridge/bridge-nf-call-iptables >/dev/null 2>&1 || true
        fi
        sleep 1
      done
    ) &
    bridge_keep=$!
  fi
  env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
    kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG"
  cleanup_bridge_keep
else
  echo "Clúster $CLUSTER_NAME ya existe."
fi

bash "$ROOT/scripts/kind-net-fix.sh" || true

# containerd se reinicia al poner el proxy; el API puede tardar un instante.
for _ in $(seq 1 30); do
  if kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

echo "Instalando Calico…"
kubectl apply -f "$ADDONS/calico.yaml"
# Si el IPPool nació con IPIP (clúster anterior), cámbialo: si no, un worker se queda NotReady.
if kubectl get ippool >/dev/null 2>&1; then
  kubectl get ippool -o name | while read -r pool; do
    kubectl patch "$pool" --type merge -p '{"spec":{"ipipMode":"Never","vxlanMode":"Always"}}' >/dev/null 2>&1 || true
  done || true
fi

echo "Esperando Calico en los nodos…"
kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=calico-node --timeout=240s || true

# Tras el proxy de containerd, kubelet a veces no marca Ready. Solo toca los NotReady.
notready="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" {print $1}' || true)"
if [ -n "${notready}" ]; then
  echo "Nodos NotReady, reiniciando kubelet: ${notready}"
  for node in ${notready}; do
    docker exec "$node" systemctl restart kubelet 2>/dev/null || true
  done
  sleep 8
fi

echo "Esperando nodos Ready (CNI)…"
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo "Instalando metrics-server, ingress-nginx y local-path…"
kubectl apply -f "$ADDONS/metrics-server.yaml"
kubectl apply -f "$ADDONS/ingress-nginx.yaml"
kubectl apply -f "$ADDONS/local-path-storage.yaml"

echo "Esperando ingress-nginx…"
kubectl -n ingress-nginx wait --for=condition=available deploy/ingress-nginx-controller --timeout=180s || true

echo
echo "Clúster operativo listo. Contexto: kind-${CLUSTER_NAME}"
kubectl get nodes -o wide
kubectl get sc
echo
echo "Siguiente: ./scripts/health-check.sh"
