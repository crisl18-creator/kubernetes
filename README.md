# Kubernetes para Administradores

[Siguiente página →](labs/M00-fundamentos-contenedores/README.md)

Formación **100 % práctica** para **administrar un clúster Kubernetes operativo**.
Si no has usado Docker, empiezas por **M00** (contenedores en el Codespace).
Después levantas el clúster con **kind**, despliegas aplicaciones, configuras red y
seguridad, monitorizas y persistes datos.

## Cómo funciona el curso

1. Haz **fork** de este repositorio en tu cuenta de GitHub.
2. Abre un **Codespace** desde tu fork (**Code → Codespaces → Create codespace on main**).
3. Sigue los módulos en orden con **← Página anterior · Siguiente página →**.

Cada módulo tiene un **README** (teoría + demostración) y uno o varios **laboratorios** donde practicas tú.

## Antes de empezar

| Requisito | Detalle |
|-----------|---------|
| Cuenta GitHub | Personal y gratuita |
| Codespace | Recomendado **8 vCPU / 16 GB RAM** (Prometheus en M07) |
| Navegador | Chromium actualizado |
| Conexión | Salida a GitHub, GHCR, `registry.k8s.io` y Docker Hub |
| Infraestructura | [infra/README.md](infra/README.md) |
| Problemas frecuentes | [labs/TROUBLESHOOTING.md](labs/TROUBLESHOOTING.md) |

No instales Docker ni Kubernetes en tu equipo: el laboratorio vive en el Codespace.

## A quién va dirigido

Administradores de sistemas que van a **configurar y administrar** clústeres Kubernetes.

**Requisitos previos:** Linux y línea de comandos. **No hace falta** saber Docker:
eso se trabaja en M00, en el mismo Codespace.

## Temario

Formación práctica: cada bloque tiene teoría en el README del módulo y laboratorios guiados.

### Fundamentos de contenedores (previo) — [M00](labs/M00-fundamentos-contenedores/README.md) · [M00 imágenes](labs/M00-imagenes-compose-cicd/README.md)

- El contenedor como proceso; `ENTRYPOINT`, `CMD` y args.
- Estados, `docker ps` y limpieza.
- Interacción (`logs`, `exec`), puertos (web visible en Codespace) y volúmenes.
- Dockerfile, build, tags y **multistage**.
- Docker Compose (dev con build context y prod).
- CI/CD con GitHub Actions hasta publicar en GHCR.

### Introducción a Kubernetes — [M01](labs/M01-entorno-codespace-kind/README.md) · [M02](labs/M02-introduccion-kubernetes/README.md)

- Conceptos principales.
- Arquitectura del clúster.
- API de Kubernetes.
- Instalación y validación del entorno (clúster **kind** en Codespace; cada nodo arranca con kubeadm).
- Laboratorio: instalar el clúster y validar (`kubectl describe nodes`, `kubectl get pods --all-namespaces`).

### Gestión del ciclo de vida de aplicaciones — [M03](labs/M03-ciclo-vida-aplicaciones/README.md)

- Deployment, ReplicaSet y Pods: quién crea a quién.
- Escalado, canary, pases de versión, imagen que falla y rollback (todo con manifiestos).
- ConfigMaps y Secrets.
- Laboratorio: primero lo básico del controlador; después config. El Service se trabaja en M05.

### Diseño y configuración del clúster — [M04](labs/M04-diseno-cluster-helm/README.md)

- Diseño de clústeres y alta disponibilidad.
- Redes y comunicación segura.
- Instalación y despliegue de un clúster.
- Pruebas de clúster y nodos.
- Helm para instalar y actualizar aplicaciones y servicios.
- Laboratorio: un control-plane y dos workers; parar el maestro y ver el efecto; Helm con values personalizados.

### Red y networking — [M05](labs/M05-red-networking/README.md)

- Networking en Kubernetes.
- Configuración de Pods y Services.
- Balanceadores de carga.
- Laboratorio: endpoints del Service; un Pod impostor con las mismas labels; NetworkPolicy entre namespaces.

### Seguridad — [M06](labs/M06-seguridad/README.md)

- Autenticación y autorización (RBAC).
- Certificados TLS.
- Políticas de red.
- Laboratorio: usuario con permisos limitados en un namespace; NetworkPolicy entre Pods.

### Mantenimiento y monitorización — [M07](labs/M07-mantenimiento-monitorizacion/README.md)

- Actualización de clústeres y nodos.
- Políticas de backup y restauración.
- Prometheus y Grafana.
- Introducción al Operator Pattern.
- Laboratorio: Prometheus; backup/restore de etcd; operador (ServiceMonitor / Prometheus Operator).

### Almacenamiento — [M08](labs/M08-almacenamiento/README.md)

- Persistent Volumes (PV) y Persistent Volume Claims (PVC).
- StorageClasses.
- StatefulSets.
- Laboratorio: PV/PVC y persistencia de datos tras reiniciar Pods.

## Módulos

| # | Módulo | Índice |
|---|--------|--------|
| M00 | Fundamentos de contenedores | [labs/M00-fundamentos-contenedores/](labs/M00-fundamentos-contenedores/README.md) |
| M00 | Imágenes, Compose y registro | [labs/M00-imagenes-compose-cicd/](labs/M00-imagenes-compose-cicd/README.md) |
| M01 | Entorno Codespace y kind | [labs/M01-entorno-codespace-kind/](labs/M01-entorno-codespace-kind/README.md) |
| M02 | Introducción a Kubernetes | [labs/M02-introduccion-kubernetes/](labs/M02-introduccion-kubernetes/README.md) |
| M03 | Ciclo de vida de aplicaciones | [labs/M03-ciclo-vida-aplicaciones/](labs/M03-ciclo-vida-aplicaciones/README.md) |
| M04 | Diseño y configuración del clúster | [labs/M04-diseno-cluster-helm/](labs/M04-diseno-cluster-helm/README.md) |
| M05 | Red y networking | [labs/M05-red-networking/](labs/M05-red-networking/README.md) |
| M06 | Seguridad | [labs/M06-seguridad/](labs/M06-seguridad/README.md) |
| M07 | Mantenimiento y monitorización | [labs/M07-mantenimiento-monitorizacion/](labs/M07-mantenimiento-monitorizacion/README.md) |
| M08 | Almacenamiento | [labs/M08-almacenamiento/](labs/M08-almacenamiento/README.md) |

## Empieza aquí

→ **[M00 — Fundamentos de contenedores](labs/M00-fundamentos-contenedores/README.md)** (si ya dominas Docker, puedes saltar a [M01](labs/M01-entorno-codespace-kind/README.md))
