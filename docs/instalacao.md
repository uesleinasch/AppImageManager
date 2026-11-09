# Instalação

## Pacote .deb (Ubuntu, Debian, Pop!_OS, Mint)

Baixe o arquivo `appimage-manager_<versão>_amd64.deb` na página de [Releases](https://github.com/uesleinasch/AppImageManager/releases/latest) e instale:

```bash
sudo apt install ./appimage-manager_*_amd64.deb
```

O aplicativo aparece no menu como **AppImage Manager** e também pode ser aberto pelo terminal:

```bash
appimage-manager
```

Para remover:

```bash
sudo apt remove appimage-manager
```

!!! note "Seus dados ficam"
    Remover o pacote não apaga os AppImages em `~/Applications` nem a biblioteca em `~/.config/appimage-manager`.

## Tarball (outras distribuições)

Cada release também publica `appimage-manager_<versão>_linux_x64.tar.gz` com o bundle do Flutter:

```bash
mkdir -p ~/.local/opt/appimage-manager
tar -xzf appimage-manager_*_linux_x64.tar.gz -C ~/.local/opt/appimage-manager
~/.local/opt/appimage-manager/appimage_manager
```

Dependências: GTK 3 e GLib 2.

## A partir do código-fonte

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
git clone https://github.com/uesleinasch/AppImageManager.git
cd AppImageManager
flutter pub get
flutter build linux --release
./packaging/linux/build_deb.sh 0.0.0-dev amd64
```

## Requisitos para rodar AppImages

A maioria dos AppImages usa FUSE 2. Em Ubuntu 22.04 ou superior instale:

```bash
sudo apt install libfuse2t64   # Ubuntu 24.04+
sudo apt install libfuse2      # Ubuntu 22.04
```

O AppImage Manager lê metadados com `--appimage-extract`, que não depende de FUSE. O FUSE só é necessário para **abrir** os aplicativos.

## Verificando o download

Cada release traz um `SHA256SUMS`:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```
