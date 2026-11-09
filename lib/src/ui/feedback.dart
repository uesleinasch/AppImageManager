import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

const appImageTypeGroup = XTypeGroup(
  label: 'AppImage',
  extensions: ['AppImage', 'appimage'],
  mimeTypes: ['application/vnd.appimage', 'application/x-iso9660-appimage'],
);

Future<String?> pickAppImage() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      appImageTypeGroup,
      XTypeGroup(label: 'Todos os arquivos'),
    ],
    confirmButtonText: 'Selecionar',
  );
  return file?.path;
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.errorContainer : null,
        showCloseIcon: true,
        closeIconColor: error ? scheme.onErrorContainer : null,
      ),
    );
}

Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) showMessage(context, success);
    return true;
  } catch (error) {
    if (context.mounted) showMessage(context, error.toString(), error: true);
    return false;
  }
}

String formatDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
