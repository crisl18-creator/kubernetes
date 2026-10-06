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
Deployment). Inspeccionar objetos, copiar un Pod, `exec` y `printenv`.

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

**Acción:** lista los Pods y copia **un** NAME de la columna:

```bash
kubectl -n shop get pods
```

Pégalo en `exec` (cambia `shop-web-XXXX`):

```bash
kubectl -n shop exec shop-web-XXXX -- printenv
```

En la salida busca `APP_TITLE`, `APP_ENV` y `APP_TOKEN`. Si hay mucho ruido:

```bash
kubectl -n shop exec shop-web-XXXX -- printenv | grep APP_
```

**Por qué:** `envFrom` monta **todas** las claves del ConfigMap y del Secret como
variables. No hay magia distinta entre uno y otro a ojos del proceso: la diferencia es
el objeto en la API (y quién puede `get` cada uno).

**Resultado esperado:** las tres variables. `APP_TOKEN` en claro **dentro** del
contenedor (el proceso las necesita así).

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

Copia el NAME **nuevo** (otra vez cambió el hash) y comprueba:

```bash
kubectl -n shop exec shop-web-XXXX -- printenv | grep APP_TITLE
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
guarda, espera al rollout, copia un Pod nuevo y `printenv | grep APP_`.

<details>
<summary>Ver solución</summary>

Las variables `APP_*` **desaparecen**. El ConfigMap y el Secret siguen en el namespace:
dejar de referenciarlos no los borra. Recupera con
`kubectl apply -f infra/manifests/m03/shop.yaml`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `NotFound` en exec | NAME de ejemplo, no el de tu `get pods` | Vuelve a listar y copia |
| `APP_TITLE` sigue el valor viejo | No hiciste `rollout restart` (o apply) | Los env no se recargan en caliente |
| `printenv` vacío de APP_ | Aún no aplicaste `shop.yaml` | Paso 2 |
