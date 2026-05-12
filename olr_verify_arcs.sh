#!/usr/bin/env bash
set -euo pipefail
INCOMING="/apps/olr/incoming"   # <-- AJUSTADO

echo "=== Verificación de secuencias en $INCOMING ==="

# Extrae sequence# del patrón %t_%s_%r.arc
seqs=$(find "$INCOMING" -maxdepth 1 -type f -name "*.arc" -printf "%f\n" \
  | awk -F'_' '{print $2}' | sed 's/[^0-9]//g' | sort -n)

if [[ -z "${seqs}" ]]; then
  echo "Sin archivos .arc"
  exit 0
fi

min=$(echo "$seqs" | head -n1)
max=$(echo "$seqs" | tail -n1)
count=$(echo "$seqs" | wc -l)

echo "Min seq: $min"
echo "Max seq: $max"
echo "Count  : $count"

# Detectar gaps
missing=()
prev=""
while read -r s; do
  if [[ -n "$prev" ]]; then
    exp=$((prev+1))
    if [[ "$s" -ne "$exp" ]]; then
      for m in $(seq "$exp" $((s-1))); do missing+=("$m"); done
    fi
  fi
  prev="$s"
done < <(echo "$seqs")

if ((${#missing[@]})); then
  echo "GAPS detectados: ${missing[*]}"
  exit 2
else
  echo "Secuencias consecutivas. OK"
fi
