# M06-01 — Usuario RBAC limitado

[← Página anterior](README.md) · [Siguiente página →](M06-02-tls-networkpolicy.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Crear el usuario `appuser` con permiso de **solo lectura** en el namespace `shop` y comprobar el denegado fuera de ahí.

### Prerrequisitos

- Namespace `shop` existente. OpenSSL en el Codespace (`openssl version`).

### En qué consiste

CSR de Kubernetes, firma, kubeconfig y RoleBinding del manifiesto `m06`.

### 1 — Clave y CSR

**Acción:**

```bash
openssl genrsa -out appuser.key 2048
openssl req -new -key appuser.key -out appuser.csr -subj "/CN=appuser/O=devs"
```

**Por qué:** El CN es el username que RBAC verá. El grupo `devs` viaja en `O=`.

**Resultado esperado:** ficheros `appuser.key` y `appuser.csr` en la raíz del repo (gitignored).

### 2 — El apiserver firma

**Acción:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: appuser
spec:
  request: $(base64 -w0 appuser.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF
kubectl certificate approve appuser
# El certificado es un blob, no una tabla: aquí sí hace falta jsonpath.
kubectl get csr appuser -o jsonpath='{.status.certificate}' | base64 -d > appuser.crt
```

**Por qué:** Así el usuario confía en la misma CA que el clúster. Un certificado “casero” sin esta CA no autentica.

**Resultado esperado:** CSR `Approved,Issued` y `appuser.crt` con PEM.

### 3 — kubeconfig del usuario

**Acción:**

```bash
cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ca=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

kubectl config set-cluster "$cluster" --server="$server" --certificate-authority-data="$ca" --kubeconfig=kubeconfig-appuser
kubectl config set-credentials appuser --client-certificate=appuser.crt --client-key=appuser.key --embed-certs --kubeconfig=kubeconfig-appuser
kubectl config set-context appuser --cluster="$cluster" --user=appuser --kubeconfig=kubeconfig-appuser
kubectl config use-context appuser --kubeconfig=kubeconfig-appuser
```

**Por qué:** Aísla al usuario de tu kubeconfig de admin (`kind-k8s-ops`).

**Resultado esperado:** `kubeconfig-appuser` creado.

### 4 — Binding y prueba de permisos

**Acción:**

```bash
kubectl apply -f infra/manifests/m06/rbac-shop-dev.yaml
kubectl --kubeconfig=kubeconfig-appuser -n shop get pods
kubectl --kubeconfig=kubeconfig-appuser -n shop get secrets || true
kubectl --kubeconfig=kubeconfig-appuser get nodes || true
```

**Por qué:** El Role permite get/list de pods y deployments, **no** secrets ni nodos.

**Resultado esperado:** lista de pods en `shop`; `Forbidden` en secrets y nodes.

## Comprueba tu entendimiento

**Quién eres**

`kubectl --kubeconfig=kubeconfig-appuser auth can-i get pods -n shop`

→ `yes`

`kubectl --kubeconfig=kubeconfig-appuser auth can-i get pods -n kube-system`

→ `no`

## Reto

### 1 — Añadir logs

Da a `appuser` permiso `get` sobre `pods/log` en `shop` y lee el log de un pod.

<details>
<summary>Ver solución</summary>

Edita el Role `shop-dev` añadiendo `resources: ["pods/log"]` y `verbs: ["get"]`.
`kubectl --kubeconfig=kubeconfig-appuser -n shop logs deploy/shop-web` debe funcionar.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| Unauthorized | CSR no Issued o key/crt no coinciden | `kubectl get csr`; regenera crt |
| Listas todo con appuser | Olvidaste `--kubeconfig` | Siempre pásalo en este lab |
| Forbidden en pods de shop | RoleBinding mal subject | Subject `User` / name `appuser` |
