
# Dropbear Manager

## Descripción

Dropbear Manager es un script de bash diseñado para simplificar la gestión de Dropbear SSH en sistemas Ubuntu. Ofrece una interfaz de línea de comandos fácil de usar para realizar tareas comunes como:

- Instalación de Dropbear
- Configuración de puertos
- Gestión de usuarios
- Actualización del script
- Desinstalación

## Características Principales

- 🔒 Instalación sencilla de Dropbear
- 🚪 Gestión de puertos (abrir, cerrar, mostrar)
- 👥 Creación y administración de usuarios temporales
- 🔄 Actualización automática del script
- 🧹 Limpieza de configuración
- 🗑️ Desinstalación completa

## Requisitos

- Sistema operativo: Ubuntu (probado en versiones recientes)
- Permisos de administrador (sudo)
- Conexión a Internet

## Instalación

### Método Automático

```bash
curl -sSL https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master/install.sh | sudo bash
```

### Método Manual

1. Actualizar dependencias:
```bash
sudo apt-get update
sudo apt-get install -y curl wget net-tools
```

2. Crear directorio de instalación:
```bash
mkdir -p "$HOME/.local/bin"
```

3. Descargar script:
```bash
curl -sSL https://raw.githubusercontent.com/Pedro-111/dropbear_manager/master/dropbear_manager.sh -o "$HOME/.local/bin/dropbear_manager.sh"
```

4. Hacer ejecutable:
```bash
chmod +x "$HOME/.local/bin/dropbear_manager.sh"
```

5. Configurar PATH y alias:
```bash
echo "export PATH=\"\$PATH:$HOME/.local/bin\"" >> "$HOME/.bashrc"
echo "alias dropbear-manager='$HOME/.local/bin/dropbear_manager.sh'" >> "$HOME/.bashrc"
```

6. Aplicar cambios:
```bash
source "$HOME/.bashrc"
```

## Uso

Después de la instalación, puedes ejecutar el script de dos formas:

1. Mediante el alias:
```bash
dropbear-manager
```

2. Directamente:
```bash
$HOME/.local/bin/dropbear_manager.sh
```

## Menú Principal

1. Instalar Dropbear
2. Abrir puertos adicionales
3. Cerrar puertos
4. Mostrar puertos en uso
5. Gestionar usuarios
6. Actualizar script
7. Limpiar configuración de Dropbear
8. Desinstalar
9. Salir

## Gestión de Usuarios

El script permite:
- Crear usuarios temporales
- Listar usuarios
- Ampliar/reducir días de existencia
- Actualizar contraseñas
- Eliminar usuarios

## Advertencia

- Requiere precaución al modificar configuraciones de red
- Siempre haga una copia de seguridad antes de cambios importantes
- Ejecute con permisos de administrador

## Contribuciones

Las contribuciones son bienvenidas. Por favor, abra un issue o envíe un pull request en el repositorio de GitHub.

## Autor

[Nombre del autor original: Pedro-111]

## Soporte

Si encuentra algún problema, por favor abra un issue en el repositorio de GitHub.
