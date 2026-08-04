# Construye la imagen única del stack: el mismo contenedor sirve la API y el
# build web (ver design.md, decisión D5 y capacidad `self-hosted-deployment`)
# porque el cliente llama a `/api` con rutas relativas al mismo origen que lo
# sirvió, sin `baseUrl` propio (`lib/api/api_client.dart`).
#
# Se construye desde la raíz del repositorio (`docker build -f
# packages/dnd_server/Dockerfile .`), porque tanto `dnd_app` como `dnd_server`
# dependen de `dnd_engine` por ruta relativa del monorepo.
#
# Las etiquetas de imagen usan `stable`, no una versión fija: seguir builds
# reproducibles al pie de la letra implica fijar un dígito de versión concreto
# (y actualizarlo a mano) tanto acá como en la sección "Comandos" de
# `CLAUDE.md`; se deja así por simplicidad de un despliegue de una sola
# cuenta, no por ser la práctica recomendada en un stack con más operadores.

# ---- Etapa 1: build del cliente web (Flutter) ----
FROM ghcr.io/cirruslabs/flutter:stable AS web-build
WORKDIR /workspace
COPY packages/dnd_engine ./packages/dnd_engine
COPY packages/dnd_app ./packages/dnd_app
WORKDIR /workspace/packages/dnd_app
RUN flutter pub get
RUN flutter build web --release

# ---- Etapa 2: compilación del servidor (Dart) ----
FROM dart:stable AS server-build
WORKDIR /workspace
COPY packages/dnd_engine ./packages/dnd_engine
COPY packages/dnd_server ./packages/dnd_server
WORKDIR /workspace/packages/dnd_server
RUN dart pub get
RUN dart compile exe bin/server.dart -o /workspace/dnd_server_bin

# ---- Etapa 3: runtime mínimo ----
# `dart compile exe` produce un binario nativo: no hace falta el SDK de Dart
# ni el de Flutter en la imagen final, así que ninguna clave ni credencial de
# build llega a la imagen publicada (no hay ninguna en primer lugar: la
# configuración se lee de variables de entorno recién al arrancar, ver
# `lib/src/config.dart`).
FROM debian:bookworm-slim AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=server-build /workspace/dnd_server_bin ./dnd_server
COPY --from=web-build /workspace/packages/dnd_app/build/web ./web

ENV DND_WEB_ROOT=/app/web
EXPOSE 8080

ENTRYPOINT ["/app/dnd_server"]
