import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/managed_app.dart';
import '../services/app_manager.dart';
import 'feedback.dart';
import 'github_source_dialog.dart';
import 'widgets/app_icon.dart';

Future<ManagedApp?> showInstallFlow(
  BuildContext context,
  AppManager manager,
) async {
  final path = await pickAppImage();
  if (path == null || !context.mounted) return null;

  final draft = await showDialog<InstallDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PreparingDialog(manager: manager, path: path),
  );
  if (draft == null || !context.mounted) {
    if (draft != null) await manager.discardDraft(draft);
    return null;
  }

  final app = await showDialog<ManagedApp>(
    context: context,
    barrierDismissible: false,
    builder: (_) => InstallDialog(manager: manager, draft: draft),
  );
  if (app == null) await manager.discardDraft(draft);
  return app;
}

class _PreparingDialog extends StatefulWidget {
  const _PreparingDialog({required this.manager, required this.path});

  final AppManager manager;
  final String path;

  @override
  State<_PreparingDialog> createState() => _PreparingDialogState();
}

class _PreparingDialogState extends State<_PreparingDialog> {
  @override
  void initState() {
    super.initState();
    widget.manager
        .prepareInstall(widget.path)
        .then(
          (draft) {
            if (mounted) {
              Navigator.pop(context, draft);
            } else {
              widget.manager.discardDraft(draft);
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            showMessage(context, error.toString(), error: true);
            Navigator.pop(context);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 24),
          Expanded(child: Text('Lendo ${p.basename(widget.path)}…')),
        ],
      ),
    );
  }
}

class InstallDialog extends StatefulWidget {
  const InstallDialog({super.key, required this.manager, required this.draft});

  final AppManager manager;
  final InstallDraft draft;

  @override
  State<InstallDialog> createState() => _InstallDialogState();
}

class _InstallDialogState extends State<InstallDialog> {
  late final _name = TextEditingController(text: widget.draft.metadata.name);
  var _menuEntry = true;
  var _autostart = false;
  var _removeOriginal = false;
  var _github = const GitHubSourceInput(source: null, isEmpty: true);
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() => _busy = true);
    try {
      final app = await widget.manager.install(
        widget.draft,
        name: _name.text,
        menuEntry: _menuEntry,
        autostart: _autostart,
        github: _github.source,
        removeOriginal: _removeOriginal,
      );
      if (mounted) Navigator.pop(context, app);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.draft.metadata;
    final theme = Theme.of(context);
    final canInstall =
        !_busy && _name.text.trim().isNotEmpty && _github.isValid;

    return AlertDialog(
      title: const Text('Adicionar AppImage'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIcon(path: metadata.iconFile, size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.basename(widget.draft.sourcePath),
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          metadata.version == null
                              ? 'Versão não identificada'
                              : 'Versão ${metadata.version}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.menu_open_rounded),
                title: const Text('Adicionar atalho no menu'),
                value: _menuEntry,
                onChanged: (value) => setState(() => _menuEntry = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.power_settings_new_rounded),
                title: const Text('Iniciar com o sistema'),
                value: _autostart,
                onChanged: (value) => setState(() => _autostart = value),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Remover o arquivo original após instalar'),
                value: _removeOriginal,
                onChanged: (value) =>
                    setState(() => _removeOriginal = value ?? false),
              ),
              const Divider(height: 32),
              Text('Atualizações', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              GitHubSourceFields(
                initial: null,
                optional: true,
                onChanged: (value) => setState(() => _github = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: canInstall ? _install : null,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_done_rounded),
          label: const Text('Instalar'),
        ),
      ],
    );
  }
}
