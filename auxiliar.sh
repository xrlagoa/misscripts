#!/bin/bash

# --- CONFIGURACIÓN ---
REMOTE="mi_onedrive"
VM_NAME="dcm05"
DEST_BASE="$REMOTE:Infraestructura_VMs/$VM_NAME"
REGISTRO="$HOME/misscripts/.rutas_especiales"

# Crear el registro si no existe
touch "$REGISTRO"

echo "------------------------------------------"
echo "SO-AI: Gestor de Respaldo Arquitectónico"
echo "VM: $VM_NAME | Fecha: $(date +'%d/%m/%Y %H:%M')"
echo "------------------------------------------"

# FUNCIÓN DE SINCRONIZACIÓN
sincronizar() {
    local origen=$1
    local destino=$2
    echo ">> Sincronizando: $origen"
    # El uso de --parents o la construcción de la ruta destino asegura la estructura /apps/olr
    rclone sync "$origen" "$DEST_BASE$destino" -v --inplace
}

# 1. RESPALDOS ESTÁNDAR
echo "[FASE 1: Rutas Estándar]"
sincronizar "$HOME/misdocumentos" "/misdocumentos"
sincronizar "$HOME/misscripts" "/misscripts"
sincronizar "$HOME/misproyectos" "/misproyectos"

# 2. RESPALDOS ESPECIALES REGISTRADOS
if [ -s "$REGISTRO" ]; then
    echo -e "\n[FASE 2: Rutas Especiales Detectadas]"
    while IFS= read -r ruta; do
        if [ -d "$ruta" ]; then
            sincronizar "$ruta" "$ruta"
        else
            echo "!! Advertencia: La ruta $ruta ya no existe. Saltando..."
        fi
    done < "$REGISTRO"
fi

# 3. INTERFAZ PARA NUEVAS RUTAS
echo -e "\n------------------------------------------"
read -p "¿Deseas agregar una nueva ruta especial ahora? (s/n): " respuesta
if [[ "$respuesta" =~ ^[Ss]$ ]]; then
    read -p "Introduce la ruta completa (ej: /apps/olr): " nueva_ruta
    if [ -d "$nueva_ruta" ]; then
        # Verificar si ya está registrada
        if grep -Fxq "$nueva_ruta" "$REGISTRO"; then
            echo "Esta ruta ya estaba registrada."
        else
            echo "$nueva_ruta" >> "$REGISTRO"
            echo "Ruta registrada con éxito."
            echo "Sincronizando por primera vez..."
            sincronizar "$nueva_ruta" "$nueva_ruta"
        fi
    else
        echo "Error: La ruta no existe en esta VM."
    fi
fi

echo -e "\nRespaldo completado con éxito."
echo "------------------------------------------"
