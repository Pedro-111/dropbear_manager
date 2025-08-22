#!/bin/bash

# 🎨 Colores y símbolos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 🎯 Definir variables
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="dropbear_manager.sh"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master"

# 🎯 Banner del programa
show_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               🚀 INSTALADOR DROPBEAR MANAGER             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 🔧 Función para ejecutar comandos como root
run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 📦 Función para instalar dependencias
install_dependencies() {
    echo -e "${YELLOW}📦 Instalando dependencias necesarias...${NC}"
    run_as_root apt-get update > /dev/null 2>&1
    run_as_root apt-get install -y curl wget net-tools lsof > /dev/null 2>&1
    echo -e "${GREEN}✅ Dependencias instaladas correctamente${NC}"
}

# 🔍 Verificar si se está ejecutando como root para la instalación
check_root_and_rerun() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${YELLOW}⚠️  Este instalador necesita permisos de administrador${NC}"
        echo -e "${BLUE}🔄 Reejecutando con sudo...${NC}"
        
        # Verificar si sudo está disponible
        if ! command -v sudo &> /dev/null; then
            echo -e "${RED}❌ sudo no está disponible. Por favor ejecute como root${NC}"
            exit 1
        fi
        
        # Reejecutar el script completo con sudo, pasando todas las funciones
        exec sudo bash -c "$(curl -sSL https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master/install.sh)"
    fi
}

# Función principal de instalación
main_install() {
    show_banner
    
    # 🔍 Verificar permisos de root
    check_root_and_rerun
    
    # 📦 Instalar dependencias
    install_dependencies
    
    # 📁 Crear el directorio de instalación si no existe
    echo -e "${YELLOW}📁 Creando directorio de instalación...${NC}"
    if ! mkdir -p "$INSTALL_DIR"; then
        echo -e "${RED}❌ Error al crear directorio de instalación${NC}"
        exit 1
    fi
    
    # 🌐 Descargar el script
    echo -e "${YELLOW}🌐 Descargando $SCRIPT_NAME desde GitHub...${NC}"
    
    # Mostrar progreso de descarga
    local temp_file=$(mktemp)
    if curl -sSL --connect-timeout 15 --max-time 60 "$GITHUB_RAW_URL/$SCRIPT_NAME" -o "$temp_file"; then
        # Verificar que el archivo descargado sea válido
        if [ -s "$temp_file" ] && head -1 "$temp_file" | grep -q "^#!/bin/bash"; then
            mv "$temp_file" "$INSTALL_DIR/$SCRIPT_NAME"
            echo -e "${GREEN}✅ Script descargado correctamente${NC}"
        else
            echo -e "${RED}❌ El archivo descargado no es válido${NC}"
            rm -f "$temp_file"
            exit 1
        fi
    else
        echo -e "${RED}❌ Error al descargar el script desde GitHub${NC}"
        echo -e "${YELLOW}💡 Verificando conectividad...${NC}"
        
        if ping -c 1 google.com > /dev/null 2>&1; then
            echo -e "${YELLOW}✅ Conexión a internet disponible${NC}"
            echo -e "${RED}❌ Problema con el repositorio de GitHub${NC}"
        else
            echo -e "${RED}❌ Sin conexión a internet${NC}"
        fi
        
        rm -f "$temp_file"
        exit 1
    fi
    
    # 🔐 Hacer el script ejecutable
    echo -e "${YELLOW}🔐 Configurando permisos de ejecución...${NC}"
    if ! chmod +x "$INSTALL_DIR/$SCRIPT_NAME"; then
        echo -e "${RED}❌ Error al configurar permisos${NC}"
        exit 1
    fi
    
    # 🔗 Crear enlace simbólico para acceso global
    echo -e "${YELLOW}🔗 Creando comando global...${NC}"
    if ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "/usr/local/bin/dropbear-manager"; then
        echo -e "${GREEN}✅ Comando global creado exitosamente${NC}"
    else
        echo -e "${RED}❌ Error al crear comando global${NC}"
        exit 1
    fi
    
    # 🧪 Probar la instalación
    echo -e "${YELLOW}🧪 Probando la instalación...${NC}"
    if command -v dropbear-manager &> /dev/null; then
        echo -e "${GREEN}✅ Instalación verificada correctamente${NC}"
    else
        echo -e "${RED}❌ Error en la verificación de instalación${NC}"
        exit 1
    fi
    
    # 🎉 Mostrar mensaje de éxito
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  🎉 INSTALACIÓN EXITOSA                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}📋 Información de uso:${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    echo -e "   ${CYAN}dropbear-manager${NC}      - Ver menú (requiere sudo para operaciones)"
    echo -e "   ${CYAN}sudo dropbear-manager${NC} - Ejecutar con permisos completos"
    echo ""
    echo -e "${WHITE}📍 Ubicación del script: ${YELLOW}$INSTALL_DIR/$SCRIPT_NAME${NC}"
    echo -e "${WHITE}🔗 Comando instalado en: ${YELLOW}/usr/local/bin/dropbear-manager${NC}"
    echo ""
    echo -e "${GREEN}🚀 ¡Ya puedes ejecutar 'sudo dropbear-manager' desde cualquier directorio!${NC}"
    echo ""
    
    # Preguntar si desea ejecutar el script ahora
    read -p "🚀 ¿Desea ejecutar Dropbear Manager ahora? (s/n): " run_now
    if [[ "$run_now" =~ ^[Ss]$ ]]; then
        echo -e "${BLUE}🚀 Iniciando Dropbear Manager...${NC}"
        "$INSTALL_DIR/$SCRIPT_NAME"
    fi
}

# Ejecutar instalación principal
main_install
