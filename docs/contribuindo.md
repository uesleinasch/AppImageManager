# Contribuindo

O guia completo está em [CONTRIBUTING.md](https://github.com/uesleinasch/AppImageManager/blob/main/CONTRIBUTING.md). Resumo:

## Ambiente

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
flutter pub get
flutter run -d linux
```

## Antes do pull request

```bash
dart format lib test
flutter analyze
flutter test
```

## Templates disponíveis

| Template | Onde |
| --- | --- |
| Relato de bug | [Nova issue → Relatar bug](https://github.com/uesleinasch/AppImageManager/issues/new?template=bug_report.yml) |
| Sugestão de funcionalidade | [Nova issue → Sugerir funcionalidade](https://github.com/uesleinasch/AppImageManager/issues/new?template=feature_request.yml) |
| Pull request | Preenchido automaticamente ao abrir o PR |

## Pipelines

| Workflow | Quando roda | O que faz |
| --- | --- | --- |
| **CI** | push em `main` e PRs | formatação, `flutter analyze`, testes, build Linux e `.deb` de teste |
| **Release** | tags `v*` | build, `.deb`, `tar.gz`, `SHA256SUMS` e publicação do release |
| **Docs** | mudanças em `docs/` ou `mkdocs.yml` | build com `--strict` e publicação no GitHub Pages |

## Documentação local

```bash
pip install -r requirements-docs.txt
mkdocs serve
```
