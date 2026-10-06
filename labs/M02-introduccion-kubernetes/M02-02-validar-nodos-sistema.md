# M02-02 — Validar nodos y sistema

[← Página anterior](M02-01-arquitectura-api.md) · [Siguiente página →](../M03-ciclo-vida-aplicaciones/README.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Validar el clúster como haría un administrador el día 0: nodos, taints, pods de todos los namespaces y CNI.

### Prerrequisitos

- [M02-01](M02-01-arquitectura-api.md) (API responde).

### En qué consiste

`describe` de nodos, inventario `get pods -A` y comprobación de Calico e Ingress.

### 1 — Nodos en detalle

**Acción:**

```bash
kubectl get nodes -o wide
```

Copia el **NAME** de un worker (en este curso: `k8s-ops-worker` o `k8s-ops-worker2`; el
control-plane se llama `k8s-ops-control-plane`).

```bash
kubectl describe node k8s-ops-worker
```

Si copiaste el otro worker, pega **ese** nombre. No hace falta leer el describe entero:
busca `Taints:`, `Conditions:` (`Ready`) y `Allocated resources`.

**Por qué:** `describe` enseña taints (`node-role.kubernetes.io/control-plane:NoSchedule`),
capacidad y presión de memoria. Un worker no debe llevar el taint de control-plane.

**Resultado esperado:** tres nodos `Ready`. El control-plane con `NoSchedule`; los workers
sin ese taint. En `-o wide` ves IPs `172.18.0.x` (red Docker `kind`).

### 2 — Todo lo que ya corre

**Acción:**

```bash
kubectl get pods --all-namespaces -o wide
```

**Por qué:** El laboratorio del temario pide exactamente este inventario: sistema, CNI, ingress, provisioner.

**Resultado esperado:** `kube-system`, `calico-system` o `calico-node`, `ingress-nginx`, `local-path-storage`, `metrics-server`. Pods `Running` o `Completed`.

### 3 — Ready se ve en la tabla

**Acción:**

```bash
kubectl get nodes
```

La columna **STATUS** ya dice `Ready`. Si quieres el detalle de un nodo, copia el NAME
y `kubectl describe node …` (paso 1). No hace falta jsonpath.

**Por qué:** Un nodo `Ready` significa kubelet + CNI + runtime coherentes, no solo “el
contenedor kind existe”.

**Resultado esperado:** **tres** filas `Ready` (1 control-plane + 2 workers).

### 4 — Métricas básicas

**Acción:**

```bash
kubectl top nodes
```

**Por qué:** metrics-server es el addon que convierte el clúster en operable (capacidad, HPA más adelante).

**Resultado esperado:** tabla CPU/memoria por nodo. Si dice `metrics not available yet`, espera ~30 s y reintenta.

## Comprueba tu entendimiento

**Taint de maestros**

`kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints`

→ Los `control-plane` listan `NoSchedule`; los workers vacíos o sin ese taint.

**Ingress controller**

`kubectl -n ingress-nginx get pods`

→ Controller `Running` en el nodo con label `ingress-ready=true`.

## Reto

### 1 — ¿Dónde se programa un Pod de usuario?

Crea un pod de prueba, mira en qué nodo cae (columna NODE) y bórralo. El nombre aquí
sí es fijo (`probe`):

```bash
kubectl run probe --image=busybox:1.37 --restart=Never -- sleep 30
kubectl get pod probe -o wide
kubectl delete pod probe
```

<details>
<summary>Ver solución</summary>

Debe caer en un **worker** (taint de control-plane). Si cayera en un maestro, el clúster no está usando los taints por defecto.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `top` error | metrics-server aún arrancando o sin `--kubelet-insecure-tls` | Espera; el addon del curso ya lleva el flag |
| Pods Calico CrashLoop | CIDR distinto al de kind | `cluster.yaml` y Calico usan `10.244.0.0/16` |
