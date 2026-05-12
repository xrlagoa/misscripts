#!/bin/bash

# =================================================================
# PROTOCOLO: SO-AI BACKUP ARQUITECTÓNICO (Versión Final Blindada)
# VM: dcm05 | Propósito: Sincronización Segura y Dinámica
# =================================================================

# --- CONFIGURACIÓN ---
REMOTE="mi_onedrive"
VM_NAME="dcm05"
DEST_BASE="$REMOTE:Infraestructura_VMs/$VM_NAME"
REGISTRO="$HOME/misscripts/.rutas_especiales"
LOG_DIR="$HOME/misscripts/logs"
FECHA=$(date +%Y-%m-%d_%H-%M)
ARCHIVE_DIR="$DEST_BASE/_archive/$FECHA"
LOG_FILE="$LOG_DIR/backup_$(date +%Y%m%d).log"

# Asegurar infraestructura local
mkdir -p "$LOG_DIR"
touch "$REGISTRO"

echo "------------------------------------------"
echo "SO-AI: Auditoría de Respaldo Arquitectónico"
echo "VM: $VM_NAME | Log: $LOG_FILE"
echo "------------------------------------------"

# --- FUNCIÓN NÚCLEO DE SINCRONIZACIÓN ---
sincronizar() {
    local origen=$1
    local destino=$2
    local ignore_file="$origen/.rclone_ignore"
    local filter_cmd=""
    
    # Detección automática de filtros estilo .gitignore
    if [ -f "$ignore_file" ]; then
        filter_cmd="--exclude-from $ignore_file"
        echo ">> Aplicando filtros desde: $ignore_file"
    fi

    echo ">> Procesando: $origen"
    
    # Sincronización con respaldo en papelera (_archive)
    rclone sync "$origen" "$DEST_BASE$destino" \
        $filter_cmd \
        --backup-dir "$ARCHIVE_DIR$destino" \
        --log-file="$LOG_FILE" \
        --log-level INFO \
        --inplace
}

# --- FASE 1: RUTAS ESTÁNDAR (Obligatorias) ---
echo -e "\n[FASE 1: Rutas Estándar]"
for d in misdocumentos misscripts misproyectos; do
    if [ -d "$HOME/$d" ]; then
        sincronizar "$HOME/$d" "/$d"
    else
        echo "!! Nota: Carpeta estándar $d no encontrada. Saltando..."
    fi
done

# --- FASE 2: RUTAS ESPECIALES (Auto-aprendidas) ---
if [ -s "$REGISTRO" ]; then
    echo -e "\n[FASE 2: Rutas Especiales Registradas]"
    while IFS= read -r ruta; do
        if [ -d "$ruta" ]; then
            sincronizar "$ruta" "$ruta"
        else
            echo "!! Advertencia: La ruta registrada $ruta ya no existe."
        fi
    done < "$REGISTRO"
fi

# --- FASE 3: RESUMEN DE AUDITORÍA ---
echo -e "\n------------------------------------------"
echo "RESUMEN DE MOVIMIENTOS (Auditoría):"
echo "------------------------------------------"
if [ -f "$LOG_FILE" ]; then
    MOVIDOS=$(grep "Moved to backup" "$LOG_FILE" | wc -l)
    COPIADOS=$(grep "Copied" "$LOG_FILE" | wc -l)
    
    echo "  - Archivos nuevos/actualizados: $COPIADOS"
    echo "  - Archivos enviados a Papelera (_archive): $MOVIDOS"
    
    if [ $MOVIDOS -gt 0 ]; then
        echo -e "\nDetalle de archivos protegidos en _archive (Últimos 10):"
        grep "Moved to backup" "$LOG_FILE" | awk -F': ' '{print "    * " $2}' | sed 's/Moved to backup.*//' | tail -n 10
    fi
else
    echo "No se registraron cambios técnicos en esta sesión."
fi

# --- FASE 4: GESTIÓN DINÁMICA DE NUEVAS RUTAS ---
# Solo se ejecuta si hay una terminal interactiva (evita bloqueos en cron)
if [ -t 0 ]; then
    echo -e "\n------------------------------------------"
    read -p "¿Deseas registrar una nueva ruta especial ahora? (s/n): " respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        read -p "Introduce la ruta completa (ej: /apps/olr): " nueva_ruta
        if [ -d "$nueva_ruta" ]; then
            if grep -Fxq "$nueva_ruta" "$REGISTRO"; then
                echo "Esta ruta ya estaba registrada en el sistema."
            else
                echo "$nueva_ruta" >> "$REGISTRO"
                echo "Ruta registrada con éxito. Sincronizando por primera vez..."
                sincronizar "$nueva_ruta" "$nueva_ruta"
            fi
        else
            echo "Error: La ruta $nueva_ruta no es válida o no existe."
        fi
    fi
fi

echo -e "\n$(date +'%H:%M:%S') - Proceso finalizado."
echo "------------------------------------------"
