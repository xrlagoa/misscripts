#!/bin/bash
# Desc: Gestor avanzado multi-VM: Trazabilidad, Sincronización selectiva y Clonado.

MI_VM=$(hostname)

actualizar_readme_tabla() {
    echo -e "# Índice Global de Scripts\n" > README.md
    echo -e "Generado automáticamente desde: **$MI_VM**\n" >> README.md
    echo -e "| Script | Descripción | Origen Sugerido |" >> README.md
    echo -e "| :--- | :--- | :--- |" >> README.md
    for f in *.sh; do
        desc=$(grep -m 1 "^# Desc:" "$f" | sed 's/# Desc: //')
        echo "| \`$f\` | ${desc:-Sin descripción} | $MI_VM |" >> README.md
    done
}

while true; do
    echo "======================================"
    echo "   SISTEMA DE GESTIÓN (Host: $MI_VM)"
    echo "======================================"
    echo "Directorio actual: $(pwd)"
    echo "--------------------------------------"
    echo "1. Crear/Inicializar proyecto local"
    echo "2. SUBIR Cambios (Push a Develop)"
    echo "3. BAJAR Cambios (Pull/Sincronizar)"
    echo "4. TRAER Proyecto de GitHub (Clone)"
    echo "5. Actualizar Tabla de Scripts / README"
    echo "6. Cambiar de directorio (CD)"
    echo "7. Salir"
    read -p "Opción: " opcion

    case $opcion in
        1)
            ACTUAL=$(pwd)
            read -p "Ruta [$ACTUAL]: " RUTA
            cd "${RUTA:-$ACTUAL}" || exit
            read -p "Nombre repo: " NOMBRE
            read -p "Desc. Larga GitHub: " DESC_REPO
            [ -z "$(ls -A)" ] && echo "# $NOMBRE" > README.md
            git init
            git add .
            git commit -m "Carga inicial [$MI_VM]: $NOMBRE"
            gh repo create "$NOMBRE" --public --description "$DESC_REPO" --source=. --remote=origin --push
            # Crear rama develop inmediatamente
            git checkout -b develop
            git push -u origin develop
            ;;
        
        2)
            CAMBIOS=$(git status --porcelain)
            if [ -z "$CAMBIOS" ]; then
                echo "ℹ️  Sin cambios pendientes en $MI_VM."
                sleep 1
            else
                git status -s
                read -p "Mensaje de actualización: " MSG
                git add .
                git commit -m "[$MI_VM] $MSG"
                RAMA=$(git branch --show-current)
                git push origin "$RAMA"
                echo "✅ Actualizado en rama $RAMA desde $MI_VM."
            fi
            ;;

        3)
            echo "--- Sincronizando con GitHub ---"
            git fetch origin
            RAMA=$(git branch --show-current)
            DIFERENCIAS=$(git rev-list HEAD..origin/"$RAMA" --count)
            if [ "$DIFERENCIAS" -eq 0 ]; then
                echo "ℹ️  Todo al día."
            else
                echo "⚠️  Hay $DIFERENCIAS cambios en GitHub."
                echo "a) Descargar TODO (Sync)"
                echo "b) Elegir archivos específicos (Manual)"
                read -p "Seleccione modo: " MODO
                if [ "$MODO" = "a" ]; then
                    git pull origin "$RAMA"
                elif [ "$MODO" = "b" ]; then
                    git diff --name-only HEAD origin/"$RAMA"
                    read -p "Archivo a actualizar (o 'fin'): " FILE
                    while [ "$FILE" != "fin" ]; do
                        git checkout origin/"$RAMA" -- "$FILE"
                        read -p "Siguiente (o 'fin'): " FILE
                    done
                fi
            fi
            ;;

        4)
            read -p "Nombre del repo en GitHub: " REPO_NOM
            read -p "Ruta destino: " RUTA_DEST
            mkdir -p "$RUTA_DEST"
            cd "$RUTA_DEST" || exit
            gh repo clone "xrlagoa/$REPO_NOM" .
            # Nos movemos a develop por defecto para trabajar
            git checkout develop || git checkout -b develop
            ;;

        5) actualizar_readme_tabla && echo "✅ Tabla generada." ;;
        6) read -p "Ruta: " NR && cd "$NR" && echo "Cambiado a: $(pwd)" ;;
        7) exit 0 ;;
    esac
done
