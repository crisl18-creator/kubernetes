# Solución de problemas — clúster kind en Codespace

## Contenedores sin Internet (`apt`, `curl`, ImagePullBackOff)

El Codespace **sí** llega a Internet (`docker pull nginx:1.14.1` funciona). Eso no implica
que un contenedor *dentro* de Docker o un **nodo kind** pueda bajar nada.

Hay dos almacenes de imágenes distintos:

```text
docker pull nginx:1.14.1          →  daemon Docker del Codespace
kubectl apply (image: nginx:…)    →  containerd DENTRO del nodo kind
```

Kubelet nunca ve lo que bajaste con `docker pull`. Si el nodo no resuelve DNS (típico
en Codespaces: kind reescribe `resolv.conf` a `127.0.0.11`), el Pod queda en
`ImagePullBackOff` aunque la imagen ya esté en el Codespace.

**Comprobar**

```bash
kubectl describe pod NOMBRE | tail -n 30
docker exec k8s-ops-control-plane getent hosts registry-1.docker.io
```

**Cargar la imagen del Codespace en kind** (no hace falta que el nodo tenga red).

No uses `kind load docker-image`: en Docker 29+ (Codespaces) revienta con
`ctr: content digest sha256:…: not found` porque el tar lleva el índice multi-arch
y faltan capas de otras arquitecturas.

```bash
# clúster del curso:
bash scripts/kind-load-image.sh nginx:1.27 k8s-ops

# o a mano (clúster por defecto se llama `kind`):
docker image save --platform linux/amd64 --output /tmp/nginx.tar nginx:1.14.1
kind load image-archive /tmp/nginx.tar --name kind
kubectl rollout restart deploy/nginx-deployment
```

Si `docker image save` no admite `--platform`:

```bash
for node in $(kind get nodes --name kind); do
  docker save nginx:1.14.1 | docker exec -i "$node" \
    ctr --namespace=k8s.io images import --digests -
done
kubectl rollout restart deploy/nginx-deployment
```

**Arreglar DNS/NAT de los nodos** (el `cluster-up` ya lo lanza):

```bash
bash scripts/kind-net-fix.sh
```

En Codespaces actuales (Docker 29) la red Docker `kind` **no tiene NAT**. El kubelet
solo hace pull si `scripts/kind-net-fix.sh` deja un proxy CONNECT en la gateway
(`172.18.0.1:3128`) y `containerd` usa `HTTPS_PROXY`. `cluster-up.sh` ya lo lanza.

Si `kind create` se queda en **Joining worker nodes**, los workers no llegan al
API (`:6443`). En Docker 29 `bridge-nf-call-iptables=1` tira ese tráfico. No hace
falta matar el proceso: `cluster-up.sh` apaga ese sysctl mientras crea el clúster.
Si ya está colgado:

```bash
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0
```

y espera unos segundos; el join suele continuar.

Los Pods **siguen sin navegar** a Internet (eso es la red del Pod/CNI). Lo que se
arregla es **bajar imágenes**. `wget` desde dentro de un Pod a `1.1.1.1` puede fallar
y no contradice un ImagePull correcto.

## Docker o puertos de M00

```bash
docker info
docker ps -a
docker rm -f m00-web m00-sleep m00-hola
docker compose -f infra/m00/web/compose.yaml down
```

- **8888 ocupado:** `docker ps` te dice el nombre; `docker rm -f` ese nombre.
- **Ports no muestra 8888:** Forward a Port → `8888`, o recarga la ventana del Codespace.
- **`name already in use`:** `docker rm -f` del nombre que indica el error.

## El Codespace no tiene `kind`

El `postCreate` aún no ha terminado. Ejecuta:

```bash
bash scripts/bootstrap-tools.sh
command -v kind kubectl helm docker
```

## Un worker `NotReady`

En Codespaces pasa a menudo: Calico con **IPIP/BGP** no peera en la red Docker de Kind,
o kubelet no se recupera tras el proxy de `containerd`. El nodo sin CNI se queda NotReady.

**Ver qué nodo y por qué** (copia el NAME de la tabla):

```bash
kubectl get nodes
kubectl describe node k8s-ops-worker2
kubectl -n kube-system get pods -o wide
```

En `describe`, busca `NetworkUnavailable` o `KubeletNotReady`. En los pods, el
`calico-node-…` de **ese** nodo: si está `0/1`, `CrashLoop` o `ImagePullBackOff`, el
worker no puede ponerse Ready.

**Arreglo en caliente** (sustituye el nombre de **tu** worker):

```bash
docker exec k8s-ops-worker2 systemctl restart kubelet
kubectl get nodes
```

Espera 20 s. Si `calico-node` no tira imagen: `bash scripts/kind-net-fix.sh` y otra vez
el `restart kubelet`.

**Arreglo de verdad** (el `cluster-up` del repo ya usa Calico en VXLAN, no IPIP):

```bash
git pull
./scripts/cluster-down.sh
./scripts/cluster-up.sh
kubectl get nodes
```

Los tres deben quedar `Ready`. Un Codespace de **2 núcleos / 8 GB** también vale para
M01–M06; Prometheus (M07) pide 16 GB.

## Contexto kubectl incorrecto

```bash
kubectl config use-context kind-k8s-ops
```

## Port-forward a un Pod o un Service (Codespace)

`kubectl port-forward` por defecto escucha solo en `127.0.0.1`. La pestaña **Ports** del
Codespace entra por otra interfaz: ves el puerto y el navegador no carga.

**Así sí** (cambia namespace, servicio y puertos):

```bash
kubectl -n shop port-forward --address 0.0.0.0 svc/shop-web 18080:80
```

Debe salir `Forwarding from 0.0.0.0:18080 -> 80`. Luego Ports → **18080** (o
`curl -s http://127.0.0.1:18080/` en la terminal del Codespace).

`--address 0.0.0.0` es lo que hace usable el PF aquí. Sin eso, `curl` a localhost en la
**misma** terminal puede ir, y la URL de GitHub no.

No uses `8080`: Kind ya lo tiene ocupado con Ingress.

Si **no** aparece `Forwarding from` y se queda colgado, el apiserver no habla con el
kubelet del worker (`:10250`). Eso no lo arregla `--address`. Opciones:

1. `kubectl get nodes` — si un worker está NotReady, arréglalo primero.
2. Entra por **Ingress** (`curl -sH 'Host: shop.local' http://127.0.0.1:8080/`), que no usa port-forward.
3. Recrear el clúster: `./scripts/cluster-down.sh && ./scripts/cluster-up.sh`.

## `curl` a Ingress no responde en `:8080`

- El mapeo hostPort está en el **primer** control-plane (`ingress-ready=true`).
- Comprueba el controller: `kubectl -n ingress-nginx get pods,ing -A`.
- Usa cabecera Host: `curl -sH 'Host: shop.local' http://127.0.0.1:8080/`.

## NetworkPolicy “ha roto todo”

DNS vive en `kube-system`. Si tu política de egress no permite UDP/TCP 53, `nslookup` falla.
Borra la policy o aplica `infra/manifests/m05/networkpolicy.yaml` (incluye DNS).

## OOM al instalar Prometheus (M07)

El stack de monitorización pide RAM. Opciones:

1. Machine del Codespace: 16 GB.
2. Desinstalar: `helm uninstall kps -n monitoring`.
3. Recrear clúster si el nodo kind quedó inestable.

## Restore de etcd dejó la API muerta

Es un lab destructivo. Recupera el laboratorio con:

```bash
./scripts/cluster-down.sh
./scripts/cluster-up.sh
```

Luego vuelve a aplicar los manifiestos del módulo en el que estabas (`infra/manifests/`).
