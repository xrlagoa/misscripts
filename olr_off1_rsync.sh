#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
SRC_HOST="oracle@m05-legacy"
ARCH_DIR_BASE="/data/archivelog"

DST_BASE="/apps/olr"
STAGING="$DST_BASE/staging"
INCOMING="$DST_BASE/incoming"
STATE="$DST_BASE/state"
LOGS="$DST_BASE/logs"

LAST_SEQ_FILE="$STATE/last_seq.state"
TS="$(date +'%Y%m%d-%H%M%S')"
LOG="$LOGS/rsync_$TS.log"

RSYNC_DRYRUN="${RSYNC_DRYRUN:-0}"
STABLE_SLEEP="${STABLE_SLEEP:-10}"

mkdir -p "$STAGING" "$INCOMING" "$STATE" "$LOGS"

echo "===================================================" | tee -a "$LOG"
echo "[$(date)] INICIO OLR OMF SECURE MODE"               | tee -a "$LOG"
echo "===================================================" | tee -a "$LOG"
echo "[INFO] ejecutando con RSYNC_DRYRUN=$RSYNC_DRYRUN"   | tee -a "$LOG"
echo "[INFO] archiveldir origen: $ARCH_DIR_BASE"          | tee -a "$LOG"

# === PRECHECK ===
if ! ssh "$SRC_HOST" "test -d '$ARCH_DIR_BASE'"; then
  echo "[ERROR] $ARCH_DIR_BASE no existe en origen" | tee -a "$LOG"
  exit 1
fi

# === PASO 1: LISTAR ARC ===
TMP_ALL="$STATE/all_arc_$TS.txt"
: > "$TMP_ALL"

echo "[INFO] → Listando .arc desde origen" | tee -a "$LOG"

ssh "$SRC_HOST" "find '$ARCH_DIR_BASE' -type f -name '*.arc' -printf '%p\n'" \
  | LC_ALL=C sort | tee -a "$LOG" > "$TMP_ALL"

if [[ ! -s "$TMP_ALL" ]]; then
  echo "[INFO] No hay .arc en origen" | tee -a "$LOG"
  exit 0
fi

# === PASO 2: EXTRAER SECUENCIA ===
TMP_SEQ="$STATE/seq_list_$TS.txt"
: > "$TMP_SEQ"

echo "[INFO] → Extrayendo secuencias OMF (campo 2)" | tee -a "$LOG"

while IFS= read -r FP; do
  [[ "$FP" == "$ARCH_DIR_BASE/"* ]] || continue
  BN="$(basename "$FP")"
  SEQ="$(echo "$BN" | awk -F'_' '{print $2}' | sed 's/[^0-9]//g')"

  echo "[DEBUG] FP=$FP → BN=$BN → SEQ=$SEQ" | tee -a "$LOG"

  [[ "$SEQ" =~ ^[0-9]+$ ]] || continue
  echo "$SEQ|$FP" >> "$TMP_SEQ"
done < "$TMP_ALL"

if [[ ! -s "$TMP_SEQ" ]]; then
  echo "[WARN] No hay secuencias extraídas" | tee -a "$LOG"
  exit 0
fi

# === PASO 3: LAST_SEQ ===
if [[ -f "$LAST_SEQ_FILE" ]]; then
  LAST_SEQ=$(cat "$LAST_SEQ_FILE")
else
  LAST_SEQ=0
fi

echo "[INFO] last_seq actual: $LAST_SEQ" | tee -a "$LOG"

# === PASO 4: SECUENCIAS NUEVAS ===
TMP_NEW="$STATE/new_seq_$TS.txt"
: > "$TMP_NEW"

awk -F'|' -v last="$LAST_SEQ" '{if ($1 > last) print $0}' "$TMP_SEQ" \
  | sort -n -t'|' -k1,1 \
  | tee -a "$LOG" > "$TMP_NEW"

if [[ ! -s "$TMP_NEW" ]]; then
  echo "[INFO] No hay secuencias nuevas" | tee -a "$LOG"
  exit 0
fi

echo "[INFO] Secuencias nuevas detectadas:" | tee -a "$LOG"
cat "$TMP_NEW" | sed 's/^/[SEQ] /' | tee -a "$LOG"

# === PASO 5: ESTABILIDAD ===
TMP_STABLE="$STATE/stable_$TS.txt"
: > "$TMP_STABLE"

echo "[INFO] → Verificando estabilidad (2 lecturas, ${STABLE_SLEEP}s)" | tee -a "$LOG"

while IFS='|' read -r SEQ FP; do
  SZ1=$(ssh "$SRC_HOST" "stat -c %s '$FP'" 2>/dev/null || echo 0)
  sleep "$STABLE_SLEEP"
  SZ2=$(ssh "$SRC_HOST" "stat -c %s '$FP'" 2>/dev/null || echo 0)

  echo "[DEBUG] $FP → SZ1=$SZ1 SZ2=$SZ2" | tee -a "$LOG"

  if [[ "$SZ1" -gt 0 && "$SZ1" -eq "$SZ2" ]]; then
    echo "$SEQ|$FP" >> "$TMP_STABLE"
  else
    echo "[WARN] NO ESTABLE: $FP" | tee -a "$LOG"
  fi
done < "$TMP_NEW"

if [[ ! -s "$TMP_STABLE" ]]; then
  echo "[INFO] Ningún archivo pasó estabilidad" | tee -a "$LOG"
  exit 0
fi

STABLE_COUNT=$(wc -l < "$TMP_STABLE")
echo "[INFO] Archivos estables: $STABLE_COUNT" | tee -a "$LOG"

# === PASO 6: RSYNC ===
TMP_FILES="$STATE/files_$TS.txt"
cut -d'|' -f2 "$TMP_STABLE" | sed 's|^/||' > "$TMP_FILES"

echo "[INFO] → Rutas que se enviarán por rsync:" | tee -a "$LOG"
sed 's/^/[FILE] /' "$TMP_FILES" | tee -a "$LOG"

RSYNC_FLAGS="-avz --no-whole-file --prune-empty-dirs \
--stats \
--chmod=Du=rwx,Dg=rx,Fu=rw,Fg=r,Fo=r \
--partial-dir=$STAGING/.rsync-partial"

if [[ "$RSYNC_DRYRUN" == "1" ]]; then
  RSYNC_FLAGS="$RSYNC_FLAGS -n"
  echo "[INFO] *** DRY-RUN ACTIVADO ***" | tee -a "$LOG"
fi

echo "[INFO] Ejecutando rsync..." | tee -a "$LOG"

rsync $RSYNC_FLAGS \
  --files-from="$TMP_FILES" "$SRC_HOST":/ "$STAGING"/ | tee -a "$LOG"

# === PASO 7: MOVER ===
echo "[INFO] → Moviendo a INCOMING" | tee -a "$LOG"

MOVED_LAST="$LAST_SEQ"

if [[ "$RSYNC_DRYRUN" == "1" ]]; then
  while IFS='|' read -r SEQ FP; do
    BN="$(basename "$FP")"
    REL="${FP#/}"
    SRC_LOCAL="$STAGING/$REL"
    echo "[DRY-RUN] mv '$SRC_LOCAL' '$INCOMING/$BN'" | tee -a "$LOG"
    (( SEQ > MOVED_LAST )) && MOVED_LAST="$SEQ"
  done < "$TMP_STABLE"
else
  while IFS='|' read -r SEQ FP; do
    BN="$(basename "$FP")"
    REL="${FP#/}"
    SRC_LOCAL="$STAGING/$REL"
    if [[ -f "$SRC_LOCAL" ]]; then
      mv -f "$SRC_LOCAL" "$INCOMING/$BN"
      echo "[INFO] Movido: $BN" | tee -a "$LOG"
      (( SEQ > MOVED_LAST )) && MOVED_LAST="$SEQ"
    else
      echo "[WARN] No existe en STAGING: $SRC_LOCAL" | tee -a "$LOG"
    fi
  done < "$TMP_STABLE"
fi

# === PASO 8: ACTUALIZAR last_seq ===
if [[ "$RSYNC_DRYRUN" != "1" ]]; then
  echo "$MOVED_LAST" > "$LAST_SEQ_FILE"
fi

echo "[INFO] COPIA COMPLETADA — last_seq=$MOVED_LAST" | tee -a "$LOG"
echo "===================================================" | tee -a "$LOG"
