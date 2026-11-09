# AppImage Manager

Gerenciador de AppImages para Linux, feito com **Flutter** e **Material Design 3**.

AppImages são práticos, mas ficam soltos na pasta de downloads: sem ícone no menu, sem início automático e sem um jeito simples de atualizar. O AppImage Manager resolve isso em uma interface só.

<div class="grid cards" markdown>

-   :material-menu-open: **Atalho no menu**

    ---

    Cria a entrada `.desktop` com nome, ícone, categorias e argumentos originais do aplicativo, visível no GNOME e em outros ambientes.

-   :material-power: **Início com o sistema**

    ---

    Liga e desliga a inicialização automática via `~/.config/autostart`, com um clique.

-   :material-cloud-sync: **Atualizações**

    ---

    Substitua manualmente por um arquivo novo ou vincule ao **GitHub Releases** para verificar e baixar versões novas.

-   :material-open-source-initiative: **Código aberto**

    ---

    Licença MIT, templates de issue e PR prontos e CI completo para quem quiser contribuir.

</div>

## Começando

1. [Instale](instalacao.md) o pacote `.deb` do último release.
2. Abra **AppImage Manager** no menu de aplicativos.
3. Clique em **Adicionar AppImage** e escolha o arquivo.

## Onde ficam os arquivos

| O quê | Caminho |
| --- | --- |
| AppImages gerenciados | `~/Applications/<id>.AppImage` |
| Biblioteca (configuração) | `~/.config/appimage-manager/library.json` |
| Ícones extraídos | `~/.local/share/appimage-manager/icons/` |
| Atalhos do menu | `~/.local/share/applications/appimagemanager-<id>.desktop` |
| Início automático | `~/.config/autostart/appimagemanager-<id>.desktop` |

As variáveis `XDG_CONFIG_HOME`, `XDG_DATA_HOME` e `XDG_CACHE_HOME` são respeitadas.
