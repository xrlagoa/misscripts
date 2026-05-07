#!/bin/bash
# Desc: Gestor integral de repositorios con detección de cambios y documentación automática.

# Función para la tabla del README
actualizar_readme_tabla() {
    echo -e "\n## Índice de Scripts\n" > README.tmp
    echo -e "| Script | Descripción |" >> README.tmp
    echo -e "| :--- | :--- |" >> README.tmp
    for f in *.sh; do
        desc=$(grep -m 1 "^# Desc:" "$f" | sed 's/# Desc: //')
        echo "| \`$f\` | ${desc:-Sin descripción} |" >> README.tmp
    done
    cat README.tmp > README.md
    rm README.tmp
}

while true; do
    echo "======================================"
    echo "   GESTOR PROFESIONAL DE GITHUB"
    echo "======================================"
    echo "Directorio actual: $(pwd)"
    echo "--------------------------------------"
    echo "1. Crear e inicializar proyecto (Metadatos)"
    echo "2. Actualizar repositorio (Ver cambios + Push)"
    echo "3. Cambiar Descripción del Repo en GitHub"
    echo "4. Actualizar Tabla de Scripts en README"
    echo "5. Cambiar de directorio (CD)"
    echo "6. Salir"
    read -p "Seleccione una opción: " opcion

    case $opcion in
        1)
            read -p "Confirmar ruta raíz [/home/custuser/misscripts]: " RUTA
            RUTA=${RUTA:-$(pwd)}
            cd "$RUTA" || exit
            read -p "Nombre corto del repo: " NOMBRE
            read -p "Descripción corta (Commit): " DESC_COMMIT
            read -p "Descripción larga (GitHub): " DESC_REPO
            git init
            git add .
            git commit -m "Carga inicial: $DESC_COMMIT"
            gh repo create "$NOMBRE" --public --description "$DESC_REPO" --source=. --remote=origin --push
            ;;
        
        2)
            echo "--- Verificando cambios en $(pwd) ---"
            # Capturamos el estado
            CAMBIOS=$(git status --porcelain)

            if [ -z "$CAMBIOS" ]; then
                # Ahora usamos un mensaje más visible y una pausa
                echo "--------------------------------------"
                echo "ℹ️  Todo al día. No hay cambios pendientes."
                echo "--------------------------------------"
                sleep 1 # Pausa de un segundo para que alcances a leerlo
            else
                echo "Cambios detectados:"
                git status -s
                echo "--------------------------------------"
                read -p "Mensaje de actualización: " MSG
                git add .
                git commit -m "$MSG"
                RAMA=$(git branch --show-current)
                git push origin "$RAMA"
                echo "✅ ¡Actualizado con éxito!"
            fi
            ;;

        3)
            read -p "Nueva descripción: " NUEVA_DESC
            gh repo edit --description "$NUEVA_DESC"
            ;;

        4)
            actualizar_readme_tabla
            echo "✅ Tabla generada en README.md."
            ;;

        5)
            read -p "Nueva ruta: " NUEVA_RUTA
            cd "$NUEVA_RUTA" && echo "Cambiado a: $(pwd)"
            ;;

        6) exit 0 ;;
    esac
done
