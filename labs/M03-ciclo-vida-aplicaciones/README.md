# M03 — Ciclo de vida de aplicaciones

[← Página anterior](../M02-introduccion-kubernetes/M02-02-validar-nodos-sistema.md) · [Siguiente página →](M03-01-deploy-replicaset-rollout.md)

> [!NOTE]
> **Cómo funciona este módulo.** Primero la **teoría**, luego la **demostración guiada** del
> formador, y después **practicas tú** en el/los laboratorio(s).

## Qué aprenderás

- Qué es un Deployment, un ReplicaSet y un Pod, y quién crea a quién.
- Escalar, ver en qué nodo cae cada réplica, hacer canary y pases de versión con YAML.
- Reaccionar cuando la imagen nueva no existe (`ImagePullBackOff`) y hacer rollback.
- Externalizar config (`ConfigMap`) y secretos (`Secret`).
- **No** trabajamos Service aún: eso es M05 (endpoints, impostor, Ingress).

## Cómo practicar (sin scripts)

En estos labs **no** hay `POD=$(kubectl … jsonpath=…)`. El gesto es siempre el mismo:

1. `kubectl -n shop get pods` (o `get pods -o wide`).
2. Copias el **NAME** de la tabla.
3. Lo pegas: `kubectl -n shop describe pod …` / `exec …`.

El sufijo (`-6f7d8c9b4-xk2lm`) cambia en cada clúster y en cada ReplicaSet. Si copias el
nombre de la guía al pie de la letra, fallará.

Los pases de versión son **ficheros** en `infra/manifests/m03/basico/`, no un `kubectl patch`.

## Teoría

Los objetos básicos (Pod, Volume, Namespace) se combinan en **controladores**:
ReplicaSet, Deployment, StatefulSet, DaemonSet, Job.

| Objeto | Responsabilidad |
|--------|-----------------|
| **Pod** | Instancia en ejecución (efímera). El nombre incluye un hash: no lo memorices, lo copias. |
| **ReplicaSet** | “Quiero N pods con esta plantilla” (labels/selectors). |
| **Deployment** | Cómo actualizar esa plantilla (rolling, historial, rollback). |
| **ConfigMap** | Config no sensible inyectada como env o fichero. |
| **Secret** | Igual, pero para credenciales (sigue siendo base64, no magia). |
| **Namespace** | Espacio de trabajo (aquí `shop`). |

kubectl aplica YAML: el clúster se gobierna **como código**. El cliente habla con el
apiserver; las imágenes salen del registry.

![kubectl aplica un Deployment; el clúster tira imágenes y coloca Pods](../img/M03-demo-deployment.png)

Estrategia **RollingUpdate**: Kubernetes sube pods nuevos y baja los viejos respetando
`maxUnavailable` / `maxSurge`. Cada revisión es un ReplicaSet. Si la versión nueva no
pone `Ready` (imagen inexistente, probe que falla), los Pods viejos **siguen** y
`kubectl rollout undo` vuelve al ReplicaSet anterior.

![Un Deployment con dos ReplicaSets (v1 y v2) durante un rolling update](../img/M03-demo-replicaset.png)

Un **canary** es otro Deployment (pocas réplicas, versión nueva) al lado del estable.
Cuando convence, promocionas el estable y borras el canary.

Los **namespaces** aíslan recursos (p. ej. `shop` vs `payments` en M05).

![Dos namespaces con pods y un Service](../img/M03-demo-namespaces.png)

> [!WARNING]
> `kubectl delete pod` no cambia el estado deseado: el ReplicaSet crea otro.
> El contrato que debes cambiar es el **manifiesto del Deployment**.

Los nodos son finitos (CPU/RAM). En los manifiestos del curso cada contenedor declara
`resources.requests` y `limits` para no comerse el Codespace.

## Demostración guiada

> Recorrido que hace el formador en vivo.

1. `kubectl apply -f infra/manifests/m03/basico/shop-web-v1.yaml` deja 2 Pods. `get pods`,
   copiar un NAME, `describe`: Args `shop-web v1`. `-o wide` enseña el worker.
2. Escalar con `shop-web-replicas-4.yaml` y volver a v1: mismo ReplicaSet, distinto recuento.
3. Canary (`shop-web-canary`) = un Deployment extra. Promoción = aplicar `shop-web-v2.yaml`
   y borrar el canary. `rollout history` lista revisiones.
4. `shop-web-imagen-mala.yaml` deja Pods en `ImagePullBackOff`; `rollout undo` recupera v2.
5. `shop.yaml` añade ConfigMap/Secret y `envFrom`. `exec` + `printenv` (NAME copiado) muestra `APP_*`.

## Ahora practica tú

| Lab | Título | Qué harás |
|-----|--------|-----------|
| M03-01 | [Deployment, ReplicaSet y pases de versión](M03-01-deploy-replicaset-rollout.md) | v1 → escala → canary → v2 → imagen mala → rollback |
| M03-02 | [ConfigMap y Secret](M03-02-configmap-secret.md) | Inyectar env y comprobarla en un Pod |

→ Empieza por **[M03-01 — Deployment, ReplicaSet y pases de versión](M03-01-deploy-replicaset-rollout.md)**.
