import 'package:flutter/material.dart';

import '../models/managed_app.dart';
import '../services/app_manager.dart';
import 'feedback.dart';
import 'github_source_dialog.dart';
import 'widgets/app_icon.dart';

class AppDetailsPage extends StatelessWidget {
  const AppDetailsPage({super.key, required this.manager, required this.appId});

  final AppManager manager;
  final String appId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final app = manager.byId(appId);
        if (app == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Aplicativo removido.')),
          );
        }
        final busy = manager.taskFor(appId) != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(app.name),
            actions: [
              IconButton(
                tooltip: 'Renomear',
                onPressed: busy ? null : () => _rename(context, app),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Remover',
                onPressed: busy ? null : () => _remove(context, app),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(app: app, manager: manager),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Integração com o sistema',
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.menu_open_rounded),
                        title: const Text('Atalho no menu de aplicativos'),
                        subtitle: Text(manager.paths.menuEntryPath(app.id)),
                        value: app.menuEntry,
                        onChanged: busy
                            ? null
                            : (value) => runGuarded(
                                context,
                                () => manager.setMenuEntry(app.id, value),
                              ),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.power_settings_new_rounded),
                        title: const Text('Iniciar com o sistema'),
                        subtitle: Text(
                          manager.paths.autostartEntryPath(app.id),
                        ),
                        value: app.autostart,
                        onChanged: busy
                            ? null
                            : (value) => runGuarded(
                                context,
                                () => manager.setAutostart(app.id, value),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _UpdatesSection(app: app, manager: manager, busy: busy),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Informações',
                    children: [
                      _InfoTile(
                        Icons.insert_drive_file_outlined,
                        'Arquivo',
                        app.appImagePath,
                      ),
                      _InfoTile(
                        Icons.event_outlined,
                        'Instalado em',
                        formatDate(app.installedAt),
                      ),
                      _InfoTile(
                        Icons.history_rounded,
                        'Atualizado em',
                        formatDate(app.updatedAt),
                      ),
                      if (app.releaseTag != null)
                        _InfoTile(
                          Icons.sell_outlined,
                          'Release instalado',
                          app.releaseTag!,
                        ),
                      if (app.categories.isNotEmpty)
                        _InfoTile(
                          Icons.category_outlined,
                          'Categorias',
                          app.categories.join(', '),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, ManagedApp app) async {
    final controller = TextEditingController(text: app.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome exibido no menu',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    await runGuarded(context, () => manager.rename(app.id, name));
  }

  Future<void> _remove(BuildContext context, ManagedApp app) async {
    var deleteFile = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: const Icon(Icons.delete_outline_rounded),
          title: Text('Remover ${app.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O atalho no menu, o início automático e o ícone serão removidos.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Apagar também o arquivo .AppImage'),
                value: deleteFile,
                onChanged: (value) =>
                    setState(() => deleteFile = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    final removed = await runGuarded(
      context,
      () => manager.remove(app.id, deleteFile: deleteFile),
      success: '${app.name} removido.',
    );
    if (removed) navigator.pop();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.app, required this.manager});

  final ManagedApp app;
  final AppManager manager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = manager.taskFor(app.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppIcon(path: app.iconPath, size: 72),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name, style: theme.textTheme.headlineSmall),
                      Text(
                        app.version == null
                            ? 'Versão desconhecida'
                            : 'Versão ${app.version}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (app.comment != null) ...[
                        const SizedBox(height: 4),
                        Text(app.comment!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: task != null
                      ? null
                      : () => runGuarded(context, () => manager.launch(app.id)),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Abrir'),
                ),
              ],
            ),
            if (task != null) ...[
              const SizedBox(height: 16),
              Text(
                task.progress == null
                    ? task.label
                    : '${task.label} — ${(task.progress! * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: task.progress),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpdatesSection extends StatefulWidget {
  const _UpdatesSection({
    required this.app,
    required this.manager,
    required this.busy,
  });

  final ManagedApp app;
  final AppManager manager;
  final bool busy;

  @override
  State<_UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends State<_UpdatesSection> {
  var _checking = false;

  ManagedApp get app => widget.app;
  AppManager get manager => widget.manager;

  Future<void> _changeMode(bool useGitHub) async {
    if (useGitHub == app.usesGitHub) return;
    if (!useGitHub) {
      await runGuarded(context, () => manager.setUpdateSource(app.id, null));
      return;
    }
    await _configureGitHub();
  }

  Future<void> _configureGitHub() async {
    final source = await showGitHubSourceDialog(context, initial: app.github);
    if (source == null || !mounted) return;
    await runGuarded(context, () => manager.setUpdateSource(app.id, source));
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final release = await manager.checkForUpdate(app.id);
      if (!mounted) return;
      showMessage(
        context,
        release == null
            ? '${app.name} já está na versão mais recente.'
            : 'Nova versão disponível: ${release.tag}',
      );
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _updateFromFile() async {
    final path = await pickAppImage();
    if (path == null || !mounted) return;
    await runGuarded(
      context,
      () => manager.updateFromFile(app.id, path),
      success: '${app.name} atualizado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final update = manager.updateFor(app.id);
    final disabled = widget.busy || _checking;
    final source = app.github;

    return _Section(
      title: 'Atualizações',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.back_hand_outlined),
                label: Text('Manual'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.cloud_sync_outlined),
                label: Text('GitHub Releases'),
              ),
            ],
            selected: {app.usesGitHub},
            onSelectionChanged: disabled
                ? null
                : (value) => _changeMode(value.first),
          ),
        ),
        if (source != null) ...[
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: Text(source.slug),
            subtitle: Text(
              [
                source.assetPattern == null
                    ? 'Asset escolhido automaticamente'
                    : 'Padrão: ${source.assetPattern}',
                if (source.includePrereleases) 'inclui pré-lançamentos',
                'última verificação: ${formatDate(app.lastCheckedAt)}',
              ].join(' · '),
            ),
            trailing: IconButton(
              tooltip: 'Configurar',
              onPressed: disabled ? null : _configureGitHub,
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
          if (update != null)
            ListTile(
              leading: Icon(
                Icons.new_releases_outlined,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: Text('Nova versão: ${update.name}'),
              subtitle: Text('Publicada em ${formatDate(update.publishedAt)}'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: disabled ? null : _check,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Verificar agora'),
                ),
                FilledButton.icon(
                  onPressed: disabled || update == null
                      ? null
                      : () => runGuarded(
                          context,
                          () => manager.applyGitHubUpdate(app.id),
                          success: '${app.name} atualizado para ${update.tag}.',
                        ),
                  icon: const Icon(Icons.system_update_alt_rounded),
                  label: Text(
                    update == null
                        ? 'Atualizar'
                        : 'Atualizar para ${update.version}',
                  ),
                ),
              ],
            ),
          ),
        ] else
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('Substituir por um novo arquivo'),
            subtitle: const Text(
              'Escolha a nova versão do .AppImage; atalhos e configurações são mantidos.',
            ),
            trailing: FilledButton.tonal(
              onPressed: disabled ? null : _updateFromFile,
              child: const Text('Selecionar arquivo'),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: SelectableText(value),
    );
  }
}
