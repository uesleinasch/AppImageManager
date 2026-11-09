class DesktopEntry {
  DesktopEntry(this.values);

  factory DesktopEntry.parse(String content, {String? locale}) {
    final values = <String, String>{};
    final localized = <String, String>{};
    var inMainGroup = false;

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        inMainGroup = line == '[$mainGroup]';
        continue;
      }
      if (!inMainGroup) continue;

      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = unescapeValue(line.substring(separator + 1).trim());

      final localeStart = key.indexOf('[');
      if (localeStart > 0 && key.endsWith(']')) {
        final baseKey = key.substring(0, localeStart);
        final keyLocale = key.substring(localeStart + 1, key.length - 1);
        if (locale != null && _localeMatches(keyLocale, locale)) {
          localized[baseKey] = value;
        }
        continue;
      }
      values.putIfAbsent(key, () => value);
    }

    values.addAll(localized);
    return DesktopEntry(values);
  }

  static const mainGroup = 'Desktop Entry';

  final Map<String, String> values;

  String? operator [](String key) {
    final value = values[key];
    return value == null || value.isEmpty ? null : value;
  }

  List<String> list(String key) => (this[key] ?? '')
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  String? get execArguments {
    final exec = this['Exec'];
    if (exec == null) return null;
    final tokens = splitExec(exec);
    if (tokens.length <= 1) return null;
    return tokens.skip(1).map(quoteExecArg).join(' ');
  }

  static bool _localeMatches(String keyLocale, String locale) {
    final normalized = locale.split('.').first.split('@').first;
    return keyLocale == normalized || keyLocale == normalized.split('_').first;
  }

  static String escapeValue(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t')
      .replaceAll('\r', r'\r');

  static String unescapeValue(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char != r'\' || i == value.length - 1) {
        buffer.write(char);
        continue;
      }
      final next = value[++i];
      buffer.write(switch (next) {
        's' => ' ',
        'n' => '\n',
        't' => '\t',
        'r' => '\r',
        r'\' => r'\',
        _ => '\\$next',
      });
    }
    return buffer.toString();
  }

  static final _reservedExecChars = RegExp(r'''[\s"'\\><~|&;$*?#()`]''');

  static String quoteExecArg(String arg) {
    if (arg.isNotEmpty && !_reservedExecChars.hasMatch(arg)) return arg;
    final escaped = arg.replaceAllMapped(
      RegExp(r'["`$\\]'),
      (m) => '\\${m[0]}',
    );
    return '"$escaped"';
  }

  static List<String> splitExec(String exec) {
    final tokens = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    var hasToken = false;

    for (var i = 0; i < exec.length; i++) {
      final char = exec[i];
      if (inQuotes) {
        if (char == r'\' && i + 1 < exec.length) {
          current.write(exec[++i]);
        } else if (char == '"') {
          inQuotes = false;
        } else {
          current.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
        hasToken = true;
      } else if (char == ' ' || char == '\t') {
        if (hasToken) {
          tokens.add(current.toString());
          current.clear();
          hasToken = false;
        }
      } else {
        current.write(char);
        hasToken = true;
      }
    }
    if (hasToken) tokens.add(current.toString());
    return tokens;
  }

  static String build(Map<String, String> entries) {
    final buffer = StringBuffer('[$mainGroup]\n');
    entries.forEach((key, value) => buffer.write('$key=$value\n'));
    return buffer.toString();
  }
}
