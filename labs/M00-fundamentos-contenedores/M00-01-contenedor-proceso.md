# M00-01 — El contenedor es un proceso

[← Página anterior](README.md) · [Siguiente página →](M00-02-entrypoint-cmd-args.md)

> Práctica del módulo. La teoría y la demo están en el [README del módulo](README.md).

### Objetivo

Arrancar contenedores, verlos como procesos (`docker ps`, `docker top`) y dejar el Codespace limpio.

### Prerrequisitos

- Estás en un **Codespace** de este repo (fork → **Code → Codespaces → Create codespace on main**).
- En la terminal: `docker info` responde sin error.

Si `docker` no existe, espera a que el Codespace termine de arrancar y vuelve a probar `docker info`.

### En qué consiste

Un `echo` que muere al instante, un `sleep` que se queda Running, inspección del PID 1 y limpieza.

### 1 — Comprobar Docker en el Codespace

**Acción:**

```bash
pwd
docker info >/dev/null && echo docker-ok
docker version --format '{{.Server.Version}}'
```

**Por qué:** El daemon de Docker corre **dentro** del Codespace (Docker-in-Docker). No hay que instalar nada en tu PC.

**Resultado esperado:** `docker-ok` y un número de versión. El `pwd` es `/workspaces/…` (nombre de tu fork).

### 2 — Un proceso que acaba (Exited)

**Acción:**

```bash
docker run --name m00-hola alpine:3.20 echo "soy un proceso y ya terminé"
docker ps -a --filter name=m00-hola
```

**Por qué:** `echo` imprime y sale. El contenedor no “sigue encendido”: su PID 1 ha muerto.

**Resultado esperado:** ves el texto `soy un proceso y ya terminé`. En `docker ps -a` el estado es **Exited (0)**. `docker ps` (sin `-a`) **no** lo lista.

> [!TIP]
> La primera vez Docker descarga `alpine:3.20`. Las siguientes son instantáneas.

### 3 — Un proceso que no acaba (Running)

**Acción:**

```bash
docker run -d --name m00-sleep alpine:3.20 sleep 3600
docker ps --filter name=m00-sleep
docker top m00-sleep
```

**Por qué:** `-d` es *detached* (en segundo plano). `sleep 3600` es el PID 1: mientras duerme, el contenedor está Running.

**Resultado esperado:** una fila `Up …`. `docker top` muestra `sleep 3600`.

### 4 — Parar, volver a arrancar, borrar

**Acción:**

```bash
docker stop m00-sleep
docker ps -a --filter name=m00-sleep
docker start m00-sleep
docker ps --filter name=m00-sleep
docker stop m00-sleep
docker rm m00-sleep
docker rm m00-hola
docker ps -a --filter name=m00-
```

**Por qué:** `stop` envía señal al PID 1. `start` reutiliza el **mismo** contenedor. `rm` lo elimina: ya no existe, no solo está parado.

**Resultado esperado:** tras `rm`, el filtro `m00-` no lista nada.

### 5 — Limpieza a mano

**Acción:** lista y borra por nombre (sustituye los que tengas):

```bash
docker ps -a
docker rm -f m00-hola m00-sleep
docker ps -a
```

Si hay más `Exited` que no quieras, `docker container prune` pide confirmación y borra **todos** los parados.

**Por qué:** Tienes que ver qué existe (`ps -a`) y elegir el nombre. Un script te lo oculta.

**Resultado esperado:** `docker ps -a` sin `m00-hola` ni `m00-sleep`.

## Comprueba tu entendimiento

**Running vs Exited**

`docker run --name m00-ls alpine:3.20 ls /` y luego `docker ps -a --filter name=m00-ls`

→ Estado **Exited**. `ls` no es un servidor: termina. Borra con `docker rm m00-ls`.

**Qué lista `docker ps`**

Arranca otra vez `docker run -d --name m00-sleep alpine:3.20 sleep 3600`. Compara `docker ps` y `docker ps -a`.

→ `ps` solo el Running; `ps -a` también los Exited. Luego `docker rm -f m00-sleep`.

## Reto

### 1 — Código de salida distinto de 0

```bash
docker run --name m00-fail alpine:3.20 sh -c "exit 7"
docker ps -a --filter name=m00-fail
```

<details>
<summary>Ver solución</summary>

Estado `Exited (7)`. El número es el código de salida del PID 1, no “el puerto”. `docker rm m00-fail`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `Cannot connect to the Docker daemon` | Codespace aún arrancando | Espera; `docker info` |
| `The container name … is already in use` | No borraste el anterior | `docker rm -f m00-hola` |
| `docker ps` vacío pero “sí lo creé” | Está Exited | `docker ps -a` |
