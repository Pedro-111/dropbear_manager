#!/bin/bash

# Función para ejecutar comandos como root
run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Definir variables
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="dropbear_manager.sh"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master"

# Función para instalar dependencias
install_dependencies() {
    run_as_root apt-get update
    run_as_root apt-get install -y curl wget net-tools
}

# Instalar dependencias
install_dependencies

# Crear el directorio de instalación si no existe
mkdir -p "$INSTALL_DIR"

# Descargar el script
echo "Descargando $SCRIPT_NAME..."
curl -sSL "$GITHUB_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"

# Hacer el script ejecutable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Agregar el directorio al PATH si no está ya
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.bashrc"
    echo "Se ha añadido $INSTALL_DIR a su PATH."
fi

# Crear un alias
echo "alias dropbear-manager='$INSTALL_DIR/$SCRIPT_NAME'" >> "$HOME/.bashrc"

# Aplicar los cambios inmediatamente
source "$HOME/.bashrc"

echo "Instalación completada. El comando 'dropbear-manager' está ahora disponible."
echo "Puede ejecutar 'dropbear-manager' en cualquier momento para gestionar Dropbear."
