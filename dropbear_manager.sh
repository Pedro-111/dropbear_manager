#!/bin/bash

# 🎨 Colores y símbolos Unicode
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 🎯 Banner del programa
show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                     🔐 DROPBEAR MANAGER                        ║${NC}"
    echo -e "${CYAN}║                   Gestor SSH Seguro v2.0                       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 🔍 Verificar si se está ejecutando como root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}⚠️  Este script debe ser ejecutado como root${NC}"
        echo -e "${YELLOW}💡 Usa: ${WHITE}sudo dropbear-manager${NC}"
        exit 1
    fi
}

# 🛠️ Función para verificar si un comando necesita sudo
need_sudo() {
    if [ "$(id -u)" != "0" ]; then
        echo "sudo"
    fi
}

# 📦 Verificar dependencias
check_dependencies() {
    echo -e "${YELLOW}🔍 Verificando dependencias...${NC}"
    
    local missing_deps=()
    
    if ! command -v netstat &> /dev/null; then
        missing_deps+=("net-tools")
    fi
    
    if ! command -v lsof &> /dev/null; then
        missing_deps+=("lsof")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}📦 Instalando dependencias faltantes: ${missing_deps[*]}${NC}"
        apt-get update > /dev/null 2>&1
        apt-get install -y "${missing_deps[@]}" > /dev/null 2>&1
        echo -e "${GREEN}✅ Dependencias instaladas correctamente${NC}"
    else
        echo -e "${GREEN}✅ Todas las dependencias están instaladas${NC}"
    fi
}

# ✅ Función para validar la configuración de Dropbear
validate_dropbear_config() {
    echo -e "${YELLOW}🔧 Validando configuración de Dropbear...${NC}"
    if ! sh -n /etc/default/dropbear 2>/dev/null; then
        echo -e "${RED}❌ Error en la configuración de Dropbear. Corrigiendo...${NC}"
        sed -i '/^[0-9]/d' /etc/default/dropbear
        echo -e "${GREEN}✅ Configuración corregida${NC}"
    else
        echo -e "${GREEN}✅ Configuración de Dropbear válida${NC}"
    fi
}

# 🚀 Instalar Dropbear
install_dropbear() {
    show_banner
    echo -e "${BOLD}${BLUE}📥 INSTALACIÓN DE DROPBEAR${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if command -v dropbear &> /dev/null; then
        echo -e "${YELLOW}⚠️  Dropbear ya está instalado${NC}"
        read -p "🔄 ¿Desea reinstalarlo? (s/n): " reinstall
        if [ "$reinstall" != "s" ]; then
            return
        fi
    fi
    
    echo -e "${YELLOW}📦 Instalando Dropbear...${NC}"
    
    # Mostrar progreso
    {
        apt-get update
        apt-get install -y dropbear
    } > /dev/null 2>&1 &
    
    # Animación de carga
    local pid=$!
    local spin='-\|/'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${YELLOW}🔄 Instalando... ${spin:$i:1}${NC}"
        sleep 0.1
    done
    wait $pid
    printf "\r"
    
    if ! command -v dropbear &> /dev/null; then
        echo -e "${RED}❌ Error: La instalación de Dropbear falló${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Dropbear instalado correctamente${NC}"
    
    clean_dropbear_config
    
    echo ""
    echo -e "${YELLOW}🔧 Configurando puerto principal para Dropbear...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    
    while true; do
        echo ""
        read -p "🔌 Ingrese el puerto principal para Dropbear (no use el puerto 22): " dropbear_port
        
        # Validar que sea un número
        if ! [[ "$dropbear_port" =~ ^[0-9]+$ ]] || [ "$dropbear_port" -lt 1 ] || [ "$dropbear_port" -gt 65535 ]; then
            echo -e "${RED}❌ Puerto inválido. Debe ser un número entre 1 y 65535.${NC}"
            continue
        fi
        
        # Verificar si el puerto está en uso
        if netstat -tuln | grep ":$dropbear_port " > /dev/null; then
            echo -e "${RED}❌ El puerto $dropbear_port ya está en uso por otro proceso.${NC}"
            echo -e "${YELLOW}💡 Por favor, elija otro puerto.${NC}"
        elif [ "$dropbear_port" = "22" ]; then
            echo -e "${RED}❌ El puerto 22 no está permitido. Por favor, elija otro puerto.${NC}"
        else
            break
        fi
    done
    
    # Modificar la configuración de Dropbear
    sed -i "s/^DROPBEAR_PORT=/DROPBEAR_PORT=$dropbear_port/" /etc/default/dropbear
    
    restart_dropbear
    
    echo ""
    echo -e "${GREEN}🎉 ¡Dropbear instalado y configurado exitosamente!${NC}"
    echo -e "${WHITE}📋 Puerto configurado: ${YELLOW}$dropbear_port${NC}"
    
    read -p "Presiona Enter para continuar..."
}

# 🔓 Abrir puertos adicionales
open_ports() {
    show_banner
    echo -e "${BOLD}${BLUE}🔓 ABRIR PUERTOS ADICIONALES${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if ! command -v dropbear &> /dev/null; then
        echo -e "${RED}❌ Dropbear no está instalado${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    read -p "🔌 Ingrese el puerto adicional que desea abrir: " port
    
    # Validar puerto
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}❌ Puerto inválido. Debe ser un número entre 1 y 65535.${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    if netstat -tuln | grep ":$port " > /dev/null; then
        echo -e "${RED}❌ El puerto $port ya está en uso por otro proceso.${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    if [ "$port" = "22" ]; then
        echo -e "${RED}❌ El puerto 22 no está permitido.${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    if lsof -i :$port > /dev/null 2>&1; then
        echo -e "${RED}❌ El puerto $port ya está en uso${NC}"
    else
        current_args=$(grep "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear | cut -d'"' -f2)
        new_args="$current_args -p $port"
        sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$new_args\"/" /etc/default/dropbear
        
        restart_dropbear
        echo -e "${GREEN}✅ Puerto $port abierto exitosamente${NC}"
    fi
    
    read -p "Presiona Enter para continuar..."
}

# 🔒 Cerrar puerto
close_port() {
    show_banner
    echo -e "${BOLD}${BLUE}🔒 CERRAR PUERTO${NC}"
    echo -e "${CYAN}═══════════════════${NC}"
    echo ""
    
    if ! command -v dropbear &> /dev/null; then
        echo -e "${RED}❌ Dropbear no está instalado${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    # Mostrar puertos actuales
    echo -e "${WHITE}📋 Puertos actualmente configurados:${NC}"
    show_ports_inline
    echo ""
    
    read -p "🔌 Ingrese el puerto que desea cerrar: " port
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}❌ Puerto inválido. Debe ser un número entre 1 y 65535.${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    # Verificar si el puerto está configurado
    if ! grep -qE "DROPBEAR_PORT=$port|DROPBEAR_EXTRA_ARGS=.*-p $port" /etc/default/dropbear; then
        echo -e "${RED}❌ El puerto $port no está configurado para Dropbear${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    # Obtener la configuración actual
    current_port=$(grep "^DROPBEAR_PORT=" /etc/default/dropbear | cut -d'=' -f2)
    current_args=$(grep "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear | cut -d'"' -f2)
    
    if [ "$current_port" = "$port" ]; then
        echo -e "${RED}⚠️  El puerto $port es el puerto principal de Dropbear${NC}"
        read -p "🔄 ¿Desea actualizar el puerto principal? (s/n): " choice
        if [ "$choice" = "s" ]; then
            read -p "🔌 Ingrese el nuevo puerto principal: " new_port
            
            if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
                echo -e "${RED}❌ Nuevo puerto inválido${NC}"
                read -p "Presiona Enter para continuar..."
                return
            fi
            
            sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$new_port/" /etc/default/dropbear
            echo -e "${GREEN}✅ Puerto principal actualizado a $new_port exitosamente${NC}"
            restart_dropbear
        fi
    else
        # Si es un puerto adicional, lo removemos de DROPBEAR_EXTRA_ARGS
        new_args=$(echo $current_args | sed "s/-p $port//g" | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
        sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$new_args\"/" /etc/default/dropbear
        echo -e "${GREEN}✅ Puerto adicional $port cerrado exitosamente${NC}"
        restart_dropbear
    fi
    
    read -p "Presiona Enter para continuar..."
}

# 🔄 Reiniciar Dropbear con indicadores mejorados
restart_dropbear() {
    echo ""
    echo -e "${YELLOW}🔄 Reiniciando Dropbear...${NC}"
    
    # Detener servicio
    service dropbear stop > /dev/null 2>&1
    sleep 1
    
    # Mostrar progreso con animación
    {
        sleep 2
        service dropbear start
    } > /dev/null 2>&1 &
    
    local pid=$!
    local spin='-\|/'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${YELLOW}🔄 Reiniciando servicio... ${spin:$i:1}${NC}"
        sleep 0.2
    done
    wait $pid
    local exit_code=$?
    printf "\r"
    
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}❌ Error al reiniciar Dropbear${NC}"
        echo -e "${YELLOW}📋 Mostrando logs de error:${NC}"
        service dropbear status
        journalctl -xeu dropbear.service --no-pager -n 10
        return 1
    fi
    
    sleep 1
    
    if ! pgrep -x "dropbear" > /dev/null; then
        echo -e "${RED}❌ Error: Dropbear no se está ejecutando después del reinicio${NC}"
        echo -e "${YELLOW}📋 Mostrando logs:${NC}"
        journalctl -xeu dropbear.service --no-pager -n 10
        return 1
    else
        echo -e "${GREEN}✅ Dropbear reiniciado exitosamente${NC}"
        return 0
    fi
}

# 🧹 Limpiar configuración de Dropbear
clean_dropbear_config() {
    echo -e "${YELLOW}🧹 Limpiando configuración de Dropbear...${NC}"
    
    if [ -f /etc/default/dropbear ]; then
        cp /etc/default/dropbear /etc/default/dropbear.bak.$(date +%Y%m%d_%H%M%S)
    fi
    
    cat > /etc/default/dropbear << 'EOF'
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
    
    echo -e "${GREEN}✅ Configuración de Dropbear limpiada${NC}"
}

# 📊 Función para mostrar puertos (versión inline)
show_ports_inline() {
    if [ ! -f /etc/default/dropbear ]; then
        echo -e "${RED}❌ Archivo de configuración no encontrado${NC}"
        return
    fi
    
    main_port=$(awk -F= '/^DROPBEAR_PORT=/ {print $2}' /etc/default/dropbear)
    extra_ports=$(awk -F'-p ' '/DROPBEAR_EXTRA_ARGS=/ {
        for (i=2; i<=NF; i++) {
            print $i
        }
    }' /etc/default/dropbear | cut -d' ' -f1 | tr -d '"' | sort -n | uniq)
    
    local ports_list=""
    
    if [ -n "$main_port" ]; then
        ports_list="$main_port (principal)"
    fi
    
    if [ -n "$extra_ports" ]; then
        while read -r port; do
            if [ -n "$port" ]; then
                if [ -n "$ports_list" ]; then
                    ports_list="$ports_list, $port"
                else
                    ports_list="$port"
                fi
            fi
        done <<< "$extra_ports"
    fi
    
    if [ -n "$ports_list" ]; then
        echo -e "${WHITE}   🔌 $ports_list${NC}"
    else
        echo -e "${YELLOW}   ⚠️  No hay puertos configurados${NC}"
    fi
}

# 📊 Mostrar puertos en uso según la configuración de Dropbear
show_ports() {
    show_banner
    echo -e "${BOLD}${BLUE}📊 PUERTOS CONFIGURADOS${NC}"
    echo -e "${CYAN}═══════════════════════════${NC}"
    echo ""
    
    if ! command -v dropbear &> /dev/null; then
        echo -e "${YELLOW}⚠️  Dropbear no está instalado${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    if [ ! -f /etc/default/dropbear ]; then
        echo -e "${RED}❌ El archivo de configuración de Dropbear no se encontró${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    echo -e "${WHITE}📋 Estado de puertos Dropbear:${NC}"
    echo -e "${CYAN}════════════════════════════${NC}"
    printf "%-10s %-15s %-10s\n" "PUERTO" "TIPO" "ESTADO"
    echo -e "${CYAN}────────────────────────────────────${NC}"
    
    main_port=$(awk -F= '/^DROPBEAR_PORT=/ {print $2}' /etc/default/dropbear)
    extra_ports=$(awk -F'-p ' '/DROPBEAR_EXTRA_ARGS=/ {
        for (i=2; i<=NF; i++) {
            print $i
        }
    }' /etc/default/dropbear | cut -d' ' -f1 | tr -d '"' | sort -n | uniq)
    
    local found_ports=false
    
    if [ -n "$main_port" ]; then
        if netstat -tuln | grep ":$main_port " > /dev/null; then
            status="${GREEN}✅ ACTIVO${NC}"
        else
            status="${RED}❌ INACTIVO${NC}"
        fi
        printf "%-10s %-15s %-20s\n" "$main_port" "Principal" "$status"
        found_ports=true
    fi
    
    if [ -n "$extra_ports" ]; then
        while read -r port; do
            if [ -n "$port" ]; then
                if netstat -tuln | grep ":$port " > /dev/null; then
                    status="${GREEN}✅ ACTIVO${NC}"
                else
                    status="${RED}❌ INACTIVO${NC}"
                fi
                printf "%-10s %-15s %-20s\n" "$port" "Adicional" "$status"
                found_ports=true
            fi
        done <<< "$extra_ports"
    fi
    
    if [ "$found_ports" = false ]; then
        echo -e "${YELLOW}⚠️  No se encontraron puertos configurados para Dropbear${NC}"
    fi
    
    echo ""
    # Mostrar estado del servicio
    if pgrep -x "dropbear" > /dev/null; then
        echo -e "${WHITE}🔧 Estado del servicio: ${GREEN}✅ EJECUTÁNDOSE${NC}"
    else
        echo -e "${WHITE}🔧 Estado del servicio: ${RED}❌ DETENIDO${NC}"
    fi
    
    read -p "Presiona Enter para continuar..."
}

# 👤 Crear usuarios temporales
create_user() {
    show_banner
    echo -e "${BOLD}${BLUE}👤 CREAR USUARIO TEMPORAL${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    read -p "👤 Ingrese el nombre de usuario: " username
    
    # Validar nombre de usuario
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}❌ Nombre de usuario inválido. Use solo letras, números, guiones y guiones bajos.${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}❌ El usuario '$username' ya existe${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    read -p "📅 Ingrese el número de días de validez: " days
    
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ]; then
        echo -e "${RED}❌ Número de días inválido${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    echo -e "${YELLOW}🔧 Creando usuario...${NC}"
    
    if useradd -m -s /bin/false -e $(date -d "+$days days" +%Y-%m-%d) "$username"; then
        echo -e "${YELLOW}🔒 Configure la contraseña para $username:${NC}"
        if passwd "$username"; then
            echo -e "${GREEN}✅ Usuario $username creado exitosamente${NC}"
            echo -e "${WHITE}📅 Expira en: ${YELLOW}$(date -d "+$days days" +%Y-%m-%d)${NC}"
        else
            echo -e "${RED}❌ Error al configurar la contraseña${NC}"
            userdel -r "$username" 2>/dev/null
        fi
    else
        echo -e "${RED}❌ Error al crear el usuario${NC}"
    fi
    
    read -p "Presiona Enter para continuar..."
}

# 📋 Listar usuarios
list_users() {
    show_banner
    echo -e "${BOLD}${BLUE}📋 LISTA DE USUARIOS${NC}"
    echo -e "${CYAN}═══════════════════════${NC}"
    echo ""
    
    echo -e "${WHITE}👥 Usuarios del sistema (UID >= 1000):${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    printf "%-15s %-15s %-20s %-10s\n" "USUARIO" "UID" "EXPIRACIÓN" "ESTADO"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    
    local found_users=false
    
    while IFS=: read -r username x uid gid gecos home shell; do
        if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
            found_users=true
            
            # Obtener fecha de expiración
            expiry=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
            
            if [ "$expiry" = "never" ]; then
                expiry_display="${GREEN}Never${NC}"
                status="${GREEN}✅ ACTIVO${NC}"
            else
                expiry_date=$(date -d "$expiry" +%Y-%m-%d 2>/dev/null || echo "N/A")
                if [ "$expiry_date" != "N/A" ] && [ $(date -d "$expiry_date" +%s) -lt $(date +%s) ]; then
                    expiry_display="${RED}$expiry_date${NC}"
                    status="${RED}❌ EXPIRADO${NC}"
                else
                    expiry_display="${YELLOW}$expiry_date${NC}"
                    status="${GREEN}✅ ACTIVO${NC}"
                fi
            fi
            
            printf "%-15s %-15s %-30s %-20s\n" "$username" "$uid" "$expiry_display" "$status"
        fi
    done < /etc/passwd
    
    if [ "$found_users" = false ]; then
        echo -e "${YELLOW}⚠️  No se encontraron usuarios regulares${NC}"
    fi
    
    read -p "Presiona Enter para continuar..."
}

# 📅 Extender días de usuario
extend_user_days() {
    show_banner
    echo -e "${BOLD}${BLUE}📅 EXTENDER DÍAS DE USUARIO${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    read -p "👤 Ingrese el nombre de usuario: " username
   
   if ! id "$username" >/dev/null 2>&1; then
       echo -e "${RED}❌ El usuario $username no existe${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   read -p "📅 Ingrese el número de días a añadir: " days
   
   if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ]; then
       echo -e "${RED}❌ Número de días inválido${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   current_expiry=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
   
   if [ "$current_expiry" = "never" ]; then
       new_expiry=$(date -d "+$days days" +%Y-%m-%d)
   else
       new_expiry=$(date -d "$current_expiry +$days days" +%Y-%m-%d 2>/dev/null)
       if [ $? -ne 0 ]; then
           echo -e "${RED}❌ Error al calcular la nueva fecha de expiración${NC}"
           read -p "Presiona Enter para continuar..."
           return
       fi
   fi
   
   if chage -E "$new_expiry" "$username"; then
       echo -e "${GREEN}✅ Se han añadido $days días a la cuenta de $username${NC}"
       echo -e "${WHITE}📅 Nueva fecha de expiración: ${YELLOW}$new_expiry${NC}"
   else
       echo -e "${RED}❌ Error al actualizar la fecha de expiración${NC}"
   fi
   
   read -p "Presiona Enter para continuar..."
}

# 📉 Reducir días de usuario
reduce_user_days() {
   show_banner
   echo -e "${BOLD}${BLUE}📉 REDUCIR DÍAS DE USUARIO${NC}"
   echo -e "${CYAN}══════════════════════════════${NC}"
   echo ""
   
   read -p "👤 Ingrese el nombre de usuario: " username
   
   if ! id "$username" >/dev/null 2>&1; then
       echo -e "${RED}❌ El usuario $username no existe${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   read -p "📅 Ingrese el número de días a reducir: " days
   
   if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ]; then
       echo -e "${RED}❌ Número de días inválido${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   current_expiry=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
   
   if [ "$current_expiry" = "never" ]; then
       echo -e "${YELLOW}⚠️  El usuario no tiene fecha de expiración establecida${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   new_expiry=$(date -d "$current_expiry -$days days" +%Y-%m-%d 2>/dev/null)
   if [ $? -ne 0 ]; then
       echo -e "${RED}❌ Error al calcular la nueva fecha de expiración${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   if chage -E "$new_expiry" "$username"; then
       echo -e "${GREEN}✅ Se han reducido $days días de la cuenta de $username${NC}"
       echo -e "${WHITE}📅 Nueva fecha de expiración: ${YELLOW}$new_expiry${NC}"
   else
       echo -e "${RED}❌ Error al actualizar la fecha de expiración${NC}"
   fi
   
   read -p "Presiona Enter para continuar..."
}

# 🔐 Actualizar contraseña de usuario
update_user_password() {
   show_banner
   echo -e "${BOLD}${BLUE}🔐 ACTUALIZAR CONTRASEÑA${NC}"
   echo -e "${CYAN}══════════════════════════${NC}"
   echo ""
   
   read -p "👤 Ingrese el nombre de usuario: " username
   
   if ! id "$username" >/dev/null 2>&1; then
       echo -e "${RED}❌ El usuario $username no existe${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   echo -e "${YELLOW}🔒 Configure la nueva contraseña para $username:${NC}"
   if passwd "$username"; then
       echo -e "${GREEN}✅ Contraseña actualizada exitosamente${NC}"
   else
       echo -e "${RED}❌ Error al actualizar la contraseña${NC}"
   fi
   
   read -p "Presiona Enter para continuar..."
}

# 🗑️ Eliminar usuario
delete_user() {
   show_banner
   echo -e "${BOLD}${BLUE}🗑️  ELIMINAR USUARIO${NC}"
   echo -e "${CYAN}════════════════════${NC}"
   echo ""
   
   read -p "👤 Ingrese el nombre de usuario a eliminar: " username
   
   if ! id "$username" >/dev/null 2>&1; then
       echo -e "${RED}❌ El usuario $username no existe${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   echo -e "${YELLOW}⚠️  ADVERTENCIA: Esta acción eliminará completamente al usuario y su directorio home${NC}"
   read -p "🗑️  ¿Está seguro que desea eliminar el usuario '$username'? (s/N): " confirm
   
   if [[ "$confirm" =~ ^[Ss]$ ]]; then
       if userdel -r "$username" 2>/dev/null; then
           echo -e "${GREEN}✅ Usuario $username eliminado exitosamente${NC}"
       else
           echo -e "${RED}❌ Error al eliminar el usuario${NC}"
       fi
   else
       echo -e "${YELLOW}❌ Operación cancelada${NC}"
   fi
   
   read -p "Presiona Enter para continuar..."
}

# 👥 Menu de gestión de usuarios
manage_users_menu() {
   while true; do
       show_banner
       echo -e "${BOLD}${BLUE}👥 GESTIÓN DE USUARIOS${NC}"
       echo -e "${CYAN}═══════════════════════${NC}"
       echo ""
       echo -e "${WHITE}📋 Seleccione una opción:${NC}"
       echo ""
       echo -e "  ${YELLOW}1.${NC} 👤 Crear usuario temporal"
       echo -e "  ${YELLOW}2.${NC} 📋 Listar usuarios"
       echo -e "  ${YELLOW}3.${NC} 📅 Extender días de existencia"
       echo -e "  ${YELLOW}4.${NC} 📉 Reducir días de existencia"
       echo -e "  ${YELLOW}5.${NC} 🔐 Actualizar contraseña"
       echo -e "  ${YELLOW}6.${NC} 🗑️  Eliminar usuario"
       echo -e "  ${YELLOW}7.${NC} 🔙 Volver al menú principal"
       echo ""
       echo -e "${CYAN}═══════════════════════════════════════${NC}"
       read -p "🔢 Seleccione una opción [1-7]: " option

       case $option in
           1) create_user ;;
           2) list_users ;;
           3) extend_user_days ;;
           4) reduce_user_days ;;
           5) update_user_password ;;
           6) delete_user ;;
           7) break ;;
           *) 
               echo -e "${RED}❌ Opción no válida${NC}"
               sleep 1
           ;;
       esac
   done
}

# 🔄 Función para actualizar el script
update_script() {
   show_banner
   echo -e "${BOLD}${BLUE}🔄 ACTUALIZAR SCRIPT${NC}"
   echo -e "${CYAN}═══════════════════${NC}"
   echo ""
   
   SCRIPT_URL="https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master/dropbear_manager.sh"
   CURRENT_SCRIPT="$0"
   
   echo -e "${YELLOW}🌐 Verificando actualizaciones...${NC}"
   
   # Descargar el nuevo script con indicador de progreso
   if curl -s --connect-timeout 10 "$SCRIPT_URL" -o "${CURRENT_SCRIPT}.tmp"; then
       if [ -s "${CURRENT_SCRIPT}.tmp" ]; then
           # Verificar si el archivo descargado es válido
           if head -1 "${CURRENT_SCRIPT}.tmp" | grep -q "^#!/bin/bash"; then
               chmod +x "${CURRENT_SCRIPT}.tmp"
               mv "${CURRENT_SCRIPT}.tmp" "$CURRENT_SCRIPT"
               
               echo -e "${GREEN}✅ Script actualizado exitosamente${NC}"
               echo -e "${YELLOW}🔄 Por favor, reinicie el script para usar la nueva versión${NC}"
               
               read -p "🔄 ¿Desea reiniciar el script ahora? (s/n): " restart_choice
               if [[ "$restart_choice" =~ ^[Ss]$ ]]; then
                   echo -e "${BLUE}🚀 Reiniciando script...${NC}"
                   exec "$CURRENT_SCRIPT"
               fi
           else
               echo -e "${RED}❌ El archivo descargado no es válido${NC}"
               rm -f "${CURRENT_SCRIPT}.tmp"
           fi
       else
           echo -e "${RED}❌ El archivo descargado está vacío${NC}"
           rm -f "${CURRENT_SCRIPT}.tmp"
       fi
   else
       echo -e "${RED}❌ Error al conectar con el servidor${NC}"
       echo -e "${YELLOW}💡 Verifique su conexión a internet${NC}"
   fi
   
   read -p "Presiona Enter para continuar..."
}

# 🗑️ Función para desinstalar
uninstall() {
   show_banner
   echo -e "${BOLD}${RED}🗑️  DESINSTALACIÓN${NC}"
   echo -e "${CYAN}═══════════════════${NC}"
   echo ""
   
   echo -e "${YELLOW}⚠️  ADVERTENCIA: Esta acción eliminará componentes del sistema${NC}"
   echo ""
   
   # Opción para desinstalar el script
   echo -e "${WHITE}🔧 Componentes a desinstalar:${NC}"
   echo ""
   read -p "🗑️  ¿Desea desinstalar el script Dropbear Manager? (s/n): " uninstall_script
   read -p "🗑️  ¿Desea desinstalar Dropbear completamente? (s/n): " uninstall_dropbear
   echo ""
   
   if [[ "$uninstall_script" =~ ^[Ss]$ ]]; then
       echo -e "${RED}🗑️  Desinstalando script...${NC}"
       
       # Eliminar el script
       if [ -f "/usr/local/bin/dropbear_manager.sh" ]; then
           rm -f "/usr/local/bin/dropbear_manager.sh"
           echo -e "${GREEN}✅ Script principal eliminado${NC}"
       fi
       
       # Eliminar enlace simbólico
       if [ -L "/usr/local/bin/dropbear-manager" ]; then
           rm -f "/usr/local/bin/dropbear-manager"
           echo -e "${GREEN}✅ Comando global eliminado${NC}"
       fi
   fi
   
   if [[ "$uninstall_dropbear" =~ ^[Ss]$ ]]; then
       echo -e "${RED}🗑️  Desinstalando Dropbear...${NC}"
       
       # Detener el servicio
       service dropbear stop > /dev/null 2>&1
       
       # Remover paquete
       apt-get remove --purge -y dropbear > /dev/null 2>&1
       apt-get autoremove -y > /dev/null 2>&1
       
       # Eliminar configuraciones
       rm -rf /etc/dropbear /etc/default/dropbear
       
       echo -e "${GREEN}✅ Dropbear desinstalado completamente${NC}"
   fi
   
   echo ""
   if [[ "$uninstall_script" =~ ^[Ss]$ ]] || [[ "$uninstall_dropbear" =~ ^[Ss]$ ]]; then
       echo -e "${GREEN}🎉 Desinstalación completada${NC}"
       
       if [[ "$uninstall_script" =~ ^[Ss]$ ]]; then
           echo -e "${YELLOW}👋 ¡Gracias por usar Dropbear Manager!${NC}"
           exit 0
       fi
   else
       echo -e "${YELLOW}❌ Operación cancelada${NC}"
   fi
   
   read -p "Presiona Enter para continuar..."
}

# 🐛 Función para habilitar la depuración en Dropbear
enable_debugging() {
   show_banner
   echo -e "${BOLD}${BLUE}🐛 DEPURACIÓN DE DROPBEAR${NC}"
   echo -e "${CYAN}═══════════════════════════${NC}"
   echo ""
   
   if ! command -v dropbear &> /dev/null; then
       echo -e "${RED}❌ Dropbear no está instalado${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   current_args=$(grep "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear | cut -d'"' -f2)
   
   if echo "$current_args" | grep -q "\-v"; then
       echo -e "${YELLOW}⚠️  La depuración ya está habilitada${NC}"
       read -p "🔄 ¿Desea deshabilitarla? (s/n): " disable_debug
       if [[ "$disable_debug" =~ ^[Ss]$ ]]; then
           new_args=$(echo "$current_args" | sed 's/-v//g' | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
           sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$new_args\"/" /etc/default/dropbear
           restart_dropbear
           echo -e "${GREEN}✅ Depuración deshabilitada${NC}"
       fi
   else
       echo -e "${YELLOW}🐛 Habilitando depuración verbosa...${NC}"
       new_args="$current_args -v"
       sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$new_args\"/" /etc/default/dropbear
       restart_dropbear
       echo -e "${GREEN}✅ Depuración habilitada${NC}"
       echo -e "${WHITE}📋 Use 'journalctl -f -u dropbear' para ver los logs en tiempo real${NC}"
   fi
   
   read -p "Presiona Enter para continuar..."
}

# 🔑 Función para verificar y convertir claves
verify_and_convert_keys() {
   show_banner
   echo -e "${BOLD}${BLUE}🔑 VERIFICAR CLAVES SSH${NC}"
   echo -e "${CYAN}══════════════════════${NC}"
   echo ""
   
   if ! command -v dropbear &> /dev/null; then
       echo -e "${RED}❌ Dropbear no está instalado${NC}"
       read -p "Presiona Enter para continuar..."
       return
   fi
   
   echo -e "${YELLOW}🔍 Verificando claves existentes...${NC}"
   
   local keys_checked=0
   local keys_ok=0
   
   # Verificar clave RSA
   if [ -f "/etc/dropbear/dropbear_rsa_host_key" ]; then
       keys_checked=$((keys_checked + 1))
       if [ -f "/etc/dropbear/dropbear_rsa_host_key.pub" ]; then
           echo -e "${GREEN}✅ Clave RSA encontrada${NC}"
           keys_ok=$((keys_ok + 1))
       else
           echo -e "${YELLOW}⚠️  Clave pública RSA faltante${NC}"
       fi
   fi
   
   # Verificar clave DSS
   if [ -f "/etc/dropbear/dropbear_dss_host_key" ]; then
       keys_checked=$((keys_checked + 1))
       if [ -f "/etc/dropbear/dropbear_dss_host_key.pub" ]; then
           echo -e "${GREEN}✅ Clave DSS encontrada${NC}"
           keys_ok=$((keys_ok + 1))
       else
           echo -e "${YELLOW}⚠️  Clave pública DSS faltante${NC}"
       fi
   fi
   
   # Verificar clave ECDSA
   if [ -f "/etc/dropbear/dropbear_ecdsa_host_key" ]; then
       keys_checked=$((keys_checked + 1))
       if [ -f "/etc/dropbear/dropbear_ecdsa_host_key.pub" ]; then
           echo -e "${GREEN}✅ Clave ECDSA encontrada${NC}"
           keys_ok=$((keys_ok + 1))
       else
           echo -e "${YELLOW}⚠️  Clave pública ECDSA faltante${NC}"
       fi
   fi
   
   if [ $keys_checked -eq 0 ]; then
       echo -e "${RED}❌ No se encontraron claves. Generando nuevas...${NC}"
       generate_keys
   elif [ $keys_ok -eq $keys_checked ]; then
       echo -e "${GREEN}✅ Todas las claves están correctas${NC}"
   else
       echo -e "${YELLOW}⚠️  Algunas claves necesitan reparación${NC}"
       read -p "🔧 ¿Desea regenerar las claves? (s/n): " regen_keys
       if [[ "$regen_keys" =~ ^[Ss]$ ]]; then
           generate_keys
       fi
   fi
   
   read -p "Presiona Enter para continuar..."
}

# 🔐 Función para generar claves si no existen
generate_keys() {
   echo -e "${YELLOW}🔐 Generando claves para Dropbear...${NC}"
   
   # Crear directorio si no existe
   mkdir -p /etc/dropbear
   
   # Generar clave RSA
   echo -e "${YELLOW}🔑 Generando clave RSA...${NC}"
   if dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1; then
       echo -e "${GREEN}✅ Clave RSA generada${NC}"
   else
       echo -e "${RED}❌ Error generando clave RSA${NC}"
   fi
   
   # Generar clave DSS
   echo -e "${YELLOW}🔑 Generando clave DSS...${NC}"
   if dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key > /dev/null 2>&1; then
       echo -e "${GREEN}✅ Clave DSS generada${NC}"
   else
       echo -e "${RED}❌ Error generando clave DSS${NC}"
   fi
   
   # Generar clave ECDSA
   echo -e "${YELLOW}🔑 Generando clave ECDSA...${NC}"
   if dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key > /dev/null 2>&1; then
       echo -e "${GREEN}✅ Clave ECDSA generada${NC}"
   else
       echo -e "${RED}❌ Error generando clave ECDSA${NC}"
   fi
   
   # Establecer permisos correctos
   chmod 600 /etc/dropbear/dropbear_*_host_key
   chmod 644 /etc/dropbear/dropbear_*_host_key.pub 2>/dev/null || true
   
   echo -e "${GREEN}✅ Generación de claves completada${NC}"
}

# 📊 Función para mostrar información del sistema
show_system_info() {
   show_banner
   echo -e "${BOLD}${BLUE}📊 INFORMACIÓN DEL SISTEMA${NC}"
   echo -e "${CYAN}═══════════════════════════════${NC}"
   echo ""
   
   # Información del servidor
   echo -e "${WHITE}🖥️  Información del Servidor:${NC}"
   echo -e "${CYAN}────────────────────────────────${NC}"
   echo -e "${WHITE}   🏷️  Hostname: ${YELLOW}$(hostname)${NC}"
   echo -e "${WHITE}   🐧 OS: ${YELLOW}$(lsb_release -d 2>/dev/null | cut -f2 || echo "$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)")${NC}"
   echo -e "${WHITE}   ⚡ Kernel: ${YELLOW}$(uname -r)${NC}"
   echo -e "${WHITE}   🏛️  Arquitectura: ${YELLOW}$(uname -m)${NC}"
   echo -e "${WHITE}   ⏰ Uptime: ${YELLOW}$(uptime -p)${NC}"
   
   echo ""
   
   # Estado de Dropbear
   echo -e "${WHITE}🔐 Estado de Dropbear:${NC}"
   echo -e "${CYAN}─────────────────────${NC}"
   if command -v dropbear &> /dev/null; then
       echo -e "${WHITE}   📦 Instalado: ${GREEN}✅ SÍ${NC}"
       
       if pgrep -x "dropbear" > /dev/null; then
           echo -e "${WHITE}   🔧 Estado: ${GREEN}✅ EJECUTÁNDOSE${NC}"
           echo -e "${WHITE}   👤 Procesos: ${YELLOW}$(pgrep -x "dropbear" | wc -l)${NC}"
       else
           echo -e "${WHITE}   🔧 Estado: ${RED}❌ DETENIDO${NC}"
       fi
       
       # Mostrar puertos configurados
       echo -e "${WHITE}   🔌 Puertos configurados:${NC}"
       show_ports_inline
   else
       echo -e "${WHITE}   📦 Instalado: ${RED}❌ NO${NC}"
   fi
   
   echo ""
   
   # Recursos del sistema
   echo -e "${WHITE}💻 Recursos del Sistema:${NC}"
   echo -e "${CYAN}─────────────────────────${NC}"
   
   # CPU
   local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
   echo -e "${WHITE}   🔥 CPU: ${YELLOW}${cpu_usage}% usado${NC}"
   
   # Memoria
   local mem_info=$(free -h | grep "Mem:")
   local mem_used=$(echo $mem_info | awk '{print $3}')
   local mem_total=$(echo $mem_info | awk '{print $2}')
   echo -e "${WHITE}   🧠 RAM: ${YELLOW}${mem_used}/${mem_total} usado${NC}"
   
   # Espacio en disco
   local disk_info=$(df -h / | tail -1)
   local disk_used=$(echo $disk_info | awk '{print $3}')
   local disk_total=$(echo $disk_info | awk '{print $2}')
   local disk_percent=$(echo $disk_info | awk '{print $5}')
   echo -e "${WHITE}   💾 Disco: ${YELLOW}${disk_used}/${disk_total} (${disk_percent}) usado${NC}"
   
   echo ""
   
   # Conexiones activas
   echo -e "${WHITE}🌐 Conexiones SSH Activas:${NC}"
   echo -e "${CYAN}───────────────────────────${NC}"
   local ssh_connections=$(netstat -tn 2>/dev/null | grep ":22\|:$(grep DROPBEAR_PORT /etc/default/dropbear 2>/dev/null | cut -d'=' -f2)" | grep ESTABLISHED | wc -l)
   echo -e "${WHITE}   📊 Conexiones activas: ${YELLOW}${ssh_connections}${NC}"
   
   read -p "Presiona Enter para continuar..."
}

# 📋 Función principal del menú
main_menu() {
   # Verificar root al inicio
   check_root
   
   # Verificar dependencias
   check_dependencies
   
   while true; do
       show_banner
       echo -e "${WHITE}🚀 Bienvenido a Dropbear Manager v2.0${NC}"
       echo -e "${CYAN}═══════════════════════════════════════${NC}"
       echo ""
       echo -e "${WHITE}📋 Seleccione una opción:${NC}"
       echo ""
       echo -e "  ${YELLOW} 1.${NC} 📥 Instalar Dropbear"
       echo -e "  ${YELLOW} 2.${NC} 🔓 Abrir puertos adicionales"
       echo -e "  ${YELLOW} 3.${NC} 🔒 Cerrar puertos"
       echo -e "  ${YELLOW} 4.${NC} 📊 Mostrar puertos configurados"
       echo -e "  ${YELLOW} 5.${NC} 👥 Gestionar usuarios"
       echo -e "  ${YELLOW} 6.${NC} 🔄 Actualizar script"
       echo -e "  ${YELLOW} 7.${NC} 🧹 Limpiar configuración"
       echo -e "  ${YELLOW} 8.${NC} 📊 Información del sistema"
       echo -e "  ${YELLOW} 9.${NC} 🐛 Habilitar/Deshabilitar depuración"
       echo -e "  ${YELLOW}10.${NC} 🔑 Verificar y generar claves"
       echo -e "  ${YELLOW}11.${NC} 🗑️  Desinstalar"
       echo -e "  ${YELLOW}12.${NC} 🚪 Salir"
       echo ""
       echo -e "${CYAN}═══════════════════════════════════════${NC}"
       read -p "🔢 Seleccione una opción [1-12]: " choice

       case $choice in
           1) install_dropbear ;;
           2) open_ports ;;
           3) close_port ;;
           4) show_ports ;;
           5) manage_users_menu ;;
           6) update_script ;;
           7) 
               clean_dropbear_config
               echo -e "${GREEN}✅ Configuración limpiada exitosamente${NC}"
               read -p "Presiona Enter para continuar..."
           ;;
           8) show_system_info ;;
           9) enable_debugging ;;
           10) 
               verify_and_convert_keys
               generate_keys
           ;;
           11) uninstall ;;
           12) 
               echo -e "${GREEN}👋 ¡Gracias por usar Dropbear Manager!${NC}"
               exit 0 
           ;;
           *) 
               echo -e "${RED}❌ Opción no válida. Por favor seleccione un número del 1 al 12.${NC}"
               sleep 2
           ;;
       esac
   done
}

# 🚀 Ejecutar el programa principal
main_menu
