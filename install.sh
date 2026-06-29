#!/usr/bin/env bash
# Caelestia Web Wallpaper - Script de instalación
# Instala los módulos de wallpapers online (Wallhaven + UHDPaper) en tu configuración de Caelestia

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Rutas por defecto
CAELESTIA_DIR="${CAELESTIA_DIR:-$HOME/.config/quickshell/caelestia}"
SCRIPTS_DIR="$CAELESTIA_DIR/scripts/webWallpaper"
SERVICES_DIR="$CAELESTIA_DIR/services"
MODULES_DIR="$CAELESTIA_DIR/modules/nexus"

# Directorio del script (de donde se ejecuta)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        error "Directorio de Caelestia no encontrado: $CAELESTIA_DIR"
    fi
    success "Directorio de Caelestia: $CAELESTIA_DIR"
}

install_python_deps() {
    info "Instalando dependencias de Python..."
    
    # Wallhaven dependencies
    if command -v pip3 &> /dev/null; then
        pip3 install requests --quiet 2>/dev/null || warn "No se pudo instalar requests via pip"
    elif python3 -m pip &> /dev/null; then
        python3 -m pip install requests --quiet 2>/dev/null || warn "No se pudo instalar requests via pip"
    else
        warn "pip no disponible. Asegúrate de tener 'requests' instalado."
    fi
    
    # UHDPaper dependencies
    if [ -f "$SCRIPT_DIR/scripts/uhdpaper/requirements.txt" ]; then
        if command -v pip3 &> /dev/null; then
            pip3 install -r "$SCRIPT_DIR/scripts/uhdpaper/requirements.txt" --quiet 2>/dev/null || warn "Error instalando dependencias de UHDPaper"
        elif python3 -m pip &> /dev/null; then
            python3 -m pip install -r "$SCRIPT_DIR/scripts/uhdpaper/requirements.txt" --quiet 2>/dev/null || warn "Error instalando dependencias de UHDPaper"
        fi
    fi
    
    success "Dependencias de Python instaladas"
}

install_scripts() {
    info "Instalando scripts de wallpapers online..."
    
    mkdir -p "$SCRIPTS_DIR"
    
    # Copiar Wallhaven
    if [ -d "$SCRIPT_DIR/scripts/wallhaven" ]; then
        cp -r "$SCRIPT_DIR/scripts/wallhaven" "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/wallhaven/main.py"
        success "Script Wallhaven instalado"
    else
        warn "Script Wallhaven no encontrado en la fuente"
    fi
    
    # Copiar UHDPaper
    if [ -d "$SCRIPT_DIR/scripts/uhdpaper" ]; then
        cp -r "$SCRIPT_DIR/scripts/uhdpaper" "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/uhdpaper/main.py"
        success "Script UHDPaper instalado"
    else
        warn "Script UHDPaper no encontrado en la fuente"
    fi
}

install_services() {
    info "Instalando servicios QML..."
    
    mkdir -p "$SERVICES_DIR"
    
    # Copiar servicios solo si no existen o si se fuerza
    for service in WallhavenService.qml UhdService.qml Wallpapers.qml; do
        if [ -f "$SCRIPT_DIR/services/$service" ]; then
            if [ -f "$SERVICES_DIR/$service" ]; then
                warn "$service ya existe. Usando -f para forzar actualización."
                if [ "${FORCE:-}" = "1" ]; then
                    cp "$SCRIPT_DIR/services/$service" "$SERVICES_DIR/"
                    success "$service actualizado"
                else
                    warn "$service no actualizado (usa FORCE=1 para sobrescribir)"
                fi
            else
                cp "$SCRIPT_DIR/services/$service" "$SERVICES_DIR/"
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
    
    # Add OnlineWallpapers component after ColourSelect if missing
    if grep -q "ColourSelect" "$dst" 2>/dev/null; then
        awk '/ColourSelect \{/{found=1} found && /\}/{print; print "                Component {"; print "                    OnlineWallpapers {}"; print "                }"; found=0; next}1' "$dst" > "${dst}.tmp" && mv "${dst}.tmp" "$dst"
        success "OnlineWallpapers agregado al registry"
        return 0
    fi
    
    warn "No se pudo mergear PageCompRegistry automáticamente"
    return 1
}

install_modules() {
    info "Instalando módulos QML..."
    
    # Crear directorios
    mkdir -p "$MODULES_DIR/pages/wallandstyle"
    mkdir -p "$MODULES_DIR/common"
    
    # Copiar OnlineWallpapers.qml (siempre, es nuevo)
    if [ -f "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/OnlineWallpapers.qml" ]; then
        cp "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/OnlineWallpapers.qml" "$MODULES_DIR/pages/wallandstyle/"
        success "OnlineWallpapers.qml instalado"
    fi
    
    # Copiar WallItemOnline.qml (siempre, es nuevo)
    if [ -f "$SCRIPT_DIR/modules/nexus/common/WallItemOnline.qml" ]; then
        cp "$SCRIPT_DIR/modules/nexus/common/WallItemOnline.qml" "$MODULES_DIR/common/"
        success "WallItemOnline.qml instalado"
    fi
    
    # WallpaperAndStyle.qml - siempre actualizar (tiene fixes importantes)
    if [ -f "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/WallpaperAndStyle.qml" ]; then
        if [ -f "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml" ]; then
            # Comparar y actualizar si hay cambios
            if ! diff -q "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/WallpaperAndStyle.qml" "$MODULES_DIR/pages/wallandstyle/WallpaperAndStyle.qml" >/dev/null 2>&1; then
                cp "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/WallpaperAndStyle.qml" "$MODULES_DIR/pages/wallandstyle/"
                success "WallpaperAndStyle.qml actualizado (con fixes)"
            else
                debug "WallpaperAndStyle.qml ya está actualizado"
            fi
        else
            cp "$SCRIPT_DIR/modules/nexus/pages/wallandstyle/WallpaperAndStyle.qml" "$MODULES_DIR/pages/wallandstyle/"
            success "WallpaperAndStyle.qml instalado"
        fi
    fi
    
    # PageCompRegistry.qml - mergear OnlineWallpapers si falta
    if [ -f "$SCRIPT_DIR/modules/nexus/PageCompRegistry.qml" ]; then
        if [ -f "$MODULES_DIR/PageCompRegistry.qml" ]; then
            # Intentar mergear el componente OnlineWallpapers
            merge_registry "$SCRIPT_DIR/modules/nexus/PageCompRegistry.qml" "$MODULES_DIR/PageCompRegistry.qml"
        else
            cp "$SCRIPT_DIR/modules/nexus/PageCompRegistry.qml" "$MODULES_DIR/"
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
            echo "  CAELESTIA_DIR  Directorio de Caelestia (default: ~/.config/quickshell/caelestia)"
            exit 0
            ;;
        *)
            error "Opción desconocida: $1"
            ;;
    esac
done

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
