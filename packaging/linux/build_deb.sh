#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?uso: build_deb.sh <versão> [arquitetura-debian]}"
ARCH="${2:-amd64}"

case "$ARCH" in
  amd64) FLUTTER_ARCH="x64" ;;
  arm64) FLUTTER_ARCH="arm64" ;;
  *) echo "Arquitetura não suportada: $ARCH" >&2; exit 1 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGE="appimage-manager"
APP_ID="io.github.uesleinasch.appimage_manager"
BUNDLE="${BUNDLE:-$ROOT/build/linux/$FLUTTER_ARCH/release/bundle}"
OUT_DIR="$ROOT/build/deb"
STAGE="$OUT_DIR/${PACKAGE}_${VERSION}_${ARCH}"

if [[ ! -x "$BUNDLE/appimage_manager" ]]; then
  echo "Bundle não encontrado em $BUNDLE. Rode 'flutter build linux --release' antes." >&2
  exit 1
fi

rm -rf "$STAGE"
install -d \
  "$STAGE/DEBIAN" \
  "$STAGE/opt/$PACKAGE" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/icons/hicolor/scalable/apps" \
  "$STAGE/usr/share/doc/$PACKAGE"

cp -a "$BUNDLE/." "$STAGE/opt/$PACKAGE/"
ln -s "/opt/$PACKAGE/appimage_manager" "$STAGE/usr/bin/$PACKAGE"
install -m 644 "$ROOT/packaging/linux/$APP_ID.desktop" "$STAGE/usr/share/applications/$APP_ID.desktop"
install -m 644 "$ROOT/packaging/linux/appimage-manager.svg" "$STAGE/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"
install -m 644 "$ROOT/LICENSE" "$STAGE/usr/share/doc/$PACKAGE/copyright"

INSTALLED_SIZE="$(du -sk --exclude=DEBIAN "$STAGE" | cut -f1)"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PACKAGE
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0t64 | libgtk-3-0, libglib2.0-0t64 | libglib2.0-0
Recommends: libfuse2t64 | libfuse2, desktop-file-utils
Maintainer: Ueslei Nascimento <uesleinasch@users.noreply.github.com>
Homepage: https://github.com/uesleinasch/AppImageManager
Description: Gerenciador de AppImages para Linux
 Instala e organiza arquivos AppImage, cria atalhos no menu do GNOME,
 controla o início automático com o sistema e atualiza aplicativos
 manualmente ou a partir de GitHub Releases.
EOF

cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t /usr/share/icons/hicolor || true
fi
EOF
cp "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

dpkg-deb --build --root-owner-group "$STAGE" "$OUT_DIR/${PACKAGE}_${VERSION}_${ARCH}.deb"
echo "$OUT_DIR/${PACKAGE}_${VERSION}_${ARCH}.deb"
