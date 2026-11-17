class GitHubSource {
  const GitHubSource({
    required this.owner,
    required this.repo,
    this.assetPattern,
    this.includePrereleases = false,
  });

  factory GitHubSource.fromJson(Map<String, dynamic> json) => GitHubSource(
    owner: json['owner'] as String,
    repo: json['repo'] as String,
    assetPattern: json['assetPattern'] as String?,
    includePrereleases: json['includePrereleases'] as bool? ?? false,
  );

  static final _ownerPattern = RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$',
  );
  static final _repoPattern = RegExp(r'^[A-Za-z0-9_.-]+$');

  static final _zsyncLatestUrl = RegExp(
    r'^https://github\.com/([^/]+)/([^/]+)/releases/latest/download/([^/]+)\.zsync$',
  );

  static GitHubSource? fromUpdateInformation(String? information) {
    final parts = (information ?? '').trim().split('|');
    if (parts.length == 5 && parts[0] == 'gh-releases-zsync') {
      final channel = parts[3];
      if (!const {'latest', 'latest-pre', 'latest-all'}.contains(channel)) {
        return null;
      }
      final pattern = parts[4].replaceFirst(RegExp(r'\.zsync$'), '');
      return tryParse(
        '${parts[1]}/${parts[2]}',
        assetPattern: pattern == '*' ? null : pattern,
        includePrereleases: channel != 'latest',
      );
    }
    if (parts.length == 2 && parts[0] == 'zsync') {
      final match = _zsyncLatestUrl.firstMatch(parts[1]);
      if (match == null) return null;
      return tryParse(
        '${match[1]}/${match[2]}',
        assetPattern: Uri.decodeComponent(match[3]!),
      );
    }
    return null;
  }

  static GitHubSource? tryParse(
    String input, {
    String? assetPattern,
    bool includePrereleases = false,
  }) {
    var text = input.trim();
    if (text.isEmpty) return null;

    text = text
        .replaceFirst(RegExp(r'^git@github\.com:'), '')
        .replaceFirst(RegExp(r'^(https?://)?(www\.)?github\.com/'), '');

    final segments = text.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;

    final owner = segments[0];
    final repo = segments[1].replaceFirst(RegExp(r'\.git$'), '');
    if (!_ownerPattern.hasMatch(owner) || !_repoPattern.hasMatch(repo)) {
      return null;
    }

    final pattern = assetPattern?.trim();
    return GitHubSource(
      owner: owner,
      repo: repo,
      assetPattern: pattern == null || pattern.isEmpty ? null : pattern,
      includePrereleases: includePrereleases,
    );
  }

  final String owner;
  final String repo;
  final String? assetPattern;
  final bool includePrereleases;

  String get slug => '$owner/$repo';

  Uri get webUrl => Uri.https('github.com', '/$owner/$repo');

  Map<String, dynamic> toJson() => {
    'owner': owner,
    'repo': repo,
    if (assetPattern != null) 'assetPattern': assetPattern,
    'includePrereleases': includePrereleases,
  };

  @override
  bool operator ==(Object other) =>
      other is GitHubSource &&
      other.owner == owner &&
      other.repo == repo &&
      other.assetPattern == assetPattern &&
      other.includePrereleases == includePrereleases;

  @override
  int get hashCode =>
      Object.hash(owner, repo, assetPattern, includePrereleases);
}
