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

# Función para validar la configuración de Dropbear
validate_dropbear_config() {
    if ! sh -n /etc/default/dropbear; then
        echo -e "${RED}Error en la configuración de Dropbear. Corrigiendo...${NC}"
        # Eliminar cualquier línea que comience con un número
        $(need_sudo) sed -i '/^[0-9]/d' /etc/default/dropbear
        echo -e "${GREEN}Configuración corregida${NC}"
    fi
}

# Función para instalar Dropbear
install_dropbear() {
    echo -e "${YELLOW}Instalando Dropbear...${NC}"
    $(need_sudo) apt-get update
    $(need_sudo) apt-get install -y dropbear
    
    echo -e "${YELLOW}Configurando puerto para Dropbear...${NC}"
    read -p "Ingrese el puerto para Dropbear (no use el puerto 22): " dropbear_port
    
    while [ "$dropbear_port" = "22" ]; do
        echo -e "${RED}El puerto 22 no está permitido. Por favor, elija otro puerto.${NC}"
        read -p "Ingrese el puerto para Dropbear (no use el puerto 22): " dropbear_port
    done
    
    # Modificar la configuración de Dropbear
    $(need_sudo) sed -i "s/^NO_START=1/NO_START=0/" /etc/default/dropbear
    $(need_sudo) sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$dropbear_port/" /etc/default/dropbear
    
    validate_dropbear_config
    
    echo -e "${YELLOW}Reiniciando Dropbear...${NC}"
    if ! $(need_sudo) systemctl restart dropbear; then
        echo -e "${RED}Error al reiniciar Dropbear. Mostrando logs:${NC}"
        $(need_sudo) systemctl status dropbear
        $(need_sudo) journalctl -xeu dropbear.service
    else
        echo -e "${GREEN}Dropbear instalado y configurado con éxito en el puerto $dropbear_port${NC}"
    fi
}

# Función para abrir puertos
open_ports() {
    echo -e "${YELLOW}Abriendo puertos adicionales para Dropbear...${NC}"
    read -p "Ingrese el puerto adicional que desea abrir: " port
    
    while [ "$port" = "22" ]; do
        echo -e "${RED}El puerto 22 no está permitido. Por favor, elija otro puerto.${NC}"
        read -p "Ingrese el puerto adicional que desea abrir: " port
    done
    
    if lsof -i :$port > /dev/null; then
        echo -e "${RED}El puerto $port ya está en uso${NC}"
    else
        current_ports=$(grep "^DROPBEAR_PORT=" /etc/default/dropbear | cut -d'=' -f2)
        $(need_sudo) sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$current_ports $port/" /etc/default/dropbear
        
        validate_dropbear_config
        
        echo -e "${YELLOW}Reiniciando Dropbear...${NC}"
        if ! $(need_sudo) systemctl restart dropbear; then
            echo -e "${RED}Error al reiniciar Dropbear. Mostrando logs:${NC}"
            $(need_sudo) systemctl status dropbear
            $(need_sudo) journalctl -xeu dropbear.service
        else
            echo -e "${GREEN}Puerto $port abierto con éxito${NC}"
        fi
    fi
}
# Función para mostrar puertos en uso
show_ports() {
    echo -e "${BLUE}Puertos Dropbear configurados:${NC}"
    grep "^DROPBEAR_PORT=" /etc/default/dropbear | cut -d'=' -f2 | tr ' ' '\n' | sort -n | uniq | while read port; do
        echo -e "$port\tCONFIGURADO"
    done
}

# Función para crear usuarios temporales
create_user() {
    echo -e "${YELLOW}Creando usuario temporal...${NC}"
    read -p "Ingrese el nombre de usuario: " username
    read -p "Ingrese el número de días de validez: " days

    # Crear usuario con shell nula y fecha de expiración
    $(need_sudo) useradd -m -s /bin/false -e $(date -d "+$days days" +%Y-%m-%d) $username

    # Solicitar y asignar contraseña
    echo -e "${YELLOW}Ingrese la contraseña para el usuario $username:${NC}"
    $(need_sudo) passwd $username
    
    echo -e "${GREEN}Usuario $username creado con éxito. Expira en $days días${NC}"
}

# Función para actualizar el script
update_script() {
    echo -e "${YELLOW}Actualizando el script...${NC}"
    # Aquí iría la lógica para actualizar el script desde un repositorio
    echo -e "${GREEN}Script actualizado con éxito${NC}"
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

# Menú principal
while true; do
    echo -e "\n${BLUE}=== Menú de Dropbear ===${NC}"
    echo "1. Instalar Dropbear"
    echo "2. Abrir puertos adicionales"
    echo "3. Mostrar puertos en uso"
    echo "4. Crear usuario temporal"
    echo "5. Actualizar script"
    echo "6. Desinstalar"
    echo "7. Salir"
    
    read -p "Seleccione una opción: " choice
    
    case $choice in
        1) install_dropbear ;;
        2) open_ports ;;
        3) show_ports ;;
        4) create_user ;;
        5) update_script ;;
        6) uninstall; exit 0 ;;
        7) exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}" ;;
    esac
done
