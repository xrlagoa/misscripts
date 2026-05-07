#!/usr/bin/env bash

# Ejecutar sqlplus como usuario oracle cargando su entorno completo
exec sudo -i -u oracle /u01/app/oracle/product/11.2.0/xe/bin/sqlplus "$@"