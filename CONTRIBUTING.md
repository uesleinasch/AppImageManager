# Contribuindo com o AppImage Manager

Obrigado pelo interesse! Toda contribuição é bem-vinda: código, documentação, testes, traduções e relatos de bug.

## Primeiros passos

1. Faça um fork e clone o repositório.
2. Instale o [Flutter](https://docs.flutter.dev/get-started/install/linux) (canal stable) e as dependências de build Linux:

   ```bash
   sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
   ```

3. Rode o app:

   ```bash
   flutter pub get
   flutter run -d linux
   ```

## Fluxo de trabalho

- Crie uma branch a partir de `main` (`feat/nome-curto`, `fix/nome-curto`, `docs/...`).
- Commits seguem [Conventional Commits](https://www.conventionalcommits.org/pt-br/) (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `ci:`).
- Antes de abrir o PR:

  ```bash
  dart format lib test
  flutter analyze
  flutter test
  ```

- Abra o PR preenchendo o template. O CI precisa passar.

## Organização do código

| Pasta | Conteúdo |
| --- | --- |
| `lib/src/models` | Modelos persistidos (`ManagedApp`, `GitHubSource`) |
| `lib/src/services` | Regras de negócio sem dependência de UI: inspeção de AppImage, `.desktop`, GitHub Releases, persistência |
| `lib/src/ui` | Telas e diálogos Material 3 |
| `packaging/linux` | Ícone, `.desktop` e script do pacote `.deb` |
| `docs/` | Site de documentação (MkDocs Material) |

Mais detalhes em [Arquitetura](docs/arquitetura.md).

## Documentação

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

## Publicando uma versão (mantenedores)

1. Atualize `version` em `pubspec.yaml`.
2. Crie e envie a tag: `git tag v0.2.0 && git push origin v0.2.0`.
3. O workflow **Release** gera o `.deb`, o `tar.gz` e publica o release.

## Código de conduta

Ao participar, você concorda com o [Código de Conduta](CODE_OF_CONDUCT.md).
