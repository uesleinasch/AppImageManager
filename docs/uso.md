# Gerenciando aplicativos

## Adicionar um AppImage

1. Clique em **Adicionar AppImage** (ou no botão **Adicionar** quando a lista já tiver itens).
2. Escolha o arquivo `.AppImage`.
3. O app lê o arquivo e mostra nome, versão e ícone detectados.
4. Ajuste o nome, se quiser, e escolha:
    - **Adicionar atalho no menu**: cria a entrada no menu de aplicativos.
    - **Iniciar com o sistema**: abre o aplicativo ao entrar na sessão.
    - **Remover o arquivo original**: apaga o arquivo de onde ele foi escolhido (por exemplo, em `Downloads`).
    - **Repositório no GitHub** (opcional): habilita atualizações automáticas. Veja [Atualizações](atualizacoes.md).
5. Clique em **Instalar**.

O arquivo é copiado para `~/Applications/<id>.AppImage` com permissão de execução. O nome do arquivo instalado é fixo, então atalhos e início automático continuam válidos depois de atualizar.

### Como os metadados são lidos

Para AppImages do tipo 2, o app extrai apenas o `.desktop` e o ícone para uma pasta temporária usando `--appimage-extract <padrão>`. Daí vêm:

- nome, comentário e categorias;
- argumentos do `Exec` (por exemplo `--no-sandbox %U` em apps Electron);
- `StartupWMClass`, que agrupa a janela com o ícone certo na dock;
- versão (`X-AppImage-Version`), com o nome do arquivo como alternativa.

AppImages do tipo 1 não são executados durante a leitura; o nome e a versão são deduzidos do nome do arquivo.

### Abrir um AppImage pelo gerenciador de arquivos

O AppImage Manager se registra para os tipos `application/vnd.appimage` e `application/x-iso9660-appimage`. Ao abrir um `.AppImage` com ele (clique direito › **Abrir com** › AppImage Manager; marque **Definir como padrão** para usar sempre no duplo clique), aparece a escolha:

- **Integrar e abrir**: segue o fluxo normal de instalação e abre o app no fim;
- **Abrir uma vez**: dá permissão de execução ao arquivo e o executa onde está, sem instalar;
- **Cancelar**.

Se o arquivo já é um AppImage gerenciado, ele apenas é aberto.

Também funciona pelo terminal: `appimage-manager ~/Downloads/App.AppImage`.

## Abrir

Use o botão ▶ na lista ou **Abrir** na tela de detalhes.

## Atalho no menu e início automático

Na tela de detalhes, a seção **Integração com o sistema** tem dois interruptores. Cada um cria ou remove o arquivo `.desktop` correspondente na hora. O caminho do arquivo aparece embaixo do interruptor.

O atalho do menu recebe o mesmo nome do `.desktop` que vem dentro do AppImage (por exemplo `pairlan.desktop`). No Wayland, o GNOME e o KDE ligam a janela ao atalho pelo `app_id`, que normalmente é esse nome. Assim a dock mostra o ícone certo mesmo quando o `StartupWMClass` do app está errado. Se já existir outro arquivo com esse nome que não foi criado pelo AppImage Manager, ele não é tocado e o atalho usa `appimagemanager-<id>.desktop`.

## Ações no menu de aplicativos

O atalho de cada app ganha duas ações no clique direito do menu/dock:

- **Atualizar (AppImage Manager)**: abre os detalhes do app e já procura a atualização. Com GitHub, verifica e aplica; no modo manual, pede o arquivo novo.
- **Remover (AppImage Manager)**: abre os detalhes do app com a confirmação de remoção.

Elas chamam `appimage-manager --update <id>` e `appimage-manager --remove <id>`. Atalhos criados antes desta versão ganham as ações depois de **Reparar integração**.

Cada chamada abre uma janela nova do AppImage Manager. Se outra janela já estiver aberta, ela recarrega a lista sozinha quando a biblioteca muda.

## Tipos de arquivo associados

Se o `.desktop` do AppImage declara `MimeType=`, o atalho do menu também declara esses tipos. O app passa a aparecer em **Abrir com** para esses arquivos. Pacotes de tipos em `usr/share/mime/packages/*.xml` dentro do AppImage são instalados em `~/.local/share/mime/packages/`, e o `update-mime-database` é chamado. Assim, extensões novas (por exemplo `*.excalidraw`) passam a ser reconhecidas.

Por segurança, um pacote só é instalado se todos os tipos que ele define estão no `MimeType=` do app. Um AppImage não consegue redefinir tipos de outros programas, como `*.pdf`.

O interruptor **Abrir tipos de arquivo associados** liga e desliga a associação. Ele exige o atalho no menu. O AppImage Manager não troca o aplicativo padrão; escolha-o em **Abrir com** › **Definir como padrão** no gerenciador de arquivos.

## Ícone genérico na dock

Se a janela aparece na dock com um ícone genérico, o ambiente gráfico não conseguiu ligar a janela ao atalho. Há duas ferramentas na seção **Integração com o sistema**:

- **Reparar integração**: lê de novo o `.desktop` e o ícone do AppImage instalado e regrava os atalhos. Use em apps instalados antes desta versão para adotar o nome novo do atalho. O botão **Reparar integração de todos**, na barra da tela inicial, repara todos de uma vez.
- **Classe da janela (StartupWMClass)**: troca o valor usado no atalho. Ele deve ser igual ao `app_id` da janela (Wayland) ou ao `WM_CLASS` (X11). Em X11 dá para ver com `xprop WM_CLASS`; em Wayland, rode o app com `WAYLAND_DEBUG=1` e procure `set_app_id`. O valor personalizado continua valendo depois de atualizar o app. **Restaurar original** volta ao valor do AppImage.

!!! tip "O atalho não apareceu?"
    O GNOME costuma detectar o arquivo novo em alguns segundos. Se demorar, encerre e entre de novo na sessão.

## Renomear

Use o ícone de lápis na barra superior dos detalhes. O nome muda no menu e no início automático.

## Remover

Use o ícone de lixeira. O atalho, o início automático e o ícone extraído são sempre removidos. Desmarque **Apagar também o arquivo .AppImage** para manter o executável em `~/Applications`.

### Apagar o arquivo direto da pasta

Também dá para remover apagando o `.AppImage` de `~/Applications`. O atalho tem `TryExec`, então o menu o esconde na hora, mesmo com o AppImage Manager fechado. Na próxima vez que o AppImage Manager abrir (ou na hora, se ele estiver aberto), o resto é limpo: início automático, ícone, tipos de arquivo e a entrada na lista. Um aviso mostra o que foi removido.

## Configurações

O ícone de engrenagem na tela inicial abre as configurações:

- **Verificar atualizações ao abrir**: consulta o GitHub dos apps vinculados sempre que o AppImage Manager abre. Desligado por padrão.
- **Limpar apps cujo arquivo foi apagado**: a limpeza descrita acima. Ligado por padrão.
- **Abrir arquivos .AppImage com o AppImage Manager**: roda `xdg-mime default io.github.uesleinasch.appimage_manager.desktop application/vnd.appimage application/x-iso9660-appimage`. Depois disso, o duplo clique num `.AppImage` oferece **Integrar e abrir**. Requer o pacote `.deb` instalado.

As configurações ficam em `~/.config/appimage-manager/settings.json`.
