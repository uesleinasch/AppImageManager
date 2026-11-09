import 'package:flutter/material.dart';

import '../models/github_source.dart';

class GitHubSourceFields extends StatefulWidget {
  const GitHubSourceFields({
    super.key,
    required this.initial,
    required this.onChanged,
    this.optional = false,
  });

  final GitHubSource? initial;
  final ValueChanged<GitHubSourceInput> onChanged;
  final bool optional;

  @override
  State<GitHubSourceFields> createState() => _GitHubSourceFieldsState();
}

class GitHubSourceInput {
  const GitHubSourceInput({required this.source, required this.isEmpty});

  final GitHubSource? source;
  final bool isEmpty;

  bool get isValid => source != null || isEmpty;
}

class _GitHubSourceFieldsState extends State<GitHubSourceFields> {
  late final _repo = TextEditingController(text: widget.initial?.slug ?? '');
  late final _pattern = TextEditingController(
    text: widget.initial?.assetPattern ?? '',
  );
  late bool _prereleases = widget.initial?.includePrereleases ?? false;

  GitHubSourceInput get _input => GitHubSourceInput(
    source: GitHubSource.tryParse(
      _repo.text,
      assetPattern: _pattern.text,
      includePrereleases: _prereleases,
    ),
    isEmpty: _repo.text.trim().isEmpty,
  );

  void _notify() => widget.onChanged(_input);

  @override
  void dispose() {
    _repo.dispose();
    _pattern.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final showError = !input.isEmpty && input.source == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _repo,
          decoration: InputDecoration(
            labelText: widget.optional
                ? 'Repositório no GitHub (opcional)'
                : 'Repositório no GitHub',
            hintText: 'dono/repositorio ou URL do GitHub',
            prefixIcon: const Icon(Icons.code_rounded),
            errorText: showError ? 'Use o formato dono/repositorio' : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(_notify),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pattern,
          enabled: !input.isEmpty,
          decoration: const InputDecoration(
            labelText: 'Padrão do arquivo (opcional)',
            hintText: '*x86_64.AppImage',
            helperText: 'Use * e ? para escolher o asset certo do release',
            prefixIcon: Icon(Icons.filter_alt_outlined),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(_notify),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Incluir pré-lançamentos'),
          subtitle: const Text('Considera releases marcados como pre-release'),
          value: _prereleases,
          onChanged: input.isEmpty
              ? null
              : (value) => setState(() {
                  _prereleases = value;
                  _notify();
                }),
        ),
      ],
    );
  }
}

Future<GitHubSource?> showGitHubSourceDialog(
  BuildContext context, {
  GitHubSource? initial,
}) {
  var input = GitHubSourceInput(source: initial, isEmpty: initial == null);
  return showDialog<GitHubSource>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        icon: const Icon(Icons.cloud_download_outlined),
        title: const Text('Atualizações via GitHub Releases'),
        content: SizedBox(
          width: 460,
          child: GitHubSourceFields(
            initial: initial,
            onChanged: (value) => setState(() => input = value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: input.source == null
                ? null
                : () => Navigator.pop(context, input.source),
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}
