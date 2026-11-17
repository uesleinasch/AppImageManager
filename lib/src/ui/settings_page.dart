import 'package:flutter/material.dart';

import '../services/app_manager.dart';
import 'feedback.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.manager});

  final AppManager manager;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<bool> _isDefault = widget.manager.isDefaultAppImageHandler();

  AppManager get manager => widget.manager;

  Future<void> _makeDefault() async {
    final ok = await runGuarded(
      context,
      manager.makeDefaultAppImageHandler,
      success: 'AppImages agora abrem com o AppImage Manager.',
    );
    if (ok && mounted) {
      setState(() => _isDefault = manager.isDefaultAppImageHandler());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final settings = manager.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Configurações')),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.update_rounded),
                          title: const Text('Verificar atualizações ao abrir'),
                          subtitle: const Text(
                            'Consulta o GitHub dos apps vinculados sempre que o '
                            'AppImage Manager abre',
                          ),
                          value: settings.checkUpdatesOnStart,
                          onChanged: (value) => runGuarded(
                            context,
                            () => manager.updateSettings(
                              settings.copyWith(checkUpdatesOnStart: value),
                            ),
                          ),
                        ),
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.cleaning_services_outlined,
                          ),
                          title: const Text(
                            'Limpar apps cujo arquivo foi apagado',
                          ),
                          subtitle: const Text(
                            'Remove atalhos, ícone e tipos de arquivo quando o '
                            '.AppImage some de ~/Applications',
                          ),
                          value: settings.cleanupMissing,
                          onChanged: (value) => runGuarded(
                            context,
                            () => manager.updateSettings(
                              settings.copyWith(cleanupMissing: value),
                            ),
                          ),
                        ),
                        FutureBuilder<bool>(
                          future: _isDefault,
                          builder: (context, snapshot) {
                            final isDefault = snapshot.data ?? false;
                            return ListTile(
                              leading: const Icon(Icons.open_in_new_rounded),
                              title: const Text(
                                'Abrir arquivos .AppImage com o AppImage Manager',
                              ),
                              subtitle: Text(
                                isDefault
                                    ? 'Já é o aplicativo padrão'
                                    : 'O duplo clique passa a oferecer '
                                          '"Integrar e abrir". Requer o pacote '
                                          '.deb instalado.',
                              ),
                              trailing: isDefault
                                  ? const Icon(Icons.check_circle_outline)
                                  : FilledButton.tonal(
                                      onPressed: snapshot.hasData
                                          ? _makeDefault
                                          : null,
                                      child: const Text('Definir como padrão'),
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
