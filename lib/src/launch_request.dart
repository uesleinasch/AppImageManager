sealed class LaunchRequest {
  const LaunchRequest();

  static LaunchRequest? parse(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final next = i + 1 < args.length ? args[i + 1] : null;
      switch (arg) {
        case '--update' when next != null:
          return UpdateAppRequest(next);
        case '--remove' when next != null:
          return RemoveAppRequest(next);
        case '--install' when next != null:
          return InstallFileRequest(_toPath(next));
      }
      if (!arg.startsWith('-')) return InstallFileRequest(_toPath(arg));
    }
    return null;
  }

  static String _toPath(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.isScheme('file') ? uri.toFilePath() : value;
  }
}

class UpdateAppRequest extends LaunchRequest {
  const UpdateAppRequest(this.appId);

  final String appId;
}

class RemoveAppRequest extends LaunchRequest {
  const RemoveAppRequest(this.appId);

  final String appId;
}

class InstallFileRequest extends LaunchRequest {
  const InstallFileRequest(this.path);

  final String path;
}
