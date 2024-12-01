#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar si se está ejecutando como root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Este script debe ser ejecutado como root\${NC}"
    exit 1
fi

# Función para verificar si un comando necesita sudo
need_sudo() {
    if [ "\$(id -u)" != "0" ]; then
        echo "sudo"
    fi
}

check_dependencies() {
    if ! command -v netstat &> /dev/null; then
        echo "netstat no está instalado. Instalando..."
        sudo apt-get install net-tools -y
    fi
}

check_dependencies

# Función para validar la configuración de Dropbear
validate_dropbear_config() {
    if ! sh -n /etc/default/dropbear; then
        echo -e "\${RED}Error en la configuración de Dropbear. Corrigiendo...\${NC}"
        # Eliminar cualquier línea que comience con un número
        \$(need_sudo) sed -i '/^[0-9]/d' /etc/default/dropbear
        echo -e "${GREEN}Configuración corregida${NC}"
    fi
}

install_dropbear() {
    echo -e "${YELLOW}Instalando Dropbear...${NC}"
    $(need_sudo) apt-get update
    $(need_sudo) apt-get install -y dropbear
    if ! command -v dropbear &> /dev/null; then
        echo -e "${RED}Error: La instalación de Dropbear falló${NC}"
        exit 1
    fi
    clean_dropbear_config

    echo -e "${YELLOW}Configurando puerto principal para Dropbear...${NC}"

    # Bucle para seguir pidiendo un puerto hasta que sea válido
    while true; do
        read -p "Ingrese el puerto principal para Dropbear (no use el puerto 22): " dropbear_port

        # Verificar si el puerto está en uso
        if netstat -tuln | grep ":\$dropbear_port " > /dev/null; then
            echo "El puerto \$dropbear_port ya está en uso por otro proceso. Por favor, elija otro puerto."
        elif [ "$dropbear_port" = "22" ]; then
            echo -e "${RED}El puerto 22 no está permitido. Por favor, elija otro puerto.\${NC}"
        else
            break
        fi
    done

    # Modificar la configuración de Dropbear
    \$(need_sudo) sed -i "s/^DROPBEAR_PORT=/DROPBEAR_PORT=\$dropbear_port/" /etc/default/dropbear

    restart_dropbear
}

open_ports() {
    echo -e "\${YELLOW}Abriendo puertos adicionales para Dropbear...\${NC}"
    read -p "Ingrese el puerto adicional que desea abrir: " port
    if netstat -tuln | grep ":\$port " > /dev/null; then
        echo "El puerto \$port ya está en uso por otro proceso. Por favor, elija otro puerto."
        return
    fi
    while [ "$port" = "22" ]; do
        echo -e "${RED}El puerto 22 no está permitido. Por favor, elija otro puerto.\${NC}"
        read -p "Ingrese el puerto adicional que desea abrir: " port
    done

    if lsof -i :$port > /dev/null; then
        echo -e "${RED}El puerto $port ya está en uso${NC}"
    else
        current_args=\$(grep "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear | cut -d'"' -f2)
        new_args="\$current_args -p $port"
        $(need_sudo) sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"\$new_args\"/" /etc/default/dropbear

        restart_dropbear
    fi
}

close_port() {
    echo -e "\${YELLOW}Cerrando puerto para Dropbear...\${NC}"
    read -p "Ingrese el puerto que desea cerrar: " port

    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "\$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}Puerto inválido. Debe ser un número entre 1 y 65535.\${NC}"
        return
    fi

    # Verificar si el puerto está configurado
    if ! grep -qE "DROPBEAR_PORT=\$port|DROPBEAR_EXTRA_ARGS=.*-p $port" /etc/default/dropbear; then
        echo -e "${RED}El puerto $port no está configurado para Dropbear${NC}"
        return
    fi

    # Obtener la configuración actual
    current_port=$(grep "^DROPBEAR_PORT=" /etc/default/dropbear | cut -d'=' -f2)
    current_args=$(grep "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear | cut -d'"' -f2)

    if [ "\$current_port" = "$port" ]; then
        echo -e "${RED}El puerto $port es el puerto principal de Dropbear y no se puede cerrar.${NC}"
        read -p "¿Desea actualizar el puerto principal? (s/n): " choice
        if [ "\$choice" = "s" ]; then
            read -p "Ingrese el nuevo puerto principal: " new_port

            if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "\$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
                echo -e "${RED}Nuevo puerto inválido. Debe ser un número entre 1 y 65535.${NC}"
                return
            fi

            $(need_sudo) sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$new_port/" /etc/default/dropbear
            echo -e "${GREEN}Puerto principal actualizado a $new_port exitosamente${NC}"
            restart_dropbear
        fi
        return
    else
        # Si es un puerto adicional, lo removemos de DROPBEAR_EXTRA_ARGS
        new_args=\$(echo \$current_args | sed "s/-p $port//g")
        $(need_sudo) sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$new_args\"/" /etc/default/dropbear
        echo -e "${GREEN}Puerto adicional $port cerrado exitosamente${NC}"
    fi

    restart_dropbear
}

restart_dropbear() {
    echo -e "${YELLOW}Reiniciando Dropbear...${NC}"
    $(need_sudo) service dropbear stop
    sleep 2
    if ! $(need_sudo) service dropbear start; then
        echo -e "${RED}Error al reiniciar Dropbear. Mostrando logs:${NC}"
        $(need_sudo) service dropbear status
        $(need_sudo) journalctl -xeu dropbear.service
    else
        echo -e "${GREEN}Dropbear reiniciado con éxito${NC}"
    fi
    sleep 2
    if ! pgrep -x "dropbear" > /dev/null; then
        echo -e "${RED}Error: Dropbear no se está ejecutando después del reinicio${NC}"
        echo -e "${YELLOW}Mostrando logs:${NC}"
        $(need_sudo) journalctl -xeu dropbear.service
    else
        echo -e "${GREEN}Dropbear reiniciado con éxito\${NC}"
    fi
}

clean_dropbear_config() {
    echo -e "${YELLOW}Limpiando configuración de Dropbear...${NC}"
    $(need_sudo) cp /etc/default/dropbear /etc/default/dropbear.bak
    $(need_sudo) cat > /etc/default/dropbear << EOF
# Defaults for dropbear initscript
# sourced by /etc/init.d/dropbear
# installed at /etc/default/dropbear by the maintainer scripts

# Change to NO_START=0 to start dropbear at system boot
NO_START=0

# the TCP port that Dropbear listens on
DROPBEAR_PORT=

# any additional arguments for Dropbear
DROPBEAR_EXTRA_ARGS=""

# specify an optional banner file containing a message to be
# sent to clients before they connect, such as "/etc/issue.net"
DROPBEAR_BANNER=""

# RSA hostkey file (default: /etc/dropbear/dropbear_rsa_host_key)
#DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"

# DSS hostkey file (default: /etc/dropbear/dropbear_dss_host_key)
#DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"

# ECDSA hostkey file (default: /etc/dropbear/dropbear_ecdsa_host_key)
#DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"

# Receive window size - this is a tradeoff between memory and
# network performance
DROPBEAR_RECEIVE_WINDOW=65536
EOF
    echo -e "${GREEN}Configuración de Dropbear limpiada y reiniciada${NC}"
}

# Función para mostrar puertos en uso según la configuración de Dropbear
show_ports() {
    # Verificar si Dropbear está instalado
    if ! command -v dropbear &> /dev/null; then
        echo -e "${YELLOW}Dropbear no está instalado. Por favor, instálelo primero.${NC}"
        exit 1
    fi

    # Verificar si el archivo de configuración existe
    if [ ! -f /etc/default/dropbear ]; then
        echo -e "${RED}El archivo de configuración de Dropbear no se encontró.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Puertos Dropbear configurados:${NC}"
    echo -e "PORT\tSTATE"

    # Extraer el puerto principal
    main_port=\$(awk -F= '/^DROPBEAR_PORT=/ {print \$2}' /etc/default/dropbear)

    # Extraer los puertos adicionales de DROPBEAR_EXTRA_ARGS
    extra_ports=\$(awk -F'-p ' '/DROPBEAR_EXTRA_ARGS=/ {
        for (i=2; i<=NF; i++) {
            print \$i
        }
    }' /etc/default/dropbear | cut -d' ' -f1 | tr -d '"' | sort -n | uniq)

    # Mostrar el puerto principal
    if [ -n "\$main_port" ]; then
        echo -e "\$main_port\tCONFIGURED"
    fi

    # Mostrar los puertos adicionales
    if [ -n "\$extra_ports" ]; then
        echo "\$extra_ports" | while read port; do
            echo -e "\$port\tCONFIGURED"
        done
    fi

    # Si no se encontraron puertos, mostrar mensaje
    if [ -z "\$main_port" ] && [ -z "$extra_ports" ]; then
        echo -e "${YELLOW}No se encontraron puertos configurados para Dropbear.\${NC}"
    fi
}

# Función para crear usuarios temporales
create_user() {
    echo -e "\${YELLOW}Creando usuario temporal...${NC}"
    read -p "Ingrese el nombre de usuario: " username
    read -p "Ingrese el número de días de validez: " days

    $(need_sudo) useradd -m -s /bin/false -e \$(date -d "+\$days days" +%Y-%m-%d) $username
    $(need_sudo) passwd $username
    echo -e "${GREEN}Usuario \$username creado con éxito. Expira en $days días${NC}"
}

list_users() {
    echo -e "${YELLOW}Lista de usuarios creados:${NC}"
    \$(need_sudo) awk -F: '\$3 >= 1000 && \$1 != "nobody" {print \$1}' /etc/passwd
}

# Menu de gestion de usuarios
manage_users_menu() {
    clear
    echo "=== Gestión de Usuarios ==="
    echo "1. Crear usuario"
    echo "2. Listar usuarios"
    echo "3. Ampliar días de existencia de un usuario"
    echo "4. Disminuir días de existencia de un usuario"
    echo "5. Actualizar contraseña de un usuario"
    echo "6. Eliminar usuario"
    echo "7. Volver al menú principal"
    echo -n "Seleccione una opción: "
    read option

    case \$option in
        1) create_user ;;
        2) list_users ;;
        3) extend_user_days ;;
        4) reduce_user_days ;;
        5) update_user_password ;;
        6) delete_user ;;
        7) main_menu ;;
        *) echo "Opción no válida"; sleep 2; manage_users_menu ;;
    esac
}

extend_user_days() {
    read -p "Ingrese el nombre de usuario: " username
    read -p "Ingrese el número de días a añadir: " days

    if id "\$username" >/dev/null 2>&1; then
        new_expiry=\$(date -d "$($(need_sudo) chage -l \$username | grep 'Account expires' | cut -d: -f2) +$days days" +%Y-%m-%d)
        $(need_sudo) chage -E \$new_expiry $username
        echo -e "${GREEN}Se han añadido \$days días a la cuenta de $username${NC}"
    else
        echo -e "\${RED}El usuario $username no existe${NC}"
    fi
}

reduce_user_days() {
    read -p "Ingrese el nombre de usuario: " username
    read -p "Ingrese el número de días a reducir: " days

    if id "\$username" >/dev/null 2>&1; then
        new_expiry=\$(date -d "$($(need_sudo) chage -l \$username | grep 'Account expires' | cut -d: -f2) -$days days" +%Y-%m-%d)
        $(need_sudo) chage -E \$new_expiry $username
        echo -e "${GREEN}Se han reducido \$days días de la cuenta de $username${NC}"
    else
        echo -e "\${RED}El usuario $username no existe${NC}"
    fi
}

update_user_password() {
    read -p "Ingrese el nombre de usuario: " username

    if id "\$username" >/dev/null 2>&1; then
        \$(need_sudo) passwd $username
    else
        echo -e "${RED}El usuario $username no existe${NC}"
    fi
}

delete_user() {
    read -p "Ingrese el nombre de usuario a eliminar: " username

    if id "\$username" >/dev/null 2>&1; then
        \$(need_sudo) userdel -r $username
        echo -e "${GREEN}Usuario $username eliminado con éxito${NC}"
    else
        echo -e "\${RED}El usuario $username no existe${NC}"
    fi
}

# Función para actualizar el script
update_script() {
    echo -e "${YELLOW}Actualizando el script...${NC}"

    # URL del script en GitHub
    SCRIPT_URL="https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master/dropbear_manager.sh"

    # Nombre del script actual
    CURRENT_SCRIPT="\$0"

    # Descargar el nuevo script
    if curl -s "$SCRIPT_URL" -o "${CURRENT_SCRIPT}.tmp"; then
        # Verificar si la descarga fue exitosa
        if [ -s "\${CURRENT_SCRIPT}.tmp" ]; then
            # Hacer el nuevo script ejecutable
            chmod +x "\${CURRENT_SCRIPT}.tmp"

            # Reemplazar el script actual con el nuevo
            mv "\${CURRENT_SCRIPT}.tmp" "$CURRENT_SCRIPT"

            echo -e "${GREEN}Script actualizado con éxito. Por favor, reinicie el script.${NC}"
            exit 0
        else
            echo -e "${RED}Error: El archivo descargado está vacío.${NC}"
            rm -f "${CURRENT_SCRIPT}.tmp"
        fi
    else
        echo -e "${RED}Error al descargar el script. Por favor, verifica tu conexión a internet.${NC}"
    fi
}

# Función para desinstalar
uninstall() {
    echo -e "${YELLOW}=== Desinstalación ===${NC}"

    # Opción para desinstalar el script
    read -p "¿Desea desinstalar el script? (s/n): " uninstall_script
    if [[ "$uninstall_script" =~ ^[Ss]$ ]]; then
        echo -e "${RED}Desinstalando el script...${NC}"

        # Eliminar el script
        if [ -f "\$0" ]; then
            rm "$0"
            echo -e "${GREEN}Script eliminado con éxito\${NC}"
        else
            echo -e "${RED}No se pudo encontrar el script para eliminar${NC}"
        fi

        # Eliminar el alias
        sed -i '/alias dropbear-manager=/d' "\$HOME/.bashrc"

        # Eliminar la entrada del PATH
        sed -i '/export PATH=.*\.local\/bin/d' "$HOME/.bashrc"

        echo -e "${GREEN}Alias y entrada del PATH eliminados\${NC}"
    fi

    # Opción para desinstalar Dropbear
    read -p "¿Desea desinstalar Dropbear? (s/n): " uninstall_dropbear
    if [[ "$uninstall_dropbear" =~ ^[Ss]$ ]]; then
        echo -e "${RED}Desinstalando Dropbear...${NC}"
        $(need_sudo) apt-get remove --purge -y dropbear
        $(need_sudo) apt-get autoremove -y
        $(need_sudo) rm -rf /etc/dropbear
        echo -e "${GREEN}Dropbear desinstalado con éxito\${NC}"

        # Eliminar la configuración de Dropbear
        if [ -f "/etc/default/dropbear" ]; then
            $(need_sudo) rm /etc/default/dropbear
            echo -e "${GREEN}Configuración de Dropbear eliminada\${NC}"
        fi
    fi

    # Si ambos fueron desinstalados, salir del script
    if [[ "$uninstall_script" =~ ^[Ss]$ ]] && [[ "$uninstall_dropbear" =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Desinstalación completa. Saliendo...${NC}"
        # Eliminar el directorio de instalación si está vacío
        rmdir --ignore-fail-on-non-empty "\$HOME/.local/bin"
        source "\$HOME/.bashrc"
        exit 0
    elif [[ "$uninstall_script" =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Script desinstalado. Saliendo...${NC}"
        # Eliminar el directorio de instalación si está vacío
        rmdir --ignore-fail-on-non-empty "\$HOME/.local/bin"
        source "\$HOME/.bashrc"
        exit 0
    fi

    # Si solo se desinstaló Dropbear, volver al menú principal
    echo -e "\${YELLOW}Volviendo al menú principal...\${NC}"
    source "\$HOME/.bashrc"
}

# Función para habilitar la depuración en Dropbear
enable_debugging() {
    echo -e "\${YELLOW}Habilitando la depuración en Dropbear...${NC}"
    $(need_sudo) sed -i 's/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-v"/' /etc/default/dropbear
    restart_dropbear
    echo -e "${GREEN}Depuración habilitada. Por favor, revise los logs para más detalles.${NC}"
}

# Función para verificar y convertir claves
verify_and_convert_keys() {
    echo -e "${YELLOW}Verificando y convirtiendo claves...${NC}"
    # Verificar si las claves están en el formato correcto
    if ! grep -q "ssh-rsa" /etc/dropbear/dropbear_rsa_host_key.pub; then
        echo -e "${RED}La clave pública no está en el formato correcto. Convirtiendo...${NC}"
                # Convertir la clave pública a formato OpenSSH
        ssh-keygen -i -f /etc/dropbear/dropbear_rsa_host_key.pub > /etc/dropbear/dropbear_rsa_host_key.pub.tmp
        mv /etc/dropbear/dropbear_rsa_host_key.pub.tmp /etc/dropbear/dropbear_rsa_host_key.pub
        echo -e "${GREEN}Clave pública convertida con éxito${NC}"
    else
        echo -e "${GREEN}La clave pública está en el formato correcto${NC}"
    fi

    # Verificar si la clave privada está en el formato correcto
    if ! grep -q "BEGIN RSA PRIVATE KEY" /etc/dropbear/dropbear_rsa_host_key; then
        echo -e "${RED}La clave privada no está en el formato correcto. Convirtiendo...${NC}"
        # Convertir la clave privada a formato OpenSSH
        ssh-keygen -p -f /etc/dropbear/dropbear_rsa_host_key -m PEM -P ""
        echo -e "${GREEN}Clave privada convertida con éxito${NC}"
    else
        echo -e "${GREEN}La clave privada está en el formato correcto${NC}"
    fi
}

# Menú principal
while true; do
    echo -e "\n${BLUE}=== Menú de Dropbear ===${NC}"
    echo "1. Instalar Dropbear"
    echo "2. Abrir puertos adicionales"
    echo "3. Cerrar puertos"
    echo "4. Mostrar puertos en uso"
    echo "5. Gestionar usuarios"
    echo "6. Actualizar script"
    echo "7. Limpiar configuración de Dropbear"
    echo "8. Desinstalar"
    echo "9. Habilitar depuración"
    echo "10. Verificar y convertir claves"
    echo "11. Salir"

    read -p "Seleccione una opción: " choice

    case $choice in
        1) install_dropbear ;;
        2) open_ports ;;
        3) close_port ;;
        4) show_ports ;;
        5) manage_users ;;
        6) update_script ;;
        7) clean_dropbear_config ;;
        8) uninstall; exit 0 ;;
        9) enable_debugging ;;
        10) verify_and_convert_keys ;;
        11) exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}" ;;
    esac
done

