# M01-01 — Bootstrap del entorno

[← Página anterior](README.md) · [Siguiente página →](M01-02-cluster-operativo.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Dejar operativo tu fork, el Codespace y las herramientas (`docker`, `kind`, `kubectl`, `helm`).

### Prerrequisitos

- Cuenta GitHub personal.
- Navegador actualizado y permiso para crear Codespaces.
- Si Docker te suena a nuevo, haz antes **[M00](../M00-fundamentos-contenedores/README.md)**.

### En qué consiste

Fork del repositorio, arranque del Codespace y comprobación de que el `postCreate` instaló kind.

### 1 — Fork y Codespace

**Acción:** Haz fork de `my-it-labs/kubernetes-administradores-201` a tu cuenta. En **tu fork**:
**Code → Codespaces → Create codespace on main**. Elige máquina **8 vCPU / 16 GB** si el menú lo permite.

**Por qué:** Cada alumno trabaja en su copia. Prometheus (M07) agradece RAM de sobra.

**Resultado esperado:** Terminal en `/workspaces/kubernetes-administradores-201` (o el nombre de tu fork).

> [!TIP]
> Si el Codespace arranca en 2 vCPU / 8 GB, M01–M06 suelen aguantar; M07 puede quedarse sin memoria.

### 2 — Herramientas: `bootstrap-tools.sh`

**Acción:** Al crear el Codespace se ejecuta solo. Si `kind` no aparece, lánzalo a mano:

```bash
bash scripts/bootstrap-tools.sh
command -v docker kubectl helm kind
docker info >/dev/null && echo docker-ok
```

**Por qué:** kind no viene en todas las imágenes base. El script fija el binario para todo el grupo.

**Resultado esperado:** los cuatro comandos resuelven ruta; `docker info` no error.

### 3 — Árbol del repositorio

**Acción:**

```bash
ls labs scripts infra infra/kind infra/addons
```

**Por qué:** Los labs leen manifiestos de `infra/`. Si no ves esas carpetas, no estás en la raíz del repo.

**Resultado esperado:** existen `scripts/cluster-up.sh` e `infra/kind/cluster.yaml`.

## Comprueba tu entendimiento

**Herramientas en PATH**

`kind version && kubectl version --client && helm version`

→ Tres versiones, sin `command not found`.

**Dónde estás**

`pwd`

→ Directorio del repo del curso (no `/home/david/Cursos/template`).

## Reto

### 1 — Qué instala el postCreate

Abre `.devcontainer/devcontainer.json` y localiza `postCreateCommand`.

<details>
<summary>Ver solución</summary>

Ejecuta `chmod +x scripts/*.sh && bash scripts/bootstrap-tools.sh`. Docker, kubectl y Helm llegan por *features* del devcontainer; kind lo añade el script.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `kind: command not found` | postCreate incompleto | `bash scripts/bootstrap-tools.sh` |
| Docker daemon error | Codespace aún inicializando | Esperar y repetir `docker info` |
| No aparece Create codespace | Estás en el repo original sin fork | Fork primero, Codespace en **tu** copia |
