# M05 — Red y networking

[← Página anterior](../M04-diseno-cluster-helm/M04-02-helm-values.md) · [Siguiente página →](M05-01-services-ingress.md)

> [!NOTE]
> **Cómo funciona este módulo.** Primero la **teoría**, luego la **demostración guiada** del
> formador, y después **practicas tú** en el/los laboratorio(s).

## Qué aprenderás

- Por qué un Pod no sirve como nombre estable (su IP muere con él).
- Cómo un Service elige backends **por labels** (Endpoints).
- Qué pasa si un Pod suelto lleva las mismas etiquetas (impostor).
- Entrar por Ingress (borde del Codespace).
- Cortar este-oeste con NetworkPolicy entre namespaces.

## Teoría

Cada Pod recibe una IP del CIDR de Calico (`10.244.0.0/16` aquí). Esa IP muere con el Pod,
así que no sirve como nombre estable. Un **Service** es la abstracción que agrupa Pods
**por selector de labels** y define cómo acceder a ellos (ClusterIP, NodePort, puerto).

El Service **no** dice “los Pods que creó el Deployment X”. Dice `selector: app=shop-web`.
Cualquier objeto Ready con esas labels entra en **Endpoints**. Un `kubectl run` mal
etiquetado, un Pod YAML de prueba o un compañero de lab te mete tráfico en un proceso
que no es “la app”.

![Service delante de Pods en varios nodos](../img/M05-demo-service.png)

**Ingress** mapea host y rutas HTTP hacia Services. En cloud suele haber un balanceador
de pago delante; aquí el controller **ingress-nginx** entra por `:8080`/`:8443` del Codespace.

| Tipo | Alcance | Uso típico |
|------|---------|------------|
| **ClusterIP** | Solo dentro del clúster | Este-oeste |
| **NodePort** | Puerto alto en cada nodo | Labs / legado |
| **LoadBalancer** | IP externa (cloud) | En kind casi nunca hay LB cloud |
| **Ingress** | L7 HTTP(S) en el controller | Host + path → Service |

**NetworkPolicy** es firewall de Pod. Por defecto **todo está permitido**. En cuanto existe una
policy que selecciona un Pod, ese Pod pasa a “deny + lo que la policy permite”.

> [!WARNING]
> Una policy de egress que no lista DNS (`kube-system`, puerto 53) “rompe internet” dentro del namespace.
> Calico hace cumplir estas reglas; kindnet (CNI por defecto de kind) no era suficiente para este curso.

## Demostración guiada

> Recorrido que hace el formador en vivo.

1. `kubectl -n shop get pods -o wide` y `get endpoints shop-web`: las IPs coinciden.
2. Se aplica `pod-impostor.yaml` (label `app: shop-web`, texto `IMPOSTOR`). Endpoints
   ganan una IP. Varios `curl` desde `netcheck` a `http://shop-web.shop` mezclan la app
   y `IMPOSTOR`. Al borrar el Pod suelto, el Deployment no lo recrea.
3. Ingress `shop.local` por `:8080` del Codespace (`Host: shop.local`).
4. Tras las policies, `netcheck` sigue llegando a `shop-web` y **deja de** llegar a
   `payments-api.payments`.

## Ahora practica tú

| Lab | Título | Qué harás |
|-----|--------|-----------|
| M05-01 | [Services, endpoints e Ingress](M05-01-services-ingress.md) | Endpoints, impostor, borde HTTP |
| M05-02 | [NetworkPolicy entre namespaces](M05-02-networkpolicy.md) | Cortar shop → payments |

→ Empieza por **[M05-01 — Services, endpoints e Ingress](M05-01-services-ingress.md)**.
