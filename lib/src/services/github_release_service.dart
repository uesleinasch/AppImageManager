import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/github_source.dart';
import 'version.dart';

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
    name: json['name'] as String,
    downloadUrl: Uri.parse(json['browser_download_url'] as String),
    size: json['size'] as int? ?? 0,
  );

  final String name;
  final Uri downloadUrl;
  final int size;
}

class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.htmlUrl,
    required this.prerelease,
    required this.assets,
    this.publishedAt,
    this.body,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) => ReleaseInfo(
    tag: json['tag_name'] as String,
    name: (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : json['tag_name'] as String,
    htmlUrl: Uri.parse(json['html_url'] as String),
    prerelease: json['prerelease'] as bool? ?? false,
    publishedAt: json['published_at'] == null
        ? null
        : DateTime.tryParse(json['published_at'] as String),
    body: json['body'] as String?,
    assets: (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReleaseAsset.fromJson)
        .toList(),
  );

  final String tag;
  final String name;
  final Uri htmlUrl;
  final bool prerelease;
  final List<ReleaseAsset> assets;
  final DateTime? publishedAt;
  final String? body;

  String get version => normalizeVersion(tag);
}

class GitHubException implements Exception {
  const GitHubException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef DownloadProgress = void Function(int received, int? total);

class GitHubReleaseService {
  GitHubReleaseService({http.Client? client, this.token})
    : _client = client ?? http.Client();

  static const _architectureAliases = {
    'x86_64': ['x86_64', 'x86-64', 'amd64', 'x64'],
    'aarch64': ['aarch64', 'arm64'],
    'armhf': ['armhf', 'armv7l', 'armv7'],
    'i686': ['i386', 'i686'],
  };

  final http.Client _client;
  final String? token;

  static String? currentArchitecture() => switch (Abi.current()) {
    Abi.linuxX64 => 'x86_64',
    Abi.linuxArm64 => 'aarch64',
    Abi.linuxArm => 'armhf',
    Abi.linuxIA32 => 'i686',
    _ => null,
  };

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'AppImageManager',
    if (token case final value? when value.isNotEmpty)
      'Authorization': 'Bearer $value',
  };

  Future<ReleaseInfo> latestRelease(GitHubSource source) async {
    final path = source.includePrereleases
        ? '/repos/${source.owner}/${source.repo}/releases'
        : '/repos/${source.owner}/${source.repo}/releases/latest';
    final uri = Uri.https(
      'api.github.com',
      path,
      source.includePrereleases ? {'per_page': '15'} : null,
    );

    final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers);
    } on SocketException catch (error) {
      throw GitHubException('Sem conexão com o GitHub: ${error.message}');
    } on http.ClientException catch (error) {
      throw GitHubException('Falha ao consultar o GitHub: ${error.message}');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 404:
        throw GitHubException(
          'Nenhum release encontrado em ${source.slug}. '
          'Confira o repositório ou habilite pré-lançamentos.',
        );
      case 403 || 429:
        throw const GitHubException(
          'Limite de requisições da API do GitHub atingido. '
          'Tente novamente mais tarde ou defina GITHUB_TOKEN.',
        );
      default:
        throw GitHubException(
          'O GitHub respondeu com status ${response.statusCode}.',
        );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return ReleaseInfo.fromJson(decoded);
    if (decoded is List) {
      final release = decoded
          .whereType<Map<String, dynamic>>()
          .where((r) => r['draft'] != true)
          .map(ReleaseInfo.fromJson)
          .firstOrNull;
      if (release != null) return release;
    }
    throw GitHubException('Nenhum release publicado em ${source.slug}.');
  }

  static RegExp globToRegExp(String glob) {
    final buffer = StringBuffer('^');
    for (final char in glob.split('')) {
      buffer.write(switch (char) {
        '*' => '.*',
        '?' => '.',
        _ => RegExp.escape(char),
      });
    }
    buffer.write(r'$');
    return RegExp(buffer.toString(), caseSensitive: false);
  }

  static ReleaseAsset? selectAsset(
    ReleaseInfo release, {
    String? pattern,
    String? architecture,
  }) {
    var candidates = release.assets
        .where((a) => a.name.toLowerCase().endsWith('.appimage'))
        .toList();
    if (pattern != null && pattern.isNotEmpty) {
      final regex = globToRegExp(pattern);
      candidates = candidates.where((a) => regex.hasMatch(a.name)).toList();
    }
    if (candidates.length <= 1 || architecture == null) {
      return candidates.firstOrNull;
    }

    bool mentions(String name, List<String> aliases) {
      final lower = name.toLowerCase();
      return aliases.any(
        (alias) =>
            RegExp('(^|[^a-z0-9])${RegExp.escape(alias)}([^a-z0-9]|\$)')
                .hasMatch(lower),
      );
    }

    final own = _architectureAliases[architecture] ?? [architecture];
    final others = _architectureAliases.entries
        .where((e) => e.key != architecture)
        .expand((e) => e.value)
        .where((alias) => !own.contains(alias))
        .toList();

    return candidates.where((a) => mentions(a.name, own)).firstOrNull ??
        candidates.where((a) => !mentions(a.name, others)).firstOrNull;
  }

  Future<void> download(
    ReleaseAsset asset,
    String destination, {
    DownloadProgress? onProgress,
  }) async {
    final request = http.Request('GET', asset.downloadUrl)
      ..headers.addAll({
        'Accept': 'application/octet-stream',
        'User-Agent': 'AppImageManager',
      });

    final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } on SocketException catch (error) {
      throw GitHubException('Falha no download: ${error.message}');
    } on http.ClientException catch (error) {
      throw GitHubException('Falha no download: ${error.message}');
    }
    if (response.statusCode != 200) {
      throw GitHubException(
        'Download de ${asset.name} falhou (status ${response.statusCode}).',
      );
    }

    final total =
        response.contentLength ?? (asset.size > 0 ? asset.size : null);
    final sink = File(destination).openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    if (total != null && received != total) {
      throw GitHubException(
        'Download de ${asset.name} incompleto ($received de $total bytes).',
      );
    }
  }

  void close() => _client.close();
}
