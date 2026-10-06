# M04-02 — Helm con values

[← Página anterior](M04-01-ha-fallo-maestro.md) · [Siguiente página →](../M05-red-networking/README.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Instalar el chart `ops-web` y actualizarlo con un fichero de values (staging: 3 réplicas + Ingress).

### Prerrequisitos

- Tres nodos Ready. Si en M04-01 paraste el control-plane, arráncalo otra vez (`docker start k8s-ops-control-plane`).

### En qué consiste

`helm install`, inspección de los objetos generados, `helm upgrade -f values-staging.yaml`, prueba HTTP.

### 1 — Ver qué va a crear el chart

**Acción:**

```bash
helm template ops-web infra/charts/ops-web
```

**Por qué:** Template sin instalar evita sorpresas. Helm renderiza YAML; Kubernetes no “entiende Helm”.

**Resultado esperado:** un Deployment y un Service; el Ingress no sale (está `enabled: false` por defecto).

### 2 — Instalar en `shop`

**Acción:**

```bash
helm install ops-web infra/charts/ops-web --namespace shop --create-namespace
helm -n shop list
kubectl -n shop get deploy,svc -l app=ops-web
```

**Por qué:** El release tiene nombre (`ops-web`) distinto del chart. `helm list` es el inventario de paquetes del clúster.

**Resultado esperado:** release `deployed`; 2 réplicas; texto por defecto `ops-web via Helm` (lo verás en el paso 4).

### 3 — Upgrade con values de staging

**Acción:**

```bash
helm upgrade ops-web infra/charts/ops-web -n shop -f infra/charts/ops-web/values-staging.yaml
kubectl -n shop rollout status deploy/ops-web
kubectl -n shop get deploy ops-web ing
```

**Por qué:** Personalizar sin fork del chart es el flujo diario (réplicas, host, flags).

**Resultado esperado:** 3 réplicas; objeto Ingress `ops-web` host `ops.local`.

### 4 — Probar el servicio

**Acción:**

```bash
kubectl -n shop run curl --rm -it --restart=Never --image=busybox:1.37 -- wget -qO- http://ops-web
curl -sH 'Host: ops.local' http://127.0.0.1:8080/
```

**Por qué:** ClusterIP es interno; Ingress es el borde mapeado a `:8080` del Codespace.

**Resultado esperado:** `ops-web staging` en ambos caminos (Ingress puede tardar ~15 s en programar).

## Comprueba tu entendimiento

**Diff de values**

`helm -n shop get values ops-web`

→ `replicaCount: 3` y `ingress.enabled: true`.

**Histórico**

`helm -n shop history ops-web`

→ Revisión 1 install, revisión 2 upgrade.

## Reto

### 1 — Rollback de Helm

Vuelve al mensaje por defecto sin borrar el release.

<details>
<summary>Ver solución</summary>

```bash
helm rollback ops-web 1 -n shop
# o helm upgrade ... sin el -f staging
```

`helm rollback` restaura el release; no confundir con `kubectl rollout undo` (eso es solo el Deployment).

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| Ingress 404 | Falta cabecera `Host: ops.local` | `curl -H 'Host: ops.local'` |
| `cannot re-use a name` | Release ya instalado | `helm upgrade` o `helm uninstall ops-web -n shop` |
