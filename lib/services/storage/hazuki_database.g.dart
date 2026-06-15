// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hazuki_database.dart';

// ignore_for_file: type=lint
class $ReadHistoryEntriesTable extends ReadHistoryEntries
    with TableInfo<$ReadHistoryEntriesTable, ReadHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storageKeyMeta = const VerificationMeta(
    'storageKey',
  );
  @override
  late final GeneratedColumn<String> storageKey = GeneratedColumn<String>(
    'storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _comicIdMeta = const VerificationMeta(
    'comicId',
  );
  @override
  late final GeneratedColumn<String> comicId = GeneratedColumn<String>(
    'comic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subTitleMeta = const VerificationMeta(
    'subTitle',
  );
  @override
  late final GeneratedColumn<String> subTitle = GeneratedColumn<String>(
    'sub_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    storageKey,
    comicId,
    sourceKey,
    title,
    cover,
    subTitle,
    timestampMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'read_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('storage_key')) {
      context.handle(
        _storageKeyMeta,
        storageKey.isAcceptableOrUnknown(data['storage_key']!, _storageKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_storageKeyMeta);
    }
    if (data.containsKey('comic_id')) {
      context.handle(
        _comicIdMeta,
        comicId.isAcceptableOrUnknown(data['comic_id']!, _comicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_comicIdMeta);
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    } else if (isInserting) {
      context.missing(_coverMeta);
    }
    if (data.containsKey('sub_title')) {
      context.handle(
        _subTitleMeta,
        subTitle.isAcceptableOrUnknown(data['sub_title']!, _subTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_subTitleMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storageKey};
  @override
  ReadHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadHistoryEntry(
      storageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_key'],
      )!,
      comicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_id'],
      )!,
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      )!,
      subTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_title'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
    );
  }

  @override
  $ReadHistoryEntriesTable createAlias(String alias) {
    return $ReadHistoryEntriesTable(attachedDatabase, alias);
  }
}

class ReadHistoryEntry extends DataClass
    implements Insertable<ReadHistoryEntry> {
  final String storageKey;
  final String comicId;
  final String sourceKey;
  final String title;
  final String cover;
  final String subTitle;
  final int timestampMs;
  const ReadHistoryEntry({
    required this.storageKey,
    required this.comicId,
    required this.sourceKey,
    required this.title,
    required this.cover,
    required this.subTitle,
    required this.timestampMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['storage_key'] = Variable<String>(storageKey);
    map['comic_id'] = Variable<String>(comicId);
    map['source_key'] = Variable<String>(sourceKey);
    map['title'] = Variable<String>(title);
    map['cover'] = Variable<String>(cover);
    map['sub_title'] = Variable<String>(subTitle);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    return map;
  }

  ReadHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return ReadHistoryEntriesCompanion(
      storageKey: Value(storageKey),
      comicId: Value(comicId),
      sourceKey: Value(sourceKey),
      title: Value(title),
      cover: Value(cover),
      subTitle: Value(subTitle),
      timestampMs: Value(timestampMs),
    );
  }

  factory ReadHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadHistoryEntry(
      storageKey: serializer.fromJson<String>(json['storageKey']),
      comicId: serializer.fromJson<String>(json['comicId']),
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      title: serializer.fromJson<String>(json['title']),
      cover: serializer.fromJson<String>(json['cover']),
      subTitle: serializer.fromJson<String>(json['subTitle']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storageKey': serializer.toJson<String>(storageKey),
      'comicId': serializer.toJson<String>(comicId),
      'sourceKey': serializer.toJson<String>(sourceKey),
      'title': serializer.toJson<String>(title),
      'cover': serializer.toJson<String>(cover),
      'subTitle': serializer.toJson<String>(subTitle),
      'timestampMs': serializer.toJson<int>(timestampMs),
    };
  }

  ReadHistoryEntry copyWith({
    String? storageKey,
    String? comicId,
    String? sourceKey,
    String? title,
    String? cover,
    String? subTitle,
    int? timestampMs,
  }) => ReadHistoryEntry(
    storageKey: storageKey ?? this.storageKey,
    comicId: comicId ?? this.comicId,
    sourceKey: sourceKey ?? this.sourceKey,
    title: title ?? this.title,
    cover: cover ?? this.cover,
    subTitle: subTitle ?? this.subTitle,
    timestampMs: timestampMs ?? this.timestampMs,
  );
  ReadHistoryEntry copyWithCompanion(ReadHistoryEntriesCompanion data) {
    return ReadHistoryEntry(
      storageKey: data.storageKey.present
          ? data.storageKey.value
          : this.storageKey,
      comicId: data.comicId.present ? data.comicId.value : this.comicId,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      title: data.title.present ? data.title.value : this.title,
      cover: data.cover.present ? data.cover.value : this.cover,
      subTitle: data.subTitle.present ? data.subTitle.value : this.subTitle,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadHistoryEntry(')
          ..write('storageKey: $storageKey, ')
          ..write('comicId: $comicId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('title: $title, ')
          ..write('cover: $cover, ')
          ..write('subTitle: $subTitle, ')
          ..write('timestampMs: $timestampMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    storageKey,
    comicId,
    sourceKey,
    title,
    cover,
    subTitle,
    timestampMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadHistoryEntry &&
          other.storageKey == this.storageKey &&
          other.comicId == this.comicId &&
          other.sourceKey == this.sourceKey &&
          other.title == this.title &&
          other.cover == this.cover &&
          other.subTitle == this.subTitle &&
          other.timestampMs == this.timestampMs);
}

class ReadHistoryEntriesCompanion extends UpdateCompanion<ReadHistoryEntry> {
  final Value<String> storageKey;
  final Value<String> comicId;
  final Value<String> sourceKey;
  final Value<String> title;
  final Value<String> cover;
  final Value<String> subTitle;
  final Value<int> timestampMs;
  final Value<int> rowid;
  const ReadHistoryEntriesCompanion({
    this.storageKey = const Value.absent(),
    this.comicId = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.title = const Value.absent(),
    this.cover = const Value.absent(),
    this.subTitle = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadHistoryEntriesCompanion.insert({
    required String storageKey,
    required String comicId,
    required String sourceKey,
    required String title,
    required String cover,
    required String subTitle,
    required int timestampMs,
    this.rowid = const Value.absent(),
  }) : storageKey = Value(storageKey),
       comicId = Value(comicId),
       sourceKey = Value(sourceKey),
       title = Value(title),
       cover = Value(cover),
       subTitle = Value(subTitle),
       timestampMs = Value(timestampMs);
  static Insertable<ReadHistoryEntry> custom({
    Expression<String>? storageKey,
    Expression<String>? comicId,
    Expression<String>? sourceKey,
    Expression<String>? title,
    Expression<String>? cover,
    Expression<String>? subTitle,
    Expression<int>? timestampMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storageKey != null) 'storage_key': storageKey,
      if (comicId != null) 'comic_id': comicId,
      if (sourceKey != null) 'source_key': sourceKey,
      if (title != null) 'title': title,
      if (cover != null) 'cover': cover,
      if (subTitle != null) 'sub_title': subTitle,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadHistoryEntriesCompanion copyWith({
    Value<String>? storageKey,
    Value<String>? comicId,
    Value<String>? sourceKey,
    Value<String>? title,
    Value<String>? cover,
    Value<String>? subTitle,
    Value<int>? timestampMs,
    Value<int>? rowid,
  }) {
    return ReadHistoryEntriesCompanion(
      storageKey: storageKey ?? this.storageKey,
      comicId: comicId ?? this.comicId,
      sourceKey: sourceKey ?? this.sourceKey,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      subTitle: subTitle ?? this.subTitle,
      timestampMs: timestampMs ?? this.timestampMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storageKey.present) {
      map['storage_key'] = Variable<String>(storageKey.value);
    }
    if (comicId.present) {
      map['comic_id'] = Variable<String>(comicId.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (subTitle.present) {
      map['sub_title'] = Variable<String>(subTitle.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadHistoryEntriesCompanion(')
          ..write('storageKey: $storageKey, ')
          ..write('comicId: $comicId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('title: $title, ')
          ..write('cover: $cover, ')
          ..write('subTitle: $subTitle, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressEntriesTable extends ReadingProgressEntries
    with TableInfo<$ReadingProgressEntriesTable, ReadingProgressEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storageKeyMeta = const VerificationMeta(
    'storageKey',
  );
  @override
  late final GeneratedColumn<String> storageKey = GeneratedColumn<String>(
    'storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _comicIdMeta = const VerificationMeta(
    'comicId',
  );
  @override
  late final GeneratedColumn<String> comicId = GeneratedColumn<String>(
    'comic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epIdMeta = const VerificationMeta('epId');
  @override
  late final GeneratedColumn<String> epId = GeneratedColumn<String>(
    'ep_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    storageKey,
    comicId,
    sourceKey,
    epId,
    title,
    chapterIndex,
    pageIndex,
    timestampMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('storage_key')) {
      context.handle(
        _storageKeyMeta,
        storageKey.isAcceptableOrUnknown(data['storage_key']!, _storageKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_storageKeyMeta);
    }
    if (data.containsKey('comic_id')) {
      context.handle(
        _comicIdMeta,
        comicId.isAcceptableOrUnknown(data['comic_id']!, _comicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_comicIdMeta);
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('ep_id')) {
      context.handle(
        _epIdMeta,
        epId.isAcceptableOrUnknown(data['ep_id']!, _epIdMeta),
      );
    } else if (isInserting) {
      context.missing(_epIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storageKey};
  @override
  ReadingProgressEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressEntry(
      storageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_key'],
      )!,
      comicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_id'],
      )!,
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      epId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ep_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
    );
  }

  @override
  $ReadingProgressEntriesTable createAlias(String alias) {
    return $ReadingProgressEntriesTable(attachedDatabase, alias);
  }
}

class ReadingProgressEntry extends DataClass
    implements Insertable<ReadingProgressEntry> {
  final String storageKey;
  final String comicId;
  final String sourceKey;
  final String epId;
  final String title;
  final int chapterIndex;
  final int pageIndex;
  final int timestampMs;
  const ReadingProgressEntry({
    required this.storageKey,
    required this.comicId,
    required this.sourceKey,
    required this.epId,
    required this.title,
    required this.chapterIndex,
    required this.pageIndex,
    required this.timestampMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['storage_key'] = Variable<String>(storageKey);
    map['comic_id'] = Variable<String>(comicId);
    map['source_key'] = Variable<String>(sourceKey);
    map['ep_id'] = Variable<String>(epId);
    map['title'] = Variable<String>(title);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['page_index'] = Variable<int>(pageIndex);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    return map;
  }

  ReadingProgressEntriesCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressEntriesCompanion(
      storageKey: Value(storageKey),
      comicId: Value(comicId),
      sourceKey: Value(sourceKey),
      epId: Value(epId),
      title: Value(title),
      chapterIndex: Value(chapterIndex),
      pageIndex: Value(pageIndex),
      timestampMs: Value(timestampMs),
    );
  }

  factory ReadingProgressEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressEntry(
      storageKey: serializer.fromJson<String>(json['storageKey']),
      comicId: serializer.fromJson<String>(json['comicId']),
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      epId: serializer.fromJson<String>(json['epId']),
      title: serializer.fromJson<String>(json['title']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storageKey': serializer.toJson<String>(storageKey),
      'comicId': serializer.toJson<String>(comicId),
      'sourceKey': serializer.toJson<String>(sourceKey),
      'epId': serializer.toJson<String>(epId),
      'title': serializer.toJson<String>(title),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'timestampMs': serializer.toJson<int>(timestampMs),
    };
  }

  ReadingProgressEntry copyWith({
    String? storageKey,
    String? comicId,
    String? sourceKey,
    String? epId,
    String? title,
    int? chapterIndex,
    int? pageIndex,
    int? timestampMs,
  }) => ReadingProgressEntry(
    storageKey: storageKey ?? this.storageKey,
    comicId: comicId ?? this.comicId,
    sourceKey: sourceKey ?? this.sourceKey,
    epId: epId ?? this.epId,
    title: title ?? this.title,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    pageIndex: pageIndex ?? this.pageIndex,
    timestampMs: timestampMs ?? this.timestampMs,
  );
  ReadingProgressEntry copyWithCompanion(ReadingProgressEntriesCompanion data) {
    return ReadingProgressEntry(
      storageKey: data.storageKey.present
          ? data.storageKey.value
          : this.storageKey,
      comicId: data.comicId.present ? data.comicId.value : this.comicId,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      epId: data.epId.present ? data.epId.value : this.epId,
      title: data.title.present ? data.title.value : this.title,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressEntry(')
          ..write('storageKey: $storageKey, ')
          ..write('comicId: $comicId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('epId: $epId, ')
          ..write('title: $title, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('timestampMs: $timestampMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    storageKey,
    comicId,
    sourceKey,
    epId,
    title,
    chapterIndex,
    pageIndex,
    timestampMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressEntry &&
          other.storageKey == this.storageKey &&
          other.comicId == this.comicId &&
          other.sourceKey == this.sourceKey &&
          other.epId == this.epId &&
          other.title == this.title &&
          other.chapterIndex == this.chapterIndex &&
          other.pageIndex == this.pageIndex &&
          other.timestampMs == this.timestampMs);
}

class ReadingProgressEntriesCompanion
    extends UpdateCompanion<ReadingProgressEntry> {
  final Value<String> storageKey;
  final Value<String> comicId;
  final Value<String> sourceKey;
  final Value<String> epId;
  final Value<String> title;
  final Value<int> chapterIndex;
  final Value<int> pageIndex;
  final Value<int> timestampMs;
  final Value<int> rowid;
  const ReadingProgressEntriesCompanion({
    this.storageKey = const Value.absent(),
    this.comicId = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.epId = const Value.absent(),
    this.title = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressEntriesCompanion.insert({
    required String storageKey,
    required String comicId,
    required String sourceKey,
    required String epId,
    required String title,
    required int chapterIndex,
    this.pageIndex = const Value.absent(),
    required int timestampMs,
    this.rowid = const Value.absent(),
  }) : storageKey = Value(storageKey),
       comicId = Value(comicId),
       sourceKey = Value(sourceKey),
       epId = Value(epId),
       title = Value(title),
       chapterIndex = Value(chapterIndex),
       timestampMs = Value(timestampMs);
  static Insertable<ReadingProgressEntry> custom({
    Expression<String>? storageKey,
    Expression<String>? comicId,
    Expression<String>? sourceKey,
    Expression<String>? epId,
    Expression<String>? title,
    Expression<int>? chapterIndex,
    Expression<int>? pageIndex,
    Expression<int>? timestampMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storageKey != null) 'storage_key': storageKey,
      if (comicId != null) 'comic_id': comicId,
      if (sourceKey != null) 'source_key': sourceKey,
      if (epId != null) 'ep_id': epId,
      if (title != null) 'title': title,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (pageIndex != null) 'page_index': pageIndex,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressEntriesCompanion copyWith({
    Value<String>? storageKey,
    Value<String>? comicId,
    Value<String>? sourceKey,
    Value<String>? epId,
    Value<String>? title,
    Value<int>? chapterIndex,
    Value<int>? pageIndex,
    Value<int>? timestampMs,
    Value<int>? rowid,
  }) {
    return ReadingProgressEntriesCompanion(
      storageKey: storageKey ?? this.storageKey,
      comicId: comicId ?? this.comicId,
      sourceKey: sourceKey ?? this.sourceKey,
      epId: epId ?? this.epId,
      title: title ?? this.title,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      pageIndex: pageIndex ?? this.pageIndex,
      timestampMs: timestampMs ?? this.timestampMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storageKey.present) {
      map['storage_key'] = Variable<String>(storageKey.value);
    }
    if (comicId.present) {
      map['comic_id'] = Variable<String>(comicId.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (epId.present) {
      map['ep_id'] = Variable<String>(epId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressEntriesCompanion(')
          ..write('storageKey: $storageKey, ')
          ..write('comicId: $comicId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('epId: $epId, ')
          ..write('title: $title, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryEntriesTable extends SearchHistoryEntries
    with TableInfo<$SearchHistoryEntriesTable, SearchHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keywordMeta = const VerificationMeta(
    'keyword',
  );
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
    'keyword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [keyword, position, updatedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('keyword')) {
      context.handle(
        _keywordMeta,
        keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta),
      );
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {keyword};
  @override
  SearchHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryEntry(
      keyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keyword'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $SearchHistoryEntriesTable createAlias(String alias) {
    return $SearchHistoryEntriesTable(attachedDatabase, alias);
  }
}

class SearchHistoryEntry extends DataClass
    implements Insertable<SearchHistoryEntry> {
  final String keyword;
  final int position;
  final int updatedAtMs;
  const SearchHistoryEntry({
    required this.keyword,
    required this.position,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['keyword'] = Variable<String>(keyword);
    map['position'] = Variable<int>(position);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  SearchHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryEntriesCompanion(
      keyword: Value(keyword),
      position: Value(position),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory SearchHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryEntry(
      keyword: serializer.fromJson<String>(json['keyword']),
      position: serializer.fromJson<int>(json['position']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyword': serializer.toJson<String>(keyword),
      'position': serializer.toJson<int>(position),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  SearchHistoryEntry copyWith({
    String? keyword,
    int? position,
    int? updatedAtMs,
  }) => SearchHistoryEntry(
    keyword: keyword ?? this.keyword,
    position: position ?? this.position,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  SearchHistoryEntry copyWithCompanion(SearchHistoryEntriesCompanion data) {
    return SearchHistoryEntry(
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      position: data.position.present ? data.position.value : this.position,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryEntry(')
          ..write('keyword: $keyword, ')
          ..write('position: $position, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(keyword, position, updatedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryEntry &&
          other.keyword == this.keyword &&
          other.position == this.position &&
          other.updatedAtMs == this.updatedAtMs);
}

class SearchHistoryEntriesCompanion
    extends UpdateCompanion<SearchHistoryEntry> {
  final Value<String> keyword;
  final Value<int> position;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const SearchHistoryEntriesCompanion({
    this.keyword = const Value.absent(),
    this.position = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoryEntriesCompanion.insert({
    required String keyword,
    required int position,
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : keyword = Value(keyword),
       position = Value(position);
  static Insertable<SearchHistoryEntry> custom({
    Expression<String>? keyword,
    Expression<int>? position,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (keyword != null) 'keyword': keyword,
      if (position != null) 'position': position,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoryEntriesCompanion copyWith({
    Value<String>? keyword,
    Value<int>? position,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return SearchHistoryEntriesCompanion(
      keyword: keyword ?? this.keyword,
      position: position ?? this.position,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryEntriesCompanion(')
          ..write('keyword: $keyword, ')
          ..write('position: $position, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTombstonesTable extends SearchHistoryTombstones
    with TableInfo<$SearchHistoryTombstonesTable, SearchHistoryTombstone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keywordMeta = const VerificationMeta(
    'keyword',
  );
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
    'keyword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [keyword, deletedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('keyword')) {
      context.handle(
        _keywordMeta,
        keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta),
      );
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {keyword};
  @override
  SearchHistoryTombstone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryTombstone(
      keyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keyword'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      )!,
    );
  }

  @override
  $SearchHistoryTombstonesTable createAlias(String alias) {
    return $SearchHistoryTombstonesTable(attachedDatabase, alias);
  }
}

class SearchHistoryTombstone extends DataClass
    implements Insertable<SearchHistoryTombstone> {
  final String keyword;
  final int deletedAtMs;
  const SearchHistoryTombstone({
    required this.keyword,
    required this.deletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['keyword'] = Variable<String>(keyword);
    map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    return map;
  }

  SearchHistoryTombstonesCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryTombstonesCompanion(
      keyword: Value(keyword),
      deletedAtMs: Value(deletedAtMs),
    );
  }

  factory SearchHistoryTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryTombstone(
      keyword: serializer.fromJson<String>(json['keyword']),
      deletedAtMs: serializer.fromJson<int>(json['deletedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyword': serializer.toJson<String>(keyword),
      'deletedAtMs': serializer.toJson<int>(deletedAtMs),
    };
  }

  SearchHistoryTombstone copyWith({String? keyword, int? deletedAtMs}) =>
      SearchHistoryTombstone(
        keyword: keyword ?? this.keyword,
        deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      );
  SearchHistoryTombstone copyWithCompanion(
    SearchHistoryTombstonesCompanion data,
  ) {
    return SearchHistoryTombstone(
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryTombstone(')
          ..write('keyword: $keyword, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(keyword, deletedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryTombstone &&
          other.keyword == this.keyword &&
          other.deletedAtMs == this.deletedAtMs);
}

class SearchHistoryTombstonesCompanion
    extends UpdateCompanion<SearchHistoryTombstone> {
  final Value<String> keyword;
  final Value<int> deletedAtMs;
  final Value<int> rowid;
  const SearchHistoryTombstonesCompanion({
    this.keyword = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoryTombstonesCompanion.insert({
    required String keyword,
    required int deletedAtMs,
    this.rowid = const Value.absent(),
  }) : keyword = Value(keyword),
       deletedAtMs = Value(deletedAtMs);
  static Insertable<SearchHistoryTombstone> custom({
    Expression<String>? keyword,
    Expression<int>? deletedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (keyword != null) 'keyword': keyword,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoryTombstonesCompanion copyWith({
    Value<String>? keyword,
    Value<int>? deletedAtMs,
    Value<int>? rowid,
  }) {
    return SearchHistoryTombstonesCompanion(
      keyword: keyword ?? this.keyword,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryTombstonesCompanion(')
          ..write('keyword: $keyword, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryClearStatesTable extends SearchHistoryClearStates
    with TableInfo<$SearchHistoryClearStatesTable, SearchHistoryClearState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryClearStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clearedAtMsMeta = const VerificationMeta(
    'clearedAtMs',
  );
  @override
  late final GeneratedColumn<int> clearedAtMs = GeneratedColumn<int>(
    'cleared_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, clearedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history_clear_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryClearState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cleared_at_ms')) {
      context.handle(
        _clearedAtMsMeta,
        clearedAtMs.isAcceptableOrUnknown(
          data['cleared_at_ms']!,
          _clearedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clearedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchHistoryClearState map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryClearState(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clearedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cleared_at_ms'],
      )!,
    );
  }

  @override
  $SearchHistoryClearStatesTable createAlias(String alias) {
    return $SearchHistoryClearStatesTable(attachedDatabase, alias);
  }
}

class SearchHistoryClearState extends DataClass
    implements Insertable<SearchHistoryClearState> {
  final String id;
  final int clearedAtMs;
  const SearchHistoryClearState({required this.id, required this.clearedAtMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cleared_at_ms'] = Variable<int>(clearedAtMs);
    return map;
  }

  SearchHistoryClearStatesCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryClearStatesCompanion(
      id: Value(id),
      clearedAtMs: Value(clearedAtMs),
    );
  }

  factory SearchHistoryClearState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryClearState(
      id: serializer.fromJson<String>(json['id']),
      clearedAtMs: serializer.fromJson<int>(json['clearedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clearedAtMs': serializer.toJson<int>(clearedAtMs),
    };
  }

  SearchHistoryClearState copyWith({String? id, int? clearedAtMs}) =>
      SearchHistoryClearState(
        id: id ?? this.id,
        clearedAtMs: clearedAtMs ?? this.clearedAtMs,
      );
  SearchHistoryClearState copyWithCompanion(
    SearchHistoryClearStatesCompanion data,
  ) {
    return SearchHistoryClearState(
      id: data.id.present ? data.id.value : this.id,
      clearedAtMs: data.clearedAtMs.present
          ? data.clearedAtMs.value
          : this.clearedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryClearState(')
          ..write('id: $id, ')
          ..write('clearedAtMs: $clearedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, clearedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryClearState &&
          other.id == this.id &&
          other.clearedAtMs == this.clearedAtMs);
}

class SearchHistoryClearStatesCompanion
    extends UpdateCompanion<SearchHistoryClearState> {
  final Value<String> id;
  final Value<int> clearedAtMs;
  final Value<int> rowid;
  const SearchHistoryClearStatesCompanion({
    this.id = const Value.absent(),
    this.clearedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoryClearStatesCompanion.insert({
    required String id,
    required int clearedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clearedAtMs = Value(clearedAtMs);
  static Insertable<SearchHistoryClearState> custom({
    Expression<String>? id,
    Expression<int>? clearedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clearedAtMs != null) 'cleared_at_ms': clearedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoryClearStatesCompanion copyWith({
    Value<String>? id,
    Value<int>? clearedAtMs,
    Value<int>? rowid,
  }) {
    return SearchHistoryClearStatesCompanion(
      id: id ?? this.id,
      clearedAtMs: clearedAtMs ?? this.clearedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clearedAtMs.present) {
      map['cleared_at_ms'] = Variable<int>(clearedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryClearStatesCompanion(')
          ..write('id: $id, ')
          ..write('clearedAtMs: $clearedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFavoriteFoldersTable extends LocalFavoriteFolders
    with TableInfo<$LocalFavoriteFoldersTable, LocalFavoriteFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFavoriteFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sourceKey, updatedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_favorite_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFavoriteFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFavoriteFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFavoriteFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $LocalFavoriteFoldersTable createAlias(String alias) {
    return $LocalFavoriteFoldersTable(attachedDatabase, alias);
  }
}

class LocalFavoriteFolder extends DataClass
    implements Insertable<LocalFavoriteFolder> {
  final String id;
  final String name;
  final String sourceKey;
  final int updatedAtMs;
  const LocalFavoriteFolder({
    required this.id,
    required this.name,
    required this.sourceKey,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['source_key'] = Variable<String>(sourceKey);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  LocalFavoriteFoldersCompanion toCompanion(bool nullToAbsent) {
    return LocalFavoriteFoldersCompanion(
      id: Value(id),
      name: Value(name),
      sourceKey: Value(sourceKey),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory LocalFavoriteFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFavoriteFolder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sourceKey': serializer.toJson<String>(sourceKey),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  LocalFavoriteFolder copyWith({
    String? id,
    String? name,
    String? sourceKey,
    int? updatedAtMs,
  }) => LocalFavoriteFolder(
    id: id ?? this.id,
    name: name ?? this.name,
    sourceKey: sourceKey ?? this.sourceKey,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  LocalFavoriteFolder copyWithCompanion(LocalFavoriteFoldersCompanion data) {
    return LocalFavoriteFolder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteFolder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sourceKey, updatedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFavoriteFolder &&
          other.id == this.id &&
          other.name == this.name &&
          other.sourceKey == this.sourceKey &&
          other.updatedAtMs == this.updatedAtMs);
}

class LocalFavoriteFoldersCompanion
    extends UpdateCompanion<LocalFavoriteFolder> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> sourceKey;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const LocalFavoriteFoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFavoriteFoldersCompanion.insert({
    required String id,
    required String name,
    this.sourceKey = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<LocalFavoriteFolder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? sourceKey,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sourceKey != null) 'source_key': sourceKey,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFavoriteFoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? sourceKey,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return LocalFavoriteFoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceKey: sourceKey ?? this.sourceKey,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteFoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFavoriteComicsTable extends LocalFavoriteComics
    with TableInfo<$LocalFavoriteComicsTable, LocalFavoriteComic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFavoriteComicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storageKeyMeta = const VerificationMeta(
    'storageKey',
  );
  @override
  late final GeneratedColumn<String> storageKey = GeneratedColumn<String>(
    'storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _comicIdMeta = const VerificationMeta(
    'comicId',
  );
  @override
  late final GeneratedColumn<String> comicId = GeneratedColumn<String>(
    'comic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subTitleMeta = const VerificationMeta(
    'subTitle',
  );
  @override
  late final GeneratedColumn<String> subTitle = GeneratedColumn<String>(
    'sub_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updateTimeMeta = const VerificationMeta(
    'updateTime',
  );
  @override
  late final GeneratedColumn<String> updateTime = GeneratedColumn<String>(
    'update_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    storageKey,
    comicId,
    sourceKey,
    title,
    subTitle,
    cover,
    updateTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_favorite_comics';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFavoriteComic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('storage_key')) {
      context.handle(
        _storageKeyMeta,
        storageKey.isAcceptableOrUnknown(data['storage_key']!, _storageKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_storageKeyMeta);
    }
    if (data.containsKey('comic_id')) {
      context.handle(
        _comicIdMeta,
        comicId.isAcceptableOrUnknown(data['comic_id']!, _comicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_comicIdMeta);
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('sub_title')) {
      context.handle(
        _subTitleMeta,
        subTitle.isAcceptableOrUnknown(data['sub_title']!, _subTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_subTitleMeta);
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    } else if (isInserting) {
      context.missing(_coverMeta);
    }
    if (data.containsKey('update_time')) {
      context.handle(
        _updateTimeMeta,
        updateTime.isAcceptableOrUnknown(data['update_time']!, _updateTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_updateTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storageKey};
  @override
  LocalFavoriteComic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFavoriteComic(
      storageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_key'],
      )!,
      comicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_id'],
      )!,
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_title'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      )!,
      updateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}update_time'],
      )!,
    );
  }

  @override
  $LocalFavoriteComicsTable createAlias(String alias) {
    return $LocalFavoriteComicsTable(attachedDatabase, alias);
  }
}

class LocalFavoriteComic extends DataClass
    implements Insertable<LocalFavoriteComic> {
  final String storageKey;
  final String comicId;
  final String sourceKey;
  final String title;
  final String subTitle;
  final String cover;
  final String updateTime;
  const LocalFavoriteComic({
    required this.storageKey,
    required this.comicId,
    required this.sourceKey,
    required this.title,
    required this.subTitle,
    required this.cover,
    required this.updateTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['storage_key'] = Variable<String>(storageKey);
    map['comic_id'] = Variable<String>(comicId);
    map['source_key'] = Variable<String>(sourceKey);
    map['title'] = Variable<String>(title);
    map['sub_title'] = Variable<String>(subTitle);
    map['cover'] = Variable<String>(cover);
    map['update_time'] = Variable<String>(updateTime);
    return map;
  }

  LocalFavoriteComicsCompanion toCompanion(bool nullToAbsent) {
    return LocalFavoriteComicsCompanion(
      storageKey: Value(storageKey),
      comicId: Value(comicId),
      sourceKey: Value(sourceKey),
      title: Value(title),
      subTitle: Value(subTitle),
      cover: Value(cover),
      updateTime: Value(updateTime),
    );
  }

  factory LocalFavoriteComic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFavoriteComic(
      storageKey: serializer.fromJson<String>(json['storageKey']),
      comicId: serializer.fromJson<String>(json['comicId']),
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      title: serializer.fromJson<String>(json['title']),
      subTitle: serializer.fromJson<String>(json['subTitle']),
      cover: serializer.fromJson<String>(json['cover']),
      updateTime: serializer.fromJson<String>(json['updateTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storageKey': serializer.toJson<String>(storageKey),
      'comicId': serializer.toJson<String>(comicId),
      'sourceKey': serializer.toJson<String>(sourceKey),
      'title': serializer.toJson<String>(title),
      'subTitle': serializer.toJson<String>(subTitle),
      'cover': serializer.toJson<String>(cover),
      'updateTime': serializer.toJson<String>(updateTime),
    };
  }

  LocalFavoriteComic copyWith({
    String? storageKey,
    String? comicId,
    String? sourceKey,
    String? title,
    String? subTitle,
    String? cover,
    String? updateTime,
  }) => LocalFavoriteComic(
    storageKey: storageKey ?? this.storageKey,
    comicId: comicId ?? this.comicId,
    sourceKey: sourceKey ?? this.sourceKey,
    title: title ?? this.title,
    subTitle: subTitle ?? this.subTitle,
    cover: cover ?? this.cover,
    updateTime: updateTime ?? this.updateTime,
  );
  LocalFavoriteComic copyWithCompanion(LocalFavoriteComicsCompanion data) {
    return LocalFavoriteComic(
      storageKey: data.storageKey.present
          ? data.storageKey.value
          : this.storageKey,
      comicId: data.comicId.present ? data.comicId.value : this.comicId,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      title: data.title.present ? data.title.value : this.title,
      subTitle: data.subTitle.present ? data.subTitle.value : this.subTitle,
      cover: data.cover.present ? data.cover.value : this.cover,
      updateTime: data.updateTime.present
          ? data.updateTime.value
          : this.updateTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteComic(')
          ..write('storageKey: $storageKey, ')
          ..write('comicId: $comicId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('title: $title, ')
          ..write('subTitle: $subTitle, ')
          ..write('cover: $cover, ')
          ..write('updateTime: $updateTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    storageKey,
    comicId,
    sourceKey,
    title,
    subTitle,
    cover,
    updateTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFavoriteComic &&
          other.storageKey == this.storageKey &&
          other.comicId == this.comicId &&
          other.sourceKey == this.sourceKey &&
          other.title == this.title &&
          other.subTitle == this.subTitle &&
          other.cover == this.cover &&
          other.updateTime == this.updateTime);
}

class LocalFavoriteComicsCompanion extends UpdateCompanion<LocalFavoriteComic> {
  final Value<String> storageKey;
  final Value<String> comicId;
  final Value<String> sourceKey;
  final Value<String> title;
  final Value<String> subTitle;
  final Value<String> cover;
  final Value<String> updateTime;
  final Value<int> rowid;
  const LocalFavoriteComicsCompanion({
    this.storageKey = const Value.absent(),
    this.comicId = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.title = const Value.absent(),
    this.subTitle = const Value.absent(),
    this.cover = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFavoriteComicsCompanion.insert({
    required String storageKey,
    required String comicId,
    this.sourceKey = const Value.absent(),
    required String title,
    required String subTitle,
    required String cover,
    required String updateTime,
    this.rowid = const Value.absent(),
  }) : storageKey = Value(storageKey),
       comicId = Value(comicId),
       title = Value(title),
       subTitle = Value(subTitle),
       cover = Value(cover),
       updateTime = Value(updateTime);
  static Insertable<LocalFavoriteComic> custom({
    Expression<String>? storageKey,
    Expression<String>? comicId,
    Expression<String>? sourceKey,
    Expression<String>? title,
    Expression<String>? subTitle,
    Expression<String>? cover,
    Expression<String>? updateTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storageKey != null) 'storage_key': storageKey,
      if (comicId != null) 'comic_id': comicId,
      if (sourceKey != null) 'source_key': sourceKey,
      if (title != null) 'title': title,
      if (subTitle != null) 'sub_title': subTitle,
      if (cover != null) 'cover': cover,
      if (updateTime != null) 'update_time': updateTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFavoriteComicsCompanion copyWith({
    Value<String>? storageKey,
    Value<String>? comicId,
    Value<String>? sourceKey,
    Value<String>? title,
    Value<String>? subTitle,
    Value<String>? cover,
    Value<String>? updateTime,
    Value<int>? rowid,
  }) {
    return LocalFavoriteComicsCompanion(
      storageKey: storageKey ?? this.storageKey,
      comicId: comicId ?? this.comicId,
      sourceKey: sourceKey ?? this.sourceKey,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      cover: cover ?? this.cover,
      updateTime: updateTime ?? this.updateTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storageKey.present) {
      map['storage_key'] = Variable<String>(storageKey.value);
    }
    if (comicId.present) {
      map['comic_id'] = Variable<String>(comicId.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subTitle.present) {
      map['sub_title'] = Variable<String>(subTitle.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (updateTime.present) {
      map['update_time'] = Variable<String>(updateTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteComicsCompanion(')
          ..write('storageKey: $storageKey, ')
          ..write('comicId: $comicId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('title: $title, ')
          ..write('subTitle: $subTitle, ')
          ..write('cover: $cover, ')
          ..write('updateTime: $updateTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFavoriteComicFoldersTable extends LocalFavoriteComicFolders
    with TableInfo<$LocalFavoriteComicFoldersTable, LocalFavoriteComicFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFavoriteComicFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _comicStorageKeyMeta = const VerificationMeta(
    'comicStorageKey',
  );
  @override
  late final GeneratedColumn<String> comicStorageKey = GeneratedColumn<String>(
    'comic_storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMsMeta = const VerificationMeta(
    'savedAtMs',
  );
  @override
  late final GeneratedColumn<int> savedAtMs = GeneratedColumn<int>(
    'saved_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [comicStorageKey, folderId, savedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_favorite_comic_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFavoriteComicFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('comic_storage_key')) {
      context.handle(
        _comicStorageKeyMeta,
        comicStorageKey.isAcceptableOrUnknown(
          data['comic_storage_key']!,
          _comicStorageKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_comicStorageKeyMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('saved_at_ms')) {
      context.handle(
        _savedAtMsMeta,
        savedAtMs.isAcceptableOrUnknown(data['saved_at_ms']!, _savedAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {comicStorageKey, folderId};
  @override
  LocalFavoriteComicFolder map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFavoriteComicFolder(
      comicStorageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_storage_key'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      savedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_at_ms'],
      )!,
    );
  }

  @override
  $LocalFavoriteComicFoldersTable createAlias(String alias) {
    return $LocalFavoriteComicFoldersTable(attachedDatabase, alias);
  }
}

class LocalFavoriteComicFolder extends DataClass
    implements Insertable<LocalFavoriteComicFolder> {
  final String comicStorageKey;
  final String folderId;
  final int savedAtMs;
  const LocalFavoriteComicFolder({
    required this.comicStorageKey,
    required this.folderId,
    required this.savedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['comic_storage_key'] = Variable<String>(comicStorageKey);
    map['folder_id'] = Variable<String>(folderId);
    map['saved_at_ms'] = Variable<int>(savedAtMs);
    return map;
  }

  LocalFavoriteComicFoldersCompanion toCompanion(bool nullToAbsent) {
    return LocalFavoriteComicFoldersCompanion(
      comicStorageKey: Value(comicStorageKey),
      folderId: Value(folderId),
      savedAtMs: Value(savedAtMs),
    );
  }

  factory LocalFavoriteComicFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFavoriteComicFolder(
      comicStorageKey: serializer.fromJson<String>(json['comicStorageKey']),
      folderId: serializer.fromJson<String>(json['folderId']),
      savedAtMs: serializer.fromJson<int>(json['savedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'comicStorageKey': serializer.toJson<String>(comicStorageKey),
      'folderId': serializer.toJson<String>(folderId),
      'savedAtMs': serializer.toJson<int>(savedAtMs),
    };
  }

  LocalFavoriteComicFolder copyWith({
    String? comicStorageKey,
    String? folderId,
    int? savedAtMs,
  }) => LocalFavoriteComicFolder(
    comicStorageKey: comicStorageKey ?? this.comicStorageKey,
    folderId: folderId ?? this.folderId,
    savedAtMs: savedAtMs ?? this.savedAtMs,
  );
  LocalFavoriteComicFolder copyWithCompanion(
    LocalFavoriteComicFoldersCompanion data,
  ) {
    return LocalFavoriteComicFolder(
      comicStorageKey: data.comicStorageKey.present
          ? data.comicStorageKey.value
          : this.comicStorageKey,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      savedAtMs: data.savedAtMs.present ? data.savedAtMs.value : this.savedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteComicFolder(')
          ..write('comicStorageKey: $comicStorageKey, ')
          ..write('folderId: $folderId, ')
          ..write('savedAtMs: $savedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(comicStorageKey, folderId, savedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFavoriteComicFolder &&
          other.comicStorageKey == this.comicStorageKey &&
          other.folderId == this.folderId &&
          other.savedAtMs == this.savedAtMs);
}

class LocalFavoriteComicFoldersCompanion
    extends UpdateCompanion<LocalFavoriteComicFolder> {
  final Value<String> comicStorageKey;
  final Value<String> folderId;
  final Value<int> savedAtMs;
  final Value<int> rowid;
  const LocalFavoriteComicFoldersCompanion({
    this.comicStorageKey = const Value.absent(),
    this.folderId = const Value.absent(),
    this.savedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFavoriteComicFoldersCompanion.insert({
    required String comicStorageKey,
    required String folderId,
    required int savedAtMs,
    this.rowid = const Value.absent(),
  }) : comicStorageKey = Value(comicStorageKey),
       folderId = Value(folderId),
       savedAtMs = Value(savedAtMs);
  static Insertable<LocalFavoriteComicFolder> custom({
    Expression<String>? comicStorageKey,
    Expression<String>? folderId,
    Expression<int>? savedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (comicStorageKey != null) 'comic_storage_key': comicStorageKey,
      if (folderId != null) 'folder_id': folderId,
      if (savedAtMs != null) 'saved_at_ms': savedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFavoriteComicFoldersCompanion copyWith({
    Value<String>? comicStorageKey,
    Value<String>? folderId,
    Value<int>? savedAtMs,
    Value<int>? rowid,
  }) {
    return LocalFavoriteComicFoldersCompanion(
      comicStorageKey: comicStorageKey ?? this.comicStorageKey,
      folderId: folderId ?? this.folderId,
      savedAtMs: savedAtMs ?? this.savedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (comicStorageKey.present) {
      map['comic_storage_key'] = Variable<String>(comicStorageKey.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (savedAtMs.present) {
      map['saved_at_ms'] = Variable<int>(savedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteComicFoldersCompanion(')
          ..write('comicStorageKey: $comicStorageKey, ')
          ..write('folderId: $folderId, ')
          ..write('savedAtMs: $savedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFavoriteFolderTombstonesTable extends LocalFavoriteFolderTombstones
    with
        TableInfo<
          $LocalFavoriteFolderTombstonesTable,
          LocalFavoriteFolderTombstone
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFavoriteFolderTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [folderId, deletedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_favorite_folder_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFavoriteFolderTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderId};
  @override
  LocalFavoriteFolderTombstone map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFavoriteFolderTombstone(
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      )!,
    );
  }

  @override
  $LocalFavoriteFolderTombstonesTable createAlias(String alias) {
    return $LocalFavoriteFolderTombstonesTable(attachedDatabase, alias);
  }
}

class LocalFavoriteFolderTombstone extends DataClass
    implements Insertable<LocalFavoriteFolderTombstone> {
  final String folderId;
  final int deletedAtMs;
  const LocalFavoriteFolderTombstone({
    required this.folderId,
    required this.deletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_id'] = Variable<String>(folderId);
    map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    return map;
  }

  LocalFavoriteFolderTombstonesCompanion toCompanion(bool nullToAbsent) {
    return LocalFavoriteFolderTombstonesCompanion(
      folderId: Value(folderId),
      deletedAtMs: Value(deletedAtMs),
    );
  }

  factory LocalFavoriteFolderTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFavoriteFolderTombstone(
      folderId: serializer.fromJson<String>(json['folderId']),
      deletedAtMs: serializer.fromJson<int>(json['deletedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderId': serializer.toJson<String>(folderId),
      'deletedAtMs': serializer.toJson<int>(deletedAtMs),
    };
  }

  LocalFavoriteFolderTombstone copyWith({String? folderId, int? deletedAtMs}) =>
      LocalFavoriteFolderTombstone(
        folderId: folderId ?? this.folderId,
        deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      );
  LocalFavoriteFolderTombstone copyWithCompanion(
    LocalFavoriteFolderTombstonesCompanion data,
  ) {
    return LocalFavoriteFolderTombstone(
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteFolderTombstone(')
          ..write('folderId: $folderId, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(folderId, deletedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFavoriteFolderTombstone &&
          other.folderId == this.folderId &&
          other.deletedAtMs == this.deletedAtMs);
}

class LocalFavoriteFolderTombstonesCompanion
    extends UpdateCompanion<LocalFavoriteFolderTombstone> {
  final Value<String> folderId;
  final Value<int> deletedAtMs;
  final Value<int> rowid;
  const LocalFavoriteFolderTombstonesCompanion({
    this.folderId = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFavoriteFolderTombstonesCompanion.insert({
    required String folderId,
    required int deletedAtMs,
    this.rowid = const Value.absent(),
  }) : folderId = Value(folderId),
       deletedAtMs = Value(deletedAtMs);
  static Insertable<LocalFavoriteFolderTombstone> custom({
    Expression<String>? folderId,
    Expression<int>? deletedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderId != null) 'folder_id': folderId,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFavoriteFolderTombstonesCompanion copyWith({
    Value<String>? folderId,
    Value<int>? deletedAtMs,
    Value<int>? rowid,
  }) {
    return LocalFavoriteFolderTombstonesCompanion(
      folderId: folderId ?? this.folderId,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteFolderTombstonesCompanion(')
          ..write('folderId: $folderId, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFavoriteEntryTombstonesTable extends LocalFavoriteEntryTombstones
    with
        TableInfo<
          $LocalFavoriteEntryTombstonesTable,
          LocalFavoriteEntryTombstone
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFavoriteEntryTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storageKeyMeta = const VerificationMeta(
    'storageKey',
  );
  @override
  late final GeneratedColumn<String> storageKey = GeneratedColumn<String>(
    'storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _comicIdMeta = const VerificationMeta(
    'comicId',
  );
  @override
  late final GeneratedColumn<String> comicId = GeneratedColumn<String>(
    'comic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    storageKey,
    comicId,
    sourceKey,
    deletedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_favorite_entry_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFavoriteEntryTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('storage_key')) {
      context.handle(
        _storageKeyMeta,
        storageKey.isAcceptableOrUnknown(data['storage_key']!, _storageKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_storageKeyMeta);
    }
    if (data.containsKey('comic_id')) {
      context.handle(
        _comicIdMeta,
        comicId.isAcceptableOrUnknown(data['comic_id']!, _comicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_comicIdMeta);
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storageKey};
  @override
  LocalFavoriteEntryTombstone map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFavoriteEntryTombstone(
      storageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_key'],
      )!,
      comicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_id'],
      )!,
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      )!,
    );
  }

  @override
  $LocalFavoriteEntryTombstonesTable createAlias(String alias) {
    return $LocalFavoriteEntryTombstonesTable(attachedDatabase, alias);
  }
}

class LocalFavoriteEntryTombstone extends DataClass
    implements Insertable<LocalFavoriteEntryTombstone> {
  final String storageKey;
  final String comicId;
  final String sourceKey;
  final int deletedAtMs;
  const LocalFavoriteEntryTombstone({
    required this.storageKey,
    required this.comicId,
    required this.sourceKey,
    required this.deletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['storage_key'] = Variable<String>(storageKey);
    map['comic_id'] = Variable<String>(comicId);
    map['source_key'] = Variable<String>(sourceKey);
    map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    return map;
  }

  LocalFavoriteEntryTombstonesCompanion toCompanion(bool nullToAbsent) {
    return LocalFavoriteEntryTombstonesCompanion(
      storageKey: Value(storageKey),
      comicId: Value(comicId),
      sourceKey: Value(sourceKey),
      deletedAtMs: Value(deletedAtMs),
    );
  }

  factory LocalFavoriteEntryTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFavoriteEntryTombstone(
      storageKey: serializer.fromJson<String>(json['storageKey']),
      comicId: serializer.fromJson<String>(json['comicId']),
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      deletedAtMs: serializer.fromJson<int>(json['deletedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storageKey': serializer.toJson<String>(storageKey),
      'comicId': serializer.toJson<String>(comicId),
      'sourceKey': serializer.toJson<String>(sourceKey),
      'deletedAtMs': serializer.toJson<int>(deletedAtMs),
    };
  }

  LocalFavoriteEntryTombstone copyWith({
    String? storageKey,
    String? comicId,
    String? sourceKey,
    int? deletedAtMs,
  }) => LocalFavoriteEntryTombstone(
    storageKey: storageKey ?? this.storageKey,
    comicId: comicId ?? this.comicId,
    sourceKey: sourceKey ?? this.sourceKey,
    deletedAtMs: deletedAtMs ?? this.deletedAtMs,
  );
  LocalFavoriteEntryTombstone copyWithCompanion(
    LocalFavoriteEntryTombstonesCompanion data,
  ) {
    return LocalFavoriteEntryTombstone(
      storageKey: data.storageKey.present
          ? data.storageKey.value
          : this.storageKey,
      comicId: data.comicId.present ? data.comicId.value : this.comicId,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteEntryTombstone(')
          ..write('storageKey: $storageKey, ')
          ..write('comicId: $comicId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(storageKey, comicId, sourceKey, deletedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFavoriteEntryTombstone &&
          other.storageKey == this.storageKey &&
          other.comicId == this.comicId &&
          other.sourceKey == this.sourceKey &&
          other.deletedAtMs == this.deletedAtMs);
}

class LocalFavoriteEntryTombstonesCompanion
    extends UpdateCompanion<LocalFavoriteEntryTombstone> {
  final Value<String> storageKey;
  final Value<String> comicId;
  final Value<String> sourceKey;
  final Value<int> deletedAtMs;
  final Value<int> rowid;
  const LocalFavoriteEntryTombstonesCompanion({
    this.storageKey = const Value.absent(),
    this.comicId = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFavoriteEntryTombstonesCompanion.insert({
    required String storageKey,
    required String comicId,
    this.sourceKey = const Value.absent(),
    required int deletedAtMs,
    this.rowid = const Value.absent(),
  }) : storageKey = Value(storageKey),
       comicId = Value(comicId),
       deletedAtMs = Value(deletedAtMs);
  static Insertable<LocalFavoriteEntryTombstone> custom({
    Expression<String>? storageKey,
    Expression<String>? comicId,
    Expression<String>? sourceKey,
    Expression<int>? deletedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storageKey != null) 'storage_key': storageKey,
      if (comicId != null) 'comic_id': comicId,
      if (sourceKey != null) 'source_key': sourceKey,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFavoriteEntryTombstonesCompanion copyWith({
    Value<String>? storageKey,
    Value<String>? comicId,
    Value<String>? sourceKey,
    Value<int>? deletedAtMs,
    Value<int>? rowid,
  }) {
    return LocalFavoriteEntryTombstonesCompanion(
      storageKey: storageKey ?? this.storageKey,
      comicId: comicId ?? this.comicId,
      sourceKey: sourceKey ?? this.sourceKey,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storageKey.present) {
      map['storage_key'] = Variable<String>(storageKey.value);
    }
    if (comicId.present) {
      map['comic_id'] = Variable<String>(comicId.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteEntryTombstonesCompanion(')
          ..write('storageKey: $storageKey, ')
          ..write('comicId: $comicId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFavoriteComicFolderTombstonesTable
    extends LocalFavoriteComicFolderTombstones
    with
        TableInfo<
          $LocalFavoriteComicFolderTombstonesTable,
          LocalFavoriteComicFolderTombstone
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFavoriteComicFolderTombstonesTable(
    this.attachedDatabase, [
    this._alias,
  ]);
  static const VerificationMeta _comicStorageKeyMeta = const VerificationMeta(
    'comicStorageKey',
  );
  @override
  late final GeneratedColumn<String> comicStorageKey = GeneratedColumn<String>(
    'comic_storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    comicStorageKey,
    folderId,
    deletedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_favorite_comic_folder_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFavoriteComicFolderTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('comic_storage_key')) {
      context.handle(
        _comicStorageKeyMeta,
        comicStorageKey.isAcceptableOrUnknown(
          data['comic_storage_key']!,
          _comicStorageKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_comicStorageKeyMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {comicStorageKey, folderId};
  @override
  LocalFavoriteComicFolderTombstone map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFavoriteComicFolderTombstone(
      comicStorageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_storage_key'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      )!,
    );
  }

  @override
  $LocalFavoriteComicFolderTombstonesTable createAlias(String alias) {
    return $LocalFavoriteComicFolderTombstonesTable(attachedDatabase, alias);
  }
}

class LocalFavoriteComicFolderTombstone extends DataClass
    implements Insertable<LocalFavoriteComicFolderTombstone> {
  final String comicStorageKey;
  final String folderId;
  final int deletedAtMs;
  const LocalFavoriteComicFolderTombstone({
    required this.comicStorageKey,
    required this.folderId,
    required this.deletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['comic_storage_key'] = Variable<String>(comicStorageKey);
    map['folder_id'] = Variable<String>(folderId);
    map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    return map;
  }

  LocalFavoriteComicFolderTombstonesCompanion toCompanion(bool nullToAbsent) {
    return LocalFavoriteComicFolderTombstonesCompanion(
      comicStorageKey: Value(comicStorageKey),
      folderId: Value(folderId),
      deletedAtMs: Value(deletedAtMs),
    );
  }

  factory LocalFavoriteComicFolderTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFavoriteComicFolderTombstone(
      comicStorageKey: serializer.fromJson<String>(json['comicStorageKey']),
      folderId: serializer.fromJson<String>(json['folderId']),
      deletedAtMs: serializer.fromJson<int>(json['deletedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'comicStorageKey': serializer.toJson<String>(comicStorageKey),
      'folderId': serializer.toJson<String>(folderId),
      'deletedAtMs': serializer.toJson<int>(deletedAtMs),
    };
  }

  LocalFavoriteComicFolderTombstone copyWith({
    String? comicStorageKey,
    String? folderId,
    int? deletedAtMs,
  }) => LocalFavoriteComicFolderTombstone(
    comicStorageKey: comicStorageKey ?? this.comicStorageKey,
    folderId: folderId ?? this.folderId,
    deletedAtMs: deletedAtMs ?? this.deletedAtMs,
  );
  LocalFavoriteComicFolderTombstone copyWithCompanion(
    LocalFavoriteComicFolderTombstonesCompanion data,
  ) {
    return LocalFavoriteComicFolderTombstone(
      comicStorageKey: data.comicStorageKey.present
          ? data.comicStorageKey.value
          : this.comicStorageKey,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteComicFolderTombstone(')
          ..write('comicStorageKey: $comicStorageKey, ')
          ..write('folderId: $folderId, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(comicStorageKey, folderId, deletedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFavoriteComicFolderTombstone &&
          other.comicStorageKey == this.comicStorageKey &&
          other.folderId == this.folderId &&
          other.deletedAtMs == this.deletedAtMs);
}

class LocalFavoriteComicFolderTombstonesCompanion
    extends UpdateCompanion<LocalFavoriteComicFolderTombstone> {
  final Value<String> comicStorageKey;
  final Value<String> folderId;
  final Value<int> deletedAtMs;
  final Value<int> rowid;
  const LocalFavoriteComicFolderTombstonesCompanion({
    this.comicStorageKey = const Value.absent(),
    this.folderId = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFavoriteComicFolderTombstonesCompanion.insert({
    required String comicStorageKey,
    required String folderId,
    required int deletedAtMs,
    this.rowid = const Value.absent(),
  }) : comicStorageKey = Value(comicStorageKey),
       folderId = Value(folderId),
       deletedAtMs = Value(deletedAtMs);
  static Insertable<LocalFavoriteComicFolderTombstone> custom({
    Expression<String>? comicStorageKey,
    Expression<String>? folderId,
    Expression<int>? deletedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (comicStorageKey != null) 'comic_storage_key': comicStorageKey,
      if (folderId != null) 'folder_id': folderId,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFavoriteComicFolderTombstonesCompanion copyWith({
    Value<String>? comicStorageKey,
    Value<String>? folderId,
    Value<int>? deletedAtMs,
    Value<int>? rowid,
  }) {
    return LocalFavoriteComicFolderTombstonesCompanion(
      comicStorageKey: comicStorageKey ?? this.comicStorageKey,
      folderId: folderId ?? this.folderId,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (comicStorageKey.present) {
      map['comic_storage_key'] = Variable<String>(comicStorageKey.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoriteComicFolderTombstonesCompanion(')
          ..write('comicStorageKey: $comicStorageKey, ')
          ..write('folderId: $folderId, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadGroupsTable extends DownloadGroups
    with TableInfo<$DownloadGroupsTable, DownloadGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAtMs, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $DownloadGroupsTable createAlias(String alias) {
    return $DownloadGroupsTable(attachedDatabase, alias);
  }
}

class DownloadGroup extends DataClass implements Insertable<DownloadGroup> {
  final String id;
  final String name;
  final int createdAtMs;
  final int sortOrder;
  const DownloadGroup({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  DownloadGroupsCompanion toCompanion(bool nullToAbsent) {
    return DownloadGroupsCompanion(
      id: Value(id),
      name: Value(name),
      createdAtMs: Value(createdAtMs),
      sortOrder: Value(sortOrder),
    );
  }

  factory DownloadGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  DownloadGroup copyWith({
    String? id,
    String? name,
    int? createdAtMs,
    int? sortOrder,
  }) => DownloadGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  DownloadGroup copyWithCompanion(DownloadGroupsCompanion data) {
    return DownloadGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAtMs, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAtMs == this.createdAtMs &&
          other.sortOrder == this.sortOrder);
}

class DownloadGroupsCompanion extends UpdateCompanion<DownloadGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> createdAtMs;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const DownloadGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadGroupsCompanion.insert({
    required String id,
    required String name,
    required int createdAtMs,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAtMs = Value(createdAtMs);
  static Insertable<DownloadGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAtMs,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? createdAtMs,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return DownloadGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadGroupComicsTable extends DownloadGroupComics
    with TableInfo<$DownloadGroupComicsTable, DownloadGroupComic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadGroupComicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _comicStorageKeyMeta = const VerificationMeta(
    'comicStorageKey',
  );
  @override
  late final GeneratedColumn<String> comicStorageKey = GeneratedColumn<String>(
    'comic_storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMsMeta = const VerificationMeta(
    'addedAtMs',
  );
  @override
  late final GeneratedColumn<int> addedAtMs = GeneratedColumn<int>(
    'added_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, comicStorageKey, addedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_group_comics';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadGroupComic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('comic_storage_key')) {
      context.handle(
        _comicStorageKeyMeta,
        comicStorageKey.isAcceptableOrUnknown(
          data['comic_storage_key']!,
          _comicStorageKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_comicStorageKeyMeta);
    }
    if (data.containsKey('added_at_ms')) {
      context.handle(
        _addedAtMsMeta,
        addedAtMs.isAcceptableOrUnknown(data['added_at_ms']!, _addedAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, comicStorageKey};
  @override
  DownloadGroupComic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadGroupComic(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      comicStorageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_storage_key'],
      )!,
      addedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at_ms'],
      )!,
    );
  }

  @override
  $DownloadGroupComicsTable createAlias(String alias) {
    return $DownloadGroupComicsTable(attachedDatabase, alias);
  }
}

class DownloadGroupComic extends DataClass
    implements Insertable<DownloadGroupComic> {
  final String groupId;
  final String comicStorageKey;
  final int addedAtMs;
  const DownloadGroupComic({
    required this.groupId,
    required this.comicStorageKey,
    required this.addedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['comic_storage_key'] = Variable<String>(comicStorageKey);
    map['added_at_ms'] = Variable<int>(addedAtMs);
    return map;
  }

  DownloadGroupComicsCompanion toCompanion(bool nullToAbsent) {
    return DownloadGroupComicsCompanion(
      groupId: Value(groupId),
      comicStorageKey: Value(comicStorageKey),
      addedAtMs: Value(addedAtMs),
    );
  }

  factory DownloadGroupComic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadGroupComic(
      groupId: serializer.fromJson<String>(json['groupId']),
      comicStorageKey: serializer.fromJson<String>(json['comicStorageKey']),
      addedAtMs: serializer.fromJson<int>(json['addedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'comicStorageKey': serializer.toJson<String>(comicStorageKey),
      'addedAtMs': serializer.toJson<int>(addedAtMs),
    };
  }

  DownloadGroupComic copyWith({
    String? groupId,
    String? comicStorageKey,
    int? addedAtMs,
  }) => DownloadGroupComic(
    groupId: groupId ?? this.groupId,
    comicStorageKey: comicStorageKey ?? this.comicStorageKey,
    addedAtMs: addedAtMs ?? this.addedAtMs,
  );
  DownloadGroupComic copyWithCompanion(DownloadGroupComicsCompanion data) {
    return DownloadGroupComic(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      comicStorageKey: data.comicStorageKey.present
          ? data.comicStorageKey.value
          : this.comicStorageKey,
      addedAtMs: data.addedAtMs.present ? data.addedAtMs.value : this.addedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroupComic(')
          ..write('groupId: $groupId, ')
          ..write('comicStorageKey: $comicStorageKey, ')
          ..write('addedAtMs: $addedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, comicStorageKey, addedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadGroupComic &&
          other.groupId == this.groupId &&
          other.comicStorageKey == this.comicStorageKey &&
          other.addedAtMs == this.addedAtMs);
}

class DownloadGroupComicsCompanion extends UpdateCompanion<DownloadGroupComic> {
  final Value<String> groupId;
  final Value<String> comicStorageKey;
  final Value<int> addedAtMs;
  final Value<int> rowid;
  const DownloadGroupComicsCompanion({
    this.groupId = const Value.absent(),
    this.comicStorageKey = const Value.absent(),
    this.addedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadGroupComicsCompanion.insert({
    required String groupId,
    required String comicStorageKey,
    required int addedAtMs,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       comicStorageKey = Value(comicStorageKey),
       addedAtMs = Value(addedAtMs);
  static Insertable<DownloadGroupComic> custom({
    Expression<String>? groupId,
    Expression<String>? comicStorageKey,
    Expression<int>? addedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (comicStorageKey != null) 'comic_storage_key': comicStorageKey,
      if (addedAtMs != null) 'added_at_ms': addedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadGroupComicsCompanion copyWith({
    Value<String>? groupId,
    Value<String>? comicStorageKey,
    Value<int>? addedAtMs,
    Value<int>? rowid,
  }) {
    return DownloadGroupComicsCompanion(
      groupId: groupId ?? this.groupId,
      comicStorageKey: comicStorageKey ?? this.comicStorageKey,
      addedAtMs: addedAtMs ?? this.addedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (comicStorageKey.present) {
      map['comic_storage_key'] = Variable<String>(comicStorageKey.value);
    }
    if (addedAtMs.present) {
      map['added_at_ms'] = Variable<int>(addedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroupComicsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('comicStorageKey: $comicStorageKey, ')
          ..write('addedAtMs: $addedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadGroupTombstonesTable extends DownloadGroupTombstones
    with TableInfo<$DownloadGroupTombstonesTable, DownloadGroupTombstone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadGroupTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, deletedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_group_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadGroupTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  DownloadGroupTombstone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadGroupTombstone(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      )!,
    );
  }

  @override
  $DownloadGroupTombstonesTable createAlias(String alias) {
    return $DownloadGroupTombstonesTable(attachedDatabase, alias);
  }
}

class DownloadGroupTombstone extends DataClass
    implements Insertable<DownloadGroupTombstone> {
  final String groupId;
  final int deletedAtMs;
  const DownloadGroupTombstone({
    required this.groupId,
    required this.deletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    return map;
  }

  DownloadGroupTombstonesCompanion toCompanion(bool nullToAbsent) {
    return DownloadGroupTombstonesCompanion(
      groupId: Value(groupId),
      deletedAtMs: Value(deletedAtMs),
    );
  }

  factory DownloadGroupTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadGroupTombstone(
      groupId: serializer.fromJson<String>(json['groupId']),
      deletedAtMs: serializer.fromJson<int>(json['deletedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'deletedAtMs': serializer.toJson<int>(deletedAtMs),
    };
  }

  DownloadGroupTombstone copyWith({String? groupId, int? deletedAtMs}) =>
      DownloadGroupTombstone(
        groupId: groupId ?? this.groupId,
        deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      );
  DownloadGroupTombstone copyWithCompanion(
    DownloadGroupTombstonesCompanion data,
  ) {
    return DownloadGroupTombstone(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroupTombstone(')
          ..write('groupId: $groupId, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, deletedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadGroupTombstone &&
          other.groupId == this.groupId &&
          other.deletedAtMs == this.deletedAtMs);
}

class DownloadGroupTombstonesCompanion
    extends UpdateCompanion<DownloadGroupTombstone> {
  final Value<String> groupId;
  final Value<int> deletedAtMs;
  final Value<int> rowid;
  const DownloadGroupTombstonesCompanion({
    this.groupId = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadGroupTombstonesCompanion.insert({
    required String groupId,
    required int deletedAtMs,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       deletedAtMs = Value(deletedAtMs);
  static Insertable<DownloadGroupTombstone> custom({
    Expression<String>? groupId,
    Expression<int>? deletedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadGroupTombstonesCompanion copyWith({
    Value<String>? groupId,
    Value<int>? deletedAtMs,
    Value<int>? rowid,
  }) {
    return DownloadGroupTombstonesCompanion(
      groupId: groupId ?? this.groupId,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroupTombstonesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadGroupComicTombstonesTable extends DownloadGroupComicTombstones
    with
        TableInfo<
          $DownloadGroupComicTombstonesTable,
          DownloadGroupComicTombstone
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadGroupComicTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _comicStorageKeyMeta = const VerificationMeta(
    'comicStorageKey',
  );
  @override
  late final GeneratedColumn<String> comicStorageKey = GeneratedColumn<String>(
    'comic_storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, comicStorageKey, deletedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_group_comic_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadGroupComicTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('comic_storage_key')) {
      context.handle(
        _comicStorageKeyMeta,
        comicStorageKey.isAcceptableOrUnknown(
          data['comic_storage_key']!,
          _comicStorageKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_comicStorageKeyMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, comicStorageKey};
  @override
  DownloadGroupComicTombstone map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadGroupComicTombstone(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      comicStorageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_storage_key'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      )!,
    );
  }

  @override
  $DownloadGroupComicTombstonesTable createAlias(String alias) {
    return $DownloadGroupComicTombstonesTable(attachedDatabase, alias);
  }
}

class DownloadGroupComicTombstone extends DataClass
    implements Insertable<DownloadGroupComicTombstone> {
  final String groupId;
  final String comicStorageKey;
  final int deletedAtMs;
  const DownloadGroupComicTombstone({
    required this.groupId,
    required this.comicStorageKey,
    required this.deletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['comic_storage_key'] = Variable<String>(comicStorageKey);
    map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    return map;
  }

  DownloadGroupComicTombstonesCompanion toCompanion(bool nullToAbsent) {
    return DownloadGroupComicTombstonesCompanion(
      groupId: Value(groupId),
      comicStorageKey: Value(comicStorageKey),
      deletedAtMs: Value(deletedAtMs),
    );
  }

  factory DownloadGroupComicTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadGroupComicTombstone(
      groupId: serializer.fromJson<String>(json['groupId']),
      comicStorageKey: serializer.fromJson<String>(json['comicStorageKey']),
      deletedAtMs: serializer.fromJson<int>(json['deletedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'comicStorageKey': serializer.toJson<String>(comicStorageKey),
      'deletedAtMs': serializer.toJson<int>(deletedAtMs),
    };
  }

  DownloadGroupComicTombstone copyWith({
    String? groupId,
    String? comicStorageKey,
    int? deletedAtMs,
  }) => DownloadGroupComicTombstone(
    groupId: groupId ?? this.groupId,
    comicStorageKey: comicStorageKey ?? this.comicStorageKey,
    deletedAtMs: deletedAtMs ?? this.deletedAtMs,
  );
  DownloadGroupComicTombstone copyWithCompanion(
    DownloadGroupComicTombstonesCompanion data,
  ) {
    return DownloadGroupComicTombstone(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      comicStorageKey: data.comicStorageKey.present
          ? data.comicStorageKey.value
          : this.comicStorageKey,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroupComicTombstone(')
          ..write('groupId: $groupId, ')
          ..write('comicStorageKey: $comicStorageKey, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, comicStorageKey, deletedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadGroupComicTombstone &&
          other.groupId == this.groupId &&
          other.comicStorageKey == this.comicStorageKey &&
          other.deletedAtMs == this.deletedAtMs);
}

class DownloadGroupComicTombstonesCompanion
    extends UpdateCompanion<DownloadGroupComicTombstone> {
  final Value<String> groupId;
  final Value<String> comicStorageKey;
  final Value<int> deletedAtMs;
  final Value<int> rowid;
  const DownloadGroupComicTombstonesCompanion({
    this.groupId = const Value.absent(),
    this.comicStorageKey = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadGroupComicTombstonesCompanion.insert({
    required String groupId,
    required String comicStorageKey,
    required int deletedAtMs,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       comicStorageKey = Value(comicStorageKey),
       deletedAtMs = Value(deletedAtMs);
  static Insertable<DownloadGroupComicTombstone> custom({
    Expression<String>? groupId,
    Expression<String>? comicStorageKey,
    Expression<int>? deletedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (comicStorageKey != null) 'comic_storage_key': comicStorageKey,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadGroupComicTombstonesCompanion copyWith({
    Value<String>? groupId,
    Value<String>? comicStorageKey,
    Value<int>? deletedAtMs,
    Value<int>? rowid,
  }) {
    return DownloadGroupComicTombstonesCompanion(
      groupId: groupId ?? this.groupId,
      comicStorageKey: comicStorageKey ?? this.comicStorageKey,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (comicStorageKey.present) {
      map['comic_storage_key'] = Variable<String>(comicStorageKey.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroupComicTombstonesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('comicStorageKey: $comicStorageKey, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HazukiDatabase extends GeneratedDatabase {
  _$HazukiDatabase(QueryExecutor e) : super(e);
  $HazukiDatabaseManager get managers => $HazukiDatabaseManager(this);
  late final $ReadHistoryEntriesTable readHistoryEntries =
      $ReadHistoryEntriesTable(this);
  late final $ReadingProgressEntriesTable readingProgressEntries =
      $ReadingProgressEntriesTable(this);
  late final $SearchHistoryEntriesTable searchHistoryEntries =
      $SearchHistoryEntriesTable(this);
  late final $SearchHistoryTombstonesTable searchHistoryTombstones =
      $SearchHistoryTombstonesTable(this);
  late final $SearchHistoryClearStatesTable searchHistoryClearStates =
      $SearchHistoryClearStatesTable(this);
  late final $LocalFavoriteFoldersTable localFavoriteFolders =
      $LocalFavoriteFoldersTable(this);
  late final $LocalFavoriteComicsTable localFavoriteComics =
      $LocalFavoriteComicsTable(this);
  late final $LocalFavoriteComicFoldersTable localFavoriteComicFolders =
      $LocalFavoriteComicFoldersTable(this);
  late final $LocalFavoriteFolderTombstonesTable localFavoriteFolderTombstones =
      $LocalFavoriteFolderTombstonesTable(this);
  late final $LocalFavoriteEntryTombstonesTable localFavoriteEntryTombstones =
      $LocalFavoriteEntryTombstonesTable(this);
  late final $LocalFavoriteComicFolderTombstonesTable
  localFavoriteComicFolderTombstones = $LocalFavoriteComicFolderTombstonesTable(
    this,
  );
  late final $DownloadGroupsTable downloadGroups = $DownloadGroupsTable(this);
  late final $DownloadGroupComicsTable downloadGroupComics =
      $DownloadGroupComicsTable(this);
  late final $DownloadGroupTombstonesTable downloadGroupTombstones =
      $DownloadGroupTombstonesTable(this);
  late final $DownloadGroupComicTombstonesTable downloadGroupComicTombstones =
      $DownloadGroupComicTombstonesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    readHistoryEntries,
    readingProgressEntries,
    searchHistoryEntries,
    searchHistoryTombstones,
    searchHistoryClearStates,
    localFavoriteFolders,
    localFavoriteComics,
    localFavoriteComicFolders,
    localFavoriteFolderTombstones,
    localFavoriteEntryTombstones,
    localFavoriteComicFolderTombstones,
    downloadGroups,
    downloadGroupComics,
    downloadGroupTombstones,
    downloadGroupComicTombstones,
  ];
}

typedef $$ReadHistoryEntriesTableCreateCompanionBuilder =
    ReadHistoryEntriesCompanion Function({
      required String storageKey,
      required String comicId,
      required String sourceKey,
      required String title,
      required String cover,
      required String subTitle,
      required int timestampMs,
      Value<int> rowid,
    });
typedef $$ReadHistoryEntriesTableUpdateCompanionBuilder =
    ReadHistoryEntriesCompanion Function({
      Value<String> storageKey,
      Value<String> comicId,
      Value<String> sourceKey,
      Value<String> title,
      Value<String> cover,
      Value<String> subTitle,
      Value<int> timestampMs,
      Value<int> rowid,
    });

class $$ReadHistoryEntriesTableFilterComposer
    extends Composer<_$HazukiDatabase, $ReadHistoryEntriesTable> {
  $$ReadHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comicId => $composableBuilder(
    column: $table.comicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subTitle => $composableBuilder(
    column: $table.subTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadHistoryEntriesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $ReadHistoryEntriesTable> {
  $$ReadHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comicId => $composableBuilder(
    column: $table.comicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subTitle => $composableBuilder(
    column: $table.subTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadHistoryEntriesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $ReadHistoryEntriesTable> {
  $$ReadHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comicId =>
      $composableBuilder(column: $table.comicId, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get subTitle =>
      $composableBuilder(column: $table.subTitle, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );
}

class $$ReadHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $ReadHistoryEntriesTable,
          ReadHistoryEntry,
          $$ReadHistoryEntriesTableFilterComposer,
          $$ReadHistoryEntriesTableOrderingComposer,
          $$ReadHistoryEntriesTableAnnotationComposer,
          $$ReadHistoryEntriesTableCreateCompanionBuilder,
          $$ReadHistoryEntriesTableUpdateCompanionBuilder,
          (
            ReadHistoryEntry,
            BaseReferences<
              _$HazukiDatabase,
              $ReadHistoryEntriesTable,
              ReadHistoryEntry
            >,
          ),
          ReadHistoryEntry,
          PrefetchHooks Function()
        > {
  $$ReadHistoryEntriesTableTableManager(
    _$HazukiDatabase db,
    $ReadHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadHistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadHistoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> storageKey = const Value.absent(),
                Value<String> comicId = const Value.absent(),
                Value<String> sourceKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> cover = const Value.absent(),
                Value<String> subTitle = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadHistoryEntriesCompanion(
                storageKey: storageKey,
                comicId: comicId,
                sourceKey: sourceKey,
                title: title,
                cover: cover,
                subTitle: subTitle,
                timestampMs: timestampMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storageKey,
                required String comicId,
                required String sourceKey,
                required String title,
                required String cover,
                required String subTitle,
                required int timestampMs,
                Value<int> rowid = const Value.absent(),
              }) => ReadHistoryEntriesCompanion.insert(
                storageKey: storageKey,
                comicId: comicId,
                sourceKey: sourceKey,
                title: title,
                cover: cover,
                subTitle: subTitle,
                timestampMs: timestampMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $ReadHistoryEntriesTable,
      ReadHistoryEntry,
      $$ReadHistoryEntriesTableFilterComposer,
      $$ReadHistoryEntriesTableOrderingComposer,
      $$ReadHistoryEntriesTableAnnotationComposer,
      $$ReadHistoryEntriesTableCreateCompanionBuilder,
      $$ReadHistoryEntriesTableUpdateCompanionBuilder,
      (
        ReadHistoryEntry,
        BaseReferences<
          _$HazukiDatabase,
          $ReadHistoryEntriesTable,
          ReadHistoryEntry
        >,
      ),
      ReadHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$ReadingProgressEntriesTableCreateCompanionBuilder =
    ReadingProgressEntriesCompanion Function({
      required String storageKey,
      required String comicId,
      required String sourceKey,
      required String epId,
      required String title,
      required int chapterIndex,
      Value<int> pageIndex,
      required int timestampMs,
      Value<int> rowid,
    });
typedef $$ReadingProgressEntriesTableUpdateCompanionBuilder =
    ReadingProgressEntriesCompanion Function({
      Value<String> storageKey,
      Value<String> comicId,
      Value<String> sourceKey,
      Value<String> epId,
      Value<String> title,
      Value<int> chapterIndex,
      Value<int> pageIndex,
      Value<int> timestampMs,
      Value<int> rowid,
    });

class $$ReadingProgressEntriesTableFilterComposer
    extends Composer<_$HazukiDatabase, $ReadingProgressEntriesTable> {
  $$ReadingProgressEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comicId => $composableBuilder(
    column: $table.comicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epId => $composableBuilder(
    column: $table.epId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressEntriesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $ReadingProgressEntriesTable> {
  $$ReadingProgressEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comicId => $composableBuilder(
    column: $table.comicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epId => $composableBuilder(
    column: $table.epId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressEntriesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $ReadingProgressEntriesTable> {
  $$ReadingProgressEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comicId =>
      $composableBuilder(column: $table.comicId, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<String> get epId =>
      $composableBuilder(column: $table.epId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );
}

class $$ReadingProgressEntriesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $ReadingProgressEntriesTable,
          ReadingProgressEntry,
          $$ReadingProgressEntriesTableFilterComposer,
          $$ReadingProgressEntriesTableOrderingComposer,
          $$ReadingProgressEntriesTableAnnotationComposer,
          $$ReadingProgressEntriesTableCreateCompanionBuilder,
          $$ReadingProgressEntriesTableUpdateCompanionBuilder,
          (
            ReadingProgressEntry,
            BaseReferences<
              _$HazukiDatabase,
              $ReadingProgressEntriesTable,
              ReadingProgressEntry
            >,
          ),
          ReadingProgressEntry,
          PrefetchHooks Function()
        > {
  $$ReadingProgressEntriesTableTableManager(
    _$HazukiDatabase db,
    $ReadingProgressEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ReadingProgressEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReadingProgressEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> storageKey = const Value.absent(),
                Value<String> comicId = const Value.absent(),
                Value<String> sourceKey = const Value.absent(),
                Value<String> epId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressEntriesCompanion(
                storageKey: storageKey,
                comicId: comicId,
                sourceKey: sourceKey,
                epId: epId,
                title: title,
                chapterIndex: chapterIndex,
                pageIndex: pageIndex,
                timestampMs: timestampMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storageKey,
                required String comicId,
                required String sourceKey,
                required String epId,
                required String title,
                required int chapterIndex,
                Value<int> pageIndex = const Value.absent(),
                required int timestampMs,
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressEntriesCompanion.insert(
                storageKey: storageKey,
                comicId: comicId,
                sourceKey: sourceKey,
                epId: epId,
                title: title,
                chapterIndex: chapterIndex,
                pageIndex: pageIndex,
                timestampMs: timestampMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $ReadingProgressEntriesTable,
      ReadingProgressEntry,
      $$ReadingProgressEntriesTableFilterComposer,
      $$ReadingProgressEntriesTableOrderingComposer,
      $$ReadingProgressEntriesTableAnnotationComposer,
      $$ReadingProgressEntriesTableCreateCompanionBuilder,
      $$ReadingProgressEntriesTableUpdateCompanionBuilder,
      (
        ReadingProgressEntry,
        BaseReferences<
          _$HazukiDatabase,
          $ReadingProgressEntriesTable,
          ReadingProgressEntry
        >,
      ),
      ReadingProgressEntry,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryEntriesTableCreateCompanionBuilder =
    SearchHistoryEntriesCompanion Function({
      required String keyword,
      required int position,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });
typedef $$SearchHistoryEntriesTableUpdateCompanionBuilder =
    SearchHistoryEntriesCompanion Function({
      Value<String> keyword,
      Value<int> position,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

class $$SearchHistoryEntriesTableFilterComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryEntriesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryEntriesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$SearchHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $SearchHistoryEntriesTable,
          SearchHistoryEntry,
          $$SearchHistoryEntriesTableFilterComposer,
          $$SearchHistoryEntriesTableOrderingComposer,
          $$SearchHistoryEntriesTableAnnotationComposer,
          $$SearchHistoryEntriesTableCreateCompanionBuilder,
          $$SearchHistoryEntriesTableUpdateCompanionBuilder,
          (
            SearchHistoryEntry,
            BaseReferences<
              _$HazukiDatabase,
              $SearchHistoryEntriesTable,
              SearchHistoryEntry
            >,
          ),
          SearchHistoryEntry,
          PrefetchHooks Function()
        > {
  $$SearchHistoryEntriesTableTableManager(
    _$HazukiDatabase db,
    $SearchHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SearchHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> keyword = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryEntriesCompanion(
                keyword: keyword,
                position: position,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String keyword,
                required int position,
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryEntriesCompanion.insert(
                keyword: keyword,
                position: position,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $SearchHistoryEntriesTable,
      SearchHistoryEntry,
      $$SearchHistoryEntriesTableFilterComposer,
      $$SearchHistoryEntriesTableOrderingComposer,
      $$SearchHistoryEntriesTableAnnotationComposer,
      $$SearchHistoryEntriesTableCreateCompanionBuilder,
      $$SearchHistoryEntriesTableUpdateCompanionBuilder,
      (
        SearchHistoryEntry,
        BaseReferences<
          _$HazukiDatabase,
          $SearchHistoryEntriesTable,
          SearchHistoryEntry
        >,
      ),
      SearchHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryTombstonesTableCreateCompanionBuilder =
    SearchHistoryTombstonesCompanion Function({
      required String keyword,
      required int deletedAtMs,
      Value<int> rowid,
    });
typedef $$SearchHistoryTombstonesTableUpdateCompanionBuilder =
    SearchHistoryTombstonesCompanion Function({
      Value<String> keyword,
      Value<int> deletedAtMs,
      Value<int> rowid,
    });

class $$SearchHistoryTombstonesTableFilterComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryTombstonesTable> {
  $$SearchHistoryTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTombstonesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryTombstonesTable> {
  $$SearchHistoryTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTombstonesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryTombstonesTable> {
  $$SearchHistoryTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );
}

class $$SearchHistoryTombstonesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $SearchHistoryTombstonesTable,
          SearchHistoryTombstone,
          $$SearchHistoryTombstonesTableFilterComposer,
          $$SearchHistoryTombstonesTableOrderingComposer,
          $$SearchHistoryTombstonesTableAnnotationComposer,
          $$SearchHistoryTombstonesTableCreateCompanionBuilder,
          $$SearchHistoryTombstonesTableUpdateCompanionBuilder,
          (
            SearchHistoryTombstone,
            BaseReferences<
              _$HazukiDatabase,
              $SearchHistoryTombstonesTable,
              SearchHistoryTombstone
            >,
          ),
          SearchHistoryTombstone,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTombstonesTableTableManager(
    _$HazukiDatabase db,
    $SearchHistoryTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryTombstonesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SearchHistoryTombstonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SearchHistoryTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> keyword = const Value.absent(),
                Value<int> deletedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryTombstonesCompanion(
                keyword: keyword,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String keyword,
                required int deletedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryTombstonesCompanion.insert(
                keyword: keyword,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $SearchHistoryTombstonesTable,
      SearchHistoryTombstone,
      $$SearchHistoryTombstonesTableFilterComposer,
      $$SearchHistoryTombstonesTableOrderingComposer,
      $$SearchHistoryTombstonesTableAnnotationComposer,
      $$SearchHistoryTombstonesTableCreateCompanionBuilder,
      $$SearchHistoryTombstonesTableUpdateCompanionBuilder,
      (
        SearchHistoryTombstone,
        BaseReferences<
          _$HazukiDatabase,
          $SearchHistoryTombstonesTable,
          SearchHistoryTombstone
        >,
      ),
      SearchHistoryTombstone,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryClearStatesTableCreateCompanionBuilder =
    SearchHistoryClearStatesCompanion Function({
      required String id,
      required int clearedAtMs,
      Value<int> rowid,
    });
typedef $$SearchHistoryClearStatesTableUpdateCompanionBuilder =
    SearchHistoryClearStatesCompanion Function({
      Value<String> id,
      Value<int> clearedAtMs,
      Value<int> rowid,
    });

class $$SearchHistoryClearStatesTableFilterComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryClearStatesTable> {
  $$SearchHistoryClearStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clearedAtMs => $composableBuilder(
    column: $table.clearedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryClearStatesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryClearStatesTable> {
  $$SearchHistoryClearStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clearedAtMs => $composableBuilder(
    column: $table.clearedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryClearStatesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $SearchHistoryClearStatesTable> {
  $$SearchHistoryClearStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get clearedAtMs => $composableBuilder(
    column: $table.clearedAtMs,
    builder: (column) => column,
  );
}

class $$SearchHistoryClearStatesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $SearchHistoryClearStatesTable,
          SearchHistoryClearState,
          $$SearchHistoryClearStatesTableFilterComposer,
          $$SearchHistoryClearStatesTableOrderingComposer,
          $$SearchHistoryClearStatesTableAnnotationComposer,
          $$SearchHistoryClearStatesTableCreateCompanionBuilder,
          $$SearchHistoryClearStatesTableUpdateCompanionBuilder,
          (
            SearchHistoryClearState,
            BaseReferences<
              _$HazukiDatabase,
              $SearchHistoryClearStatesTable,
              SearchHistoryClearState
            >,
          ),
          SearchHistoryClearState,
          PrefetchHooks Function()
        > {
  $$SearchHistoryClearStatesTableTableManager(
    _$HazukiDatabase db,
    $SearchHistoryClearStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryClearStatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SearchHistoryClearStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SearchHistoryClearStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> clearedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryClearStatesCompanion(
                id: id,
                clearedAtMs: clearedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int clearedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryClearStatesCompanion.insert(
                id: id,
                clearedAtMs: clearedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryClearStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $SearchHistoryClearStatesTable,
      SearchHistoryClearState,
      $$SearchHistoryClearStatesTableFilterComposer,
      $$SearchHistoryClearStatesTableOrderingComposer,
      $$SearchHistoryClearStatesTableAnnotationComposer,
      $$SearchHistoryClearStatesTableCreateCompanionBuilder,
      $$SearchHistoryClearStatesTableUpdateCompanionBuilder,
      (
        SearchHistoryClearState,
        BaseReferences<
          _$HazukiDatabase,
          $SearchHistoryClearStatesTable,
          SearchHistoryClearState
        >,
      ),
      SearchHistoryClearState,
      PrefetchHooks Function()
    >;
typedef $$LocalFavoriteFoldersTableCreateCompanionBuilder =
    LocalFavoriteFoldersCompanion Function({
      required String id,
      required String name,
      Value<String> sourceKey,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });
typedef $$LocalFavoriteFoldersTableUpdateCompanionBuilder =
    LocalFavoriteFoldersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> sourceKey,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

class $$LocalFavoriteFoldersTableFilterComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteFoldersTable> {
  $$LocalFavoriteFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFavoriteFoldersTableOrderingComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteFoldersTable> {
  $$LocalFavoriteFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFavoriteFoldersTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteFoldersTable> {
  $$LocalFavoriteFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$LocalFavoriteFoldersTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $LocalFavoriteFoldersTable,
          LocalFavoriteFolder,
          $$LocalFavoriteFoldersTableFilterComposer,
          $$LocalFavoriteFoldersTableOrderingComposer,
          $$LocalFavoriteFoldersTableAnnotationComposer,
          $$LocalFavoriteFoldersTableCreateCompanionBuilder,
          $$LocalFavoriteFoldersTableUpdateCompanionBuilder,
          (
            LocalFavoriteFolder,
            BaseReferences<
              _$HazukiDatabase,
              $LocalFavoriteFoldersTable,
              LocalFavoriteFolder
            >,
          ),
          LocalFavoriteFolder,
          PrefetchHooks Function()
        > {
  $$LocalFavoriteFoldersTableTableManager(
    _$HazukiDatabase db,
    $LocalFavoriteFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFavoriteFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFavoriteFoldersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalFavoriteFoldersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> sourceKey = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteFoldersCompanion(
                id: id,
                name: name,
                sourceKey: sourceKey,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> sourceKey = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteFoldersCompanion.insert(
                id: id,
                name: name,
                sourceKey: sourceKey,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFavoriteFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $LocalFavoriteFoldersTable,
      LocalFavoriteFolder,
      $$LocalFavoriteFoldersTableFilterComposer,
      $$LocalFavoriteFoldersTableOrderingComposer,
      $$LocalFavoriteFoldersTableAnnotationComposer,
      $$LocalFavoriteFoldersTableCreateCompanionBuilder,
      $$LocalFavoriteFoldersTableUpdateCompanionBuilder,
      (
        LocalFavoriteFolder,
        BaseReferences<
          _$HazukiDatabase,
          $LocalFavoriteFoldersTable,
          LocalFavoriteFolder
        >,
      ),
      LocalFavoriteFolder,
      PrefetchHooks Function()
    >;
typedef $$LocalFavoriteComicsTableCreateCompanionBuilder =
    LocalFavoriteComicsCompanion Function({
      required String storageKey,
      required String comicId,
      Value<String> sourceKey,
      required String title,
      required String subTitle,
      required String cover,
      required String updateTime,
      Value<int> rowid,
    });
typedef $$LocalFavoriteComicsTableUpdateCompanionBuilder =
    LocalFavoriteComicsCompanion Function({
      Value<String> storageKey,
      Value<String> comicId,
      Value<String> sourceKey,
      Value<String> title,
      Value<String> subTitle,
      Value<String> cover,
      Value<String> updateTime,
      Value<int> rowid,
    });

class $$LocalFavoriteComicsTableFilterComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteComicsTable> {
  $$LocalFavoriteComicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comicId => $composableBuilder(
    column: $table.comicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subTitle => $composableBuilder(
    column: $table.subTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFavoriteComicsTableOrderingComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteComicsTable> {
  $$LocalFavoriteComicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comicId => $composableBuilder(
    column: $table.comicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subTitle => $composableBuilder(
    column: $table.subTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFavoriteComicsTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteComicsTable> {
  $$LocalFavoriteComicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comicId =>
      $composableBuilder(column: $table.comicId, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subTitle =>
      $composableBuilder(column: $table.subTitle, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => column,
  );
}

class $$LocalFavoriteComicsTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $LocalFavoriteComicsTable,
          LocalFavoriteComic,
          $$LocalFavoriteComicsTableFilterComposer,
          $$LocalFavoriteComicsTableOrderingComposer,
          $$LocalFavoriteComicsTableAnnotationComposer,
          $$LocalFavoriteComicsTableCreateCompanionBuilder,
          $$LocalFavoriteComicsTableUpdateCompanionBuilder,
          (
            LocalFavoriteComic,
            BaseReferences<
              _$HazukiDatabase,
              $LocalFavoriteComicsTable,
              LocalFavoriteComic
            >,
          ),
          LocalFavoriteComic,
          PrefetchHooks Function()
        > {
  $$LocalFavoriteComicsTableTableManager(
    _$HazukiDatabase db,
    $LocalFavoriteComicsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFavoriteComicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFavoriteComicsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalFavoriteComicsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> storageKey = const Value.absent(),
                Value<String> comicId = const Value.absent(),
                Value<String> sourceKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subTitle = const Value.absent(),
                Value<String> cover = const Value.absent(),
                Value<String> updateTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteComicsCompanion(
                storageKey: storageKey,
                comicId: comicId,
                sourceKey: sourceKey,
                title: title,
                subTitle: subTitle,
                cover: cover,
                updateTime: updateTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storageKey,
                required String comicId,
                Value<String> sourceKey = const Value.absent(),
                required String title,
                required String subTitle,
                required String cover,
                required String updateTime,
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteComicsCompanion.insert(
                storageKey: storageKey,
                comicId: comicId,
                sourceKey: sourceKey,
                title: title,
                subTitle: subTitle,
                cover: cover,
                updateTime: updateTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFavoriteComicsTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $LocalFavoriteComicsTable,
      LocalFavoriteComic,
      $$LocalFavoriteComicsTableFilterComposer,
      $$LocalFavoriteComicsTableOrderingComposer,
      $$LocalFavoriteComicsTableAnnotationComposer,
      $$LocalFavoriteComicsTableCreateCompanionBuilder,
      $$LocalFavoriteComicsTableUpdateCompanionBuilder,
      (
        LocalFavoriteComic,
        BaseReferences<
          _$HazukiDatabase,
          $LocalFavoriteComicsTable,
          LocalFavoriteComic
        >,
      ),
      LocalFavoriteComic,
      PrefetchHooks Function()
    >;
typedef $$LocalFavoriteComicFoldersTableCreateCompanionBuilder =
    LocalFavoriteComicFoldersCompanion Function({
      required String comicStorageKey,
      required String folderId,
      required int savedAtMs,
      Value<int> rowid,
    });
typedef $$LocalFavoriteComicFoldersTableUpdateCompanionBuilder =
    LocalFavoriteComicFoldersCompanion Function({
      Value<String> comicStorageKey,
      Value<String> folderId,
      Value<int> savedAtMs,
      Value<int> rowid,
    });

class $$LocalFavoriteComicFoldersTableFilterComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteComicFoldersTable> {
  $$LocalFavoriteComicFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savedAtMs => $composableBuilder(
    column: $table.savedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFavoriteComicFoldersTableOrderingComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteComicFoldersTable> {
  $$LocalFavoriteComicFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savedAtMs => $composableBuilder(
    column: $table.savedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFavoriteComicFoldersTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteComicFoldersTable> {
  $$LocalFavoriteComicFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get savedAtMs =>
      $composableBuilder(column: $table.savedAtMs, builder: (column) => column);
}

class $$LocalFavoriteComicFoldersTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $LocalFavoriteComicFoldersTable,
          LocalFavoriteComicFolder,
          $$LocalFavoriteComicFoldersTableFilterComposer,
          $$LocalFavoriteComicFoldersTableOrderingComposer,
          $$LocalFavoriteComicFoldersTableAnnotationComposer,
          $$LocalFavoriteComicFoldersTableCreateCompanionBuilder,
          $$LocalFavoriteComicFoldersTableUpdateCompanionBuilder,
          (
            LocalFavoriteComicFolder,
            BaseReferences<
              _$HazukiDatabase,
              $LocalFavoriteComicFoldersTable,
              LocalFavoriteComicFolder
            >,
          ),
          LocalFavoriteComicFolder,
          PrefetchHooks Function()
        > {
  $$LocalFavoriteComicFoldersTableTableManager(
    _$HazukiDatabase db,
    $LocalFavoriteComicFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFavoriteComicFoldersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalFavoriteComicFoldersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalFavoriteComicFoldersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> comicStorageKey = const Value.absent(),
                Value<String> folderId = const Value.absent(),
                Value<int> savedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteComicFoldersCompanion(
                comicStorageKey: comicStorageKey,
                folderId: folderId,
                savedAtMs: savedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String comicStorageKey,
                required String folderId,
                required int savedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteComicFoldersCompanion.insert(
                comicStorageKey: comicStorageKey,
                folderId: folderId,
                savedAtMs: savedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFavoriteComicFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $LocalFavoriteComicFoldersTable,
      LocalFavoriteComicFolder,
      $$LocalFavoriteComicFoldersTableFilterComposer,
      $$LocalFavoriteComicFoldersTableOrderingComposer,
      $$LocalFavoriteComicFoldersTableAnnotationComposer,
      $$LocalFavoriteComicFoldersTableCreateCompanionBuilder,
      $$LocalFavoriteComicFoldersTableUpdateCompanionBuilder,
      (
        LocalFavoriteComicFolder,
        BaseReferences<
          _$HazukiDatabase,
          $LocalFavoriteComicFoldersTable,
          LocalFavoriteComicFolder
        >,
      ),
      LocalFavoriteComicFolder,
      PrefetchHooks Function()
    >;
typedef $$LocalFavoriteFolderTombstonesTableCreateCompanionBuilder =
    LocalFavoriteFolderTombstonesCompanion Function({
      required String folderId,
      required int deletedAtMs,
      Value<int> rowid,
    });
typedef $$LocalFavoriteFolderTombstonesTableUpdateCompanionBuilder =
    LocalFavoriteFolderTombstonesCompanion Function({
      Value<String> folderId,
      Value<int> deletedAtMs,
      Value<int> rowid,
    });

class $$LocalFavoriteFolderTombstonesTableFilterComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteFolderTombstonesTable> {
  $$LocalFavoriteFolderTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFavoriteFolderTombstonesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteFolderTombstonesTable> {
  $$LocalFavoriteFolderTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFavoriteFolderTombstonesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteFolderTombstonesTable> {
  $$LocalFavoriteFolderTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );
}

class $$LocalFavoriteFolderTombstonesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $LocalFavoriteFolderTombstonesTable,
          LocalFavoriteFolderTombstone,
          $$LocalFavoriteFolderTombstonesTableFilterComposer,
          $$LocalFavoriteFolderTombstonesTableOrderingComposer,
          $$LocalFavoriteFolderTombstonesTableAnnotationComposer,
          $$LocalFavoriteFolderTombstonesTableCreateCompanionBuilder,
          $$LocalFavoriteFolderTombstonesTableUpdateCompanionBuilder,
          (
            LocalFavoriteFolderTombstone,
            BaseReferences<
              _$HazukiDatabase,
              $LocalFavoriteFolderTombstonesTable,
              LocalFavoriteFolderTombstone
            >,
          ),
          LocalFavoriteFolderTombstone,
          PrefetchHooks Function()
        > {
  $$LocalFavoriteFolderTombstonesTableTableManager(
    _$HazukiDatabase db,
    $LocalFavoriteFolderTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFavoriteFolderTombstonesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalFavoriteFolderTombstonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalFavoriteFolderTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> folderId = const Value.absent(),
                Value<int> deletedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteFolderTombstonesCompanion(
                folderId: folderId,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String folderId,
                required int deletedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteFolderTombstonesCompanion.insert(
                folderId: folderId,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFavoriteFolderTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $LocalFavoriteFolderTombstonesTable,
      LocalFavoriteFolderTombstone,
      $$LocalFavoriteFolderTombstonesTableFilterComposer,
      $$LocalFavoriteFolderTombstonesTableOrderingComposer,
      $$LocalFavoriteFolderTombstonesTableAnnotationComposer,
      $$LocalFavoriteFolderTombstonesTableCreateCompanionBuilder,
      $$LocalFavoriteFolderTombstonesTableUpdateCompanionBuilder,
      (
        LocalFavoriteFolderTombstone,
        BaseReferences<
          _$HazukiDatabase,
          $LocalFavoriteFolderTombstonesTable,
          LocalFavoriteFolderTombstone
        >,
      ),
      LocalFavoriteFolderTombstone,
      PrefetchHooks Function()
    >;
typedef $$LocalFavoriteEntryTombstonesTableCreateCompanionBuilder =
    LocalFavoriteEntryTombstonesCompanion Function({
      required String storageKey,
      required String comicId,
      Value<String> sourceKey,
      required int deletedAtMs,
      Value<int> rowid,
    });
typedef $$LocalFavoriteEntryTombstonesTableUpdateCompanionBuilder =
    LocalFavoriteEntryTombstonesCompanion Function({
      Value<String> storageKey,
      Value<String> comicId,
      Value<String> sourceKey,
      Value<int> deletedAtMs,
      Value<int> rowid,
    });

class $$LocalFavoriteEntryTombstonesTableFilterComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteEntryTombstonesTable> {
  $$LocalFavoriteEntryTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comicId => $composableBuilder(
    column: $table.comicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFavoriteEntryTombstonesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteEntryTombstonesTable> {
  $$LocalFavoriteEntryTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comicId => $composableBuilder(
    column: $table.comicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFavoriteEntryTombstonesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $LocalFavoriteEntryTombstonesTable> {
  $$LocalFavoriteEntryTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comicId =>
      $composableBuilder(column: $table.comicId, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );
}

class $$LocalFavoriteEntryTombstonesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $LocalFavoriteEntryTombstonesTable,
          LocalFavoriteEntryTombstone,
          $$LocalFavoriteEntryTombstonesTableFilterComposer,
          $$LocalFavoriteEntryTombstonesTableOrderingComposer,
          $$LocalFavoriteEntryTombstonesTableAnnotationComposer,
          $$LocalFavoriteEntryTombstonesTableCreateCompanionBuilder,
          $$LocalFavoriteEntryTombstonesTableUpdateCompanionBuilder,
          (
            LocalFavoriteEntryTombstone,
            BaseReferences<
              _$HazukiDatabase,
              $LocalFavoriteEntryTombstonesTable,
              LocalFavoriteEntryTombstone
            >,
          ),
          LocalFavoriteEntryTombstone,
          PrefetchHooks Function()
        > {
  $$LocalFavoriteEntryTombstonesTableTableManager(
    _$HazukiDatabase db,
    $LocalFavoriteEntryTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFavoriteEntryTombstonesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalFavoriteEntryTombstonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalFavoriteEntryTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> storageKey = const Value.absent(),
                Value<String> comicId = const Value.absent(),
                Value<String> sourceKey = const Value.absent(),
                Value<int> deletedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteEntryTombstonesCompanion(
                storageKey: storageKey,
                comicId: comicId,
                sourceKey: sourceKey,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storageKey,
                required String comicId,
                Value<String> sourceKey = const Value.absent(),
                required int deletedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteEntryTombstonesCompanion.insert(
                storageKey: storageKey,
                comicId: comicId,
                sourceKey: sourceKey,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFavoriteEntryTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $LocalFavoriteEntryTombstonesTable,
      LocalFavoriteEntryTombstone,
      $$LocalFavoriteEntryTombstonesTableFilterComposer,
      $$LocalFavoriteEntryTombstonesTableOrderingComposer,
      $$LocalFavoriteEntryTombstonesTableAnnotationComposer,
      $$LocalFavoriteEntryTombstonesTableCreateCompanionBuilder,
      $$LocalFavoriteEntryTombstonesTableUpdateCompanionBuilder,
      (
        LocalFavoriteEntryTombstone,
        BaseReferences<
          _$HazukiDatabase,
          $LocalFavoriteEntryTombstonesTable,
          LocalFavoriteEntryTombstone
        >,
      ),
      LocalFavoriteEntryTombstone,
      PrefetchHooks Function()
    >;
typedef $$LocalFavoriteComicFolderTombstonesTableCreateCompanionBuilder =
    LocalFavoriteComicFolderTombstonesCompanion Function({
      required String comicStorageKey,
      required String folderId,
      required int deletedAtMs,
      Value<int> rowid,
    });
typedef $$LocalFavoriteComicFolderTombstonesTableUpdateCompanionBuilder =
    LocalFavoriteComicFolderTombstonesCompanion Function({
      Value<String> comicStorageKey,
      Value<String> folderId,
      Value<int> deletedAtMs,
      Value<int> rowid,
    });

class $$LocalFavoriteComicFolderTombstonesTableFilterComposer
    extends
        Composer<_$HazukiDatabase, $LocalFavoriteComicFolderTombstonesTable> {
  $$LocalFavoriteComicFolderTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFavoriteComicFolderTombstonesTableOrderingComposer
    extends
        Composer<_$HazukiDatabase, $LocalFavoriteComicFolderTombstonesTable> {
  $$LocalFavoriteComicFolderTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFavoriteComicFolderTombstonesTableAnnotationComposer
    extends
        Composer<_$HazukiDatabase, $LocalFavoriteComicFolderTombstonesTable> {
  $$LocalFavoriteComicFolderTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );
}

class $$LocalFavoriteComicFolderTombstonesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $LocalFavoriteComicFolderTombstonesTable,
          LocalFavoriteComicFolderTombstone,
          $$LocalFavoriteComicFolderTombstonesTableFilterComposer,
          $$LocalFavoriteComicFolderTombstonesTableOrderingComposer,
          $$LocalFavoriteComicFolderTombstonesTableAnnotationComposer,
          $$LocalFavoriteComicFolderTombstonesTableCreateCompanionBuilder,
          $$LocalFavoriteComicFolderTombstonesTableUpdateCompanionBuilder,
          (
            LocalFavoriteComicFolderTombstone,
            BaseReferences<
              _$HazukiDatabase,
              $LocalFavoriteComicFolderTombstonesTable,
              LocalFavoriteComicFolderTombstone
            >,
          ),
          LocalFavoriteComicFolderTombstone,
          PrefetchHooks Function()
        > {
  $$LocalFavoriteComicFolderTombstonesTableTableManager(
    _$HazukiDatabase db,
    $LocalFavoriteComicFolderTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFavoriteComicFolderTombstonesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalFavoriteComicFolderTombstonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalFavoriteComicFolderTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> comicStorageKey = const Value.absent(),
                Value<String> folderId = const Value.absent(),
                Value<int> deletedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteComicFolderTombstonesCompanion(
                comicStorageKey: comicStorageKey,
                folderId: folderId,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String comicStorageKey,
                required String folderId,
                required int deletedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoriteComicFolderTombstonesCompanion.insert(
                comicStorageKey: comicStorageKey,
                folderId: folderId,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFavoriteComicFolderTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $LocalFavoriteComicFolderTombstonesTable,
      LocalFavoriteComicFolderTombstone,
      $$LocalFavoriteComicFolderTombstonesTableFilterComposer,
      $$LocalFavoriteComicFolderTombstonesTableOrderingComposer,
      $$LocalFavoriteComicFolderTombstonesTableAnnotationComposer,
      $$LocalFavoriteComicFolderTombstonesTableCreateCompanionBuilder,
      $$LocalFavoriteComicFolderTombstonesTableUpdateCompanionBuilder,
      (
        LocalFavoriteComicFolderTombstone,
        BaseReferences<
          _$HazukiDatabase,
          $LocalFavoriteComicFolderTombstonesTable,
          LocalFavoriteComicFolderTombstone
        >,
      ),
      LocalFavoriteComicFolderTombstone,
      PrefetchHooks Function()
    >;
typedef $$DownloadGroupsTableCreateCompanionBuilder =
    DownloadGroupsCompanion Function({
      required String id,
      required String name,
      required int createdAtMs,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$DownloadGroupsTableUpdateCompanionBuilder =
    DownloadGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> createdAtMs,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$DownloadGroupsTableFilterComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupsTable> {
  $$DownloadGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadGroupsTableOrderingComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupsTable> {
  $$DownloadGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadGroupsTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupsTable> {
  $$DownloadGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$DownloadGroupsTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $DownloadGroupsTable,
          DownloadGroup,
          $$DownloadGroupsTableFilterComposer,
          $$DownloadGroupsTableOrderingComposer,
          $$DownloadGroupsTableAnnotationComposer,
          $$DownloadGroupsTableCreateCompanionBuilder,
          $$DownloadGroupsTableUpdateCompanionBuilder,
          (
            DownloadGroup,
            BaseReferences<
              _$HazukiDatabase,
              $DownloadGroupsTable,
              DownloadGroup
            >,
          ),
          DownloadGroup,
          PrefetchHooks Function()
        > {
  $$DownloadGroupsTableTableManager(
    _$HazukiDatabase db,
    $DownloadGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupsCompanion(
                id: id,
                name: name,
                createdAtMs: createdAtMs,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int createdAtMs,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupsCompanion.insert(
                id: id,
                name: name,
                createdAtMs: createdAtMs,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $DownloadGroupsTable,
      DownloadGroup,
      $$DownloadGroupsTableFilterComposer,
      $$DownloadGroupsTableOrderingComposer,
      $$DownloadGroupsTableAnnotationComposer,
      $$DownloadGroupsTableCreateCompanionBuilder,
      $$DownloadGroupsTableUpdateCompanionBuilder,
      (
        DownloadGroup,
        BaseReferences<_$HazukiDatabase, $DownloadGroupsTable, DownloadGroup>,
      ),
      DownloadGroup,
      PrefetchHooks Function()
    >;
typedef $$DownloadGroupComicsTableCreateCompanionBuilder =
    DownloadGroupComicsCompanion Function({
      required String groupId,
      required String comicStorageKey,
      required int addedAtMs,
      Value<int> rowid,
    });
typedef $$DownloadGroupComicsTableUpdateCompanionBuilder =
    DownloadGroupComicsCompanion Function({
      Value<String> groupId,
      Value<String> comicStorageKey,
      Value<int> addedAtMs,
      Value<int> rowid,
    });

class $$DownloadGroupComicsTableFilterComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupComicsTable> {
  $$DownloadGroupComicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAtMs => $composableBuilder(
    column: $table.addedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadGroupComicsTableOrderingComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupComicsTable> {
  $$DownloadGroupComicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAtMs => $composableBuilder(
    column: $table.addedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadGroupComicsTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupComicsTable> {
  $$DownloadGroupComicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAtMs =>
      $composableBuilder(column: $table.addedAtMs, builder: (column) => column);
}

class $$DownloadGroupComicsTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $DownloadGroupComicsTable,
          DownloadGroupComic,
          $$DownloadGroupComicsTableFilterComposer,
          $$DownloadGroupComicsTableOrderingComposer,
          $$DownloadGroupComicsTableAnnotationComposer,
          $$DownloadGroupComicsTableCreateCompanionBuilder,
          $$DownloadGroupComicsTableUpdateCompanionBuilder,
          (
            DownloadGroupComic,
            BaseReferences<
              _$HazukiDatabase,
              $DownloadGroupComicsTable,
              DownloadGroupComic
            >,
          ),
          DownloadGroupComic,
          PrefetchHooks Function()
        > {
  $$DownloadGroupComicsTableTableManager(
    _$HazukiDatabase db,
    $DownloadGroupComicsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadGroupComicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadGroupComicsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadGroupComicsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> comicStorageKey = const Value.absent(),
                Value<int> addedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupComicsCompanion(
                groupId: groupId,
                comicStorageKey: comicStorageKey,
                addedAtMs: addedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String comicStorageKey,
                required int addedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupComicsCompanion.insert(
                groupId: groupId,
                comicStorageKey: comicStorageKey,
                addedAtMs: addedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadGroupComicsTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $DownloadGroupComicsTable,
      DownloadGroupComic,
      $$DownloadGroupComicsTableFilterComposer,
      $$DownloadGroupComicsTableOrderingComposer,
      $$DownloadGroupComicsTableAnnotationComposer,
      $$DownloadGroupComicsTableCreateCompanionBuilder,
      $$DownloadGroupComicsTableUpdateCompanionBuilder,
      (
        DownloadGroupComic,
        BaseReferences<
          _$HazukiDatabase,
          $DownloadGroupComicsTable,
          DownloadGroupComic
        >,
      ),
      DownloadGroupComic,
      PrefetchHooks Function()
    >;
typedef $$DownloadGroupTombstonesTableCreateCompanionBuilder =
    DownloadGroupTombstonesCompanion Function({
      required String groupId,
      required int deletedAtMs,
      Value<int> rowid,
    });
typedef $$DownloadGroupTombstonesTableUpdateCompanionBuilder =
    DownloadGroupTombstonesCompanion Function({
      Value<String> groupId,
      Value<int> deletedAtMs,
      Value<int> rowid,
    });

class $$DownloadGroupTombstonesTableFilterComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupTombstonesTable> {
  $$DownloadGroupTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadGroupTombstonesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupTombstonesTable> {
  $$DownloadGroupTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadGroupTombstonesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupTombstonesTable> {
  $$DownloadGroupTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );
}

class $$DownloadGroupTombstonesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $DownloadGroupTombstonesTable,
          DownloadGroupTombstone,
          $$DownloadGroupTombstonesTableFilterComposer,
          $$DownloadGroupTombstonesTableOrderingComposer,
          $$DownloadGroupTombstonesTableAnnotationComposer,
          $$DownloadGroupTombstonesTableCreateCompanionBuilder,
          $$DownloadGroupTombstonesTableUpdateCompanionBuilder,
          (
            DownloadGroupTombstone,
            BaseReferences<
              _$HazukiDatabase,
              $DownloadGroupTombstonesTable,
              DownloadGroupTombstone
            >,
          ),
          DownloadGroupTombstone,
          PrefetchHooks Function()
        > {
  $$DownloadGroupTombstonesTableTableManager(
    _$HazukiDatabase db,
    $DownloadGroupTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadGroupTombstonesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DownloadGroupTombstonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadGroupTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<int> deletedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupTombstonesCompanion(
                groupId: groupId,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required int deletedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupTombstonesCompanion.insert(
                groupId: groupId,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadGroupTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $DownloadGroupTombstonesTable,
      DownloadGroupTombstone,
      $$DownloadGroupTombstonesTableFilterComposer,
      $$DownloadGroupTombstonesTableOrderingComposer,
      $$DownloadGroupTombstonesTableAnnotationComposer,
      $$DownloadGroupTombstonesTableCreateCompanionBuilder,
      $$DownloadGroupTombstonesTableUpdateCompanionBuilder,
      (
        DownloadGroupTombstone,
        BaseReferences<
          _$HazukiDatabase,
          $DownloadGroupTombstonesTable,
          DownloadGroupTombstone
        >,
      ),
      DownloadGroupTombstone,
      PrefetchHooks Function()
    >;
typedef $$DownloadGroupComicTombstonesTableCreateCompanionBuilder =
    DownloadGroupComicTombstonesCompanion Function({
      required String groupId,
      required String comicStorageKey,
      required int deletedAtMs,
      Value<int> rowid,
    });
typedef $$DownloadGroupComicTombstonesTableUpdateCompanionBuilder =
    DownloadGroupComicTombstonesCompanion Function({
      Value<String> groupId,
      Value<String> comicStorageKey,
      Value<int> deletedAtMs,
      Value<int> rowid,
    });

class $$DownloadGroupComicTombstonesTableFilterComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupComicTombstonesTable> {
  $$DownloadGroupComicTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadGroupComicTombstonesTableOrderingComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupComicTombstonesTable> {
  $$DownloadGroupComicTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadGroupComicTombstonesTableAnnotationComposer
    extends Composer<_$HazukiDatabase, $DownloadGroupComicTombstonesTable> {
  $$DownloadGroupComicTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get comicStorageKey => $composableBuilder(
    column: $table.comicStorageKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );
}

class $$DownloadGroupComicTombstonesTableTableManager
    extends
        RootTableManager<
          _$HazukiDatabase,
          $DownloadGroupComicTombstonesTable,
          DownloadGroupComicTombstone,
          $$DownloadGroupComicTombstonesTableFilterComposer,
          $$DownloadGroupComicTombstonesTableOrderingComposer,
          $$DownloadGroupComicTombstonesTableAnnotationComposer,
          $$DownloadGroupComicTombstonesTableCreateCompanionBuilder,
          $$DownloadGroupComicTombstonesTableUpdateCompanionBuilder,
          (
            DownloadGroupComicTombstone,
            BaseReferences<
              _$HazukiDatabase,
              $DownloadGroupComicTombstonesTable,
              DownloadGroupComicTombstone
            >,
          ),
          DownloadGroupComicTombstone,
          PrefetchHooks Function()
        > {
  $$DownloadGroupComicTombstonesTableTableManager(
    _$HazukiDatabase db,
    $DownloadGroupComicTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadGroupComicTombstonesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DownloadGroupComicTombstonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadGroupComicTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> comicStorageKey = const Value.absent(),
                Value<int> deletedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupComicTombstonesCompanion(
                groupId: groupId,
                comicStorageKey: comicStorageKey,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String comicStorageKey,
                required int deletedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupComicTombstonesCompanion.insert(
                groupId: groupId,
                comicStorageKey: comicStorageKey,
                deletedAtMs: deletedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadGroupComicTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$HazukiDatabase,
      $DownloadGroupComicTombstonesTable,
      DownloadGroupComicTombstone,
      $$DownloadGroupComicTombstonesTableFilterComposer,
      $$DownloadGroupComicTombstonesTableOrderingComposer,
      $$DownloadGroupComicTombstonesTableAnnotationComposer,
      $$DownloadGroupComicTombstonesTableCreateCompanionBuilder,
      $$DownloadGroupComicTombstonesTableUpdateCompanionBuilder,
      (
        DownloadGroupComicTombstone,
        BaseReferences<
          _$HazukiDatabase,
          $DownloadGroupComicTombstonesTable,
          DownloadGroupComicTombstone
        >,
      ),
      DownloadGroupComicTombstone,
      PrefetchHooks Function()
    >;

class $HazukiDatabaseManager {
  final _$HazukiDatabase _db;
  $HazukiDatabaseManager(this._db);
  $$ReadHistoryEntriesTableTableManager get readHistoryEntries =>
      $$ReadHistoryEntriesTableTableManager(_db, _db.readHistoryEntries);
  $$ReadingProgressEntriesTableTableManager get readingProgressEntries =>
      $$ReadingProgressEntriesTableTableManager(
        _db,
        _db.readingProgressEntries,
      );
  $$SearchHistoryEntriesTableTableManager get searchHistoryEntries =>
      $$SearchHistoryEntriesTableTableManager(_db, _db.searchHistoryEntries);
  $$SearchHistoryTombstonesTableTableManager get searchHistoryTombstones =>
      $$SearchHistoryTombstonesTableTableManager(
        _db,
        _db.searchHistoryTombstones,
      );
  $$SearchHistoryClearStatesTableTableManager get searchHistoryClearStates =>
      $$SearchHistoryClearStatesTableTableManager(
        _db,
        _db.searchHistoryClearStates,
      );
  $$LocalFavoriteFoldersTableTableManager get localFavoriteFolders =>
      $$LocalFavoriteFoldersTableTableManager(_db, _db.localFavoriteFolders);
  $$LocalFavoriteComicsTableTableManager get localFavoriteComics =>
      $$LocalFavoriteComicsTableTableManager(_db, _db.localFavoriteComics);
  $$LocalFavoriteComicFoldersTableTableManager get localFavoriteComicFolders =>
      $$LocalFavoriteComicFoldersTableTableManager(
        _db,
        _db.localFavoriteComicFolders,
      );
  $$LocalFavoriteFolderTombstonesTableTableManager
  get localFavoriteFolderTombstones =>
      $$LocalFavoriteFolderTombstonesTableTableManager(
        _db,
        _db.localFavoriteFolderTombstones,
      );
  $$LocalFavoriteEntryTombstonesTableTableManager
  get localFavoriteEntryTombstones =>
      $$LocalFavoriteEntryTombstonesTableTableManager(
        _db,
        _db.localFavoriteEntryTombstones,
      );
  $$LocalFavoriteComicFolderTombstonesTableTableManager
  get localFavoriteComicFolderTombstones =>
      $$LocalFavoriteComicFolderTombstonesTableTableManager(
        _db,
        _db.localFavoriteComicFolderTombstones,
      );
  $$DownloadGroupsTableTableManager get downloadGroups =>
      $$DownloadGroupsTableTableManager(_db, _db.downloadGroups);
  $$DownloadGroupComicsTableTableManager get downloadGroupComics =>
      $$DownloadGroupComicsTableTableManager(_db, _db.downloadGroupComics);
  $$DownloadGroupTombstonesTableTableManager get downloadGroupTombstones =>
      $$DownloadGroupTombstonesTableTableManager(
        _db,
        _db.downloadGroupTombstones,
      );
  $$DownloadGroupComicTombstonesTableTableManager
  get downloadGroupComicTombstones =>
      $$DownloadGroupComicTombstonesTableTableManager(
        _db,
        _db.downloadGroupComicTombstones,
      );
}
