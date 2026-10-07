# M03-02 — ConfigMap y Secret

[← Página anterior](M03-01-deploy-replicaset-rollout.md) · [Siguiente página →](../M04-diseno-cluster-helm/README.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Externalizar configuración (`ConfigMap`) y un dato sensible (`Secret`) en `shop-web`,
inyectarlos como variables de entorno y comprobarlos **dentro de un Pod** (copiando su
nombre). El Service de este manifiesto lo usarás en **M05**; aquí no hace falta curl al
ClusterIP.

### Prerrequisitos

- [M03-01](M03-01-deploy-replicaset-rollout.md) terminado (`shop-web` en v1, 2 réplicas).
  Si partiste de cero: `kubectl apply -f infra/manifests/m03/basico/namespace.yaml` y
  `kubectl apply -f infra/manifests/m03/basico/shop-web-v1.yaml`.

### En qué consiste

Aplicar `infra/manifests/m03/shop.yaml` (añade ConfigMap, Secret, Service y `envFrom` al
Deployment). Inspeccionar objetos, copiar un Pod y mirar las variables **con
`kubectl debug`**: la imagen `http-echo` no trae shell.

### 1 — Leer qué se añade

**Acción:**

```bash
cat infra/manifests/m03/shop.yaml
```

Fíjate en tres bloques: `kind: ConfigMap`, `kind: Secret` (`stringData.APP_TOKEN`) y, en
el Deployment, `envFrom` (configMapRef + secretRef). El `kind: Service` también está: lo
dejamos creado para M05, no lo uses todavía.

**Por qué:** La app no debería llevar el título ni el token quemados en la imagen. El
YAML es el contrato; el contenedor solo lee el entorno.

**Resultado esperado:** ves `APP_TITLE`, `APP_ENV`, `APP_TOKEN` y `envFrom`.

### 2 — Aplicar y ver el rollout

Añadir `envFrom` **cambia la plantilla** del Pod: es un pase de versión más (nuevo ReplicaSet),
aunque el texto HTTP siga siendo v1.

**Acción:**

```bash
kubectl apply -f infra/manifests/m03/shop.yaml
kubectl -n shop rollout status deploy/shop-web
kubectl -n shop get deploy,rs,pods,cm,secret,svc
```

**Por qué:** Un apply declarativo no “parchea a ciegas”: Kubernetes compara y crea lo que
falta. El Secret aparece con tipo `Opaque`. El Service `shop-web` ya tiene ClusterIP; en
M05 mirarás sus endpoints.

**Resultado esperado:** ConfigMap `shop-config`, Secret `shop-secret`, Service `shop-web`,
Deployment 2/2. Los Pods tienen **nombres nuevos** (cambió el hash del RS).

### 3 — Inspeccionar ConfigMap y Secret (sin jsonpath)

**Acción:**

```bash
kubectl -n shop get cm shop-config -o yaml
kubectl -n shop get secret shop-secret -o yaml
```

En el Secret, el valor de `APP_TOKEN` está en `data` en **base64**, no en claro. Copia
ese blob (una sola línea) y descifra **tú** el texto que has copiado:

```bash
echo 'bGFiLXRva2VuLW5vLXVzYXItZW4tcHJvZA==' | base64 -d; echo
```

Sustituye el `bGFi…` por **el tuyo** si no coincide. En este curso el token es
`lab-token-no-usar-en-prod`, así que el base64 suele ser exactamente ese.

**Por qué:** Un Secret en Kubernetes **no está cifrado** en etcd por defecto: está
ofuscado. Cualquiera con permiso `get secret` lo lee. RBAC (M06) es lo que lo protege.

**Resultado esperado:** ConfigMap en claro (`Tienda del clúster`, `lab`). Secret en
base64; al decodificar, el token de laboratorio.

### 4 — Variables dentro del contenedor

`hashicorp/http-echo` es un binario mínimo: **no hay** `sh`, `bash`, `printenv` ni `cat`.
Un `kubectl exec … -- printenv` falla con `executable file not found`. Eso no es un error
del lab: la app no trae distro. Para entrar se añade un contenedor de depuración (Alpine)
que **comparte el PID** del contenedor `web`.

**Acción:** lista los Pods y copia **un** NAME:

```bash
kubectl -n shop get pods
```

Sustituye `shop-web-XXXX` por el de tu tabla (el contenedor se llama `web`, como en el YAML):

```bash
kubectl -n shop debug -it shop-web-XXXX --image=alpine:3.20 --target=web -- sh
```

La primera vez tarda: el nodo tiene que bajar `alpine:3.20`. Cuando veas el prompt `#`,
**no** uses `printenv` a secas (eso es el entorno de Alpine, no el de http-echo). Lee el
entorno del PID 1 (el proceso de la app):

```sh
tr '\0' '\n' < /proc/1/environ | grep APP_
```

Sal con `exit`.

Si prefieres no abrir sesión interactiva:

```bash
kubectl -n shop debug shop-web-XXXX --image=alpine:3.20 --target=web -- \
  sh -c "tr '\0' '\n' < /proc/1/environ | grep APP_"
```

**Por qué:** `envFrom` inyecta las claves en **el proceso de la app**. El contenedor
`debug` es otro proceso: `--target=web` te deja ver `/proc/1` de http-echo. ConfigMap y
Secret, a ojos del proceso, son el mismo tipo de variable; se distinguen en la API.

**Resultado esperado:** `APP_TITLE`, `APP_ENV` y `APP_TOKEN`. El token sale **en claro**
dentro del proceso (lo necesita para trabajar).

> [!TIP]
> `kubectl describe pod shop-web-XXXX` lista *de dónde* salen las variables
> (`shop-config`, `shop-secret`), no los valores. Para los valores hace falta el debug
> (o leer el ConfigMap/Secret como en el paso 3).

### 5 — Cambiar solo la config

El título vive en el ConfigMap, no en la imagen. Cámbialo en el objeto y **reinicia**
los Pods: un ConfigMap ya inyectado como env **no** se refresca solo.

**Acción:**

```bash
kubectl -n shop edit cm shop-config
```

Cambia `APP_TITLE` a `Tienda v2 config`, guarda y cierra (`:wq` en vim).

```bash
kubectl -n shop rollout restart deploy/shop-web
kubectl -n shop rollout status deploy/shop-web
kubectl -n shop get pods
```

Copia el NAME **nuevo** (otra vez cambió el hash) y el mismo debug:

```bash
kubectl -n shop debug shop-web-XXXX --image=alpine:3.20 --target=web -- \
  sh -c "tr '\0' '\n' < /proc/1/environ | grep APP_TITLE"
```

**Por qué:** `rollout restart` es un pase de versión que no cambia tu YAML de imagen:
solo regenera Pods para que cojan el ConfigMap actual. En un flujo serio editarías el
YAML del repo y harías `kubectl apply -f`, no `edit` a mano. Aquí `edit` es para ver el
efecto en un minuto.

**Resultado esperado:** `APP_TITLE=Tienda v2 config`.

Si quieres dejar el lab como el manifiesto:

```bash
kubectl apply -f infra/manifests/m03/shop.yaml
kubectl -n shop rollout status deploy/shop-web
```

## Comprueba tu entendimiento

**Quién es el padre del Pod**

`kubectl -n shop get po,rs,deploy`

→ Cada Pod lo posee un ReplicaSet; el ReplicaSet lo posee el Deployment `shop-web`.

**El Secret no es cifrado**

`kubectl -n shop get secret shop-secret -o yaml`

→ Campo `data`, base64. Quien puede `get` secretos, puede el token.

**El Service ya existe**

`kubectl -n shop get svc shop-web`

→ Tiene ClusterIP. En M05 verás **endpoints** y qué pasa si un Pod suelto lleva las
mismas labels.

## Reto

### 1 — Quitar envFrom y ver el hueco

Edita el Deployment (`kubectl -n shop edit deploy shop-web`), borra el bloque `envFrom`,
guarda, espera al rollout, copia un Pod nuevo y el mismo `debug` + `grep APP_` del paso 4.

<details>
<summary>Ver solución</summary>

Las variables `APP_*` **desaparecen**. El ConfigMap y el Secret siguen en el namespace:
dejar de referenciarlos no los borra. Recupera con
`kubectl apply -f infra/manifests/m03/shop.yaml`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `executable file not found` con `exec` | http-echo no trae shell | Es normal; usa `debug` del paso 4 |
| `printenv` en el `#` de Alpine sin `APP_` | Estás en el contenedor debug, no en la app | `tr '\0' '\n' < /proc/1/environ \| grep APP_` |
| `NotFound` en debug | NAME de ejemplo, no el de tu `get pods` | Vuelve a listar y copia |
| `APP_TITLE` sigue el valor viejo | No hiciste `rollout restart` (o apply) | Los env no se recargan en caliente |
| debug tarda / ImagePullBackOff | El nodo baja Alpine | Espera; [TROUBLESHOOTING](../TROUBLESHOOTING.md) |
