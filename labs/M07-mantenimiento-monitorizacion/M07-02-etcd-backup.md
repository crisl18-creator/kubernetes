# M07-02 — Backup y restore de etcd

[← Página anterior](M07-01-prometheus-grafana.md) · [Siguiente página →](M07-03-operator-pattern.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Generar un snapshot íntegro de etcd, simular un borrado y recuperar el objeto de dos maneras (git + verificación del snapshot).

### Prerrequisitos

- API estable. No hagas este lab con solo un control-plane a medias (completa M04-01 si lo paraste).

### En qué consiste

Canario en etcd, `snapshot save` desde el maestro, `snapshot status`, borrado, reapply del YAML y notas de restore.

### 1 — Canario

**Acción:**

```bash
kubectl -n shop create configmap etcd-canary --from-literal=marca=$(date -Is) --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop get cm etcd-canary -o yaml | grep marca
```

**Por qué:** Necesitas un objeto inequívoco para saber si el backup “caza” estado, no solo ficheros.

**Resultado esperado:** ConfigMap `etcd-canary` con clave `marca`.

### 2 — Snapshot en el control-plane

**Acción:**

```bash
ETCD_POD=etcd-k8s-ops-control-plane
kubectl -n kube-system exec "$ETCD_POD" -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-snapshot.db

kubectl -n kube-system exec "$ETCD_POD" -- etcdctl snapshot status /tmp/etcd-snapshot.db -w table
mkdir -p infra/backups
kubectl -n kube-system cp "$ETCD_POD":/tmp/etcd-snapshot.db infra/backups/etcd-snapshot.db
ls -lh infra/backups/etcd-snapshot.db
```

**Por qué:** Hablas con etcd **dentro** de su Pod (gesto de administrador). No copies `/var/lib/etcd` en caliente: `snapshot save` deja un punto consistente.

**Resultado esperado:** tabla de status (hash, revision, keys) y un `.db` en `infra/backups/` (gitignored).

### 3 — Fallo simulado

**Acción:**

```bash
kubectl -n shop delete cm etcd-canary
kubectl -n shop get cm etcd-canary || echo BORRADO
```

**Por qué:** Imita un `kubectl delete` accidental o un operador que se come un objeto. El snapshot **sí** lo contenía; el clúster vivo ya no.

**Resultado esperado:** `NotFound` / `BORRADO`.

### 4 — Recuperar el estado deseado (capa git)

**Acción:**

```bash
kubectl -n shop create configmap etcd-canary --from-literal=marca=recuperado-desde-git
kubectl -n shop get cm etcd-canary
```

**Por qué:** En operación real, la mayoría de objetos deben poder renacer desde git/Helm. etcd es la red de seguridad de lo que **no** está en git (Secrets rotados, leases, CR status).

**Resultado esperado:** ConfigMap otra vez presente.

### 5 — Restore crudo de etcd (solo si te lo piden; es destructivo)

Un restore de etcd sustituye el data-dir del miembro. Aquí solo hay uno: si lo rompes, la API se queda muda.

Si lo experimentas y no vuelve:

1. Mover `etcd.yaml` fuera de `/etc/kubernetes/manifests` en el control-plane.
2. `etcdutl snapshot restore` sobre `/var/lib/etcd`.
3. Devolver el manifiesto.
4. Si la API no vuelve: `./scripts/cluster-down.sh && ./scripts/cluster-up.sh` y reaplica `infra/manifests/`.

**Por qué:** El temario pide restore; el curso te enseña el gesto **y** la vía de escape del laboratorio.

## Comprueba tu entendimiento

**Dónde vive etcd**

`docker exec k8s-ops-control-plane ls /var/lib/etcd`

→ Data-dir del miembro stacked. No lo borres a mano.

**El snapshot pesa**

`ls -lh infra/backups/etcd-snapshot.db`

→ Megabytes, no un YAML vacío.

## Reto

### 1 — ¿Qué no restaura git?

Cita dos tipos de objeto que un `kubectl apply -f infra/` **no** recupera y sí irían en el snapshot.

<details>
<summary>Ver solución</summary>

Ejemplos: Secret generado por un operador, ServiceAccount tokens, status de CRs, leases de leader election, objetos creados a mano sin YAML. Por eso existen las dos capas.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `etcdctl: command not found` | PATH del nodo / no estás en el Pod etcd | Usa `kubectl -n kube-system exec etcd-k8s-ops-control-plane -- etcdctl …` |
| snapshot status error | Fichero a medias | Repite `snapshot save`; no copies `/var/lib/etcd` |
| API muerta tras restore | etcd a medias | `cluster-down` + `cluster-up` |
