import 'github_source.dart';

const Object _unset = Object();

class ManagedApp {
  const ManagedApp({
    required this.id,
    required this.name,
    required this.appImagePath,
    required this.installedAt,
    required this.updatedAt,
    this.version,
    this.comment,
    this.iconPath,
    this.categories = const [],
    this.execArgs,
    this.startupWmClass,
    this.menuEntry = true,
    this.autostart = false,
    this.github,
    this.releaseTag,
    this.lastCheckedAt,
  });

  factory ManagedApp.fromJson(Map<String, dynamic> json) => ManagedApp(
    id: json['id'] as String,
    name: json['name'] as String,
    appImagePath: json['appImagePath'] as String,
    installedAt: DateTime.parse(json['installedAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    version: json['version'] as String?,
    comment: json['comment'] as String?,
    iconPath: json['iconPath'] as String?,
    categories: (json['categories'] as List<dynamic>? ?? const [])
        .cast<String>(),
    execArgs: json['execArgs'] as String?,
    startupWmClass: json['startupWmClass'] as String?,
    menuEntry: json['menuEntry'] as bool? ?? true,
    autostart: json['autostart'] as bool? ?? false,
    github: json['github'] == null
        ? null
        : GitHubSource.fromJson(json['github'] as Map<String, dynamic>),
    releaseTag: json['releaseTag'] as String?,
    lastCheckedAt: json['lastCheckedAt'] == null
        ? null
        : DateTime.parse(json['lastCheckedAt'] as String),
  );

  final String id;
  final String name;
  final String appImagePath;
  final DateTime installedAt;
  final DateTime updatedAt;
  final String? version;
  final String? comment;
  final String? iconPath;
  final List<String> categories;
  final String? execArgs;
  final String? startupWmClass;
  final bool menuEntry;
  final bool autostart;
  final GitHubSource? github;
  final String? releaseTag;
  final DateTime? lastCheckedAt;

  bool get usesGitHub => github != null;

  ManagedApp copyWith({
    String? name,
    String? appImagePath,
    DateTime? updatedAt,
    Object? version = _unset,
    Object? comment = _unset,
    Object? iconPath = _unset,
    List<String>? categories,
    Object? execArgs = _unset,
    Object? startupWmClass = _unset,
    bool? menuEntry,
    bool? autostart,
    Object? github = _unset,
    Object? releaseTag = _unset,
    Object? lastCheckedAt = _unset,
  }) {
    return ManagedApp(
      id: id,
      name: name ?? this.name,
      appImagePath: appImagePath ?? this.appImagePath,
      installedAt: installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: identical(version, _unset) ? this.version : version as String?,
      comment: identical(comment, _unset) ? this.comment : comment as String?,
      iconPath: identical(iconPath, _unset)
          ? this.iconPath
          : iconPath as String?,
      categories: categories ?? this.categories,
      execArgs: identical(execArgs, _unset)
          ? this.execArgs
          : execArgs as String?,
      startupWmClass: identical(startupWmClass, _unset)
          ? this.startupWmClass
          : startupWmClass as String?,
      menuEntry: menuEntry ?? this.menuEntry,
      autostart: autostart ?? this.autostart,
      github: identical(github, _unset) ? this.github : github as GitHubSource?,
      releaseTag: identical(releaseTag, _unset)
          ? this.releaseTag
          : releaseTag as String?,
      lastCheckedAt: identical(lastCheckedAt, _unset)
          ? this.lastCheckedAt
          : lastCheckedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'appImagePath': appImagePath,
    'installedAt': installedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (version != null) 'version': version,
    if (comment != null) 'comment': comment,
    if (iconPath != null) 'iconPath': iconPath,
    if (categories.isNotEmpty) 'categories': categories,
    if (execArgs != null) 'execArgs': execArgs,
    if (startupWmClass != null) 'startupWmClass': startupWmClass,
    'menuEntry': menuEntry,
    'autostart': autostart,
    if (github != null) 'github': github!.toJson(),
    if (releaseTag != null) 'releaseTag': releaseTag,
    if (lastCheckedAt != null)
      'lastCheckedAt': lastCheckedAt!.toIso8601String(),
  };
}
