#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="$HOME/.local/opt/betelgeuse"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/betelgeuse"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_DIR="$DATA_DIR/applications"
DESKTOP_FILE="$DESKTOP_DIR/betelgeuse.desktop"
ICON_THEME="$DATA_DIR/icons/hicolor"
APP_ID="com.example.devtask"

err() {
  echo "Error: $*" >&2
  exit 1
}

refresh_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q "$DESKTOP_DIR" 2>/dev/null || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t "$ICON_THEME" 2>/dev/null || true
  fi
}

uninstall() {
  echo "Desinstalando Betelgeuse..."
  rm -rf "$APP_DIR"
  rm -f "$BIN_LINK"
  rm -f "$DESKTOP_FILE"
  if [ -d "$ICON_THEME" ]; then
    shopt -s nullglob
    for dir in "$ICON_THEME"/*/apps; do
      rm -f "$dir/betelgeuse.png"
    done
    shopt -u nullglob
  fi
  refresh_caches
  echo "Listo. Betelgeuse ya no está instalado."
  echo "Tus datos de la app (cuentas y preferencias) no se tocan."
}

usage() {
  cat <<'EOF'
Instala Betelgeuse para el usuario actual, sin sudo.

Uso:
  bash install.sh                # instala desde el directorio del script
  bash install.sh RUTA           # instala desde otro bundle ya extraído
  bash install.sh --uninstall    # desinstala
  bash install.sh --help         # muestra esta ayuda

El bundle debe contener el ejecutable "betelgeuse", lib/ y data/. Si incluye
share/icons/hicolor se instalan todos los tamaños de icono; si no, se usa el
icono que viene dentro de data/flutter_assets.

El .desktop se genera aquí (no se toma del bundle): Exec e Icon apuntan a
rutas absolutas y StartupWMClass coincide con el app-id de la app.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --uninstall)
    uninstall
    exit 0
    ;;
  -*)
    err "opción desconocida: $1 (usa --help)"
    ;;
esac

SRC="${1:-$SCRIPT_DIR}"
[ -d "$SRC" ] || err "no existe el directorio \"$SRC\"."
SRC="$(cd -- "$SRC" && pwd)"

[ -f "$SRC/betelgeuse" ] || err "no encontré el ejecutable \"betelgeuse\" en $SRC."
[ -d "$SRC/lib" ] || err "no encontré la carpeta \"lib\" en $SRC."
[ -d "$SRC/data" ] || err "no encontré la carpeta \"data\" en $SRC."

stage="$APP_DIR.new.$$"
trap 'rm -rf "$stage"' EXIT

echo "· Instalando Betelgeuse desde $SRC"
mkdir -p "$BIN_DIR" "$DESKTOP_DIR" "$ICON_THEME" "$(dirname -- "$APP_DIR")"
rm -rf "$stage"
mkdir -p "$stage"

cp -a "$SRC/betelgeuse" "$SRC/data" "$SRC/lib" "$stage/"
if [ -d "$SRC/share" ]; then
  cp -a "$SRC/share" "$stage/share"
fi
chmod +x "$stage/betelgeuse"

rm -rf "$APP_DIR"
mv "$stage" "$APP_DIR"
trap - EXIT

echo "· Enlazando $BIN_LINK"
if [ -e "$BIN_LINK" ] && [ ! -L "$BIN_LINK" ]; then
  mv -f "$BIN_LINK" "$BIN_LINK.bak"
  echo "  (había un archivo suelto; lo dejé como betelgeuse.bak)"
fi
ln -sfn "$APP_DIR/betelgeuse" "$BIN_LINK"

echo "· Instalando iconos"
shopt -s nullglob
icons=("$SRC"/share/icons/hicolor/*/apps/betelgeuse.png)
shopt -u nullglob
if [ "${#icons[@]}" -gt 0 ]; then
  for icon in "${icons[@]}"; do
    size="$(basename -- "$(dirname -- "$(dirname -- "$icon")")")"
    mkdir -p "$ICON_THEME/$size/apps"
    cp -f "$icon" "$ICON_THEME/$size/apps/betelgeuse.png"
  done
else
  fallback="$SRC/data/flutter_assets/assets/icon/betelgeuse_rounded.png"
  [ -f "$fallback" ] || fallback="$SRC/data/flutter_assets/assets/icon/betelgeuse_square.png"
  if [ -f "$fallback" ]; then
    mkdir -p "$ICON_THEME/512x512/apps"
    cp -f "$fallback" "$ICON_THEME/512x512/apps/betelgeuse.png"
  else
    echo "Aviso: no encontré ningún icono dentro del bundle." >&2
  fi
fi

echo "· Creando $DESKTOP_FILE"
cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Betelgeuse
GenericName=Tablero Kanban para GitHub
Comment=Organiza tus issues y pull requests de GitHub Projects v2
Exec="$APP_DIR/betelgeuse" %U
Icon=betelgeuse
Terminal=false
Categories=Development;ProjectManagement;
Keywords=github;kanban;projects;issues;pull-requests;
StartupNotify=true
StartupWMClass=$APP_ID
EOF
chmod 644 "$DESKTOP_FILE"

refresh_caches

echo
echo "Listo. Ejecuta 'betelgeuse' o búscala en el menú de aplicaciones."

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo
    echo "Aviso: $BIN_DIR no está en tu PATH. Añade esto a tu ~/.profile:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac
