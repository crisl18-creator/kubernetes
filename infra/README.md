# Infraestructura de laboratorio

Clúster Kubernetes **operativo** para el curso: **kind** (1 control-plane + 2 workers) + addons (Calico, ingress-nginx,
metrics-server, StorageClass `local-path`).

## Arranque

Desde la raíz del repositorio, en el Codespace:

```bash
./scripts/bootstrap-tools.sh   # automático al crear el Codespace
./scripts/cluster-up.sh        # crea k8s-ops + addons
./scripts/health-check.sh
```

Reset:

```bash
./scripts/cluster-down.sh
./scripts/cluster-up.sh
```

## Componentes

| Ruta | Uso |
|------|-----|
| `m00/` | Web visual, Dockerfiles y Compose del bloque previo (puertos 8888/8889) |
| `kind/cluster.yaml` | kind `k8s-ops`: 1 control-plane + 2 workers, sin CNI por defecto |
| `addons/calico.yaml` | CNI + NetworkPolicy (Calico v3.29.3) |
| `addons/ingress-nginx.yaml` | Ingress controller para kind (puertos 80/443 del nodo) |
| `addons/metrics-server.yaml` | Métricas (`kubectl top`) con TLS inseguro hacia kubelet |
| `addons/local-path-storage.yaml` | StorageClass por defecto `local-path` |
| `manifests/` | YAML de los labs (M03, M05, M06, M08) |
| `charts/ops-web/` | Chart Helm de la app de demostración |
| `monitoring/values.yaml` | Valores slim de kube-prometheus-stack (M07) |

## Topología

```text
            Codespace :8080 / :8443
                    │
         extraPortMappings (control-plane-1)
                    │
              ingress-nginx
                    │
         Services / NetworkPolicies
                    │
         workers + control-plane (Calico)
```

- Contexto kubectl: `kind-k8s-ops`
- API: kube-apiserver del único control-plane
- Pod CIDR: Calico (`10.244.0.0/16`) · Service CIDR: `10.96.0.0/12`

## Requisitos

- GitHub Codespace con Docker (`.devcontainer`)
- **8 vCPU / 16 GB RAM** recomendados
- Acceso saliente a GHCR, `registry.k8s.io` y Docker Hub
