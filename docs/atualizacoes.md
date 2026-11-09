# Atualizações

Cada aplicativo tem uma fonte de atualização, escolhida na seção **Atualizações** da tela de detalhes.

## Manual

Baixe a nova versão por conta própria e clique em **Selecionar arquivo**. O AppImage Manager:

1. valida o arquivo e lê os metadados novos;
2. substitui o executável em `~/Applications/<id>.AppImage` de forma atômica;
3. atualiza ícone, versão e os arquivos `.desktop`.

Atalho, início automático e nome personalizado são mantidos.

## GitHub Releases

Selecione **GitHub Releases** e informe:

| Campo | Exemplo | Para quê |
| --- | --- | --- |
| Repositório | `obsidianmd/obsidian-releases` ou a URL do GitHub | De onde vêm os releases |
| Padrão do arquivo | `*x86_64.AppImage` | Escolhe o asset quando o release tem vários `.AppImage` |
| Incluir pré-lançamentos | ligado/desligado | Considera releases marcados como *pre-release* |

### Verificar e aplicar

- **Verificar agora** consulta o último release daquele aplicativo.
- O botão de atualização na barra superior da tela inicial verifica todos os aplicativos vinculados ao GitHub e mostra quantas atualizações existem.
- **Atualizar para X** baixa o asset, mostra o progresso e instala.

### Como a versão nova é detectada

1. Se o app já foi atualizado pelo GitHub, compara a **tag** instalada com a tag do último release.
2. Caso contrário, compara a versão instalada com a tag (`v1.2.3` vira `1.2.3`), seguindo regras de versionamento semântico: `1.0.0-beta` é anterior a `1.0.0`.
3. Sem versão conhecida, qualquer release é tratado como atualização.

### Qual arquivo é baixado

Entre os assets terminados em `.AppImage`:

1. aplica o padrão, se configurado;
2. prefere o que cita a arquitetura da máquina (`x86_64`, `amd64`, `x64`, `aarch64`, `arm64`…);
3. descarta os que citam outra arquitetura.

### Limite de requisições

A API pública do GitHub permite 60 requisições por hora por IP. Se você gerencia muitos aplicativos, defina um token antes de abrir o app:

```bash
GITHUB_TOKEN=ghp_seu_token appimage-manager
```

Um token sem permissões extras (somente leitura de repositórios públicos) é suficiente.
