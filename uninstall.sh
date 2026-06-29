#!/usr/bin/env bash
# Caelestia Web Wallpaper - Script de desinstalación
# Elimina los módulos de wallpapers online (Wallhaven + UHDPaper) de tu configuración de Caelestia
# Detecta automáticamente si Caelestia está en el sistema (/etc/xdg) o en el usuario (~/.config)

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directorio del script (de donde se ejecuta)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detectar dónde está Caelestia
SYSTEM_DIR="/etc/xdg/quickshell/caelestia"
USER_DIR="$HOME/.config/quickshell/caelestia"

detect_caelestia() {
    # Si el usuario forzó CAELESTIA_DIR, usarlo
    if [ -n "${CAELESTIA_DIR:-}" ]; then
        USE_SUDO=0
        return
    fi

    # Priorizar: si hay config de usuario, usarla (sin sudo)
    if [ -d "$USER_DIR" ]; then
        CAELESTIA_DIR="$USER_DIR"
        USE_SUDO=0
        info "Detectada configuración de usuario en $USER_DIR"
        return
    fi

    # Si no hay config de usuario pero sí la del sistema, usar la del sistema (con sudo)
    if [ -d "$SYSTEM_DIR" ]; then
        CAELESTIA_DIR="$SYSTEM_DIR"
        USE_SUDO=1
        info "Detectada instalación del sistema en $SYSTEM_DIR (se usará sudo)"
        return
    fi

    # No encontrado
    error "No se encontró Caelestia en ninguna ubicación conocida"
}

# Comando wrapper para sudo
run_cmd() {
    if [ "$USE_SUDO" = "1" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

run_rm() {
    if [ "$USE_SUDO" = "1" ]; then
        sudo rm "$@"
    else
        rm "$@"
    fi
}

run_rm_rf() {
    if [ "$USE_SUDO" = "1" ]; then
        sudo rm -rf "$@"
    else
        rm -rf "$@"
    fi
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$FORCE" = "1" ]; then
        return 0
    fi
    
    if [ "$default" = "y" ]; then
        read -p "$(echo -e "${YELLOW}$prompt [Y/n]: ${NC}")" -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        read -p "$(echo -e "${YELLOW}$prompt [y/N]: ${NC}")" -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

check_installation() {
    info "Verificando archivos instalados..."
    
    local found=0
    
    # Scripts
    if [ -d "$SCRIPTS_DIR" ]; then
        found=1
        info "Scripts encontrados en $SCRIPTS_DIR"
    fi
    
    # Servicios nuevos
    for service in WallhavenService.qml UhdService.qml; do
        if [ -f "$SERVICES_DIR/$service" ]; then
            found=1
            info "Servicio encontrado: $service"
        fi
    done
    
    # Módulos nuevos
    for module in OnlineWallpapers.qml; do
        if [ -f "$MODULES_DIR/pages/wallandstyle/$module" ]; then
            found=1
            info "Módulo encontrado: $module"
        fi
    done
    
    if [ -f "$MODULES_DIR/common/WallItemOnline.qml" ]; then
        found=1
        info "Módulo encontrado: WallItemOnline.qml"
    fi
    
    if [ "$found" = "0" ]; then
        warn "No se encontraron archivos de Web Wallpaper instalados"
    fi
}

uninstall_scripts() {
    info "Eliminando scripts de wallpapers online..."
    
    if [ -d "$SCRIPTS_DIR" ]; then
        run_rm_rf "$SCRIPTS_DIR"
        success "Scripts eliminados: $SCRIPTS_DIR"
    else
        debug "Scripts no encontrados, saltando"
    fi
}

uninstall_services() {
    info "Eliminando servicios QML..."
    
    # Solo eliminar servicios que NOSOTROS instalamos (Wallpapers.qml es original)
    for service in WallhavenService.qml UhdService.qml; do
        if [ -f "$SERVICES_DIR/$service" ]; then
            run_rm "$SERVICES_DIR/$service"
            success "$service eliminado"
        fi
    done
    
    # Wallpapers.qml es original - NO eliminar
    if [ -f "$SERVICES_DIR/Wallpapers.qml" ]; then
        debug "Wallpapers.qml es original, no se elimina"
    fi
}

uninstall_modules() {
    info "Eliminando módulos QML..."
    
    # Limpiar referencias a OnlineWallpapers en PageCompRegistry.qml
    if [ -f "$MODULES_DIR/PageCompRegistry.qml" ]; then
        if grep -q "OnlineWallpapers" "$MODULES_DIR/PageCompRegistry.qml" 2>/dev/null; then
            info "Limpiando referencias en PageCompRegistry.qml..."
            # Eliminar componentes OnlineWallpapers (bloques de 3 líneas)
            run_cmd sed -i '/Component {/,/[[:space:]]*}/{
                /OnlineWallpapers/{
                    N
                    N
                    /OnlineWallpapers.*\n.*\n.*}/d
                }
            }' "$MODULES_DIR/PageCompRegistry.qml"
            # También limpiar líneas sueltas
            run_cmd sed -i '/^[[:space:]]*Component {$/{
                N
                /OnlineWallpapers/{
                    N
                    N
                    d
                }
            }' "$MODULES_DIR/PageCompRegistry.qml"
            success "PageCompRegistry.qml limpiado"
        fi
    fi
    
    # Limpiar botón "Online" en WallpaperAndStyle.qml
    if [ -f "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml" ]; then
        if grep -q "Online" "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml" 2>/dev/null; then
            if grep -q "openSubPage(4)" "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml" 2>/dev/null; then
                info "Limpiando botón Online en WallpaperAndStyle.qml..."
                # Eliminar el botón Online (IconTextButton con openSubPage(4))
                run_cmd sed -i '/IconTextButton {/,/openSubPage(4)/{
                    /openSubPage(4)/{
                        N
                        N
                        N
                        N
                        N
                        N
                        N
                        N
                        d
                    }
                }' "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml"
                success "WallpaperAndStyle.qml limpiado"
            fi
        fi
    fi
    
    # Eliminar archivos nuevos
    local new_files=(
        "$MODULES_DIR/pages/wallandstyle/OnlineWallpapers.qml"
        "$MODULES_DIR/common/WallItemOnline.qml"
    )
    
    for file in "${new_files[@]}"; do
        if [ -f "$file" ]; then
            run_rm "$file"
            success "$(basename "$file") eliminado"
        fi
    done
}

uninstall_config() {
    info "Eliminando configuración de Wallhaven..."
    
    local config_dir="$HOME/.config/caelestia/wallhaven"
    if [ -d "$config_dir" ]; then
        if confirm "¿Eliminar configuración de Wallhaven ($config_dir)?" "n"; then
            run_rm_rf "$config_dir"
            success "Configuración eliminada"
        else
            warn "Configuración conservada en $config_dir"
        fi
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Desinstalación completada            ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Ubicación: $CAELESTIA_DIR"
    echo ""
    echo "Archivos eliminados:"
    echo "  - Scripts: $SCRIPTS_DIR/"
    echo "  - Servicios: WallhavenService.qml, UhdService.qml"
    echo "  - Módulos: OnlineWallpapers.qml, WallItemOnline.qml"
    echo "  - Referencias limpiadas en PageCompRegistry.qml y WallpaperAndStyle.qml"
    echo ""
    echo "Reinicia Caelestia para aplicar los cambios."
    echo ""
}

# Parse arguments
FORCE=0
SKIP_CONFIRM=0
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=1
            SKIP_CONFIRM=1
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  -f, --force    No pedir confirmación"
            echo "  -h, --help     Mostrar esta ayuda"
            echo ""
            echo "Variables de entorno:"
            echo "  CAELESTIA_DIR  Directorio de Caelestia (auto-detecta si no se especifica)"
            exit 0
            ;;
        *)
            error "Opción desconocida: $1"
            ;;
    esac
done

# Detectar ubicación de Caelestia
detect_caelestia

# Asignar variables de rutas después de detectar
SCRIPTS_DIR="$CAELESTIA_DIR/scripts/webWallpaper"
SERVICES_DIR="$CAELESTIA_DIR/services"
MODULES_DIR="$CAELESTIA_DIR/modules/nexus"

# Main
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Caelestia Web Wallpaper Uninstaller   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

check_installation

echo ""
if ! confirm "¿Desinstalar Web Wallpaper de Caelestia?" "n"; then
    warn "Desinstalación cancelada"
    exit 0
fi

echo ""
uninstall_scripts
uninstall_services
uninstall_modules
uninstall_config
print_summary
