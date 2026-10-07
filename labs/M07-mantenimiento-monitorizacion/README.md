# M07 — Mantenimiento y monitorización

[← Página anterior](../M06-seguridad/M06-02-tls-networkpolicy.md) · [Siguiente página →](M07-01-prometheus-grafana.md)

> [!NOTE]
> **Cómo funciona este módulo.** Primero la **teoría**, luego la **demostración guiada** del
> formador, y después **practicas tú** en el/los laboratorio(s).

## Qué aprenderás

- Vaciar un nodo (`cordon` / `drain`) como paso de mantenimiento o upgrade.
- Recoger métricas con Prometheus y verlas en Grafana (Operator Pattern).
- Hacer un snapshot de etcd y razonar un restore.
- Distinguir “instalar un operador” de “escribir uno en Go”.

## Teoría

**Upgrade de nodos.** En kubeadm: `kubeadm upgrade plan/apply` + upgrade de kubelet por nodo,
siempre **drain** antes. En kind el binario del nodo va en la imagen `kindest/node`:
un “upgrade” de laboratorio es drenar, borrar el contenedor y recrear el clúster con otra
versión — o, más útil como hábito: `cordon` + `drain` + comprobar que los Pods se reubican.

**Backup.** Dos capas:

| Capa | Qué salva | Ejemplo |
|------|-----------|---------|
| Deseado | YAML / Helm / git | `infra/manifests` |
| etcd | Estado real (incl. Secrets, leases) | `etcdctl snapshot save` |

Un snapshot que **nunca** has intentado leer no es un backup. El restore de etcd en HA es
delicado (identidad de miembros). En el lab verificas el snapshot y simulas el fallo;
si el restore crudo rompe el quórum, `cluster-up` reconstruye el laboratorio.

**Componentes habituales** de un clúster que ya no es “vacío”: proxy inverso (Ingress),
TLS (cert-manager o un Secret como en M06), **Prometheus / Grafana** y, en muchos sitios, logs
(Kibana). Este módulo cubre métricas; el proxy y el TLS ya los montaste.

**Operator Pattern.** Extiendes la API con un CRD y un controlador que reconcilia.
Prometheus Operator vigila objetos `Prometheus` y `ServiceMonitor` y materializa el scrape.

> [!WARNING]
> kube-prometheus-stack es pesado. Usa Codespace **16 GB**. Si el nodo kind entra en
> MemoryPressure: desinstala el release o recrea el clúster.

## Demostración guiada

> Recorrido que hace el formador en vivo.

1. `kubectl drain k8s-ops-worker --ignore-daemonsets --delete-emptydir-data` mueve Pods al
   otro worker. `uncordon` lo reabre.
2. `helm install kps` con `infra/monitoring/values.yaml` crea el namespace `monitoring`,
   CRDs y Grafana. Un port-forward `--address 0.0.0.0` a `svc/kps-grafana` abre la UI en `:3000`.
3. `etcdctl snapshot save` dentro del control-plane deja un fichero que `snapshot status`
   declara íntegro.

## Ahora practica tú

| Lab | Título | Qué harás |
|-----|--------|-----------|
| M07-01 | [Prometheus y Grafana](M07-01-prometheus-grafana.md) | Stack de métricas |
| M07-02 | [Backup y restore de etcd](M07-02-etcd-backup.md) | Snapshot y fallo simulado |
| M07-03 | [Operator Pattern](M07-03-operator-pattern.md) | CRDs y ServiceMonitor |

→ Empieza por **[M07-01 — Prometheus y Grafana](M07-01-prometheus-grafana.md)**.
