# Política de segurança

## Versões suportadas

Correções de segurança são aplicadas apenas na versão mais recente publicada em [Releases](https://github.com/uesleinasch/AppImageManager/releases).

## Como reportar

Não abra issue pública para vulnerabilidades. Use o formulário privado em
[Security Advisories](https://github.com/uesleinasch/AppImageManager/security/advisories/new).

Inclua passos de reprodução, impacto esperado e, se possível, uma sugestão de correção. A resposta inicial deve ocorrer em até 7 dias.

## Escopo relevante

- Execução de AppImages durante a leitura de metadados (`--appimage-extract`).
- Download de releases do GitHub e substituição de arquivos executáveis.
- Geração de arquivos `.desktop` em `~/.local/share/applications` e `~/.config/autostart`.
