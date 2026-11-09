<p align="center">
  <img src="packaging/linux/appimage-manager.svg" width="96" alt="">
</p>

<h1 align="center">AppImage Manager</h1>

<p align="center">
  Aplicativo para gerenciar AppImages no Linux, feito com Flutter e Material Design 3.
</p>

<p align="center">
  <a href="https://github.com/uesleinasch/AppImageManager/actions/workflows/ci.yml"><img src="https://github.com/uesleinasch/AppImageManager/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/uesleinasch/AppImageManager/releases/latest"><img src="https://img.shields.io/github/v/release/uesleinasch/AppImageManager?include_prereleases" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licen%C3%A7a-MIT-blue" alt="Licença MIT"></a>
  <a href="https://uesleinasch.github.io/AppImageManager/"><img src="https://img.shields.io/badge/docs-MkDocs%20Material-526cfe" alt="Documentação"></a>
</p>

## Recursos

- **Gerenciar atualizações**: substituição manual por um arquivo novo ou via **GitHub Releases** (verificação, escolha do asset por arquitetura, download com progresso).
- **Atalho no menu do GNOME**: entrada `.desktop` com nome, ícone, categorias e argumentos originais extraídos do próprio AppImage.
- **Início com o sistema**: liga e desliga o autostart com um clique.
- Biblioteca com busca, renomeação, remoção e abertura direta dos aplicativos.

## Instalação

Baixe o `.deb` do [último release](https://github.com/uesleinasch/AppImageManager/releases/latest):

```bash
sudo apt install ./appimage-manager_*_amd64.deb
```

Outras opções (tarball, código-fonte) estão na [documentação](https://uesleinasch.github.io/AppImageManager/instalacao/).

## Desenvolvimento

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
flutter pub get
flutter run -d linux
flutter test
```

Gerar o pacote local:

```bash
flutter build linux --release
./packaging/linux/build_deb.sh 0.1.0 amd64
```

## Disponibilidade

- `.deb` e `tar.gz` gerados pelo GitHub Actions e publicados em [Releases](https://github.com/uesleinasch/AppImageManager/releases) a cada tag `v*`.
- Documentação no [GitHub Pages](https://uesleinasch.github.io/AppImageManager/) com Material for MkDocs.

## Contribuindo

Projeto open source com templates de issue e pull request. Leia o [CONTRIBUTING.md](CONTRIBUTING.md) e o [Código de Conduta](CODE_OF_CONDUCT.md).

## Stack

- Flutter (Linux desktop)
- Material Design 3

## Licença

[MIT](LICENSE)
