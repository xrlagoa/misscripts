#!/bin/bash

# Función para listar scripts en el README (Tu petición de la tabla)
actualizar_readme_tabla() {
    echo -e "\n## Índice de Scripts\n" > README.tmp
    echo -e "| Script | Descripción |" >> README.tmp
    echo -e "| :--- | :--- |" >> README.tmp
    for f in *.sh; do
        # Extrae la primera línea de comentario del script como descripción
        desc=$(grep -m 1 "^# Desc:" "$f" | sed 's/# Desc: //')
        echo "| \`$f\` | ${desc:-Sin descripción} |" >> README.tmp
    done
    # Aquí puedes añadir el contenido previo del README si lo deseas
    cat README.tmp > README.md
    rm README.tmp
}

# Menú Principal
while true; do
    echo "======================================"
    echo "   GESTOR PROFESIONAL DE GITHUB"
    echo "======================================"
    echo "Directorio actual: $(pwd)"
    echo "--------------------------------------"
    echo "1. Crear e inicializar proyecto (con Metadatos)"
    echo "2. Actualizar repositorio (Push rápido)"
    echo "3. Cambiar Descripción del Repo en GitHub"
    echo "4. Actualizar Tabla de Scripts en README"
    echo "5. Ver guía de .gitignore"
    echo "6. Cambiar de directorio (CD)"
    echo "7. Salir"
    read -p "Seleccione una opción: " opcion

    case $opcion in
        1)
            echo "--- Configuración de Nuevo Proyecto ---"
            read -p "Confirmar ruta raíz del proyecto [$(pwd)]: " RUTA
            RUTA=${RUTA:-$(pwd)}
            cd "$RUTA" || exit
            
            read -p "Nombre corto (ej: oraredo-cdc): " NOMBRE
            read -p "Descripción corta para el commit: " DESC_COMMIT
            read -p "Descripción larga para GitHub: " DESC_REPO

            git init
            git add .
            git commit -m "Carga inicial: $DESC_COMMIT"
            # Creamos el repo con la descripción larga
            gh repo create "$NOMBRE" --public --description "$DESC_REPO" --source=. --remote=origin --push
            ;;
        
        2)
            read -p "Mensaje de actualización: " MSG
            git add .
            git commit -m "$MSG"
            git push origin master || git push origin main
            ;;

        3)
            read -p "Nueva descripción para este repo en GitHub: " NUEVA_DESC
            gh repo edit --description "$NUEVA_DESC"
            echo "✅ Descripción actualizada en GitHub."
            ;;

        4)
            actualizar_readme_tabla
            echo "✅ README.md actualizado con la tabla de scripts."
            ;;

        5)
            # (Aquí iría la función de guía que ya teníamos)
            ;;
        
        6)
            read -p "Nueva ruta completa: " NUEVA_RUTA
            cd "$NUEVA_RUTA" && echo "Cambiado a: $(pwd)" || echo "Ruta no válida"
            ;;

        7) exit 0 ;;
    esac
done
