# M00 — Imágenes, Compose y registro

[← Página anterior](../M00-fundamentos-contenedores/M00-05-volumenes.md) · [Siguiente página →](M00-06-dockerfile.md)

> [!NOTE]
> **Cómo funciona este módulo.** Primero la **teoría**, luego la **demostración guiada** del
> formador, y después **practicas tú** en el/los laboratorio(s).

Segunda parte del bloque previo: **tú construyes** la imagen, orquestas varios contenedores
con Compose y publicas en GHCR desde GitHub Actions.

## Qué aprenderás

- Escribir un Dockerfile y personalizar nginx con tu HTML.
- Entender **multistage**: una etapa construye, otra es la imagen final.
- Poner **tags** (`v1`, `v2`, `dev`, `prod`) y ver la diferencia en el navegador.
- Orquestar web + API con **Docker Compose** y un **build context**.
- Distinguir compose de desarrollo (bind mount) y de **prod** (imagen cerrada).
- Publicar la imagen con **GitHub Actions** en `ghcr.io`.

## Teoría

### Imagen = capas + metadatos

`docker build` lee un Dockerfile y produce una imagen. Un **tag** es un alias
(`m00-web:v1`). La misma imagen puede tener varios tags.

```text
Dockerfile + context (carpeta)  →  docker build -t nombre:tag  →  docker run
```

El **context** es la carpeta que envías al daemon (por eso `COPY site/` busca `site/`
*dentro* de esa carpeta, no en todo el repo).

### Dockerfile: lo mínimo

```dockerfile
FROM nginx:1.27-alpine
COPY site/ /usr/share/nginx/html
```

| Instrucción | Qué hace |
|-------------|----------|
| `FROM` | Imagen de partida |
| `COPY` | Copia ficheros del context |
| `RUN` | Ejecuta un comando **en el build** (queda en la capa) |
| `CMD` / `ENTRYPOINT` | Proceso cuando arranque el contenedor |

### Multistage

Dos (o más) `FROM`. La etapa final solo copia el artefacto. La etapa `stamp` no viaja
a producción.

```text
alpine (stamp)  --COPY site + RUN echo-->  ficheros
nginx  (runtime) --COPY --from=stamp-->   imagen pequeña que sirves
```

### Compose

Un YAML lista **servicios**. Cada servicio es un contenedor con imagen o `build:`.

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports: ["8888:80"]
    volumes:
      - ./site:/usr/share/nginx/html:ro
```

| Modo | Fichero del curso | Idea |
|------|-------------------|------|
| **Dev** | `compose.yaml` | Build local + volumen: editas HTML y recargas |
| **Prod** | `compose.prod.yaml` | Multistage `runtime`, **sin** bind mount |

`docker compose up --build` crea la red, construye y arranca. `down` lo tira.

### CI/CD hasta el registry

Hasta M00-09 **tú** construías en el Codespace. Eso no escala: cada persona tendría
una imagen distinta, en un disco que se borra al apagar el Codespace. CI/CD mueve
ese trabajo a un **robot** de GitHub.

| Sigla | Significa | En este curso |
|-------|-----------|----------------|
| **CI** (Continuous Integration) | Cada cambio se **construye y comprueba** igual, en una máquina limpia | Actions ejecuta `docker build` |
| **CD** (Continuous Delivery/Deploy) | El artefacto se **publica** donde otros pueden usarlo | `docker push` a GHCR |

```text
tú (commit / botón Run)
        │
        ▼
  GitHub Actions          ← no es tu Codespace
  (runner ubuntu-latest)
        │  1. clona el repo (checkout)
        │  2. se identifica en el registry (login)
        │  3. docker build (etapa runtime)
        │  4. docker push
        ▼
  GHCR  ghcr.io/<cuenta>/<repo>/m00-web:tag
        │
        ▼
  Cualquier máquina (Codespace, kind, un servidor) hace docker pull
```

**Piezas que se confunden**

| Pieza | Qué es | Qué no es |
|-------|--------|-----------|
| **Workflow** | Receta YAML en `.github/workflows/` | Un contenedor |
| **Runner** | VM de GitHub que ejecuta esa receta | Tu Codespace |
| **Job** | Un bloque de pasos (`publish`) | El registry |
| **Action** | Un paso reutilizable (`checkout`, `login`, `build-push`) | Un comando que inventas tú |
| **Registry** | Almacén de **imágenes** (GHCR, Docker Hub) | Git (eso guarda el código) |
| **GHCR** | GitHub Container Registry: `ghcr.io/…` | El repo git; convive en GitHub, pero es otro servicio |
| **Tag de imagen** | `latest`, o el SHA del commit | La rama `main` de git (son mundos distintos) |
| **`GITHUB_TOKEN`** | Contraseña temporal que GitHub inyecta en el job | Tu password de login web |

El workflow del curso está en `.github/workflows/m00-publish-image.yml`. Se dispara de
dos maneras:

1. **A mano** (`workflow_dispatch`): botón **Run workflow** en Actions.
2. **Al hacer push** a `main` si cambias `infra/m00/web/**` o el propio YAML.

> [!NOTE]
> El build de CI usa la misma receta de **prod** (`Dockerfile` + `target: runtime`):
> HTML cocido en la imagen, sin volumen. Es M00-09, pero en un robot.

> [!WARNING]
> Tienes que lanzarlo en **tu fork**. En el repo `my-it-labs/…` un alumno no puede
> crear paquetes ni, a veces, disparar Actions.

## Demostración guiada

> Recorrido que hace el formador en vivo.

1. `docker build -t m00-web:v1 -f infra/m00/web/Dockerfile.dev infra/m00/web` y
   `docker run -d -p 8888:80 m00-web:v1` abre la tarjeta verde **sin** bind mount:
   el HTML ya va **dentro** de la imagen.
2. Se reconstruye con `site-v2` como `m00-web:v2`. Al recrear el contenedor con `:v2`,
   el navegador (misma URL) pasa a naranja.
3. `docker compose -f infra/m00/web/compose.yaml up --build` levanta **web + api**.
   8888 es la web; 8889 responde `soy la api del compose`.
4. En **tu fork**: Actions → **M00 publicar imagen** → **Run workflow**. El runner
   (no el Codespace) hace checkout, login en GHCR y `build --target runtime`. Al
   terminar, **Packages** muestra `m00-web`.

## Ahora practica tú

| Lab | Título | Qué harás |
|-----|--------|-----------|
| M00-06 | [Tu Dockerfile](M00-06-dockerfile.md) | Build de v1 y verla en 8888 |
| M00-07 | [Multistage y tags](M00-07-multistage-tags.md) | v1 vs v2 en el navegador |
| M00-08 | [Compose de desarrollo](M00-08-compose-dev.md) | Web + API + build context |
| M00-09 | [Compose de producción](M00-09-compose-prod.md) | Imagen cerrada, sin volumen |
| M00-10 | [Actions y GHCR](M00-10-actions-ghcr.md) | Publicar la imagen en el registry |

→ Empieza por **[M00-06 — Tu Dockerfile](M00-06-dockerfile.md)**.
