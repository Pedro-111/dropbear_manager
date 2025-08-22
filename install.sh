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

# 🔧 Función para ejecutar comandos como root
run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 🎯 Definir variables
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="dropbear_manager.sh"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║               🚀 INSTALADOR DROPBEAR MANAGER             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# 📦 Función para instalar dependencias
install_dependencies() {
    echo -e "${YELLOW}📦 Instalando dependencias necesarias...${NC}"
    run_as_root apt-get update > /dev/null 2>&1
    run_as_root apt-get install -y curl wget net-tools lsof > /dev/null 2>&1
    echo -e "${GREEN}✅ Dependencias instaladas correctamente${NC}"
}

# 🔍 Verificar si se está ejecutando como root para la instalación
if [ "$(id -u)" != "0" ]; then
    echo -e "${YELLOW}⚠️  Este instalador necesita permisos de administrador${NC}"
    echo -e "${BLUE}🔄 Reejecutando con sudo...${NC}"
    exec sudo "$0" "$@"
fi

# 📦 Instalar dependencias
install_dependencies

# 📁 Crear el directorio de instalación si no existe
echo -e "${YELLOW}📁 Creando directorio de instalación...${NC}"
mkdir -p "$INSTALL_DIR"

# 🌐 Descargar el script
echo -e "${YELLOW}🌐 Descargando $SCRIPT_NAME desde GitHub...${NC}"
if curl -sSL "$GITHUB_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo -e "${GREEN}✅ Script descargado correctamente${NC}"
else
    echo -e "${RED}❌ Error al descargar el script${NC}"
    exit 1
fi

# 🔐 Hacer el script ejecutable
echo -e "${YELLOW}🔐 Configurando permisos de ejecución...${NC}"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# 🔗 Crear enlace simbólico para acceso global
echo -e "${YELLOW}🔗 Creando comando global...${NC}"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "/usr/local/bin/dropbear-manager"

echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  🎉 INSTALACIÓN EXITOSA                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}📋 Uso:${NC}"
echo -e "   ${CYAN}dropbear-manager${NC} - Ejecutar como usuario normal"
echo -e "   ${CYAN}sudo dropbear-manager${NC} - Ejecutar con permisos de administrador"
echo ""
echo -e "${WHITE}📍 El script se ha instalado en: ${YELLOW}$INSTALL_DIR/$SCRIPT_NAME${NC}"
echo -e "${GREEN}🚀 ¡Puedes ejecutar 'dropbear-manager' desde cualquier directorio!${NC}"
