# M07-01 — Prometheus y Grafana

[← Página anterior](README.md) · [Siguiente página →](M07-02-etcd-backup.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Instalar kube-prometheus-stack (Prometheus Operator + Grafana) y ver métricas del clúster.

### Prerrequisitos

- Clúster estable, nodos Ready. Codespace con RAM suficiente.
- Helm 3.

### En qué consiste

Añadir el repo Helm, instalar con values slim, port-forward a Grafana y una query en Prometheus.

### 1 — Drain de mantenimiento (un worker)

**Acción:**

```bash
kubectl drain k8s-ops-worker --ignore-daemonsets --delete-emptydir-data --force
kubectl get po -A -o wide | grep k8s-ops-worker || true
kubectl uncordon k8s-ops-worker
```

**Por qué:** Es el gesto de “actualizo este nodo” sin tocar kind. DaemonSets (Calico) se ignoran a propósito.

**Resultado esperado:** el worker `SchedulingDisabled` durante el drain; los Deployments en el otro worker; tras `uncordon`, `Ready`.

### 2 — Instalar el stack

**Acción:**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f infra/monitoring/values.yaml
kubectl -n monitoring get pods
```

**Por qué:** El Operator Pattern llega empaquetado: CRDs + controlador + instancias Prometheus/Grafana.

**Resultado esperado:** pods `kps-…` Running (puede tardar 2–3 min). `alertmanager` no debe existir (disabled en values).

### 3 — Grafana

**Acción:**

```bash
kubectl -n monitoring port-forward --address 0.0.0.0 svc/kps-grafana 3000:80
```

En Ports abre **3000**. Usuario `admin`, contraseña `admin` (values del curso).

**Por qué:** Grafana es la cara humana de las métricas que Prometheus ya está scrapeando.
`--address 0.0.0.0` es obligatorio en Codespaces: sin eso el proceso solo escucha en
`127.0.0.1` y la pestaña Ports no entra. Deja ese comando en un terminal; `Ctrl+C` lo corta.

**Resultado esperado:** login y dashboards preinstalados (Kubernetes / Node Exporter).

Si el comando se queda pillado y no imprime `Forwarding from 0.0.0.0:3000`, el apiserver
no llega al kubelet del worker (misma red kind). Comprueba `kubectl get nodes` y
[TROUBLESHOOTING](../TROUBLESHOOTING.md).

### 4 — Prometheus

**Acción:** en otro terminal:

```bash
kubectl -n monitoring get svc
kubectl -n monitoring port-forward --address 0.0.0.0 svc/kps-prometheus 9090:9090
```

Si el Service no se llama `kps-prometheus`, usa el que liste `get svc` (puerto 9090).

Abre `:9090` → Graph. Query: `up{job="kubelet"}` o `kube_pod_info`.

**Por qué:** Si `up` no tiene series, el Operator no está scrapeando (CR `Prometheus` mal o ServiceMonitor ausente).

**Resultado esperado:** series con valor 1 para jobs del clúster.

## Comprueba tu entendimiento

**CRDs vivos**

`kubectl get crd | grep monitoring.coreos.com`

→ `prometheuses`, `servicemonitors`, `prometheusrules`, …

**Release**

`helm -n monitoring list`

→ `kps` deployed.

## Reto

### 1 — Quitar presión de RAM

Desinstala el stack sin borrar el clúster.

<details>
<summary>Ver solución</summary>

```bash
helm uninstall kps -n monitoring
kubectl delete ns monitoring
```

Los CRDs a veces quedan: `kubectl get crd | grep monitoring.coreos.com`. En este curso puedes dejarlos; `cluster-down` los elimina todos.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| Pods Pending | Poca RAM | Codespace 16 GB; values slim ya aplicados |
| Grafana 404 | Service name distinto | `kubectl -n monitoring get svc` y port-forward al svc de grafana |
| `drain` rechaza | Pods locales / PDB | `--force --delete-emptydir-data --ignore-daemonsets` |
