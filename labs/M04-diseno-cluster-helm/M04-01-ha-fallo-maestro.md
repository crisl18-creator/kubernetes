# M04-01 — Un maestro: qué pasa si cae

[← Página anterior](README.md) · [Siguiente página →](M04-02-helm-values.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Ver qué ocurre cuando el **único** control-plane de `k8s-ops` se para, y recuperarlo.

### Prerrequisitos

- Tres nodos Ready (`k8s-ops-control-plane` + dos workers).

### En qué consiste

Inventario Docker/kind, `docker stop` del maestro, comprobar que kubectl deja de responder, `docker start`.

### 1 — Topología

**Acción:**

```bash
kubectl get nodes
docker ps --format '{{.Names}}' | sort
```

**Por qué:** Necesitas el nombre exacto del contenedor a parar.

**Resultado esperado:** `k8s-ops-control-plane`, `k8s-ops-worker`, `k8s-ops-worker2`. No hay `external-load-balancer` (eso solo aparece con varios control-plane).

### 2 — Simular la caída

**Acción:**

```bash
docker stop k8s-ops-control-plane
sleep 5
kubectl get nodes
```

**Por qué:** Con un solo maestro, apiserver y etcd viven en ese contenedor. Al pararlo, la API se corta.

**Resultado esperado:** `kubectl` no responde (timeout o connection refused).

### 3 — Recuperar el maestro

**Acción:**

```bash
docker start k8s-ops-control-plane
kubectl wait --for=condition=Ready node/k8s-ops-control-plane --timeout=180s
kubectl get nodes
```

**Por qué:** Un clúster de laboratorio se reintegra el nodo; no hace falta `cluster-down` si el disco del contenedor sigue ahí.

**Resultado esperado:** otra vez tres `Ready`.

## Comprueba tu entendimiento

**etcd**

`kubectl -n kube-system get po -l component=etcd -o wide`

→ Un pod etcd, en el control-plane.

**Por qué en producción hay tres maestros**

Sin segundo apiserver no hay a quién conmutar. El temario de HA (quórum de etcd + LB) es el diseño que **no** montamos aquí para no pelear con la red de Codespaces.

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| kubectl cuelga tras el stop | Es lo esperado | `docker start k8s-ops-control-plane` |
| Nodo NotReady eterno al volver | kubelet lento | Espera `kubectl wait`; `docker logs k8s-ops-control-plane` |
