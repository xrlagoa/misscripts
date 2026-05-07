#!/bin/bash
# Desc: Gestor avanzado multi-VM: Trazabilidad, Sincronización selectiva y Clonado.
# Desc: Gestor Multi-VM con Flujo PRO/DEV (GitFlow Simplificado)
# Desc: Gestor Pro de Repositorios - Flujo Master/Develop/Features
# Version: 5.5

MI_VM=$(hostname)

# --- FUNCIÓN: Generar Tabla de Contenidos ---
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
    RAMA_ACTUAL=$(git branch --show-current 2>/dev/null)
    echo "=========================================================="
    echo "   SISTEMA DE GESTIÓN (Host: $MI_VM)"
    echo "   PROYECTO: $(basename "$(pwd)") | RAMA: [${RAMA_ACTUAL:-No Git}]"
    echo "=========================================================="
    echo " 1. [NUEVO] Crear proyecto desde cero (Master + Develop)"
    echo " 2. [ACTUALIZAR] Convertir proyecto existente (Añadir Develop)"
    echo "----------------------------------------------------------"
    echo " 3. SUBIR Cambios a rama actual ($RAMA_ACTUAL)"
    echo " 4. BAJAR Cambios (Sync rápido desde Master)"
    echo " 5. TRAER / Clonar proyecto de GitHub"
    echo "----------------------------------------------------------"
    echo " 6. Cambiar entre ramas (Master / Develop / Otros)"
    echo " 7. Crear rama de EXPERIMENTO / COLABORADOR"
    echo " 8. 🚀 PROMOVER: Fusionar Develop -> Master (PASO A PRO)"
    echo "----------------------------------------------------------"
    echo " 9. Actualizar Tabla README | 10. Cambiar de Directorio (CD)"
    echo " R. REPARAR Conexión GitHub | X. Salir"    
    read -p "Opción: " opcion

    case $opcion in
        1)
            read -p "Nombre repo: " NOMBRE
            read -p "Desc: " DESC
            git init
            echo "# $NOMBRE" > README.md
            git add .
            git commit -m "Carga inicial [$MI_VM]"
            git branch -M master
            gh repo create "xrlagoa/$NOMBRE" --public --description "$DESC" --source=. --remote=origin --push
            git checkout -b develop
            git push -u origin develop
            echo "✅ Proyecto configurado con Master (Público) y Develop."
            ;;

        2)
            echo "--- Configurando entorno Develop en proyecto actual ---"
            if [ "$RAMA_ACTUAL" == "main" ]; then
                git branch -m main master
                echo "Renombrada 'main' a 'master'."
            fi
            git checkout master && git pull origin master
            git checkout -b develop
            git push -u origin develop
            echo "✅ Ahora el proyecto tiene rama 'develop'."
            ;;

        3)
            if [ "$RAMA_ACTUAL" == "master" ]; then
                echo "⚠️  ADVERTENCIA: Estás en MASTER (Producción)."
                read -p "¿Estás seguro de subir cambios directos? (s/n): " CONF
                [ "$CONF" != "s" ] && continue
            fi
            git status -s
            read -p "Mensaje de actualización: " MSG
            git add .
            git commit -m "[$MI_VM] $MSG"
            git push origin "$RAMA_ACTUAL"
            ;;

        4)
            echo "--- Sincronizando con Master ---"
            git fetch origin
            git checkout master
            git pull origin master
            git checkout "$RAMA_ACTUAL"
            echo "✅ Base de código actualizada."
            ;;

        5)
            read -p "Nombre del repo en GitHub: " REPO_NOM
            read -p "Ruta destino: " RUTA_DEST
            mkdir -p "$RUTA_DEST" && cd "$RUTA_DEST" || exit
            gh repo clone "xrlagoa/$REPO_NOM" .
            git checkout develop || git checkout master
            ;;

        6)
            echo "Ramas disponibles:"
            git branch
            read -p "Ir a la rama: " DEST
            git checkout "$DEST"
            ;;

        7)
            echo "--- Creando rama de Feature/Experimento ---"
            read -p "Nombre de la rama (ej: feat-nueva-idea): " NUEVA
            git checkout develop
            git checkout -b "$NUEVA"
            git push -u origin "$NUEVA"
            echo "✅ Rama [$NUEVA] lista para trabajar sin romper Develop."
            ;;

        8)
            echo "--- 🚀 INICIANDO PASO A PRODUCCIÓN (Merge a Master) ---"
            git checkout master
            git pull origin master
            echo "Mezclando cambios de la rama Develop..."
            git merge develop
            if [ $? -eq 0 ]; then
                git push origin master
                echo "✅ PRODUCCIÓN ACTUALIZADA CORRECTAMENTE."
            else
                echo "❌ Error: Hay conflictos que debes resolver manualmente."
            fi
            git checkout develop
            ;;

        9) actualizar_readme_tabla && echo "✅ README actualizado." ;;
        10) read -p "Ruta: " NR && cd "$NR" && echo "Directorio: $(pwd)" ;;

        R)
            read -p "Nombre del repo: " REPO_NOM
            git remote remove origin 2>/dev/null
            git remote add origin "git@github.com:xrlagoa/$REPO_NOM.git"
            echo "✅ Remoto reparado."
            ;;

        X|x) exit 0 ;;
        *) echo "Opción no válida." ;;
    esac
done
