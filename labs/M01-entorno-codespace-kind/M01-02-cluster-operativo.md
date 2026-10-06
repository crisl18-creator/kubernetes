# M01-02 — Clúster operativo

[← Página anterior](M01-01-bootstrap-entorno.md) · [Siguiente página →](../M02-introduccion-kubernetes/README.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Crear el clúster kind `k8s-ops` y validar CNI, Ingress y StorageClass.

### Prerrequisitos

- Lab [M01-01](M01-01-bootstrap-entorno.md) terminado (`kind` y `docker` responden).

### En qué consiste

Leer la config de kind, ejecutar `cluster-up.sh` y comprobar nodos y addons con `health-check.sh`.

### 1 — Leer el manifiesto del clúster

**Acción:**

```bash
cat infra/kind/cluster.yaml
```

**Por qué:** Ahí está el diseño: 1 control-plane, 2 workers, CNI desactivado
(lo pondrá Calico), mapeo `8080/8443` para Ingress.

**Resultado esperado:** `name: k8s-ops`, un `role: control-plane` y dos `role: worker`.

### 2 — Crear el clúster

**Acción:**

```bash
./scripts/cluster-up.sh
```

La primera vez descarga la imagen `kindest/node` y los manifiestos de Calico; puede tardar varios minutos.

**Por qué:** Un solo script evita clústeres con nombres distintos y asegura los addons del curso.

**Resultado esperado:**

```bash
kubectl get nodes
# tres nodos Ready; contexto kind-k8s-ops
```

> [!WARNING]
> Hasta que Calico no esté Running, los nodos se quedan `NotReady`. El script espera a `Ready`.

### 3 — Addons operativos

**Acción:**

```bash
kubectl get sc
kubectl -n ingress-nginx get deploy
kubectl -n kube-system get deploy metrics-server
./scripts/health-check.sh
```

**Por qué:** Un clúster “operativo” no es solo API vacía: necesita red, entrada HTTP, métricas y disco.

**Resultado esperado:** StorageClass `local-path` (default), deploy de ingress y metrics-server, `health-check` sin `FALTA`.

### 4 — Idempotencia

**Acción:** vuelve a ejecutar `./scripts/cluster-up.sh`.

**Por qué:** En un curso largo recrear el clúster a ciegas borra el trabajo. El script reutiliza el existente.

**Resultado esperado:** mensaje de que `k8s-ops` ya existe; los nodos siguen.

## Comprueba tu entendimiento

**Inventario de nodos**

`kubectl get nodes -o wide`

→ 1 control-plane + 2 workers, todos `Ready`.

**CNI**

`kubectl get pods -A | grep -i calico`

→ Pods Calico `Running` (operator o `calico-node`).

## Reto

### 1 — Dónde está el quórum

¿Cuántos contenedores Docker corresponden a nodos?

```bash
docker ps --format '{{.Names}}'
```

<details>
<summary>Ver solución</summary>

Tres nombres: `k8s-ops-control-plane`, `k8s-ops-worker`, `k8s-ops-worker2`.
Con un solo control-plane kind **no** crea `external-load-balancer`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| Timeout en `kind create` | Imagen lenta, RAM, o red kind IPv6 sin ip6tables | Repetir; Codespace 16 GB; `bash scripts/kind-net-fix.sh`; [TROUBLESHOOTING](../TROUBLESHOOTING.md) |
| Nodos NotReady eterno | Calico no arranca | `kubectl get pods -A`; reset con `cluster-down` + `cluster-up` |
| Contexto distinto | Otro cluster kind | `kubectl config use-context kind-k8s-ops` |
| Pods `ImagePullBackOff` | `docker pull` no llena el nodo kind; `kind load docker-image` falla en Docker 29 | `bash scripts/kind-load-image.sh IMAGEN`; [TROUBLESHOOTING](../TROUBLESHOOTING.md) |
