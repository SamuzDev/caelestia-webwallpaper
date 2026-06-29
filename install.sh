#!/usr/bin/env bash
# Caelestia Web Wallpaper - Script de instalación
# Instala los módulos de wallpapers online (Wallhaven + UHDPaper) en tu configuración de Caelestia
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

    # Si no existe ninguno, crear en el usuario (sin sudo)
    CAELESTIA_DIR="$USER_DIR"
    USE_SUDO=0
    warn "No se encontró Caelestia. Creando configuración en $USER_DIR"
}

# Comando wrapper para sudo
run_cmd() {
    if [ "$USE_SUDO" = "1" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

run_mkdir() {
    if [ "$USE_SUDO" = "1" ]; then
        sudo mkdir -p "$@"
    else
        mkdir -p "$@"
    fi
}

run_cp() {
    if [ "$USE_SUDO" = "1" ]; then
        sudo cp "$@"
    else
        cp "$@"
    fi
}

run_chmod() {
    if [ "$USE_SUDO" = "1" ]; then
        sudo chmod "$@"
    else
        chmod "$@"
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

check_deps() {
    info "Verificando dependencias..."

    if ! command -v python3 &> /dev/null; then
        error "Python3 no encontrado. Instálalo primero."
    fi
    success "Python3: $(python3 --version)"

    if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
        warn "pip3 no encontrado. Intentando instalar dependencias manualmente..."
    fi

    if ! command -v curl &> /dev/null; then
        error "curl no encontrado. Instálalo primero."
    fi
    success "curl encontrado"

    if [ ! -d "$CAELESTIA_DIR" ]; then
        info "Creando directorio de Caelestia: $CAELESTIA_DIR"
        run_mkdir -p "$CAELESTIA_DIR"
    fi
    success "Directorio de Caelestia: $CAELESTIA_DIR"

    if [ "$USE_SUDO" = "1" ]; then
        info "Modo: Instalación del sistema (sudo)"
    else
        info "Modo: Instalación de usuario (sin sudo)"
    fi
}

install_python_deps() {
    info "Instalando dependencias de Python..."

    local pkgs=("python-requests" "python-beautifulsoup4" "python-lxml")
    local pip_pkgs=("requests" "beautifulsoup4" "lxml")

    # Detectar package manager del sistema
    if command -v pacman &> /dev/null; then
        info "Usando pacman para instalar dependencias..."
        sudo pacman -S --needed --noconfirm "${pkgs[@]}" 2>/dev/null || warn "No se pudo instalar via pacman"
    elif command -v dnf &> /dev/null; then
        info "Usando dnf para instalar dependencias..."
        sudo dnf install -y python3-requests python3-beautifulsoup4 python3-lxml 2>/dev/null || warn "No se pudo instalar via dnf"
    elif command -v apt &> /dev/null; then
        info "Usando apt para instalar dependencias..."
        sudo apt install -y python3-requests python3-bs4 python3-lxml 2>/dev/null || warn "No se pudo instalar via apt"
    elif command -v pip3 &> /dev/null; then
        info "Usando pip3 para instalar dependencias..."
        pip3 install --user "${pip_pkgs[@]}" 2>/dev/null || pip3 install "${pip_pkgs[@]}" 2>/dev/null || warn "No se pudo instalar via pip3"
    else
        warn "No se detectó package manager. Instala manualmente: ${pip_pkgs[*]}"
    fi

    success "Dependencias de Python instaladas"
}

install_scripts() {
    info "Instalando scripts de wallpapers online..."

    run_mkdir -p "$SCRIPTS_DIR"

    # Copiar Wallhaven
    if [ -d "$SCRIPT_DIR/scripts/wallhaven" ]; then
        run_cp -r "$SCRIPT_DIR/scripts/wallhaven" "$SCRIPTS_DIR/"
        run_chmod +x "$SCRIPTS_DIR/wallhaven/main.py"
        success "Script Wallhaven instalado"
    else
        warn "Script Wallhaven no encontrado en la fuente"
    fi

    # Copiar UHDPaper
    if [ -d "$SCRIPT_DIR/scripts/uhdpaper" ]; then
        run_cp -r "$SCRIPT_DIR/scripts/uhdpaper" "$SCRIPTS_DIR/"
        run_chmod +x "$SCRIPTS_DIR/uhdpaper/main.py"
        success "Script UHDPaper instalado"
    else
        warn "Script UHDPaper no encontrado en la fuente"
    fi
}

install_services() {
    info "Instalando servicios QML..."

    run_mkdir -p "$SERVICES_DIR"

    # Copiar servicios solo si no existen o si se fuerza
    for service in WallhavenService.qml UhdService.qml Wallpapers.qml; do
        if [ -f "$SCRIPT_DIR/services/$service" ]; then
            if [ -f "$SERVICES_DIR/$service" ]; then
                warn "$service ya existe. Usando -f para forzar actualización."
                if [ "${FORCE:-}" = "1" ]; then
                    run_cp "$SCRIPT_DIR/services/$service" "$SERVICES_DIR/"
                    success "$service actualizado"
                else
                    warn "$service no actualizado (usa FORCE=1 para sobrescribir)"
                fi
            else
                run_cp "$SCRIPT_DIR/services/$service" "$SERVICES_DIR/"
                success "$service instalado"
            fi
        fi
    done
}

merge_registry() {
    local src="$1"
    local dst="$2"

    # Check if OnlineWallpapers component is already registered
    if grep -q "OnlineWallpapers" "$dst" 2>/dev/null; then
        debug "PageCompRegistry ya tiene OnlineWallpapers"
        return 0
    fi

    # Guardar backup del original del usuario antes de modificar
    if [ ! -f "${dst}.bak" ]; then
        run_cp "$dst" "${dst}.bak"
        debug "Backup guardado: ${dst}.bak"
    fi

    # Simple approach: copy the fixed version from source
    run_cp "$src" "$dst"
    success "PageCompRegistry.qml actualizado con OnlineWallpapers"
    return 0
}

install_modules() {
    info "Instalando módulos QML..."

    # Crear directorios
    run_mkdir -p "$MODULES_DIR/pages/wallandstyle"
    run_mkdir -p "$MODULES_DIR/common"

    # Copiar OnlineWallpapers.qml (siempre, es nuevo)
    if [ -f "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/OnlineWallpapers.qml" ]; then
        run_cp "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/OnlineWallpapers.qml" "$MODULES_DIR/pages/wallandstyle/"
        success "OnlineWallpapers.qml instalado"
    fi

    # Copiar WallItemOnline.qml (siempre, es nuevo)
    if [ -f "$SCRIPT_DIR/modules/nexus/common/WallItemOnline.qml" ]; then
        run_cp "$SCRIPT_DIR/modules/nexus/common/WallItemOnline.qml" "$MODULES_DIR/common/"
        success "WallItemOnline.qml instalado"
    fi

    # WallpaperAndStyle.qml - siempre actualizar (tiene fixes importantes)
    if [ -f "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/WallpaperAndStyle.qml" ]; then
        if [ -f "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml" ]; then
            # Guardar backup del original antes de modificar
            if [ ! -f "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml.bak" ]; then
                run_cp "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml" "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml.bak"
                debug "Backup guardado: WallpaperAndStyle.qml.bak"
            fi
            # Comparar y actualizar si hay cambios
            if ! diff -q "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/WallpaperAndStyle.qml" "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml" >/dev/null 2>&1; then
                run_cp "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/WallpaperAndStyle.qml" "$MODULES_DIR/pages/wallandstyle/"
                success "WallpaperAndStyle.qml actualizado (con fixes)"
            else
                debug "WallpaperAndStyle.qml ya está actualizado"
            fi
        else
            run_cp "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/WallpaperAndStyle.qml" "$MODULES_DIR/pages/wallandstyle/"
            success "WallpaperAndStyle.qml instalado"
        fi
    fi

    # PageCompRegistry.qml - mergear OnlineWallpapers si falta
    if [ -f "$SCRIPT_DIR/modules/nexus/PageCompRegistry.qml" ]; then
        if [ -f "$MODULES_DIR/PageCompRegistry.qml" ]; then
            # Intentar mergear el componente OnlineWallpapers
            merge_registry "$SCRIPT_DIR/modules/nexus/PageCompRegistry.qml" "$MODULES_DIR/PageCompRegistry.qml"
        else
            run_cp "$SCRIPT_DIR/modules/nexus/PageCompRegistry.qml" "$MODULES_DIR/"
            success "PageCompRegistry.qml instalado"
        fi
    fi
}

setup_config() {
    info "Configurando wallhaven..."

    CONFIG_DIR="$HOME/.config/caelestia/wallhaven"
    mkdir -p "$CONFIG_DIR"

    if [ ! -f "$CONFIG_DIR/config.toml" ]; then
        cat > "$CONFIG_DIR/config.toml" << 'EOF'
# Configuración de Wallhaven para Caelestia
download_dir = "~/Pictures/Wallpapers"
auto_download = false
EOF
        success "Configuración de wallhaven creada en $CONFIG_DIR/config.toml"
    else
        warn "Configuración de wallhaven ya existe"
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Instalación completada exitosamente  ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Ubicación: $CAELESTIA_DIR"
    if [ "$USE_SUDO" = "1" ]; then
        echo "Modo: Sistema (requiere sudo para modificar)"
    else
        echo "Modo: Usuario (sin permisos especiales)"
    fi
    echo ""
    echo "Archivos instalados:"
    echo "  - Scripts: $SCRIPTS_DIR/"
    echo "  - Servicios: $SERVICES_DIR/"
    echo "  - Módulos: $MODULES_DIR/"
    echo ""
    echo "Para usar Wallhaven desde terminal:"
    echo "  python3 $SCRIPTS_DIR/wallhaven/main.py search 'nature'"
    echo "  python3 $SCRIPTS_DIR/wallhaven/main.py random --download"
    echo ""
    echo "Para usar UHDPaper desde terminal:"
    echo "  python3 $SCRIPTS_DIR/uhdpaper/main.py list"
    echo "  python3 $SCRIPTS_DIR/uhdpaper/main.py download <slug>"
    echo ""
    echo "Reinicia Caelestia para aplicar los cambios."
    echo ""
}

# Parse arguments
FORCE=0
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=1
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  -f, --force    Forzar sobreescritura de archivos existentes"
            echo "  -h, --help     Mostrar esta ayuda"
            echo ""
            echo "Variables de entorno:"
            echo "  CAELESTIA_DIR  Directorio de Caelestia (auto-detecta si no se especifica)"
            echo ""
            echo "Detección automática:"
            echo "  1. Si existe ~/.config/quickshell/caelestia, lo usa (sin sudo)"
            echo "  2. Si no existe pero sí /etc/xdg/quickshell/caelestia, usa esa (con sudo)"
            echo "  3. Si no existe ninguno, crea en ~/.config/quickshell/caelestia"
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
echo -e "${BLUE}║   Caelestia Web Wallpaper Installer   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

check_deps
install_python_deps
install_scripts
install_services
install_modules
setup_config
print_summary
