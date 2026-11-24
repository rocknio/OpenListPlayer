// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;
  final DateTime createdAt;
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Playlist copyWith({int? id, String? name, DateTime? createdAt}) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistItemsTable extends PlaylistItems
    with TableInfo<$PlaylistItemsTable, PlaylistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isVideoMeta = const VerificationMeta(
    'isVideo',
  );
  @override
  late final GeneratedColumn<bool> isVideo = GeneratedColumn<bool>(
    'is_video',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_video" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _thumbMeta = const VerificationMeta('thumb');
  @override
  late final GeneratedColumn<String> thumb = GeneratedColumn<String>(
    'thumb',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    path,
    name,
    isVideo,
    size,
    thumb,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_video')) {
      context.handle(
        _isVideoMeta,
        isVideo.isAcceptableOrUnknown(data['is_video']!, _isVideoMeta),
      );
    } else if (isInserting) {
      context.missing(_isVideoMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('thumb')) {
      context.handle(
        _thumbMeta,
        thumb.isAcceptableOrUnknown(data['thumb']!, _thumbMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isVideo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_video'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      thumb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistItemsTable createAlias(String alias) {
    return $PlaylistItemsTable(attachedDatabase, alias);
  }
}

class PlaylistItem extends DataClass implements Insertable<PlaylistItem> {
  final int id;
  final int playlistId;
  final String path;
  final String name;
  final bool isVideo;
  final int size;
  final String thumb;
  final int position;
  const PlaylistItem({
    required this.id,
    required this.playlistId,
    required this.path,
    required this.name,
    required this.isVideo,
    required this.size,
    required this.thumb,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['is_video'] = Variable<bool>(isVideo);
    map['size'] = Variable<int>(size);
    map['thumb'] = Variable<String>(thumb);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistItemsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistItemsCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      path: Value(path),
      name: Value(name),
      isVideo: Value(isVideo),
      size: Value(size),
      thumb: Value(thumb),
      position: Value(position),
    );
  }

  factory PlaylistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistItem(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      isVideo: serializer.fromJson<bool>(json['isVideo']),
      size: serializer.fromJson<int>(json['size']),
      thumb: serializer.fromJson<String>(json['thumb']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'isVideo': serializer.toJson<bool>(isVideo),
      'size': serializer.toJson<int>(size),
      'thumb': serializer.toJson<String>(thumb),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistItem copyWith({
    int? id,
    int? playlistId,
    String? path,
    String? name,
    bool? isVideo,
    int? size,
    String? thumb,
    int? position,
  }) => PlaylistItem(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    path: path ?? this.path,
    name: name ?? this.name,
    isVideo: isVideo ?? this.isVideo,
    size: size ?? this.size,
    thumb: thumb ?? this.thumb,
    position: position ?? this.position,
  );
  PlaylistItem copyWithCompanion(PlaylistItemsCompanion data) {
    return PlaylistItem(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      isVideo: data.isVideo.present ? data.isVideo.value : this.isVideo,
      size: data.size.present ? data.size.value : this.size,
      thumb: data.thumb.present ? data.thumb.value : this.thumb,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItem(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('isVideo: $isVideo, ')
          ..write('size: $size, ')
          ..write('thumb: $thumb, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, playlistId, path, name, isVideo, size, thumb, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistItem &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.path == this.path &&
          other.name == this.name &&
          other.isVideo == this.isVideo &&
          other.size == this.size &&
          other.thumb == this.thumb &&
          other.position == this.position);
}

class PlaylistItemsCompanion extends UpdateCompanion<PlaylistItem> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> path;
  final Value<String> name;
  final Value<bool> isVideo;
  final Value<int> size;
  final Value<String> thumb;
  final Value<int> position;
  const PlaylistItemsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.isVideo = const Value.absent(),
    this.size = const Value.absent(),
    this.thumb = const Value.absent(),
    this.position = const Value.absent(),
  });
  PlaylistItemsCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String path,
    required String name,
    required bool isVideo,
    this.size = const Value.absent(),
    this.thumb = const Value.absent(),
    required int position,
  }) : playlistId = Value(playlistId),
       path = Value(path),
       name = Value(name),
       isVideo = Value(isVideo),
       position = Value(position);
  static Insertable<PlaylistItem> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? path,
    Expression<String>? name,
    Expression<bool>? isVideo,
    Expression<int>? size,
    Expression<String>? thumb,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (isVideo != null) 'is_video': isVideo,
      if (size != null) 'size': size,
      if (thumb != null) 'thumb': thumb,
      if (position != null) 'position': position,
    });
  }

  PlaylistItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? path,
    Value<String>? name,
    Value<bool>? isVideo,
    Value<int>? size,
    Value<String>? thumb,
    Value<int>? position,
  }) {
    return PlaylistItemsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      path: path ?? this.path,
      name: name ?? this.name,
      isVideo: isVideo ?? this.isVideo,
      size: size ?? this.size,
      thumb: thumb ?? this.thumb,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isVideo.present) {
      map['is_video'] = Variable<bool>(isVideo.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (thumb.present) {
      map['thumb'] = Variable<String>(thumb.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItemsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('isVideo: $isVideo, ')
          ..write('size: $size, ')
          ..write('thumb: $thumb, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $PlayProgressesTable extends PlayProgresses
    with TableInfo<$PlayProgressesTable, PlayProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    positionMs,
    durationMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayProgress> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  PlayProgress map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayProgress(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlayProgressesTable createAlias(String alias) {
    return $PlayProgressesTable(attachedDatabase, alias);
  }
}

class PlayProgress extends DataClass implements Insertable<PlayProgress> {
  final String path;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;
  const PlayProgress({
    required this.path,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlayProgressesCompanion toCompanion(bool nullToAbsent) {
    return PlayProgressesCompanion(
      path: Value(path),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlayProgress.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayProgress(
      path: serializer.fromJson<String>(json['path']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlayProgress copyWith({
    String? path,
    int? positionMs,
    int? durationMs,
    DateTime? updatedAt,
  }) => PlayProgress(
    path: path ?? this.path,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlayProgress copyWithCompanion(PlayProgressesCompanion data) {
    return PlayProgress(
      path: data.path.present ? data.path.value : this.path,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayProgress(')
          ..write('path: $path, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, positionMs, durationMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayProgress &&
          other.path == this.path &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt);
}

class PlayProgressesCompanion extends UpdateCompanion<PlayProgress> {
  final Value<String> path;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlayProgressesCompanion({
    this.path = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayProgressesCompanion.insert({
    required String path,
    required int positionMs,
    required int durationMs,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       positionMs = Value(positionMs),
       durationMs = Value(durationMs),
       updatedAt = Value(updatedAt);
  static Insertable<PlayProgress> custom({
    Expression<String>? path,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayProgressesCompanion copyWith({
    Value<String>? path,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlayProgressesCompanion(
      path: path ?? this.path,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayProgressesCompanion(')
          ..write('path: $path, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistProgressesTable extends PlaylistProgresses
    with TableInfo<$PlaylistProgressesTable, PlaylistProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedMeta = const VerificationMeta(
    'finished',
  );
  @override
  late final GeneratedColumn<bool> finished = GeneratedColumn<bool>(
    'finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    path,
    positionMs,
    durationMs,
    finished,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistProgress> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('finished')) {
      context.handle(
        _finishedMeta,
        finished.isAcceptableOrUnknown(data['finished']!, _finishedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, path};
  @override
  PlaylistProgress map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistProgress(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      finished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}finished'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistProgressesTable createAlias(String alias) {
    return $PlaylistProgressesTable(attachedDatabase, alias);
  }
}

class PlaylistProgress extends DataClass
    implements Insertable<PlaylistProgress> {
  final int playlistId;
  final String path;
  final int positionMs;
  final int durationMs;

  /// 已看完：下次在本播单内从头播
  final bool finished;
  final DateTime updatedAt;
  const PlaylistProgress({
    required this.playlistId,
    required this.path,
    required this.positionMs,
    required this.durationMs,
    required this.finished,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['path'] = Variable<String>(path);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['finished'] = Variable<bool>(finished);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaylistProgressesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistProgressesCompanion(
      playlistId: Value(playlistId),
      path: Value(path),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      finished: Value(finished),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaylistProgress.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistProgress(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      path: serializer.fromJson<String>(json['path']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      finished: serializer.fromJson<bool>(json['finished']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'path': serializer.toJson<String>(path),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'finished': serializer.toJson<bool>(finished),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaylistProgress copyWith({
    int? playlistId,
    String? path,
    int? positionMs,
    int? durationMs,
    bool? finished,
    DateTime? updatedAt,
  }) => PlaylistProgress(
    playlistId: playlistId ?? this.playlistId,
    path: path ?? this.path,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    finished: finished ?? this.finished,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaylistProgress copyWithCompanion(PlaylistProgressesCompanion data) {
    return PlaylistProgress(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      path: data.path.present ? data.path.value : this.path,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      finished: data.finished.present ? data.finished.value : this.finished,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistProgress(')
          ..write('playlistId: $playlistId, ')
          ..write('path: $path, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('finished: $finished, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playlistId,
    path,
    positionMs,
    durationMs,
    finished,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistProgress &&
          other.playlistId == this.playlistId &&
          other.path == this.path &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.finished == this.finished &&
          other.updatedAt == this.updatedAt);
}

class PlaylistProgressesCompanion extends UpdateCompanion<PlaylistProgress> {
  final Value<int> playlistId;
  final Value<String> path;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<bool> finished;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaylistProgressesCompanion({
    this.playlistId = const Value.absent(),
    this.path = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.finished = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistProgressesCompanion.insert({
    required int playlistId,
    required String path,
    required int positionMs,
    required int durationMs,
    this.finished = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       path = Value(path),
       positionMs = Value(positionMs),
       durationMs = Value(durationMs),
       updatedAt = Value(updatedAt);
  static Insertable<PlaylistProgress> custom({
    Expression<int>? playlistId,
    Expression<String>? path,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<bool>? finished,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (path != null) 'path': path,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (finished != null) 'finished': finished,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistProgressesCompanion copyWith({
    Value<int>? playlistId,
    Value<String>? path,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<bool>? finished,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaylistProgressesCompanion(
      playlistId: playlistId ?? this.playlistId,
      path: path ?? this.path,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      finished: finished ?? this.finished,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (finished.present) {
      map['finished'] = Variable<bool>(finished.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistProgressesCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('path: $path, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('finished: $finished, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistStatesTable extends PlaylistStates
    with TableInfo<$PlaylistStatesTable, PlaylistState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, path, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId};
  @override
  PlaylistState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistState(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistStatesTable createAlias(String alias) {
    return $PlaylistStatesTable(attachedDatabase, alias);
  }
}

class PlaylistState extends DataClass implements Insertable<PlaylistState> {
  final int playlistId;
  final String path;
  final DateTime updatedAt;
  const PlaylistState({
    required this.playlistId,
    required this.path,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['path'] = Variable<String>(path);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaylistStatesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistStatesCompanion(
      playlistId: Value(playlistId),
      path: Value(path),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaylistState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistState(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      path: serializer.fromJson<String>(json['path']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'path': serializer.toJson<String>(path),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaylistState copyWith({
    int? playlistId,
    String? path,
    DateTime? updatedAt,
  }) => PlaylistState(
    playlistId: playlistId ?? this.playlistId,
    path: path ?? this.path,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaylistState copyWithCompanion(PlaylistStatesCompanion data) {
    return PlaylistState(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      path: data.path.present ? data.path.value : this.path,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistState(')
          ..write('playlistId: $playlistId, ')
          ..write('path: $path, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, path, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistState &&
          other.playlistId == this.playlistId &&
          other.path == this.path &&
          other.updatedAt == this.updatedAt);
}

class PlaylistStatesCompanion extends UpdateCompanion<PlaylistState> {
  final Value<int> playlistId;
  final Value<String> path;
  final Value<DateTime> updatedAt;
  const PlaylistStatesCompanion({
    this.playlistId = const Value.absent(),
    this.path = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaylistStatesCompanion.insert({
    this.playlistId = const Value.absent(),
    required String path,
    this.updatedAt = const Value.absent(),
  }) : path = Value(path);
  static Insertable<PlaylistState> custom({
    Expression<int>? playlistId,
    Expression<String>? path,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (path != null) 'path': path,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaylistStatesCompanion copyWith({
    Value<int>? playlistId,
    Value<String>? path,
    Value<DateTime>? updatedAt,
  }) {
    return PlaylistStatesCompanion(
      playlistId: playlistId ?? this.playlistId,
      path: path ?? this.path,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistStatesCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('path: $path, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoriesTable extends PlayHistories
    with TableInfo<$PlayHistoriesTable, PlayHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isVideoMeta = const VerificationMeta(
    'isVideo',
  );
  @override
  late final GeneratedColumn<bool> isVideo = GeneratedColumn<bool>(
    'is_video',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_video" IN (0, 1))',
    ),
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, name, isVideo, playedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_video')) {
      context.handle(
        _isVideoMeta,
        isVideo.isAcceptableOrUnknown(data['is_video']!, _isVideoMeta),
      );
    } else if (isInserting) {
      context.missing(_isVideoMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  PlayHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistory(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isVideo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_video'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at'],
      )!,
    );
  }

  @override
  $PlayHistoriesTable createAlias(String alias) {
    return $PlayHistoriesTable(attachedDatabase, alias);
  }
}

class PlayHistory extends DataClass implements Insertable<PlayHistory> {
  final String path;
  final String name;
  final bool isVideo;
  final DateTime playedAt;
  const PlayHistory({
    required this.path,
    required this.name,
    required this.isVideo,
    required this.playedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['is_video'] = Variable<bool>(isVideo);
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  PlayHistoriesCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoriesCompanion(
      path: Value(path),
      name: Value(name),
      isVideo: Value(isVideo),
      playedAt: Value(playedAt),
    );
  }

  factory PlayHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistory(
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      isVideo: serializer.fromJson<bool>(json['isVideo']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'isVideo': serializer.toJson<bool>(isVideo),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  PlayHistory copyWith({
    String? path,
    String? name,
    bool? isVideo,
    DateTime? playedAt,
  }) => PlayHistory(
    path: path ?? this.path,
    name: name ?? this.name,
    isVideo: isVideo ?? this.isVideo,
    playedAt: playedAt ?? this.playedAt,
  );
  PlayHistory copyWithCompanion(PlayHistoriesCompanion data) {
    return PlayHistory(
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      isVideo: data.isVideo.present ? data.isVideo.value : this.isVideo,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistory(')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('isVideo: $isVideo, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, name, isVideo, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistory &&
          other.path == this.path &&
          other.name == this.name &&
          other.isVideo == this.isVideo &&
          other.playedAt == this.playedAt);
}

class PlayHistoriesCompanion extends UpdateCompanion<PlayHistory> {
  final Value<String> path;
  final Value<String> name;
  final Value<bool> isVideo;
  final Value<DateTime> playedAt;
  final Value<int> rowid;
  const PlayHistoriesCompanion({
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.isVideo = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayHistoriesCompanion.insert({
    required String path,
    required String name,
    required bool isVideo,
    required DateTime playedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       name = Value(name),
       isVideo = Value(isVideo),
       playedAt = Value(playedAt);
  static Insertable<PlayHistory> custom({
    Expression<String>? path,
    Expression<String>? name,
    Expression<bool>? isVideo,
    Expression<DateTime>? playedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (isVideo != null) 'is_video': isVideo,
      if (playedAt != null) 'played_at': playedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayHistoriesCompanion copyWith({
    Value<String>? path,
    Value<String>? name,
    Value<bool>? isVideo,
    Value<DateTime>? playedAt,
    Value<int>? rowid,
  }) {
    return PlayHistoriesCompanion(
      path: path ?? this.path,
      name: name ?? this.name,
      isVideo: isVideo ?? this.isVideo,
      playedAt: playedAt ?? this.playedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isVideo.present) {
      map['is_video'] = Variable<bool>(isVideo.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoriesCompanion(')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('isVideo: $isVideo, ')
          ..write('playedAt: $playedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackPrefsTableTable extends TrackPrefsTable
    with TableInfo<$TrackPrefsTableTable, TrackPrefs> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackPrefsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioTrackMeta = const VerificationMeta(
    'audioTrack',
  );
  @override
  late final GeneratedColumn<String> audioTrack = GeneratedColumn<String>(
    'audio_track',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subtitleTrackMeta = const VerificationMeta(
    'subtitleTrack',
  );
  @override
  late final GeneratedColumn<String> subtitleTrack = GeneratedColumn<String>(
    'subtitle_track',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subDelayMsMeta = const VerificationMeta(
    'subDelayMs',
  );
  @override
  late final GeneratedColumn<int> subDelayMs = GeneratedColumn<int>(
    'sub_delay_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    audioTrack,
    subtitleTrack,
    subDelayMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_prefs_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackPrefs> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('audio_track')) {
      context.handle(
        _audioTrackMeta,
        audioTrack.isAcceptableOrUnknown(data['audio_track']!, _audioTrackMeta),
      );
    }
    if (data.containsKey('subtitle_track')) {
      context.handle(
        _subtitleTrackMeta,
        subtitleTrack.isAcceptableOrUnknown(
          data['subtitle_track']!,
          _subtitleTrackMeta,
        ),
      );
    }
    if (data.containsKey('sub_delay_ms')) {
      context.handle(
        _subDelayMsMeta,
        subDelayMs.isAcceptableOrUnknown(
          data['sub_delay_ms']!,
          _subDelayMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  TrackPrefs map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackPrefs(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      audioTrack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_track'],
      ),
      subtitleTrack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle_track'],
      ),
      subDelayMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sub_delay_ms'],
      )!,
    );
  }

  @override
  $TrackPrefsTableTable createAlias(String alias) {
    return $TrackPrefsTableTable(attachedDatabase, alias);
  }
}

class TrackPrefs extends DataClass implements Insertable<TrackPrefs> {
  final String path;
  final String? audioTrack;
  final String? subtitleTrack;
  final int subDelayMs;
  const TrackPrefs({
    required this.path,
    this.audioTrack,
    this.subtitleTrack,
    required this.subDelayMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || audioTrack != null) {
      map['audio_track'] = Variable<String>(audioTrack);
    }
    if (!nullToAbsent || subtitleTrack != null) {
      map['subtitle_track'] = Variable<String>(subtitleTrack);
    }
    map['sub_delay_ms'] = Variable<int>(subDelayMs);
    return map;
  }

  TrackPrefsTableCompanion toCompanion(bool nullToAbsent) {
    return TrackPrefsTableCompanion(
      path: Value(path),
      audioTrack: audioTrack == null && nullToAbsent
          ? const Value.absent()
          : Value(audioTrack),
      subtitleTrack: subtitleTrack == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitleTrack),
      subDelayMs: Value(subDelayMs),
    );
  }

  factory TrackPrefs.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackPrefs(
      path: serializer.fromJson<String>(json['path']),
      audioTrack: serializer.fromJson<String?>(json['audioTrack']),
      subtitleTrack: serializer.fromJson<String?>(json['subtitleTrack']),
      subDelayMs: serializer.fromJson<int>(json['subDelayMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'audioTrack': serializer.toJson<String?>(audioTrack),
      'subtitleTrack': serializer.toJson<String?>(subtitleTrack),
      'subDelayMs': serializer.toJson<int>(subDelayMs),
    };
  }

  TrackPrefs copyWith({
    String? path,
    Value<String?> audioTrack = const Value.absent(),
    Value<String?> subtitleTrack = const Value.absent(),
    int? subDelayMs,
  }) => TrackPrefs(
    path: path ?? this.path,
    audioTrack: audioTrack.present ? audioTrack.value : this.audioTrack,
    subtitleTrack: subtitleTrack.present
        ? subtitleTrack.value
        : this.subtitleTrack,
    subDelayMs: subDelayMs ?? this.subDelayMs,
  );
  TrackPrefs copyWithCompanion(TrackPrefsTableCompanion data) {
    return TrackPrefs(
      path: data.path.present ? data.path.value : this.path,
      audioTrack: data.audioTrack.present
          ? data.audioTrack.value
          : this.audioTrack,
      subtitleTrack: data.subtitleTrack.present
          ? data.subtitleTrack.value
          : this.subtitleTrack,
      subDelayMs: data.subDelayMs.present
          ? data.subDelayMs.value
          : this.subDelayMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackPrefs(')
          ..write('path: $path, ')
          ..write('audioTrack: $audioTrack, ')
          ..write('subtitleTrack: $subtitleTrack, ')
          ..write('subDelayMs: $subDelayMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, audioTrack, subtitleTrack, subDelayMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackPrefs &&
          other.path == this.path &&
          other.audioTrack == this.audioTrack &&
          other.subtitleTrack == this.subtitleTrack &&
          other.subDelayMs == this.subDelayMs);
}

class TrackPrefsTableCompanion extends UpdateCompanion<TrackPrefs> {
  final Value<String> path;
  final Value<String?> audioTrack;
  final Value<String?> subtitleTrack;
  final Value<int> subDelayMs;
  final Value<int> rowid;
  const TrackPrefsTableCompanion({
    this.path = const Value.absent(),
    this.audioTrack = const Value.absent(),
    this.subtitleTrack = const Value.absent(),
    this.subDelayMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackPrefsTableCompanion.insert({
    required String path,
    this.audioTrack = const Value.absent(),
    this.subtitleTrack = const Value.absent(),
    this.subDelayMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path);
  static Insertable<TrackPrefs> custom({
    Expression<String>? path,
    Expression<String>? audioTrack,
    Expression<String>? subtitleTrack,
    Expression<int>? subDelayMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (audioTrack != null) 'audio_track': audioTrack,
      if (subtitleTrack != null) 'subtitle_track': subtitleTrack,
      if (subDelayMs != null) 'sub_delay_ms': subDelayMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackPrefsTableCompanion copyWith({
    Value<String>? path,
    Value<String?>? audioTrack,
    Value<String?>? subtitleTrack,
    Value<int>? subDelayMs,
    Value<int>? rowid,
  }) {
    return TrackPrefsTableCompanion(
      path: path ?? this.path,
      audioTrack: audioTrack ?? this.audioTrack,
      subtitleTrack: subtitleTrack ?? this.subtitleTrack,
      subDelayMs: subDelayMs ?? this.subDelayMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (audioTrack.present) {
      map['audio_track'] = Variable<String>(audioTrack.value);
    }
    if (subtitleTrack.present) {
      map['subtitle_track'] = Variable<String>(subtitleTrack.value);
    }
    if (subDelayMs.present) {
      map['sub_delay_ms'] = Variable<int>(subDelayMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackPrefsTableCompanion(')
          ..write('path: $path, ')
          ..write('audioTrack: $audioTrack, ')
          ..write('subtitleTrack: $subtitleTrack, ')
          ..write('subDelayMs: $subDelayMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionStateTable extends SessionState
    with TableInfo<$SessionStateTable, SessionStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _queueJsonMeta = const VerificationMeta(
    'queueJson',
  );
  @override
  late final GeneratedColumn<String> queueJson = GeneratedColumn<String>(
    'queue_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentIndexMeta = const VerificationMeta(
    'currentIndex',
  );
  @override
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
    'current_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourcePlaylistIdMeta = const VerificationMeta(
    'sourcePlaylistId',
  );
  @override
  late final GeneratedColumn<int> sourcePlaylistId = GeneratedColumn<int>(
    'source_playlist_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    queueJson,
    currentIndex,
    positionMs,
    durationMs,
    sourcePlaylistId,
    savedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('queue_json')) {
      context.handle(
        _queueJsonMeta,
        queueJson.isAcceptableOrUnknown(data['queue_json']!, _queueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_queueJsonMeta);
    }
    if (data.containsKey('current_index')) {
      context.handle(
        _currentIndexMeta,
        currentIndex.isAcceptableOrUnknown(
          data['current_index']!,
          _currentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentIndexMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('source_playlist_id')) {
      context.handle(
        _sourcePlaylistIdMeta,
        sourcePlaylistId.isAcceptableOrUnknown(
          data['source_playlist_id']!,
          _sourcePlaylistIdMeta,
        ),
      );
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      queueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}queue_json'],
      )!,
      currentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_index'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sourcePlaylistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_playlist_id'],
      ),
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $SessionStateTable createAlias(String alias) {
    return $SessionStateTable(attachedDatabase, alias);
  }
}

class SessionStateData extends DataClass
    implements Insertable<SessionStateData> {
  final int id;
  final String queueJson;
  final int currentIndex;
  final int positionMs;

  /// 当前曲目已知总时长（毫秒），用于首次未满 5s 即拖动进度条退出后的恢复判定
  final int durationMs;

  /// 会话来源播单 id，用于恢复后继续写入该播单的独立进度
  final int? sourcePlaylistId;
  final DateTime savedAt;
  const SessionStateData({
    required this.id,
    required this.queueJson,
    required this.currentIndex,
    required this.positionMs,
    required this.durationMs,
    this.sourcePlaylistId,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['queue_json'] = Variable<String>(queueJson);
    map['current_index'] = Variable<int>(currentIndex);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || sourcePlaylistId != null) {
      map['source_playlist_id'] = Variable<int>(sourcePlaylistId);
    }
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  SessionStateCompanion toCompanion(bool nullToAbsent) {
    return SessionStateCompanion(
      id: Value(id),
      queueJson: Value(queueJson),
      currentIndex: Value(currentIndex),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      sourcePlaylistId: sourcePlaylistId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePlaylistId),
      savedAt: Value(savedAt),
    );
  }

  factory SessionStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionStateData(
      id: serializer.fromJson<int>(json['id']),
      queueJson: serializer.fromJson<String>(json['queueJson']),
      currentIndex: serializer.fromJson<int>(json['currentIndex']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sourcePlaylistId: serializer.fromJson<int?>(json['sourcePlaylistId']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'queueJson': serializer.toJson<String>(queueJson),
      'currentIndex': serializer.toJson<int>(currentIndex),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'sourcePlaylistId': serializer.toJson<int?>(sourcePlaylistId),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  SessionStateData copyWith({
    int? id,
    String? queueJson,
    int? currentIndex,
    int? positionMs,
    int? durationMs,
    Value<int?> sourcePlaylistId = const Value.absent(),
    DateTime? savedAt,
  }) => SessionStateData(
    id: id ?? this.id,
    queueJson: queueJson ?? this.queueJson,
    currentIndex: currentIndex ?? this.currentIndex,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    sourcePlaylistId: sourcePlaylistId.present
        ? sourcePlaylistId.value
        : this.sourcePlaylistId,
    savedAt: savedAt ?? this.savedAt,
  );
  SessionStateData copyWithCompanion(SessionStateCompanion data) {
    return SessionStateData(
      id: data.id.present ? data.id.value : this.id,
      queueJson: data.queueJson.present ? data.queueJson.value : this.queueJson,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sourcePlaylistId: data.sourcePlaylistId.present
          ? data.sourcePlaylistId.value
          : this.sourcePlaylistId,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionStateData(')
          ..write('id: $id, ')
          ..write('queueJson: $queueJson, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('sourcePlaylistId: $sourcePlaylistId, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    queueJson,
    currentIndex,
    positionMs,
    durationMs,
    sourcePlaylistId,
    savedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStateData &&
          other.id == this.id &&
          other.queueJson == this.queueJson &&
          other.currentIndex == this.currentIndex &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.sourcePlaylistId == this.sourcePlaylistId &&
          other.savedAt == this.savedAt);
}

class SessionStateCompanion extends UpdateCompanion<SessionStateData> {
  final Value<int> id;
  final Value<String> queueJson;
  final Value<int> currentIndex;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<int?> sourcePlaylistId;
  final Value<DateTime> savedAt;
  const SessionStateCompanion({
    this.id = const Value.absent(),
    this.queueJson = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sourcePlaylistId = const Value.absent(),
    this.savedAt = const Value.absent(),
  });
  SessionStateCompanion.insert({
    this.id = const Value.absent(),
    required String queueJson,
    required int currentIndex,
    required int positionMs,
    this.durationMs = const Value.absent(),
    this.sourcePlaylistId = const Value.absent(),
    this.savedAt = const Value.absent(),
  }) : queueJson = Value(queueJson),
       currentIndex = Value(currentIndex),
       positionMs = Value(positionMs);
  static Insertable<SessionStateData> custom({
    Expression<int>? id,
    Expression<String>? queueJson,
    Expression<int>? currentIndex,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<int>? sourcePlaylistId,
    Expression<DateTime>? savedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (queueJson != null) 'queue_json': queueJson,
      if (currentIndex != null) 'current_index': currentIndex,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sourcePlaylistId != null) 'source_playlist_id': sourcePlaylistId,
      if (savedAt != null) 'saved_at': savedAt,
    });
  }

  SessionStateCompanion copyWith({
    Value<int>? id,
    Value<String>? queueJson,
    Value<int>? currentIndex,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<int?>? sourcePlaylistId,
    Value<DateTime>? savedAt,
  }) {
    return SessionStateCompanion(
      id: id ?? this.id,
      queueJson: queueJson ?? this.queueJson,
      currentIndex: currentIndex ?? this.currentIndex,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      sourcePlaylistId: sourcePlaylistId ?? this.sourcePlaylistId,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (queueJson.present) {
      map['queue_json'] = Variable<String>(queueJson.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sourcePlaylistId.present) {
      map['source_playlist_id'] = Variable<int>(sourcePlaylistId.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionStateCompanion(')
          ..write('id: $id, ')
          ..write('queueJson: $queueJson, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('sourcePlaylistId: $sourcePlaylistId, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistItemsTable playlistItems = $PlaylistItemsTable(this);
  late final $PlayProgressesTable playProgresses = $PlayProgressesTable(this);
  late final $PlaylistProgressesTable playlistProgresses =
      $PlaylistProgressesTable(this);
  late final $PlaylistStatesTable playlistStates = $PlaylistStatesTable(this);
  late final $PlayHistoriesTable playHistories = $PlayHistoriesTable(this);
  late final $TrackPrefsTableTable trackPrefsTable = $TrackPrefsTableTable(
    this,
  );
  late final $SessionStateTable sessionState = $SessionStateTable(this);
  late final Index idxPlaylistItemsPidPos = Index(
    'idx_playlist_items_pid_pos',
    'CREATE INDEX idx_playlist_items_pid_pos ON playlist_items (playlist_id, position)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    playlists,
    playlistItems,
    playProgresses,
    playlistProgresses,
    playlistStates,
    playHistories,
    trackPrefsTable,
    sessionState,
    idxPlaylistItemsPidPos,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_progresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_states', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  Value<DateTime> createdAt,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> createdAt,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistItemsTable, List<PlaylistItem>>
  _playlistItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistItems,
    aliasName: 'playlists__id__playlist_items__playlist_id',
  );

  $$PlaylistItemsTableProcessedTableManager get playlistItemsRefs {
    final manager = $$PlaylistItemsTableTableManager(
      $_db,
      $_db.playlistItems,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaylistProgressesTable, List<PlaylistProgress>>
  _playlistProgressesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playlistProgresses,
        aliasName: 'playlists__id__playlist_progresses__playlist_id',
      );

  $$PlaylistProgressesTableProcessedTableManager get playlistProgressesRefs {
    final manager = $$PlaylistProgressesTableTableManager(
      $_db,
      $_db.playlistProgresses,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistProgressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaylistStatesTable, List<PlaylistState>>
  _playlistStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistStates,
    aliasName: 'playlists__id__playlist_states__playlist_id',
  );

  $$PlaylistStatesTableProcessedTableManager get playlistStatesRefs {
    final manager = $$PlaylistStatesTableTableManager(
      $_db,
      $_db.playlistStates,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistItemsRefs(
    Expression<bool> Function($$PlaylistItemsTableFilterComposer f) f,
  ) {
    final $$PlaylistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistItems,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistItemsTableFilterComposer(
            $db: $db,
            $table: $db.playlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playlistProgressesRefs(
    Expression<bool> Function($$PlaylistProgressesTableFilterComposer f) f,
  ) {
    final $$PlaylistProgressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistProgresses,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistProgressesTableFilterComposer(
            $db: $db,
            $table: $db.playlistProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playlistStatesRefs(
    Expression<bool> Function($$PlaylistStatesTableFilterComposer f) f,
  ) {
    final $$PlaylistStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistStates,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistStatesTableFilterComposer(
            $db: $db,
            $table: $db.playlistStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> playlistItemsRefs<T extends Object>(
    Expression<T> Function($$PlaylistItemsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistItems,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playlistProgressesRefs<T extends Object>(
    Expression<T> Function($$PlaylistProgressesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistProgressesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playlistProgresses,
          getReferencedColumn: (t) => t.playlistId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaylistProgressesTableAnnotationComposer(
                $db: $db,
                $table: $db.playlistProgresses,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> playlistStatesRefs<T extends Object>(
    Expression<T> Function($$PlaylistStatesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistStates,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({
            bool playlistItemsRefs,
            bool playlistProgressesRefs,
            bool playlistStatesRefs,
          })
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) => PlaylistsCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, Playlist>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                playlistItemsRefs = false,
                playlistProgressesRefs = false,
                playlistStatesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistItemsRefs) db.playlistItems,
                    if (playlistProgressesRefs) db.playlistProgresses,
                    if (playlistStatesRefs) db.playlistStates,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          Playlist,
                          $PlaylistsTable,
                          PlaylistItem,
                          $PlaylistItemsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._playlistItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'playlist_id',
                          typedResults: items,
                        ),
                      if (playlistProgressesRefs)
                        await $_getPrefetchedDataByColumns<
                          Playlist,
                          $PlaylistsTable,
                          PlaylistProgress,
                          $PlaylistProgressesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._playlistProgressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistProgressesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'playlist_id',
                          typedResults: items,
                        ),
                      if (playlistStatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Playlist,
                          $PlaylistsTable,
                          PlaylistState,
                          $PlaylistStatesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._playlistStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistStatesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'playlist_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({
        bool playlistItemsRefs,
        bool playlistProgressesRefs,
        bool playlistStatesRefs,
      })
    >;
typedef $$PlaylistItemsTableCreateCompanionBuilder =
    PlaylistItemsCompanion Function({
      Value<int> id,
      required int playlistId,
      required String path,
      required String name,
      required bool isVideo,
      Value<int> size,
      Value<String> thumb,
      required int position,
    });
typedef $$PlaylistItemsTableUpdateCompanionBuilder =
    PlaylistItemsCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<String> path,
      Value<String> name,
      Value<bool> isVideo,
      Value<int> size,
      Value<String> thumb,
      Value<int> position,
    });

final class $$PlaylistItemsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistItemsTable, PlaylistItem> {
  $$PlaylistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_items__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVideo => $composableBuilder(
    column: $table.isVideo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumb => $composableBuilder(
    column: $table.thumb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVideo => $composableBuilder(
    column: $table.isVideo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumb => $composableBuilder(
    column: $table.thumb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isVideo =>
      $composableBuilder(column: $table.isVideo, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get thumb =>
      $composableBuilder(column: $table.thumb, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistItemsTable,
          PlaylistItem,
          $$PlaylistItemsTableFilterComposer,
          $$PlaylistItemsTableOrderingComposer,
          $$PlaylistItemsTableAnnotationComposer,
          $$PlaylistItemsTableCreateCompanionBuilder,
          $$PlaylistItemsTableUpdateCompanionBuilder,
          (PlaylistItem, $$PlaylistItemsTableReferences),
          PlaylistItem,
          PrefetchHooks Function({bool playlistId})
        > {
  $$PlaylistItemsTableTableManager(_$AppDatabase db, $PlaylistItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isVideo = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> thumb = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => PlaylistItemsCompanion(
                id: id,
                playlistId: playlistId,
                path: path,
                name: name,
                isVideo: isVideo,
                size: size,
                thumb: thumb,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String path,
                required String name,
                required bool isVideo,
                Value<int> size = const Value.absent(),
                Value<String> thumb = const Value.absent(),
                required int position,
              }) => PlaylistItemsCompanion.insert(
                id: id,
                playlistId: playlistId,
                path: path,
                name: name,
                isVideo: isVideo,
                size: size,
                thumb: thumb,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistItemsTable, PlaylistItem>(table),
                  $$PlaylistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistItemsTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistItemsTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistItemsTable,
      PlaylistItem,
      $$PlaylistItemsTableFilterComposer,
      $$PlaylistItemsTableOrderingComposer,
      $$PlaylistItemsTableAnnotationComposer,
      $$PlaylistItemsTableCreateCompanionBuilder,
      $$PlaylistItemsTableUpdateCompanionBuilder,
      (PlaylistItem, $$PlaylistItemsTableReferences),
      PlaylistItem,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$PlayProgressesTableCreateCompanionBuilder =
    PlayProgressesCompanion Function({
      required String path,
      required int positionMs,
      required int durationMs,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlayProgressesTableUpdateCompanionBuilder =
    PlayProgressesCompanion Function({
      Value<String> path,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PlayProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $PlayProgressesTable> {
  $$PlayProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayProgressesTable> {
  $$PlayProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayProgressesTable> {
  $$PlayProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlayProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayProgressesTable,
          PlayProgress,
          $$PlayProgressesTableFilterComposer,
          $$PlayProgressesTableOrderingComposer,
          $$PlayProgressesTableAnnotationComposer,
          $$PlayProgressesTableCreateCompanionBuilder,
          $$PlayProgressesTableUpdateCompanionBuilder,
          (
            PlayProgress,
            BaseReferences<_$AppDatabase, $PlayProgressesTable, PlayProgress>,
          ),
          PlayProgress,
          PrefetchHooks Function()
        > {
  $$PlayProgressesTableTableManager(
    _$AppDatabase db,
    $PlayProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayProgressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayProgressesCompanion(
                path: path,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required int positionMs,
                required int durationMs,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlayProgressesCompanion.insert(
                path: path,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayProgressesTable, PlayProgress>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PlayProgressesTable,
                    PlayProgress
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayProgressesTable,
      PlayProgress,
      $$PlayProgressesTableFilterComposer,
      $$PlayProgressesTableOrderingComposer,
      $$PlayProgressesTableAnnotationComposer,
      $$PlayProgressesTableCreateCompanionBuilder,
      $$PlayProgressesTableUpdateCompanionBuilder,
      (
        PlayProgress,
        BaseReferences<_$AppDatabase, $PlayProgressesTable, PlayProgress>,
      ),
      PlayProgress,
      PrefetchHooks Function()
    >;
typedef $$PlaylistProgressesTableCreateCompanionBuilder =
    PlaylistProgressesCompanion Function({
      required int playlistId,
      required String path,
      required int positionMs,
      required int durationMs,
      Value<bool> finished,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlaylistProgressesTableUpdateCompanionBuilder =
    PlaylistProgressesCompanion Function({
      Value<int> playlistId,
      Value<String> path,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<bool> finished,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlaylistProgressesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaylistProgressesTable,
          PlaylistProgress
        > {
  $$PlaylistProgressesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) => db.playlists
      .createAlias('playlist_progresses__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistProgressesTable> {
  $$PlaylistProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistProgressesTable> {
  $$PlaylistProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistProgressesTable> {
  $$PlaylistProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistProgressesTable,
          PlaylistProgress,
          $$PlaylistProgressesTableFilterComposer,
          $$PlaylistProgressesTableOrderingComposer,
          $$PlaylistProgressesTableAnnotationComposer,
          $$PlaylistProgressesTableCreateCompanionBuilder,
          $$PlaylistProgressesTableUpdateCompanionBuilder,
          (PlaylistProgress, $$PlaylistProgressesTableReferences),
          PlaylistProgress,
          PrefetchHooks Function({bool playlistId})
        > {
  $$PlaylistProgressesTableTableManager(
    _$AppDatabase db,
    $PlaylistProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistProgressesCompanion(
                playlistId: playlistId,
                path: path,
                positionMs: positionMs,
                durationMs: durationMs,
                finished: finished,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required String path,
                required int positionMs,
                required int durationMs,
                Value<bool> finished = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistProgressesCompanion.insert(
                playlistId: playlistId,
                path: path,
                positionMs: positionMs,
                durationMs: durationMs,
                finished: finished,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistProgressesTable, PlaylistProgress>(
                    table,
                  ),
                  $$PlaylistProgressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistProgressesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistProgressesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistProgressesTable,
      PlaylistProgress,
      $$PlaylistProgressesTableFilterComposer,
      $$PlaylistProgressesTableOrderingComposer,
      $$PlaylistProgressesTableAnnotationComposer,
      $$PlaylistProgressesTableCreateCompanionBuilder,
      $$PlaylistProgressesTableUpdateCompanionBuilder,
      (PlaylistProgress, $$PlaylistProgressesTableReferences),
      PlaylistProgress,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$PlaylistStatesTableCreateCompanionBuilder =
    PlaylistStatesCompanion Function({
      Value<int> playlistId,
      required String path,
      Value<DateTime> updatedAt,
    });
typedef $$PlaylistStatesTableUpdateCompanionBuilder =
    PlaylistStatesCompanion Function({
      Value<int> playlistId,
      Value<String> path,
      Value<DateTime> updatedAt,
    });

final class $$PlaylistStatesTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistStatesTable, PlaylistState> {
  $$PlaylistStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_states__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistStatesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistStatesTable> {
  $$PlaylistStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistStatesTable> {
  $$PlaylistStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistStatesTable> {
  $$PlaylistStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistStatesTable,
          PlaylistState,
          $$PlaylistStatesTableFilterComposer,
          $$PlaylistStatesTableOrderingComposer,
          $$PlaylistStatesTableAnnotationComposer,
          $$PlaylistStatesTableCreateCompanionBuilder,
          $$PlaylistStatesTableUpdateCompanionBuilder,
          (PlaylistState, $$PlaylistStatesTableReferences),
          PlaylistState,
          PrefetchHooks Function({bool playlistId})
        > {
  $$PlaylistStatesTableTableManager(
    _$AppDatabase db,
    $PlaylistStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaylistStatesCompanion(
                playlistId: playlistId,
                path: path,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                required String path,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaylistStatesCompanion.insert(
                playlistId: playlistId,
                path: path,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistStatesTable, PlaylistState>(table),
                  $$PlaylistStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistStatesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistStatesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistStatesTable,
      PlaylistState,
      $$PlaylistStatesTableFilterComposer,
      $$PlaylistStatesTableOrderingComposer,
      $$PlaylistStatesTableAnnotationComposer,
      $$PlaylistStatesTableCreateCompanionBuilder,
      $$PlaylistStatesTableUpdateCompanionBuilder,
      (PlaylistState, $$PlaylistStatesTableReferences),
      PlaylistState,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$PlayHistoriesTableCreateCompanionBuilder =
    PlayHistoriesCompanion Function({
      required String path,
      required String name,
      required bool isVideo,
      required DateTime playedAt,
      Value<int> rowid,
    });
typedef $$PlayHistoriesTableUpdateCompanionBuilder =
    PlayHistoriesCompanion Function({
      Value<String> path,
      Value<String> name,
      Value<bool> isVideo,
      Value<DateTime> playedAt,
      Value<int> rowid,
    });

class $$PlayHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlayHistoriesTable> {
  $$PlayHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVideo => $composableBuilder(
    column: $table.isVideo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayHistoriesTable> {
  $$PlayHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVideo => $composableBuilder(
    column: $table.isVideo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayHistoriesTable> {
  $$PlayHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isVideo =>
      $composableBuilder(column: $table.isVideo, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);
}

class $$PlayHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayHistoriesTable,
          PlayHistory,
          $$PlayHistoriesTableFilterComposer,
          $$PlayHistoriesTableOrderingComposer,
          $$PlayHistoriesTableAnnotationComposer,
          $$PlayHistoriesTableCreateCompanionBuilder,
          $$PlayHistoriesTableUpdateCompanionBuilder,
          (
            PlayHistory,
            BaseReferences<_$AppDatabase, $PlayHistoriesTable, PlayHistory>,
          ),
          PlayHistory,
          PrefetchHooks Function()
        > {
  $$PlayHistoriesTableTableManager(_$AppDatabase db, $PlayHistoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isVideo = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayHistoriesCompanion(
                path: path,
                name: name,
                isVideo: isVideo,
                playedAt: playedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String name,
                required bool isVideo,
                required DateTime playedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlayHistoriesCompanion.insert(
                path: path,
                name: name,
                isVideo: isVideo,
                playedAt: playedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayHistoriesTable, PlayHistory>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PlayHistoriesTable,
                    PlayHistory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayHistoriesTable,
      PlayHistory,
      $$PlayHistoriesTableFilterComposer,
      $$PlayHistoriesTableOrderingComposer,
      $$PlayHistoriesTableAnnotationComposer,
      $$PlayHistoriesTableCreateCompanionBuilder,
      $$PlayHistoriesTableUpdateCompanionBuilder,
      (
        PlayHistory,
        BaseReferences<_$AppDatabase, $PlayHistoriesTable, PlayHistory>,
      ),
      PlayHistory,
      PrefetchHooks Function()
    >;
typedef $$TrackPrefsTableTableCreateCompanionBuilder =
    TrackPrefsTableCompanion Function({
      required String path,
      Value<String?> audioTrack,
      Value<String?> subtitleTrack,
      Value<int> subDelayMs,
      Value<int> rowid,
    });
typedef $$TrackPrefsTableTableUpdateCompanionBuilder =
    TrackPrefsTableCompanion Function({
      Value<String> path,
      Value<String?> audioTrack,
      Value<String?> subtitleTrack,
      Value<int> subDelayMs,
      Value<int> rowid,
    });

class $$TrackPrefsTableTableFilterComposer
    extends Composer<_$AppDatabase, $TrackPrefsTableTable> {
  $$TrackPrefsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioTrack => $composableBuilder(
    column: $table.audioTrack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitleTrack => $composableBuilder(
    column: $table.subtitleTrack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subDelayMs => $composableBuilder(
    column: $table.subDelayMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackPrefsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackPrefsTableTable> {
  $$TrackPrefsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioTrack => $composableBuilder(
    column: $table.audioTrack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitleTrack => $composableBuilder(
    column: $table.subtitleTrack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subDelayMs => $composableBuilder(
    column: $table.subDelayMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackPrefsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackPrefsTableTable> {
  $$TrackPrefsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get audioTrack => $composableBuilder(
    column: $table.audioTrack,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subtitleTrack => $composableBuilder(
    column: $table.subtitleTrack,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subDelayMs => $composableBuilder(
    column: $table.subDelayMs,
    builder: (column) => column,
  );
}

class $$TrackPrefsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackPrefsTableTable,
          TrackPrefs,
          $$TrackPrefsTableTableFilterComposer,
          $$TrackPrefsTableTableOrderingComposer,
          $$TrackPrefsTableTableAnnotationComposer,
          $$TrackPrefsTableTableCreateCompanionBuilder,
          $$TrackPrefsTableTableUpdateCompanionBuilder,
          (
            TrackPrefs,
            BaseReferences<_$AppDatabase, $TrackPrefsTableTable, TrackPrefs>,
          ),
          TrackPrefs,
          PrefetchHooks Function()
        > {
  $$TrackPrefsTableTableTableManager(
    _$AppDatabase db,
    $TrackPrefsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackPrefsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackPrefsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackPrefsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String?> audioTrack = const Value.absent(),
                Value<String?> subtitleTrack = const Value.absent(),
                Value<int> subDelayMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackPrefsTableCompanion(
                path: path,
                audioTrack: audioTrack,
                subtitleTrack: subtitleTrack,
                subDelayMs: subDelayMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                Value<String?> audioTrack = const Value.absent(),
                Value<String?> subtitleTrack = const Value.absent(),
                Value<int> subDelayMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackPrefsTableCompanion.insert(
                path: path,
                audioTrack: audioTrack,
                subtitleTrack: subtitleTrack,
                subDelayMs: subDelayMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackPrefsTableTable, TrackPrefs>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TrackPrefsTableTable,
                    TrackPrefs
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackPrefsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackPrefsTableTable,
      TrackPrefs,
      $$TrackPrefsTableTableFilterComposer,
      $$TrackPrefsTableTableOrderingComposer,
      $$TrackPrefsTableTableAnnotationComposer,
      $$TrackPrefsTableTableCreateCompanionBuilder,
      $$TrackPrefsTableTableUpdateCompanionBuilder,
      (
        TrackPrefs,
        BaseReferences<_$AppDatabase, $TrackPrefsTableTable, TrackPrefs>,
      ),
      TrackPrefs,
      PrefetchHooks Function()
    >;
typedef $$SessionStateTableCreateCompanionBuilder =
    SessionStateCompanion Function({
      Value<int> id,
      required String queueJson,
      required int currentIndex,
      required int positionMs,
      Value<int> durationMs,
      Value<int?> sourcePlaylistId,
      Value<DateTime> savedAt,
    });
typedef $$SessionStateTableUpdateCompanionBuilder =
    SessionStateCompanion Function({
      Value<int> id,
      Value<String> queueJson,
      Value<int> currentIndex,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<int?> sourcePlaylistId,
      Value<DateTime> savedAt,
    });

class $$SessionStateTableFilterComposer
    extends Composer<_$AppDatabase, $SessionStateTable> {
  $$SessionStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queueJson => $composableBuilder(
    column: $table.queueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourcePlaylistId => $composableBuilder(
    column: $table.sourcePlaylistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionStateTable> {
  $$SessionStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queueJson => $composableBuilder(
    column: $table.queueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourcePlaylistId => $composableBuilder(
    column: $table.sourcePlaylistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionStateTable> {
  $$SessionStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get queueJson =>
      $composableBuilder(column: $table.queueJson, builder: (column) => column);

  GeneratedColumn<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourcePlaylistId => $composableBuilder(
    column: $table.sourcePlaylistId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$SessionStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionStateTable,
          SessionStateData,
          $$SessionStateTableFilterComposer,
          $$SessionStateTableOrderingComposer,
          $$SessionStateTableAnnotationComposer,
          $$SessionStateTableCreateCompanionBuilder,
          $$SessionStateTableUpdateCompanionBuilder,
          (
            SessionStateData,
            BaseReferences<_$AppDatabase, $SessionStateTable, SessionStateData>,
          ),
          SessionStateData,
          PrefetchHooks Function()
        > {
  $$SessionStateTableTableManager(_$AppDatabase db, $SessionStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> queueJson = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int?> sourcePlaylistId = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
              }) => SessionStateCompanion(
                id: id,
                queueJson: queueJson,
                currentIndex: currentIndex,
                positionMs: positionMs,
                durationMs: durationMs,
                sourcePlaylistId: sourcePlaylistId,
                savedAt: savedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String queueJson,
                required int currentIndex,
                required int positionMs,
                Value<int> durationMs = const Value.absent(),
                Value<int?> sourcePlaylistId = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
              }) => SessionStateCompanion.insert(
                id: id,
                queueJson: queueJson,
                currentIndex: currentIndex,
                positionMs: positionMs,
                durationMs: durationMs,
                sourcePlaylistId: sourcePlaylistId,
                savedAt: savedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionStateTable, SessionStateData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SessionStateTable,
                    SessionStateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionStateTable,
      SessionStateData,
      $$SessionStateTableFilterComposer,
      $$SessionStateTableOrderingComposer,
      $$SessionStateTableAnnotationComposer,
      $$SessionStateTableCreateCompanionBuilder,
      $$SessionStateTableUpdateCompanionBuilder,
      (
        SessionStateData,
        BaseReferences<_$AppDatabase, $SessionStateTable, SessionStateData>,
      ),
      SessionStateData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistItemsTableTableManager get playlistItems =>
      $$PlaylistItemsTableTableManager(_db, _db.playlistItems);
  $$PlayProgressesTableTableManager get playProgresses =>
      $$PlayProgressesTableTableManager(_db, _db.playProgresses);
  $$PlaylistProgressesTableTableManager get playlistProgresses =>
      $$PlaylistProgressesTableTableManager(_db, _db.playlistProgresses);
  $$PlaylistStatesTableTableManager get playlistStates =>
      $$PlaylistStatesTableTableManager(_db, _db.playlistStates);
  $$PlayHistoriesTableTableManager get playHistories =>
      $$PlayHistoriesTableTableManager(_db, _db.playHistories);
  $$TrackPrefsTableTableTableManager get trackPrefsTable =>
      $$TrackPrefsTableTableTableManager(_db, _db.trackPrefsTable);
  $$SessionStateTableTableManager get sessionState =>
      $$SessionStateTableTableManager(_db, _db.sessionState);
}
