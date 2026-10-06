# M05-01 — Services, endpoints e Ingress

[← Página anterior](README.md) · [Siguiente página →](M05-02-networkpolicy.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Ver cómo un Service elige backends **por labels** (no porque el Pod lo haya creado un
Deployment), ensuciar los endpoints con un Pod impostor, limpiarlos y entrar por Ingress.

### Prerrequisitos

- `shop-web` con Service ([M03-02](../M03-ciclo-vida-aplicaciones/M03-02-configmap-secret.md)).
  Si lo borraste:

```bash
kubectl apply -f infra/manifests/m03/shop.yaml
kubectl -n shop rollout status deploy/shop-web
```

### En qué consiste

Tablas (`get pods`, `get endpoints`, `get svc`), copiar nombres e IPs a ojo, un manifiesto
de Pod impostor, `curl` al Service y al Ingress.

### 1 — Pods, IPs y Service

**Acción:**

```bash
kubectl -n shop get deploy shop-web
kubectl -n shop get pods -o wide
kubectl -n shop get svc shop-web
kubectl -n shop get endpoints shop-web
```

En `get pods -o wide` mira **NAME**, **IP** y **NODE**. En `get endpoints` mira las IPs
entre corchetes. En `get svc` mira **CLUSTER-IP** (es otra IP: la del Service, estable).

**Por qué:** El ClusterIP no es un Pod. kube-proxy (o el dataplane de Calico) reparte a
las IPs de **Endpoints**. Esas IPs tienen que coincidir con Pods **Ready** cuyas labels
pegan con el `selector` del Service (`app: shop-web`).

**Resultado esperado:** dos Pods Running, dos IPs en Endpoints, **las mismas** que en la
columna IP de los Pods. ClusterIP distinta (típicamente `10.96…`).

![Service delante de Pods en varios nodos](../img/M05-demo-service.png)

### 2 — Copiar un Pod y confirmar el selector

**Acción:** copia un **NAME** de la tabla del paso 1.

```bash
kubectl -n shop describe pod shop-web-XXXX
```

Busca `Labels:` (`app=shop-web`) e `IP:`. Compara esa IP con `kubectl -n shop get endpoints shop-web`.

El Service:

```bash
kubectl -n shop get svc shop-web -o yaml
```

Busca `selector:` → `app: shop-web`. No aparece el nombre del Deployment. No aparece el
nombre del Pod.

**Por qué:** El Service no dice “los hijos de shop-web”. Dice “quien lleve esta etiqueta”.
Eso es potente y peligroso.

**Resultado esperado:** labels del Pod = selector del Service. IP del Pod ∈ Endpoints.

### 3 — Cliente interno (netcheck) e Ingress

**Acción:**

```bash
kubectl apply -f infra/manifests/m05/ingress-y-red.yaml
kubectl -n shop get pods
kubectl -n shop get ing shop-web
kubectl -n payments get pods
```

Espera a que `netcheck` esté Running (nombre **fijo**, no hace falta copiarlo):

```bash
kubectl -n shop get pod netcheck
```

Cuando `1/1 Running`:

```bash
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
```

**Por qué:** DNS interno `shop-web.shop` apunta al ClusterIP. Cada `curl` cae en **uno**
de los Endpoints (balanceo). `http-echo` no imprime el hostname, así que las tres pueden
parecer iguales (`shop-web v1`). Lo importante ahora es: **siempre el texto de la app**,
nunca basura.

**Resultado esperado:** Ingress creado, `payments-api` Running, tres curl con `shop-web v1`
(o la versión que hayas dejado en M03).

### 4 — El impostor: mismo label, otro Pod

Hay un manifiesto que crea un Pod **suelto** (no lo gestiona el Deployment) con
`app: shop-web` y texto `IMPOSTOR`.

**Acción:** lee y aplica:

```bash
cat infra/manifests/m05/pod-impostor.yaml
kubectl apply -f infra/manifests/m05/pod-impostor.yaml
kubectl -n shop get pods -o wide
kubectl -n shop get endpoints shop-web
```

Cuenta IPs en Endpoints. Debería haber **una más** que réplicas del Deployment.

Copia el NAME `shop-impostor` (este sí es fijo) y descríbelo:

```bash
kubectl -n shop describe pod shop-impostor
```

Labels `app=shop-web`. Args `-text=IMPOSTOR`. Su IP tiene que salir en Endpoints.

**Por qué:** Acabas de simular un Pod “perdido”, un compañero que hizo un `kubectl run`
con las labels de producción, o un DaemonSet mal etiquetado. El Service **no pregunta**
quién es el padre.

**Resultado esperado:** 3 Pods con `app=shop-web` visibles (`get pods` lista también
`netcheck`, que **no** lleva esa label: no está en Endpoints). Endpoints con 3 IPs.

### 5 — El balanceo ya no es solo “la app”

**Acción:**

```bash
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
```

Repite si hace falta. Sois 3 backends: de vez en cuando saldrá **`IMPOSTOR`**.

**Por qué:** Así se diagnostica un “a veces va, a veces no”. `get endpoints` + `get pods
-o wide` + `describe` del IP que no reconoces. No hace falta un script.

**Resultado esperado:** mezcla de `shop-web v1` e `IMPOSTOR`.

### 6 — Quitar el impostor

**Acción:**

```bash
kubectl -n shop delete pod shop-impostor
kubectl -n shop get pods
kubectl -n shop get endpoints shop-web
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s http://shop-web.shop
```

**Por qué:** Al borrar el Pod, el endpoint desaparece. El Deployment **no** recrea
`shop-impostor`: no era suyo. Solo recrearía Pods `shop-web-…`.

**Resultado esperado:** otra vez 2 IPs en Endpoints; curls solo con el texto de la app.

### 7 — Entrar por el borde (Ingress)

**Acción:**

```bash
curl -sH 'Host: shop.local' http://127.0.0.1:8080/
```

**Por qué:** Norte-sur. El controller ingress-nginx (nodo `ingress-ready`) tiene el
hostPort 80 mapeado a **8080** del Codespace. Sin cabecera `Host: shop.local` nginx no
sabe qué regla aplicar.

**Resultado esperado:** el mismo texto de `shop-web`. En la pestaña Ports del Codespace,
8080 aparece como Ingress HTTP.

### 8 — Escalar y ver más endpoints

Aquí el número de réplicas es lo único que cambia: no toques el manifiesto de la
plantilla (si aplicas `shop-web-replicas-4.yaml` de M03 **quitas** el `envFrom` de M03-02).

**Acción:**

```bash
kubectl -n shop scale deploy/shop-web --replicas=3
kubectl -n shop get pods -o wide
kubectl -n shop get endpoints shop-web
```

Tres Pods, tres IPs en Endpoints, probablemente en **los dos workers**.

```bash
kubectl -n shop scale deploy/shop-web --replicas=2
kubectl -n shop get endpoints shop-web
```

**Por qué:** Más réplicas = más endpoints. El Service no se edita. `scale` cambia solo
`spec.replicas` del objeto que ya tienes.

**Resultado esperado:** 3 IPs con `--replicas=3`; 2 cuando vuelves.

## Comprueba tu entendimiento

**Clase de Ingress**

`kubectl -n shop get ing shop-web -o yaml`

→ `ingressClassName: nginx` y backend `service.name: shop-web`.

**Quién no está en Endpoints**

`kubectl -n shop get pods --show-labels`

→ `netcheck` tiene `app=netcheck`, no `app=shop-web`. Por eso curl **desde** netcheck
funciona, pero netcheck no recibe tráfico del Service `shop-web`.

**Puertos del Codespace**

Pestaña Ports → **8080**. Es el `extraPortMappings` de `infra/kind/cluster.yaml`.

## Reto

### 1 — Sin cabecera Host

```bash
curl -sv http://127.0.0.1:8080/
```

<details>
<summary>Ver solución</summary>

nginx responde 404: no hay server-name que coincida con `localhost` o la IP. La regla
está atada a `shop.local`. Con `-H 'Host: shop.local'` vuelve la app.

</details>

### 2 — Impostor otra vez, pero mírale la IP

Aplica `pod-impostor.yaml`, `get endpoints`, anota la IP extra, `delete`, confirma que
esa IP desaparece de Endpoints y **no** de un `get pods` del Deployment.

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `endpoints` vacío | Pods no Ready | `kubectl -n shop get pods`; `describe` del que no está 1/1 |
| Nunca sale `IMPOSTOR` | Aún no Ready el impostor, o ya lo borraste | `get pods`; espera 1/1; más curls |
| Connection refused :8080 | ingress-nginx no Ready | `kubectl -n ingress-nginx get pods` |
| 404 en curl al Codespace | Falta `Host: shop.local` | Paso 7 |
| `shop-web` no existe | No hiciste M03 | `kubectl apply -f infra/manifests/m03/shop.yaml` |
