# M03-01 — Deployment, ReplicaSet y pases de versión

[← Página anterior](README.md) · [Siguiente página →](M03-02-configmap-secret.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Crear un Deployment con manifiestos, ver el ReplicaSet y los Pods, escalar, repartir
entre nodos, hacer un canary, un pase de versión, un pase **que falla** (imagen que no
existe) y volver atrás. **Sin Service y sin ConfigMap**: solo el controlador.

### Prerrequisitos

- Clúster `k8s-ops` con tres nodos Ready ([M01-02](../M01-entorno-codespace-kind/M01-02-cluster-operativo.md)).

### En qué consiste

Aplicas YAML de `infra/manifests/m03/basico/`. Cada cambio de versión es **otro fichero**,
no un `patch` ni un script. Cuando un comando necesite el nombre de un Pod, haces
`kubectl get pods`, **copias la columna NAME** y la pegas en el siguiente comando.

> [!TIP]
> El nombre real será parecido a `shop-web-6f7d8c9b4-xk2lm`, no al de los ejemplos.
> Si copias el de este texto al pie de la letra, fallará: usa el de **tu** tabla.

### 1 — Leer el manifiesto v1

**Acción:**

```bash
cat infra/manifests/m03/basico/shop-web-v1.yaml
```

**Por qué:** Antes de aplicar, mira tres cosas: `kind: Deployment`, `replicas: 2` y
`args` con `-text=shop-web v1`. No hay Service. No hay ConfigMap. El contrato es
“quiero dos Pods con esta plantilla”.

**Resultado esperado:** ves `hashicorp/http-echo:1.0.0` y el texto `shop-web v1`.

### 2 — Crear namespace y Deployment

**Acción:**

```bash
kubectl apply -f infra/manifests/m03/basico/namespace.yaml
kubectl apply -f infra/manifests/m03/basico/shop-web-v1.yaml
kubectl -n shop get deploy
kubectl -n shop get rs
kubectl -n shop get pods
```

**Por qué:** Tú aplicas un **Deployment**. Kubernetes crea un **ReplicaSet**. El
ReplicaSet crea los **Pods**. `kubectl run` te oculta esa cadena; el manifiesto no.

**Resultado esperado:**

- `deploy/shop-web` con `2/2` (o `0/2` un momento, mientras tira la imagen).
- Un ReplicaSet `shop-web-xxxxxxxx`.
- Dos Pods `Running` / `Ready 1/1`.

Si un Pod está `ContainerCreating`, espera 20 s y repite `kubectl -n shop get pods`.

### 3 — Copiar un nombre y hacer describe

**Acción:** en la tabla del paso 2, copia el **NAME** de **uno** de los dos Pods.

```bash
kubectl -n shop describe pod shop-web-XXXX
```

Sustituye `shop-web-XXXX` por el nombre que copiaste. Baja hasta **Events** y hasta
**Containers → web → Args**.

**Por qué:** `describe` es el comando de un incidente. Ahí sale el nodo, la imagen, los
args (`shop-web v1`) y si el kubelet pudo hacer pull.

**Resultado esperado:** `Args` con `-text=shop-web v1`. Events `Scheduled`, `Pulled`,
`Created`, `Started`. El nodo será un **worker** (`k8s-ops-worker` o `k8s-ops-worker2`),
no el control-plane (tiene taint `NoSchedule`).

### 4 — Cómo se reparte entre nodos

**Acción:**

```bash
kubectl -n shop get pods -o wide
kubectl get nodes
```

Mira la columna **NODE** de los Pods y la tabla de nodos.

**Por qué:** El scheduler elige nodo. Con 2 réplicas y 2 workers suele haber **uno en
cada worker**. No está garantizado al 100 % (el scheduler también mira recursos), pero
en este lab casi siempre se reparte.

**Resultado esperado:** dos IPs `10.244…` distintas. `NODE` distinto en cada fila, o al
menos no el control-plane.

### 5 — Escalar a 4 y desescalar a 2

**Acción:**

```bash
kubectl apply -f infra/manifests/m03/basico/shop-web-replicas-4.yaml
kubectl -n shop get deploy shop-web
kubectl -n shop get pods -o wide
```

Cuenta las filas. Mira otra vez **NODE**: con 4 Pods verás más de uno en el mismo worker.

Vuelve a 2 réplicas con el manifiesto v1 (es el mismo Deployment, `replicas: 2`):

```bash
kubectl apply -f infra/manifests/m03/basico/shop-web-v1.yaml
kubectl -n shop get pods
```

**Por qué:** Escalar **no** crea un Deployment nuevo: cambia el número que el ReplicaSet
tiene que mantener. Los Pods de más se terminan; no hace falta `kubectl delete pod`.

**Resultado esperado:** un momento con 4 `Running`; después otra vez 2. El ReplicaSet es
**el mismo** (mismo hash en el nombre). Escalar no es un pase de versión.

Compruébalo:

```bash
kubectl -n shop get rs
```

### 6 — Canary: una réplica nueva al lado de v1

Todavía tienes v1 (2 Pods). Ahora no sustituyes todo: añades **otro** Deployment con
**una** réplica que sirve `v2-canary`.

**Acción:**

```bash
kubectl apply -f infra/manifests/m03/basico/shop-web-canary.yaml
kubectl -n shop get deploy
kubectl -n shop get rs
kubectl -n shop get pods -o wide
```

**Por qué:** Un canary es “probar la versión nueva en poco tráfico” sin tirar la estable.
Aquí no hay Service todavía, así que no hay porcentaje de peticiones: ves **3 Pods** y
**2 Deployments**. El canary tiene **otro selector** (`app: shop-web-canary`). Si llevara
las mismas labels que `shop-web`, el ReplicaSet estable **se lo quedaría** y lo mataría
o lo adoptaría. Eso lo verás con el Service en M05.

**Resultado esperado:** `shop-web` 2/2, `shop-web-canary` 1/1. Tres Pods. Copia el NAME
del canary (empieza por `shop-web-canary-`) y descríbelo:

```bash
kubectl -n shop describe pod shop-web-canary-XXXX
```

En Args debe salir `-text=shop-web v2-canary`. En un Pod de `shop-web` (copia el otro
nombre) sigue saliendo `shop-web v1`.

### 7 — Promocionar v2 y quitar el canary

El canary estaba bien. Ahora el estable pasa a v2 (2 réplicas) y borras el canary.

**Acción:**

```bash
kubectl apply -f infra/manifests/m03/basico/shop-web-v2.yaml
kubectl -n shop rollout status deploy/shop-web
kubectl -n shop delete deploy shop-web-canary
kubectl -n shop get rs
kubectl -n shop get pods
```

**Por qué:** Cambiar la **plantilla** del Pod (el texto `v1` → `v2`, o el label `version`)
crea un **ReplicaSet nuevo**. El Deployment baja el RS viejo y sube el nuevo respetando
`maxUnavailable: 0` (no te quedas a cero). `rollout status` espera a que el nuevo esté Ready.

**Resultado esperado:** `rollout status` termina en `successfully rolled out`. Un RS con
**2** réplicas (v2) y el RS viejo con **0**. Solo dos Pods, nombres **nuevos** (el hash
del RS cambió). Copia un NAME nuevo y comprueba Args:

```bash
kubectl -n shop describe pod shop-web-XXXX
```

Debe decir `shop-web v2`.

El historial del Deployment:

```bash
kubectl -n shop rollout history deploy/shop-web
```

Al menos dos revisiones.

![Un Deployment con dos ReplicaSets (v1 y v2) durante un rolling update](../img/M03-demo-replicaset.png)

### 8 — Pase de versión que falla (la imagen no existe)

**Acción:**

```bash
kubectl apply -f infra/manifests/m03/basico/shop-web-imagen-mala.yaml
kubectl -n shop get pods
```

Verás Pods nuevos en `ErrImagePull` o `ImagePullBackOff`, y los de v2 **siguen** (gracias
a `maxUnavailable: 0`: no tira los buenos hasta que los nuevos estén Ready).

Copia el NAME de un Pod que **no** esté Running:

```bash
kubectl -n shop describe pod shop-web-XXXX
```

En Events: `Failed to pull image` / `esto-no-existe`.

```bash
kubectl -n shop rollout status deploy/shop-web
```

Este comando **se queda esperando**. No está colgado el clúster: el rollout no puede
terminar. **Ctrl+C** y sigue.

**Por qué:** En la vida real el tag está mal, el registry no responde o el nodo no tira
imagen. El síntoma es el mismo. No borres el Deployment: **reviertes**.

**Resultado esperado:** al menos un Pod malo + los v2 todavía Ready. `rollout status` no
acaba.

### 9 — Rollback

**Acción:**

```bash
kubectl -n shop rollout undo deploy/shop-web
kubectl -n shop rollout status deploy/shop-web
kubectl -n shop get pods
kubectl -n shop get rs
```

Copia un NAME de los que han quedado Running y descríbelo: Args otra vez `shop-web v2`.

**Por qué:** `undo` vuelve a la revisión anterior del Deployment (el RS de v2). Es el
mismo gesto que “la actualización ha fallado, atrás”. También podrías aplicar de nuevo
`shop-web-v2.yaml`: el manifiesto es la fuente de verdad.

**Resultado esperado:** `successfully rolled out`. Los Pods de la imagen inventada
desaparecen. Historia:

```bash
kubectl -n shop rollout history deploy/shop-web
```

### 10 — Dejar v1 para el siguiente lab

**Acción:**

```bash
kubectl apply -f infra/manifests/m03/basico/shop-web-v1.yaml
kubectl -n shop rollout status deploy/shop-web
kubectl -n shop get deploy,rs,pods
```

**Por qué:** El lab de ConfigMap parte de v1. Un apply del manifiesto v1 es un pase más
(otro RS si la plantilla cambió respecto a lo que hay).

**Resultado esperado:** 2 Pods Ready, texto v1 en `describe`.

## Comprueba tu entendimiento

**Quién crea los Pods**

`kubectl -n shop get pods,rs,deploy`

→ El Deployment no “es” el proceso. El ReplicaSet es quien mantiene el número de Pods.

**Borrar un Pod a mano**

Copia un NAME y `kubectl -n shop delete pod shop-web-XXXX`. Vuelve a `get pods`.

→ Aparece **otro** Pod (nombre nuevo). El ReplicaSet cumple `replicas: 2`. Para bajar a
1 hay que cambiar el manifiesto (o `replicas`), no matar Pods.

**Nodo**

`kubectl -n shop get pods -o wide`

→ Columna NODE: workers. El control-plane no debería coger estos Pods.

## Reto

### 1 — ¿Qué pasa si aplicas el directorio entero?

```bash
kubectl apply -f infra/manifests/m03/basico/
```

<details>
<summary>Ver solución</summary>

Aplica **todos** los YAML a la vez: namespace, v1, v2, replicas-4, canary e imagen mala.
El último Deployment que gane en `shop-web` depende del orden. Nunca apliques la carpeta:
aplica **un** fichero por paso, como en el lab.

Limpia con:

```bash
kubectl apply -f infra/manifests/m03/basico/shop-web-v1.yaml
kubectl -n shop delete deploy shop-web-canary --ignore-not-found
```

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `NotFound` al describe | Pegaste el NAME de este texto, no el de tu tabla | `kubectl -n shop get pods` y copia otra vez |
| `ImagePullBackOff` en el paso 2 (v1) | Red de kind / proxy | [TROUBLESHOOTING](../TROUBLESHOOTING.md); espera o `cluster-up.sh` ya puso el proxy |
| `rollout status` no acaba | Estás en el paso de la imagen mala | Ctrl+C y `rollout undo` |
| 3 Deployments `shop-web*` | No borraste el canary | `kubectl -n shop delete deploy shop-web-canary` |
