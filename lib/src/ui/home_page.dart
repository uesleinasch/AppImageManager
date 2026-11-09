import 'package:flutter/material.dart';

import '../app.dart';
import '../models/managed_app.dart';
import '../services/app_manager.dart';
import 'app_details_page.dart';
import 'feedback.dart';
import 'install_dialog.dart';
import 'widgets/app_icon.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.manager});

  final AppManager manager;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();

  AppManager get manager => widget.manager;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final app = await showInstallFlow(context, manager);
    if (app != null && mounted) showMessage(context, '${app.name} instalado.');
  }

  Future<void> _checkAll() async {
    final errors = await manager.checkAllUpdates();
    if (!mounted) return;
    if (errors.isNotEmpty) {
      showMessage(context, errors.join('\n'), error: true);
    } else {
      final count = manager.availableUpdates;
      showMessage(
        context,
        count == 0
            ? 'Todos os aplicativos estão atualizados.'
            : '$count atualização(ões) disponível(is).',
      );
    }
  }

  void _openDetails(ManagedApp app) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppDetailsPage(manager: manager, appId: app.id),
      ),
    );
  }

  void _about() {
    showAboutDialog(
      context: context,
      applicationName: 'AppImage Manager',
      applicationVersion: appVersion,
      applicationIcon: const AppIcon(path: null, size: 48),
      applicationLegalese: 'Licença MIT\n$repositoryUrl',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final hasGitHubApps = manager.apps.any((a) => a.usesGitHub);
        return Scaffold(
          appBar: AppBar(
            title: const Text('AppImage Manager'),
            actions: [
              if (hasGitHubApps)
                manager.checkingAll
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Verificar atualizações',
                        onPressed: _checkAll,
                        icon: Badge(
                          isLabelVisible: manager.availableUpdates > 0,
                          label: Text('${manager.availableUpdates}'),
                          child: const Icon(Icons.update_rounded),
                        ),
                      ),
              IconButton(
                tooltip: 'Sobre',
                onPressed: _about,
                icon: const Icon(Icons.info_outline_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: manager.apps.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar'),
                ),
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (manager.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (manager.loadError != null) {
      return _Message(
        icon: Icons.error_outline_rounded,
        title: 'Não foi possível carregar a biblioteca',
        description: '${manager.loadError}\n${manager.paths.libraryFile}',
        action: FilledButton.tonal(
          onPressed: manager.load,
          child: const Text('Tentar novamente'),
        ),
      );
    }
    if (manager.apps.isEmpty) {
      return _Message(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum AppImage gerenciado',
        description:
            'Adicione um arquivo .AppImage para criar o atalho no menu, '
            'configurar o início automático e acompanhar atualizações.',
        action: FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar AppImage'),
        ),
      );
    }

    final query = _search.text.trim().toLowerCase();
    final apps = manager.apps
        .where((a) => query.isEmpty || a.name.toLowerCase().contains(query))
        .toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            SearchBar(
              controller: _search,
              hintText: 'Buscar aplicativos',
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            for (final app in apps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AppTile(
                  app: app,
                  manager: manager,
                  onTap: () => _openDetails(app),
                ),
              ),
            if (apps.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Nenhum aplicativo encontrado.')),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.manager,
    required this.onTap,
  });

  final ManagedApp app;
  final AppManager manager;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final update = manager.updateFor(app.id);
    final task = manager.taskFor(app.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppIcon(path: app.iconPath, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          app.version ?? 'versão desconhecida',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        _Tag(
                          icon: app.usesGitHub
                              ? Icons.cloud_sync_outlined
                              : Icons.back_hand_outlined,
                          label: app.usesGitHub ? app.github!.slug : 'Manual',
                        ),
                        if (app.autostart)
                          const _Tag(
                            icon: Icons.power_settings_new_rounded,
                            label: 'Inicia com o sistema',
                          ),
                        if (update != null)
                          _Tag(
                            icon: Icons.new_releases_outlined,
                            label: 'Nova versão ${update.version}',
                            highlight: true,
                          ),
                      ],
                    ),
                    if (task != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: task.progress),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Abrir',
                onPressed: () =>
                    runGuarded(context, () => manager.launch(app.id)),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, this.highlight = false});

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = highlight
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = highlight
        ? scheme.onTertiaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              action,
            ],
          ),
        ),
      ),
    );
  }
}
