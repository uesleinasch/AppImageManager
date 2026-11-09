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

## Abrir

Use o botão ▶ na lista ou **Abrir** na tela de detalhes.

## Atalho no menu e início automático

Na tela de detalhes, a seção **Integração com o sistema** tem dois interruptores. Cada um cria ou remove o arquivo `.desktop` correspondente na hora. O caminho do arquivo aparece embaixo do interruptor.

!!! tip "O atalho não apareceu?"
    O GNOME costuma detectar o arquivo novo em alguns segundos. Se demorar, encerre e entre de novo na sessão.

## Renomear

Use o ícone de lápis na barra superior dos detalhes. O nome muda no menu e no início automático.

## Remover

Use o ícone de lixeira. O atalho, o início automático e o ícone extraído são sempre removidos. Desmarque **Apagar também o arquivo .AppImage** para manter o executável em `~/Applications`.
