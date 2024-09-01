#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar si se está ejecutando como root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Este script debe ser ejecutado como root${NC}"
    exit 1
fi

# Función para verificar si un comando necesita sudo
need_sudo() {
    if [ "$(id -u)" != "0" ]; then
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
        echo -e "${RED}Error en la configuración de Dropbear. Corrigiendo...${NC}"
        # Eliminar cualquier línea que comience con un número
        $(need_sudo) sed -i '/^[0-9]/d' /etc/default/dropbear
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
        if netstat -tuln | grep ":$dropbear_port " > /dev/null; then
            echo "El puerto $dropbear_port ya está en uso por otro proceso. Por favor, elija otro puerto."
        elif [ "$dropbear_port" = "22" ]; then
            echo -e "${RED}El puerto 22 no está permitido. Por favor, elija otro puerto.${NC}"
        else
            break
        fi
    done
    
    # Modificar la configuración de Dropbear
    $(need_sudo) sed -i "s/^DROPBEAR_PORT=/DROPBEAR_PORT=$dropbear_port/" /etc/default/dropbear
    
    restart_dropbear

}

open_ports() {
    echo -e "${YELLOW}Abriendo puertos adicionales para Dropbear...${NC}"
    read -p "Ingrese el puerto adicional que desea abrir: " port
    if netstat -tuln | grep ":$port " > /dev/null; then
        echo "El puerto $port ya está en uso por otro proceso. Por favor, elija otro puerto."
        return
    fi
    while [ "$port" = "22" ]; do
        echo -e "${RED}El puerto 22 no está permitido. Por favor, elija otro puerto.${NC}"
        read -p "Ingrese el puerto adicional que desea abrir: " port
    done
    
    if lsof -i :$port > /dev/null; then
        echo -e "${RED}El puerto $port ya está en uso${NC}"
    else
        current_args=$(grep "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear | cut -d'"' -f2)
        new_args="$current_args -p $port"
        $(need_sudo) sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$new_args\"/" /etc/default/dropbear
        
        restart_dropbear
    fi
}

restart_dropbear() {
    echo -e "${YELLOW}Reiniciando Dropbear...${NC}"
    $(need_sudo) service dropbear stop
    sleep 2
    if ! $(need_sudo) service dropbear start; then
        echo -e "${RED}Error al reiniciar Dropbear. Mostrando logs:${NC}"
        $(need_sudo) service dropber status
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
        echo -e "${GREEN}Dropbear reiniciado con éxito${NC}"
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
    main_port=$(awk -F= '/^DROPBEAR_PORT=/ {print $2}' /etc/default/dropbear)
    
    # Extraer los puertos adicionales de DROPBEAR_EXTRA_ARGS
    extra_ports=$(awk -F'-p ' '/DROPBEAR_EXTRA_ARGS=/ {
        for (i=2; i<=NF; i++) {
            print $i
        }
    }' /etc/default/dropbear | cut -d' ' -f1 | tr -d '"' | sort -n | uniq)
    
    # Mostrar el puerto principal
    if [ -n "$main_port" ]; then
        echo -e "$main_port\tCONFIGURED"
    fi
    
    # Mostrar los puertos adicionales
    if [ -n "$extra_ports" ]; then
        echo "$extra_ports" | while read port; do
            echo -e "$port\tCONFIGURED"
        done
    fi
    
    # Si no se encontraron puertos, mostrar mensaje
    if [ -z "$main_port" ] && [ -z "$extra_ports" ]; then
        echo -e "${YELLOW}No se encontraron puertos configurados para Dropbear.${NC}"
    fi
}

# Función para crear usuarios temporales
create_user() {
    echo -e "${YELLOW}Creando usuario temporal...${NC}"
    read -p "Ingrese el nombre de usuario: " username
    read -p "Ingrese el número de días de validez: " days
    
    expiry_date=$(date -d "+$days days" +%Y-%m-%d)
    $(need_sudo) useradd -m -s /bin/false -e "$expiry_date" $username
    if [ $? -eq 0 ]; then
        $(need_sudo) passwd $username
        echo -e "${GREEN}Usuario $username creado con éxito. Expira el $expiry_date${NC}"
    else
        echo -e "${RED}Error al crear el usuario $username${NC}"
    fi
}

# Función para actualizar el script
update_script() {
    echo -e "${YELLOW}Actualizando el script...${NC}"
    
    # URL del script en GitHub
    SCRIPT_URL="https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master/dropbear_manager.sh"
    
    # Nombre del script actual
    CURRENT_SCRIPT="$0"
    
    # Descargar el nuevo script
    if curl -s "$SCRIPT_URL" -o "${CURRENT_SCRIPT}.tmp"; then
        # Verificar si la descarga fue exitosa
        if [ -s "${CURRENT_SCRIPT}.tmp" ]; then
            # Hacer el nuevo script ejecutable
            chmod +x "${CURRENT_SCRIPT}.tmp"
            
            # Reemplazar el script actual con el nuevo
            mv "${CURRENT_SCRIPT}.tmp" "$CURRENT_SCRIPT"
            
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
    echo -e "${RED}Desinstalando...${NC}"
    read -p "¿Desea desinstalar solo el script o también Dropbear? (script/dropbear): " choice
    
    if [ "$choice" = "dropbear" ]; then
        $(need_sudo) apt-get remove --purge -y dropbear
        echo -e "${GREEN}Dropbear desinstalado con éxito${NC}"
    fi
    
    # Eliminar el script
    rm "$0"
    echo -e "${GREEN}Script eliminado con éxito${NC}"
}
manage_users() {
    while true; do
        echo -e "\n${BLUE}=== Gestión de Usuarios ===${NC}"
        echo "1. Crear usuario"
        echo "2. Listar usuarios"
        echo "3. Ampliar días de existencia de un usuario"
        echo "4. Disminuir días de existencia de un usuario"
        echo "5. Actualizar contraseña de un usuario"
        echo "6. Eliminar usuario"
        echo "7. Volver al menú principal"
        
        read -p "Seleccione una opción: " user_choice
        
        case $user_choice in
            1) create_user ;;
            2) list_users ;;
            3) extend_user_days ;;
            4) reduce_user_days ;;
            5) update_user_password ;;
            6) delete_user ;;
            7) break ;;
            *) echo -e "${RED}Opción inválida${NC}" ;;
        esac
    done
}

create_user() {
    echo -e "${YELLOW}Creando usuario temporal...${NC}"
    read -p "Ingrese el nombre de usuario: " username
    read -p "Ingrese el número de días de validez: " days
    
    $(need_sudo) useradd -m -s /bin/false -e $(date -d "+$days days" +%Y-%m-%d) $username
    $(need_sudo) passwd $username
    echo -e "${GREEN}Usuario $username creado con éxito. Expira en $days días${NC}"
}

list_users() {
    echo -e "USUARIO\t\tDÍAS RESTANTES"
    echo -e "-------\t\t--------------"
    
    for user in $(awk -F':' '{ print $1 }' /etc/passwd); do
        # Verificar si el usuario tiene una fecha de expiración
        expire_date=$(chage -l $user | grep "Account expires" | awk -F': ' '{ print $2 }')
        
        if [ "$expire_date" == "never" ]; then
            days_left="Nunca expira"
        else
            expire_timestamp=$(date -d "$expire_date" +%s)
            current_timestamp=$(date +%s)
            days_left=$(( ($expire_timestamp - $current_timestamp) / 86400 ))

            if [ "$days_left" -lt "0" ]; then
                days_left="Expirado"
            fi
        fi
        
        # Mostrar el usuario y los días restantes
        echo -e "$user\t\t$days_left"
    done
}

extend_user_days() {
    read -p "Ingrese el nombre de usuario: " username
    read -p "Ingrese el número de días a añadir: " days
    
    if id "$username" >/dev/null 2>&1; then
        new_expiry=$(date -d "$($(need_sudo) chage -l $username | grep 'Account expires' | cut -d: -f2) +$days days" +%Y-%m-%d)
        $(need_sudo) chage -E $new_expiry $username
        echo -e "${GREEN}Se han añadido $days días a la cuenta de $username${NC}"
    else
        echo -e "${RED}El usuario $username no existe${NC}"
    fi
}

reduce_user_days() {
    read -p "Ingrese el nombre de usuario: " username
    read -p "Ingrese el número de días a reducir: " days
    
    if id "$username" >/dev/null 2>&1; then
        new_expiry=$(date -d "$($(need_sudo) chage -l $username | grep 'Account expires' | cut -d: -f2) -$days days" +%Y-%m-%d)
        $(need_sudo) chage -E $new_expiry $username
        echo -e "${GREEN}Se han reducido $days días de la cuenta de $username${NC}"
    else
        echo -e "${RED}El usuario $username no existe${NC}"
    fi
}

update_user_password() {
    read -p "Ingrese el nombre de usuario: " username
    
    if id "$username" >/dev/null 2>&1; then
        $(need_sudo) passwd $username
    else
        echo -e "${RED}El usuario $username no existe${NC}"
    fi
}

delete_user() {
    read -p "Ingrese el nombre de usuario a eliminar: " username
    
    if id "$username" >/dev/null 2>&1; then
        $(need_sudo) userdel -r $username
        echo -e "${GREEN}Usuario $username eliminado con éxito${NC}"
    else
        echo -e "${RED}El usuario $username no existe${NC}"
    fi
}
# Menú principal
while true; do
    echo -e "\n${BLUE}=== Menú de Dropbear ===${NC}"
    echo "1. Instalar Dropbear"
    echo "2. Abrir puertos adicionales"
    echo "3. Mostrar puertos en uso"
    echo "4. Gestionar usuarios"
    echo "5. Actualizar script"
    echo "6. Limpiar configuración de Dropbear"
    echo "7. Desinstalar"
    echo "8. Salir"
    
    read -p "Seleccione una opción: " choice
    
    case $choice in
        1) install_dropbear ;;
        2) open_ports ;;
        3) show_ports ;;
        4) manage_users ;;
        5) update_script ;;
        6) clean_dropbear_config ;;
        7) uninstall; exit 0 ;;
        8) exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}" ;;
    esac
done
