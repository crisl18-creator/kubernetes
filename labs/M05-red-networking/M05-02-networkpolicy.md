# M05-02 — NetworkPolicy entre namespaces

[← Página anterior](M05-01-services-ingress.md) · [Siguiente página →](../M06-seguridad/README.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Dejar que `shop` hable consigo mismo (y con Ingress/DNS) y **bloquear** el acceso a `payments`.

### Prerrequisitos

- [M05-01](M05-01-services-ingress.md) (`netcheck`, `shop-web`, `payments-api`).
  El impostor de M05-01 tiene que estar **borrado** (si no, `curl` a `shop-web` a veces
  devuelve `IMPOSTOR` y confunde el “antes”).

### En qué consiste

Medir conectividad **antes** y **después** de `infra/manifests/m05/networkpolicy.yaml`.
`netcheck` tiene nombre fijo: no hace falta copiarlo de una tabla.

### 1 — Línea base (todo abierto)

**Acción:** confirma que los tres objetos están Running:

```bash
kubectl -n shop get pods
kubectl -n payments get pods
```

Luego mide (el timeout evita que te quedes minutos si ya hubiera una policy a medias):

```bash
kubectl -n shop exec netcheck -- curl -s --max-time 5 http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s --max-time 5 http://payments-api.payments
```

**Por qué:** Sin policies, Calico no filtra este-oeste. Tienes que ver el “antes” para creer el “después”.

**Resultado esperado:** texto de `shop-web` y `payments-ok`. Si `shop-web` sale `IMPOSTOR`,
vuelve a M05-01 y borra `shop-impostor`.

### 2 — Aplicar policies

**Acción:**

```bash
kubectl apply -f infra/manifests/m05/networkpolicy.yaml
kubectl -n shop get netpol
kubectl -n payments get netpol
```

**Por qué:** En `payments` solo se admite tráfico originado en el propio namespace. `shop` no está en esa lista.

**Resultado esperado:** dos NetworkPolicy creadas.

### 3 — Volver a medir

**Acción:**

```bash
kubectl -n shop exec netcheck -- curl -s --max-time 5 http://shop-web.shop
kubectl -n shop exec netcheck -- curl -s --max-time 5 http://payments-api.payments || echo BLOQUEADO
```

**Por qué:** La primera petición sigue permitida (ingress desde `netcheck` en shop). La segunda debe caducar.

**Resultado esperado:** shop-web ok; payments **BLOQUEADO** o timeout.

> [!TIP]
> Si shop-web también falla, la policy de ingress no incluye el origen (Ingress controller o pods de `shop`). Reaplica el YAML del curso.

### 4 — Norte-sur sigue

**Acción:**

```bash
curl -sH 'Host: shop.local' http://127.0.0.1:8080/
```

**Por qué:** El Ingress vive en `ingress-nginx`; la policy de shop admite ese namespace en ingress.

**Resultado esperado:** la app responde igual que en M05-01.

## Comprueba tu entendimiento

**Quién está seleccionado**

`kubectl -n payments get netpol payments-deny-from-shop -o yaml`

→ `podSelector` de `payments-api`; `ingress.from` solo namespace `payments`.

**DNS**

`kubectl -n shop exec netcheck -- nslookup kubernetes.default`

→ Resuelve (esta policy no toca egress; DNS sigue abierto).

## Reto

### 1 — Abrir payments solo a shop

Cambia la policy de `payments` para **permitir** `namespaceSelector` de `shop` y verifica el curl.

<details>
<summary>Ver solución</summary>

Añade un `from.namespaceSelector` con `kubernetes.io/metadata.name: shop`.
`curl` desde `netcheck` vuelve a devolver `payments-ok`. Luego deja el lab en modo restringido o bórralo con
`kubectl -n payments delete netpol payments-deny-from-shop` si lo necesitas para módulos siguientes.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| Timeout a shop-web también | Ingress/from mal selector | Reaplica el YAML del curso |
| payments sigue abierto | CNI sin NP | Este curso usa Calico; `health-check.sh` |
