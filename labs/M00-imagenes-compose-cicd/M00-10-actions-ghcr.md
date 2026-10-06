# M00-10 — Actions y GHCR

[← Página anterior](M00-09-compose-prod.md) · [Siguiente página →](../M01-entorno-codespace-kind/README.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Publicar la imagen `m00-web` (etapa **runtime**, la de prod) en **GHCR** usando GitHub
Actions en **tu fork**, entendiendo cada pieza: workflow, runner, registro, token y tags.

### Prerrequisitos

- Has hecho [M00-09](M00-09-compose-prod.md): sabes qué es un build **sin** volumen.
- Trabajas sobre **tu fork**, no sobre `my-it-labs/kubernetes-administradores-201`.
- El Codespace (si lo tienes abierto) **no** es quien construye ahora: lo hace GitHub.

### En qué consiste

Primero compruebas que estás en el sitio correcto y que Actions está encendido.
Luego lees el YAML **línea a línea** (es la misma receta que ya corriste a mano).
Después lanzas el workflow con el botón, sigues el job, abres el paquete en GHCR
y dejas el Codespace limpio.

---

### 1 — Confirmar que estás en tu fork

**Acción:** en el navegador, mira la URL del repositorio.

- Correcto: `https://github.com/TU-USUARIO/kubernetes-administradores-201`
- Incorrecto: `https://github.com/my-it-labs/kubernetes-administradores-201`

Debajo del nombre del repo, GitHub muestra *forked from my-it-labs/…*. Si no ves
esa línea, **no es un fork**: haz **Fork** (arriba a la derecha) y entra en **tu** copia.

**Por qué:** CI/CD escribe un **paquete** (la imagen) en la cuenta que ejecuta el
workflow. En el repo de la organización el alumno no tiene permiso de `packages: write`.
El código sí se puede leer; publicar, no.

**Resultado esperado:** la URL lleva **tu** usuario. Ves *forked from my-it-labs/…*.

---

### 2 — Encender GitHub Actions en el fork

**Acción:** en **tu** fork:

1. Pestaña **Settings** (no la de tu usuario: la del **repositorio**).
2. En el menú izquierdo: **Actions → General**.
3. En *Actions permissions* elige **Allow all actions and reusable workflows**
   (o *Allow &lt;usuario&gt; actions and reusable workflows*: basta para este YAML).
4. **Save**.
5. Vuelve a la pestaña **Actions**.

La **primera** vez que un fork abre Actions, GitHub muestra un aviso
(*Workflows aren't being run on this forked repository* o *I understand my workflows…*).
Pulsa el botón para **habilitar workflows**.

**Por qué:** Un fork no ejecuta Actions hasta que el dueño lo autoriza. Es una
protección: el YAML es código que corre en una VM de GitHub; no se lanza a ciegas.

**Resultado esperado:** la pestaña **Actions** lista al menos **M00 publicar imagen**.
Si solo ves un desierto sin workflows, recarga; el fichero está en
`.github/workflows/m00-publish-image.yml`.

> [!TIP]
> **Actions** (pestaña) ≠ **Settings → Actions**. La pestaña es el historial de
> ejecuciones. Settings es el interruptor.

---

### 3 — El mapa: qué problema resuelve este lab

**Acción:** recuerda lo que ya hiciste y colócalo en esta tabla (no hace falta escribirla;
léela y señala con el dedo dónde estás ahora).

| Dónde | Qué pasaba | Límite |
|-------|------------|--------|
| M00-06 / M00-07 | `docker build` **en tu Codespace** | La imagen vive en *tu* disco y se pierde al borrar el Codespace |
| M00-09 | Compose **prod**: HTML dentro de la imagen | Sigue siendo local |
| M00-10 | Un **runner** de GitHub hace el build y **push** | Cualquiera con permiso puede `docker pull` la misma receta |

```text
  Codespace (tú)                 GitHub (el robot)
  ──────────────                 ─────────────────
  docker build …    ya lo viste   checkout del git
  docker run :8888  ya lo viste   docker build --target runtime
                                  docker push → ghcr.io/…
```

**Por qué:** CI (integración continua) = “cada vez que hay un commit decente, se
construye **igual** en una máquina limpia”. CD (entrega continua) = “el resultado
se deja en un **registry**”, no en el portátil de nadie.

**Resultado esperado:** puedes decir en una frase: *el Codespace ya no publica; Actions
construye y GHCR guarda*.

---

### 4 — Abrir el workflow y reconocer las tres zonas

**Acción:** en el Codespace (o en GitHub: pestaña **Code** → carpeta
`.github` → `workflows` → `m00-publish-image.yml`) abre el fichero.
No lo ejecutes con `bash`. Es YAML para **GitHub**, no un script de terminal.

Localiza estas **tres zonas** (están comentadas arriba del fichero):

1. `on:` — **cuándo** se dispara.
2. `jobs.publish` — **dónde** corre (`ubuntu-latest` = una VM Ubuntu que GitHub
   enciende y apaga).
3. `steps:` — **qué** hace, en orden.

**Por qué:** Un workflow es una receta. Si no separas *cuándo / dónde / qué*, el
YAML parece magia. El **runner no es tu Codespace**: es otra máquina, vacía, que
solo existe mientras dura el job.

**Resultado esperado:** señalas `workflow_dispatch`, `runs-on: ubuntu-latest` y
cuatro `steps` (Checkout, Login, Nombre en minúsculas, Build y push).

---

### 5 — `on:` cuándo se enciende el robot

**Acción:** lee el bloque `on:` y responde (en voz alta o para ti): *¿qué tengo
que hacer yo para que esto arranque?*

Hay **dos** disparadores:

| Clave | Qué la activa | Para qué sirve |
|-------|----------------|----------------|
| `workflow_dispatch` | El botón **Run workflow** en Actions | Probar ahora, sin cambiar código |
| `push` a `main` + `paths` | Un `git push` que toque `infra/m00/web/**` o este YAML | CI de verdad: cambias el HTML y se republica |

Si haces push de un README, **no** corre: `paths` lo filtra. Eso ahorra minutos
(y minutos de Actions son cuota).

**Por qué:** Sin `on:`, el YAML es un adorno. El evento es el *start* del programa.

**Resultado esperado:** sabes que en este lab usarás primero el **botón**
(`workflow_dispatch`). El push queda para el reto.

---

### 6 — Permisos y el token: quién puede escribir en GHCR

**Acción:** mira `permissions:` dentro del job.

```yaml
permissions:
  contents: read      # clonar
  packages: write     # crear/actualizar la imagen
```

El login usa `secrets.GITHUB_TOKEN`. **Tú no lo pegas.** GitHub lo inyecta en cada
run, dura solo ese job y tiene justo esos permisos.

**Por qué:** GHCR no es git. Guardar un `.tar` de imagen es otro API. Sin
`packages: write`, el `docker push` termina en `denied`. El token no es tu
contraseña de github.com: si se filtra en un log, caduca con el job.

**Resultado esperado:** relacionas `packages: write` → “puedo crear el paquete
`m00-web` en mi cuenta”.

> [!NOTE]
> **Git** guarda el Dockerfile. **GHCR** guarda el **resultado** del build (capas).
> Son dos almacenes. Por eso existe `docker pull` además de `git clone`.

---

### 7 — Cada step = un comando que ya conoces

**Acción:** recorre los `steps` y emparéjalos con lo que hiciste en el Codespace.

| Step del YAML | Equivalente que ya corriste | Detalle |
|---------------|-----------------------------|---------|
| `actions/checkout@v4` | `git clone` / abrir el repo | El runner empieza **vacío**. Sin checkout no hay `infra/m00/web` |
| `docker/login-action` | `docker login ghcr.io` | Usuario = `github.actor` (tú). Contraseña = `GITHUB_TOKEN` |
| `Nombre de imagen en minúsculas` | Cuidado con `TuUsuario` vs `tuusuario` | GHCR **exige** minúsculas en la ruta |
| `docker/build-push-action` | `docker build` + `docker push` | `context: infra/m00/web`, `file: Dockerfile`, `target: runtime`, `push: true` |

Los **tags** que se suben son dos:

```text
ghcr.io/tu-usuario/kubernetes-administradores-201/m00-web:latest
ghcr.io/tu-usuario/kubernetes-administradores-201/m00-web:<sha-del-commit>
```

- `:latest` = “la última que publicó este workflow” (se **mueve** en cada run).
- `:<sha>` = huella del commit. No se pisa: sirve para decir “esta web es *este* código”.

**Por qué:** En M00-07 etiquetabas `:v1` y `:v2` a mano. En CI el tag estable es el
**commit**. Así un clúster (más adelante, kind) puede pinchar una versión concreta.

**Resultado esperado:** ves que `target: runtime` es **el mismo** que en M00-09.
No hay bind mount. El HTML viaja **dentro** de la imagen.

---

### 8 — Lanzar el workflow a mano (clic a clic)

**Acción:** en **tu fork**, en el navegador (no en el Codespace):

1. Pestaña **Actions**.
2. En la columna izquierda, pulsa el workflow **M00 publicar imagen**
   (el `name:` del YAML).
3. A la derecha, botón **Run workflow**.
4. En el desplegable: rama **`main`** (déjala).
5. Botón verde **Run workflow**.
6. Recarga la lista si no aparece una fila nueva (a veces tarda 2–3 s).

**Por qué:** Estás disparando `workflow_dispatch`. GitHub encola un **run**, asigna
un runner, clona `main` y ejecuta los steps. Tú no tienes que tener Docker
encendido en el Codespace para este paso.

**Resultado esperado:** una ejecución nueva con un identificador (#1, #2…) y un
círculo amarillo (en cola / corriendo) o un tick verde al terminar.

> [!WARNING]
> Si el botón **Run workflow** no existe, o no está el workflow en la lista:
> o Actions sigue apagado (paso 2), o estás en `my-it-labs` sin permisos, o la
> rama no tiene el YAML (haz *Sync fork* / pull de `main`).

---

### 9 — Seguir el job y leer un log

**Acción:** pulsa la fila del run → entra en el job **publish**.

Verás los steps en orden. Un step en verde = salió 0. En rojo = falló; los
siguientes no corren.

Pulsa **Build y push (etapa runtime)** y despliega el log. Busca líneas que
mencionen `runtime`, `pushing`, o `ghcr.io`.

Tiempos típicos: 1–3 minutos la primera vez (el runner descarga nginx/alpine).
Las siguientes, más cortas (caché).

**Por qué:** El log es el `docker build` que ya viste en la terminal, solo que
ahora está en la web. Si algo falla, **no reintentas a ciegas**: abres el step
rojo y lees la última línea (`denied`, `not found`, `context`).

**Resultado esperado:** job **publish** verde. El log de build/push no termina en error.

---

### 10 — Encontrar el paquete en GHCR

**Acción:**

1. Vuelve a la **portada** de tu fork (`Code`).
2. En la columna derecha, apartado **Packages**, debería aparecer **m00-web**.
   Si no está, entra en
   `https://github.com/users/TU-USUARIO/packages?tab=packages`
   (cambia `TU-USUARIO`) o en tu perfil → **Packages**.
3. Abre **m00-web**.
4. Copia el nombre de pull que GitHub muestra. Tiene esta forma:

```text
ghcr.io/tu-usuario/kubernetes-administradores-201/m00-web:latest
```

Todo va en **minúsculas**. Si tu usuario tiene mayúsculas en la web, en GHCR
no.

**Por qué:** Eso es el **registry**. El repo git sigue teniendo el Dockerfile;
el paquete es el binario (capas) que un `docker pull` descarga. En un clúster
real, los nodos no clonan el curso: tiran de un registry.

**Resultado esperado:** ficha del paquete con al menos el tag `latest` y, si el
workflow lo publicó, un tag con el SHA del commit.

> [!TIP]
> El paquete nace **privado** por defecto. Para este curso **tú** lo ves con tu
> sesión. Si un compañero no puede hacer pull: Package settings → visibility
> **Public**, o que se autentique. No hace falta publicarlo para aprobar el lab.

---

### 11 — (Opcional) Bajar la imagen al Codespace y verla

Este paso **no** es obligatorio. El lab ya está cumplido si el paquete existe.
Si el `pull` pide login y no tienes token, **párate en el paso 10**.

**Acción:** en la terminal del Codespace, sustituye `tu-usuario` por el de GHCR
(minúsculas):

```bash
docker pull ghcr.io/tu-usuario/kubernetes-administradores-201/m00-web:latest
```

- Si responde `denied` o `unauthorized`: el paquete es privado y este Codespace
  no lleva credenciales de GHCR. No insistas. El objetivo era **publicar**.
- Si el pull funciona:

```bash
docker ps
docker rm -f m00-web
docker run -d --name m00-web -p 8888:80 \
  ghcr.io/tu-usuario/kubernetes-administradores-201/m00-web:latest
curl -sS http://127.0.0.1:8888/ | grep -E 'Hola|build'
```

Abre **Ports → 8888**. Es la tarjeta verde de **prod** (y, si el build generó
`build-info.txt`, también `/build-info.txt`).

**Por qué:** Este es el ciclo que usará Kubernetes: CI publica → el nodo hace
`pull` → corre el contenedor. Ya no dependes del `docker build` local.

**Resultado esperado:** o bien la web en 8888, o bien un `denied` que sabes
interpretar (paquete privado / sin login). Las dos salidas son válidas aquí.

---

### 12 — Limpiar el Codespace a mano

**Acción:**

```bash
docker compose -f infra/m00/web/compose.yaml down
docker compose -f infra/m00/web/compose.prod.yaml down
docker ps -a
docker rm -f m00-web m00-echoer m00-api
docker ps
```

Si un `rm` dice *No such container*, ignóralo y sigue con el siguiente nombre.

**Por qué:** M01 va a usar kind y el puerto 8888 no debe quedar cogido. No hay
script de limpieza: miras `docker ps` y borras **tú**.

**Resultado esperado:** `docker ps` vacío de contenedores `m00-*` y de servicios
`web` / `api` de Compose.

---

## Comprueba tu entendimiento

**Quién construye la imagen de este lab**

¿El Codespace ejecuta el `docker build` de M00-10?

→ No. El **runner** de Actions. El Codespace solo lo usas para leer el YAML y,
opcionalmente, hacer `pull`.

**Git vs registry**

`git clone` ¿trae la imagen `m00-web`?

→ No. Trae el Dockerfile. La imagen está en `ghcr.io/…`. Hace falta `docker pull`.

**Dos tags**

Tras un run verde, ¿`latest` y el SHA son dos imágenes distintas?

→ Suelen ser **la misma** (mismo ID) con dos nombres. `latest` se moverá en el
próximo run; el SHA de *este* commit no.

**Por qué `target: runtime`**

¿El workflow monta `./site` como en compose.dev?

→ No. Es el build de prod: el HTML se COPYó en el build.

## Reto

### 1 — Disparar el CI de verdad (con un push)

En **tu fork**:

1. Edita `infra/m00/web/site/index.html` (cambia una palabra del `<h1>`).
2. Commit en `main` y **push** a tu fork (desde el Codespace: `git add`, `git commit`,
   `git push`; o desde la UI de GitHub).
3. Abre **Actions**. Debe nacer un run **sin** pulsar Run workflow.

<details>
<summary>Ver solución</summary>

El `on.push.paths` incluye `infra/m00/web/**`. Si no aparece run: push a otra
rama, Actions apagado, o el cambio no se subió (commit solo local). Si cambiaste
solo el README del curso, el filtro `paths` **no** dispara el workflow.

</details>

### 2 — Explica el nombre

Escribe (sin copiar) las cuatro piezas de
`ghcr.io/ana/kubernetes-administradores-201/m00-web:latest`.

<details>
<summary>Ver solución</summary>

1. `ghcr.io` — el registry (GHCR).  
2. `ana` — dueña del paquete (cuenta del fork).  
3. `kubernetes-administradores-201/m00-web` — nombre del paquete (repo + imagen).  
4. `latest` — tag.  

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| Pestaña Actions vacía o “Workflows disabled” | Fork sin autorizar Actions | Settings → Actions → Allow… y el botón *I understand* |
| No sale **Run workflow** | Estás en `my-it-labs` o no hay `workflow_dispatch` | Abre **tu** fork; el YAML del curso sí lo tiene |
| Job rojo en **Login** / **Build y push** con `denied` | Sin `packages: write` o política de la org | El YAML ya pide el permiso; en una org ajenas a veces hay que habilitar Packages |
| Job rojo: `site/: not found` o context | YAML tocado / rama vieja | `main` debe tener `context: infra/m00/web` |
| No aparece Packages | Job aún corriendo o en rojo | Espera al tick verde; abre el log |
| `docker pull` → `unauthorized` | Paquete privado y Codespace sin login | Válido: el lab se cumple con el paquete visible en la web |
| El push no lanza el workflow | Cambiaste un path fuera de `infra/m00/web/**` | Edita un fichero de esa carpeta o usa Run workflow |
