#!/bin/bash
set -euo pipefail

###############################################################################
# data_sintetica.sh — UTILIDAD PRO DE CARGA SINTÉTICA (CDC‑SAFE)
#
# Parámetros:
#   $1 = NUM_INSERTS   (ej: 50)
#   $2 = NUM_UPDATES   (ej: 10)
#   $3 = NUM_DELETES   (ej: 5)
#   $4 = MODE          (reset | append)
#
# Ejemplos:
#   ./data_sintetica.sh 50 10 5 reset
#   ./data_sintetica.sh 20 5 2 append
###############################################################################

# ==============================
# VALIDACIÓN DE PARÁMETROS
# ==============================
if [ "$#" -ne 4 ]; then
  echo "Uso: $0 <num_inserts> <num_updates> <num_deletes> <reset|append>"
  exit 1
fi

NUM_INSERTS="$1"
NUM_UPDATES="$2"
NUM_DELETES="$3"
MODE="$4"

if [[ "$MODE" != "reset" && "$MODE" != "append" ]]; then
  echo "[FATAL] El modo debe ser 'reset' o 'append'"
  exit 1
fi

# ==============================
# ORACLE CLIENT (sqlplus desde XE)
# ==============================
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=$ORACLE_HOME/bin:/usr/bin:/bin

command -v sqlplus >/dev/null || {
  echo "[FATAL] sqlplus no disponible en PATH"
  exit 1
}

# ==============================
# CONEXIÓN ORACLE PRO
# ==============================
ORA_CONN="HOTUSA/HOTUSA@10.100.3.97:1521/HTSPRE11"
SCHEMA="HOTUSA"
TABLES=(TEST_TABLA_1 TEST_TABLA_2 TEST_TABLA_3 TEST_TABLA_4 TEST_TABLA_5)

# ==============================
# FUNCIÓN SQL FAIL‑FAST
# ==============================
exec_sql() {
sqlplus -s "$ORA_CONN" <<EOF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
WHENEVER SQLERROR EXIT FAILURE
$1
EXIT;
EOF
}

echo "=== DATA SINTÉTICA CDC — ORACLE PRO ==="
echo "INSERTS=${NUM_INSERTS} UPDATES=${NUM_UPDATES} DELETES=${NUM_DELETES} MODE=${MODE}"
echo "--------------------------------------"

###############################################################################
# 1. VERIFICACIÓN / CREACIÓN DE TABLAS
###############################################################################
for T in "${TABLES[@]}"; do
  CNT=$(exec_sql "
    SELECT COUNT(*)
    FROM all_tables
    WHERE owner='${SCHEMA}'
      AND table_name='${T}';
  ")

  if [ "$CNT" -eq 0 ]; then
    echo "Creando tabla ${SCHEMA}.${T}"

    exec_sql "
      CREATE TABLE ${SCHEMA}.${T} (
        ID          NUMBER PRIMARY KEY,
        TEXTO       VARCHAR2(50),
        FECHA       DATE,
        VALOR       NUMBER(10,2),
        ESTADO      CHAR(1),
        OBSERVACION VARCHAR2(200)
      );
    "
  else
    echo "Tabla ${SCHEMA}.${T} ya existe"
  fi
done

###############################################################################
# 2. DML PARAMETRIZADO POR TABLA
###############################################################################
for T in "${TABLES[@]}"; do
  echo ""
  echo ">>> TABLA ${SCHEMA}.${T}"

  # -----------------------------
  # RESET / APPEND
  # -----------------------------
  if [ "$MODE" = "reset" ]; then
    echo "  - RESET: DELETE FROM ${SCHEMA}.${T}"
    exec_sql "
      DELETE FROM ${SCHEMA}.${T};
      COMMIT;
    "
    BASE_ID=0
  else
    BASE_ID=$(exec_sql "
      SELECT NVL(MAX(ID),0) FROM ${SCHEMA}.${T};
    ")
  fi

  # -----------------------------
  # INSERTS
  # -----------------------------
  echo "  - INSERT: ${NUM_INSERTS} registros"
  for ((i=1;i<=NUM_INSERTS;i++)); do
    ID=$((BASE_ID + i))
    exec_sql "
      INSERT INTO ${SCHEMA}.${T}
      (ID, TEXTO, FECHA, VALOR, ESTADO, OBSERVACION)
      VALUES
      (
        ${ID},
        'TXT_${T}_${ID}',
        SYSDATE,
        MOD(${ID} * 17, 1000),
        CASE WHEN MOD(${ID},2)=0 THEN 'A' ELSE 'B' END,
        'GEN_${ID}'
      );
    "
  done
  exec_sql "COMMIT;"

  # -----------------------------
  # UPDATES
  # -----------------------------
  if [ "$NUM_UPDATES" -gt 0 ]; then
    echo "  - UPDATE: ${NUM_UPDATES} registros"
    exec_sql "
      UPDATE ${SCHEMA}.${T}
      SET VALOR = VALOR + 1,
          TEXTO = TEXTO || '_U'
      WHERE ID IN (
        SELECT ID FROM ${SCHEMA}.${T}
        WHERE ROWNUM <= ${NUM_UPDATES}
      );
      COMMIT;
    "
  fi

  # -----------------------------
  # DELETES
  # -----------------------------
  if [ "$NUM_DELETES" -gt 0 ]; then
    echo "  - DELETE: ${NUM_DELETES} registros"
    exec_sql "
      DELETE FROM ${SCHEMA}.${T}
      WHERE ID IN (
        SELECT ID FROM ${SCHEMA}.${T}
        WHERE ROWNUM <= ${NUM_DELETES}
      );
      COMMIT;
    "
  fi

  echo "  OK ${T}"
done

echo ""
echo "=== DATA SINTÉTICA FINALIZADA CORRECTAMENTE ==="