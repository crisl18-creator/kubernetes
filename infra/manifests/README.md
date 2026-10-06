Manifiestos de los laboratorios. Aplícalos cuando el guion lo pida:

| Ruta | Módulo |
|------|--------|
| `m03/basico/*.yaml` | M03-01: namespace, v1, réplicas, canary, v2, imagen mala |
| `m03/shop.yaml` | M03-02: `shop-web` + ConfigMap, Secret y Service |
| `m05/ingress-y-red.yaml` | Ingress, namespace `payments`, pod `netcheck` |
| `m05/pod-impostor.yaml` | Pod suelto con labels de `shop-web` (ensucia Endpoints) |
| `m05/networkpolicy.yaml` | NetworkPolicy shop/payments |
| `m06/rbac-shop-dev.yaml` | Role + RoleBinding de `appuser` |
| `m08/pvc-inventory.yaml` | PVC + Deployment `inventory` |
| `m08/statefulset-catalog.yaml` | StatefulSet `catalog` |
