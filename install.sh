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

# 🎯 Definir variables globales
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

# 📦 Función para instalar dependencias
install_dependencies() {
    echo -e "${YELLOW}📦 Instalando dependencias necesarias...${NC}"
    apt-get update > /dev/null 2>&1
    apt-get install -y curl wget net-tools lsof > /dev/null 2>&1
    echo -e "${GREEN}✅ Dependencias instaladas correctamente${NC}"
}

# 🔧 Función principal de instalación (sin reejecutar)
main_install() {
    show_banner
    
    # 🔍 Verificar si se está ejecutando como root
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
        echo -e "${YELLOW}💡 Ejecute el comando completo con sudo:${NC}"
        echo -e "   ${WHITE}curl -sSL https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master/install.sh | sudo bash${NC}"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}✅ Ejecutándose con permisos de administrador${NC}"
    echo ""
    
    # 📦 Instalar dependencias
    install_dependencies
    
    # 📁 Verificar y crear directorio de instalación
    echo -e "${YELLOW}📁 Preparando directorio de instalación...${NC}"
    
    if [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR="/usr/local/bin"
    fi
    
    if [ ! -d "$INSTALL_DIR" ]; then
        if mkdir -p "$INSTALL_DIR"; then
            echo -e "${GREEN}✅ Directorio $INSTALL_DIR creado${NC}"
        else
            echo -e "${RED}❌ Error al crear directorio $INSTALL_DIR${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Directorio $INSTALL_DIR ya existe${NC}"
    fi
    
    # 🌐 Descargar el script principal
    echo -e "${YELLOW}🌐 Descargando script principal...${NC}"
    
    local temp_file="/tmp/dropbear_manager_temp.sh"
    local script_url="${GITHUB_RAW_URL}/${SCRIPT_NAME}"
    
    echo -e "${WHITE}📡 URL: $script_url${NC}"
    
    # Limpiar archivo temporal si existe
    rm -f "$temp_file"
    
    # Descargar con timeout y verificación
    if curl -sSL --connect-timeout 30 --max-time 120 "$script_url" -o "$temp_file"; then
        # Verificar que el archivo se descargó correctamente
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            # Verificar que es un script bash válido
            if head -1 "$temp_file" | grep -q "#!/bin/bash"; then
                # Mover al directorio final
                if mv "$temp_file" "$INSTALL_DIR/$SCRIPT_NAME"; then
                    echo -e "${GREEN}✅ Script descargado exitosamente${NC}"
                else
                    echo -e "${RED}❌ Error al mover script a directorio final${NC}"
                    rm -f "$temp_file"
                    exit 1
                fi
            else
                echo -e "${RED}❌ El archivo descargado no es un script bash válido${NC}"
                echo -e "${YELLOW}🔍 Contenido del archivo:${NC}"
                head -5 "$temp_file" 2>/dev/null || echo "No se puede leer el archivo"
                rm -f "$temp_file"
                exit 1
            fi
        else
            echo -e "${RED}❌ El archivo descargado está vacío o no existe${NC}"
            rm -f "$temp_file"
            exit 1
        fi
    else
        echo -e "${RED}❌ Error al descargar script desde GitHub${NC}"
        echo -e "${YELLOW}🔍 Verificando conectividad...${NC}"
        
        if curl -sSL --connect-timeout 10 "https://google.com" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Conexión a internet disponible${NC}"
            echo -e "${RED}❌ Problema específico con GitHub o el repositorio${NC}"
            echo -e "${YELLOW}💡 Verifique que el repositorio existe y es público${NC}"
        else
            echo -e "${RED}❌ Sin conexión a internet${NC}"
            echo -e "${YELLOW}💡 Verifique su conexión de red${NC}"
        fi
        
        rm -f "$temp_file"
        exit 1
    fi
    
    # 🔐 Configurar permisos
    echo -e "${YELLOW}🔐 Configurando permisos de ejecución...${NC}"
    if chmod +x "$INSTALL_DIR/$SCRIPT_NAME"; then
        echo -e "${GREEN}✅ Permisos configurados correctamente${NC}"
    else
        echo -e "${RED}❌ Error al configurar permisos${NC}"
        exit 1
    fi
    
    # 🔗 Crear enlace simbólico
    echo -e "${YELLOW}🔗 Creando comando global 'dropbear-manager'...${NC}"
    
    # Eliminar enlace anterior si existe
    rm -f "/usr/local/bin/dropbear-manager"
    
    if ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "/usr/local/bin/dropbear-manager"; then
        echo -e "${GREEN}✅ Comando global creado exitosamente${NC}"
    else
        echo -e "${YELLOW}⚠️  No se pudo crear enlace simbólico, pero el script está disponible${NC}"
    fi
    
    # 🧪 Verificar instalación
    echo -e "${YELLOW}🧪 Verificando instalación...${NC}"
    
    # Verificar archivo principal
    if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ] && [ -x "$INSTALL_DIR/$SCRIPT_NAME" ]; then
        echo -e "${GREEN}✅ Script principal instalado correctamente${NC}"
    else
        echo -e "${RED}❌ Error: Script principal no está disponible${NC}"
        exit 1
    fi
    
    # Verificar comando global
    if command -v dropbear-manager &> /dev/null; then
        echo -e "${GREEN}✅ Comando global 'dropbear-manager' disponible${NC}"
    else
        echo -e "${YELLOW}⚠️  Comando global no disponible, use ruta completa${NC}"
    fi
    
    # 🎉 Mensaje de éxito
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    🎉 INSTALACIÓN COMPLETADA                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 📋 Información de uso
    echo -e "${WHITE}📋 INFORMACIÓN DE USO:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}🚀 Formas de ejecutar Dropbear Manager:${NC}"
    echo ""
    
    if command -v dropbear-manager &> /dev/null; then
        echo -e "   ${GREEN}✅ dropbear-manager${NC}           - Comando directo (requiere sudo para operaciones)"
        echo -e "   ${GREEN}✅ sudo dropbear-manager${NC}      - Comando con permisos completos"
    else
        echo -e "   ${YELLOW}⚠️  sudo $INSTALL_DIR/$SCRIPT_NAME${NC}  - Ruta completa"
    fi
    
    echo ""
    echo -e "${WHITE}📂 Archivos instalados:${NC}"
    echo -e "   📄 Script principal: ${YELLOW}$INSTALL_DIR/$SCRIPT_NAME${NC}"
    if [ -L "/usr/local/bin/dropbear-manager" ]; then
        echo -e "   🔗 Enlace simbólico: ${YELLOW}/usr/local/bin/dropbear-manager${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}🔧 Próximos pasos:${NC}"
    echo -e "   1️⃣  Ejecutar Dropbear Manager"
    echo -e "   2️⃣  Instalar Dropbear SSH server"
    echo -e "   3️⃣  Configurar puertos y usuarios"
    echo ""
    
    # ❓ Preguntar si ejecutar ahora
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    read -p "🚀 ¿Desea ejecutar Dropbear Manager ahora? (s/N): " run_now
    
    if [[ "$run_now" =~ ^[Ss]$ ]]; then
        echo ""
        echo -e "${BLUE}🚀 Iniciando Dropbear Manager...${NC}"
        echo ""
        sleep 1
        
        # Ejecutar el script
        if [ -x "$INSTALL_DIR/$SCRIPT_NAME" ]; then
            "$INSTALL_DIR/$SCRIPT_NAME"
        else
            echo -e "${RED}❌ Error al ejecutar script${NC}"
        fi
    else
        echo ""
        echo -e "${GREEN}✅ Instalación completada${NC}"
        echo -e "${YELLOW}💡 Ejecute 'sudo dropbear-manager' cuando esté listo${NC}"
        echo ""
    fi
}

# 🎯 Punto de entrada principal
main_install
