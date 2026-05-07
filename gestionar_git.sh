#!/bin/bash
# Desc: Gestor multi-VM con trazabilidad de hostname y sincronización bidireccional.

# Variable para identificar la máquina actual
MI_VM=$(hostname)

actualizar_readme_tabla() {
    echo -e "# Índice Global de Scripts\n" > README.md
    echo -e "Generado automáticamente desde: **$MI_VM**\n" >> README.md
    echo -e "| Script | Descripción | Origen Sugerido |" >> README.md
    echo -e "| :--- | :--- | :--- |" >> README.md
    for f in *.sh; do
        desc=$(grep -m 1 "^# Desc:" "$f" | sed 's/# Desc: //')
        # Intentamos buscar si el script tiene una marca de para qué VM es
        echo "| \`$f\` | ${desc:-Sin descripción} | $MI_VM |" >> README.md
    done
}

while true; do
    echo "======================================"
    echo "   GESTOR MULTI-VM (Host: $MI_VM)"
    echo "======================================"
    echo "Directorio: $(pwd)"
    echo "--------------------------------------"
    echo "1. Crear/Inicializar proyecto"
    echo "2. SUBIR Cambios (Push) - De VM a GitHub"
    echo "3. BAJAR Cambios (Pull) - De GitHub a VM"
    echo "4. Actualizar Tabla de Scripts"
    echo "5. Cambiar Descripción en GitHub"
    echo "6. Cambiar de directorio"
    echo "7. Salir"
    read -p "Opción: " opcion

    case $opcion in
        1)
            ACTUAL=$(pwd)
            read -p "Ruta [$ACTUAL]: " RUTA
            cd "${RUTA:-$ACTUAL}" || exit
            read -p "Nombre repo: " NOMBRE
            read -p "Desc. Larga: " DESC_REPO
            [ -z "$(ls -A)" ] && echo "# $NOMBRE" > README.md
            git init
            git add .
            git commit -m "Carga inicial [$MI_VM]: $NOMBRE"
            gh repo create "$NOMBRE" --public --description "$DESC_REPO" --source=. --remote=origin --push
            ;;
        
        2)
            if [ -z "$(git status --porcelain)" ]; then
                echo "ℹ️  Sin cambios pendientes en $MI_VM."
                sleep 1
            else
                git status -s
                read -p "Mensaje de actualización: " MSG
                git add .
                # Incluimos el hostname automáticamente en el mensaje
                git commit -m "[$MI_VM] $MSG"
                RAMA=$(git branch --show-current)
                git push origin "$RAMA"
                echo "✅ Actualizado en GitHub desde $MI_VM."
            fi
            ;;

        3)
            echo "--- Sincronizando con GitHub ---"
            git fetch origin
            RAMA=$(git branch --show-current)
            DIFERENCIAS=$(git rev-list HEAD..origin/"$RAMA" --count)
            if [ "$DIFERENCIAS" -eq 0 ]; then
                echo "ℹ️  Esta VM ya tiene la última versión."
            else
                echo "⚠️  Hay $DIFERENCIAS cambios nuevos en GitHub (hechos en otros sitios)."
                read -p "¿Descargar ahora? (s/n): " RESP
                [ "$RESP" = "s" ] && git pull origin "$RAMA" && echo "✅ VM actualizada."
            fi
            ;;

        4) actualizar_readme_tabla && echo "✅ Tabla generada." ;;
        5) read -p "Nueva desc: " ND && gh repo edit --description "$ND" ;;
        6) read -p "Ruta: " NR && cd "$NR" && echo "Cambiado a: $(pwd)" ;;
        7) exit 0 ;;
    esac
done
