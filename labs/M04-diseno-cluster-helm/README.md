# M04 — Diseño y configuración del clúster

[← Página anterior](../M03-ciclo-vida-aplicaciones/M03-02-configmap-secret.md) · [Siguiente página →](M04-01-ha-fallo-maestro.md)

> [!NOTE]
> **Cómo funciona este módulo.** Primero la **teoría**, luego la **demostración guiada** del
> formador, y después **practicas tú** en el/los laboratorio(s).

## Qué aprenderás

- Explicar el diseño HA (quórum de etcd) y contrastarlo con este lab de **un** maestro.
- Ver qué pasa al parar el control-plane (la API se cae) y recuperarlo.
- Distinguir instalación del clúster (kind/kubeadm) de instalación de *software en* el clúster (Helm).
- Instalar y actualizar un chart con values personalizados.

## Teoría

etcd es un clúster Raft. Con **tres** miembros, puedes perder **uno** y seguir teniendo quórum.
Dos maestros no bastan: un fallo te deja sin mayoría.

kind, con varios `role: control-plane`, crearía un contenedor **external-load-balancer**
delante de los kube-apiserver. **Este laboratorio no lo monta**: un control-plane y dos
workers, para que kind arranque limpio en Codespaces.

El esquema de un nodo máster (API + etcd + scheduler) y workers (kubelet) es el del diagrama.
La HA de tres maestros queda como diseño de producción, no como topología del Codespace.

![API Server, etcd y kubelet](../img/M02-demo-arquitectura.png)

> [!WARNING]
> Material introductorio a menudo dice “sólo hay un máster”. Aquí es así a propósito.
> `docker stop` de ese nodo tumba la API. En producción harían falta tres miembros de etcd.

| Capa | Qué hay en este lab |
|------|---------------------|
| Nodos | 1 CP + 2 workers (kind = kubeadm por nodo) |
| Red de Pods | Calico |
| Entrada | ingress-nginx + hostPorts |
| Paquetes | Helm (charts) |

> [!NOTE]
> **Helm** no instala Kubernetes. Instala **aplicaciones y operadores** *dentro* del clúster
> (Deployments, CRDs, Services) versionados y parametrizados con `values.yaml`.

## Demostración guiada

> Recorrido que hace el formador en vivo.

1. `docker ps` lista un control-plane y dos workers. `kubectl get --raw=/readyz` está ok.
2. Al hacer `docker stop k8s-ops-control-plane`, kubectl deja de responder: no hay segundo apiserver.
   `docker start` lo recupera.
3. `helm install` del chart `infra/charts/ops-web` con `-f values-staging.yaml` materializa réplicas
   y, si se activa, un Ingress. `helm upgrade` cambia el mensaje sin reescribir YAML a mano.

## Ahora practica tú

| Lab | Título | Qué harás |
|-----|--------|-----------|
| M04-01 | [Un maestro: qué pasa si cae](M04-01-ha-fallo-maestro.md) | Parar el control-plane y ver que la API se cae |
| M04-02 | [Helm con values](M04-02-helm-values.md) | Instalar y actualizar `ops-web` |

→ Empieza por **[M04-01 — Un maestro: qué pasa si cae](M04-01-ha-fallo-maestro.md)**.
