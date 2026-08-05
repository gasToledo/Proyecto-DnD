#!/bin/sh
# Crea el rol y la base de Zitadel dentro de la misma instancia de
# PostgreSQL que la base de la aplicación (ver design.md, decisión D11).
#
# Corre una sola vez: la imagen oficial de postgres solo ejecuta los
# scripts de `/docker-entrypoint-initdb.d/` cuando el volumen de datos está
# vacío, contra un servidor temporal local que todavía no acepta conexiones
# externas — cuando `pg_isready` empieza a responder, esta base ya existe.
#
# `REVOKE CONNECT ... FROM PUBLIC` es lo que impide que el rol `zitadel`
# llegue a la base de la aplicación: por defecto PostgreSQL le concede
# CONNECT a PUBLIC sobre toda base nueva. El dueño de cada base conserva su
# propio CONNECT implícito aunque se lo revoque a PUBLIC.
#
# La imagen oficial de postgres crea $POSTGRES_USER (acá, el rol de la
# aplicación) como SUPERUSER de la instancia -- no hay un rol "postgres"
# aparte. Un superusuario salta todo chequeo de privilegios, CONNECT
# incluido, así que este REVOKE no le cierra el paso a la base de Zitadel: la
# aplicación ya podía llegar a cualquier base de esta instancia antes de que
# hubiera una segunda. El aislamiento que agrega esta migración es en un solo
# sentido (ver design.md, decisión D11, Risks/Trade-offs).
set -eu

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE zitadel WITH LOGIN PASSWORD '$ZITADEL_DB_PASSWORD';
    CREATE DATABASE zitadel OWNER zitadel;
    REVOKE CONNECT ON DATABASE zitadel FROM PUBLIC;
    REVOKE CONNECT ON DATABASE "$POSTGRES_DB" FROM PUBLIC;
EOSQL
