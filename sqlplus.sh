#!/usr/bin/env bash

# --- Oracle environment bootstrap ---
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export ORACLE_SID=XE
export PATH=$ORACLE_HOME/bin:$PATH

# --- Safety checks ---
if [ ! -x "$ORACLE_HOME/bin/sqlplus" ]; then
  echo "ERROR: sqlplus not found in $ORACLE_HOME/bin"
  exit 1
fi

# --- Execute sqlplus ---
exec "$ORACLE_HOME/bin/sqlplus" "$@"