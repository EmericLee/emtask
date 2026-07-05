// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CalendarsTable extends Calendars
    with TableInfo<$CalendarsTable, CalendarRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#2E7D32'),
  );
  static const VerificationMeta _supportsVTodoMeta = const VerificationMeta(
    'supportsVTodo',
  );
  @override
  late final GeneratedColumn<bool> supportsVTodo = GeneratedColumn<bool>(
    'supports_v_todo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_v_todo" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _supportsVEventMeta = const VerificationMeta(
    'supportsVEvent',
  );
  @override
  late final GeneratedColumn<bool> supportsVEvent = GeneratedColumn<bool>(
    'supports_v_event',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_v_event" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ctagMeta = const VerificationMeta('ctag');
  @override
  late final GeneratedColumn<String> ctag = GeneratedColumn<String>(
    'ctag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncTokenMeta = const VerificationMeta(
    'syncToken',
  );
  @override
  late final GeneratedColumn<String> syncToken = GeneratedColumn<String>(
    'sync_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncEnabledMeta = const VerificationMeta(
    'syncEnabled',
  );
  @override
  late final GeneratedColumn<bool> syncEnabled = GeneratedColumn<bool>(
    'sync_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    displayName,
    color,
    supportsVTodo,
    supportsVEvent,
    owner,
    ctag,
    syncToken,
    syncEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendars';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('supports_v_todo')) {
      context.handle(
        _supportsVTodoMeta,
        supportsVTodo.isAcceptableOrUnknown(
          data['supports_v_todo']!,
          _supportsVTodoMeta,
        ),
      );
    }
    if (data.containsKey('supports_v_event')) {
      context.handle(
        _supportsVEventMeta,
        supportsVEvent.isAcceptableOrUnknown(
          data['supports_v_event']!,
          _supportsVEventMeta,
        ),
      );
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    }
    if (data.containsKey('ctag')) {
      context.handle(
        _ctagMeta,
        ctag.isAcceptableOrUnknown(data['ctag']!, _ctagMeta),
      );
    }
    if (data.containsKey('sync_token')) {
      context.handle(
        _syncTokenMeta,
        syncToken.isAcceptableOrUnknown(data['sync_token']!, _syncTokenMeta),
      );
    }
    if (data.containsKey('sync_enabled')) {
      context.handle(
        _syncEnabledMeta,
        syncEnabled.isAcceptableOrUnknown(
          data['sync_enabled']!,
          _syncEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      supportsVTodo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_v_todo'],
      )!,
      supportsVEvent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_v_event'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      ctag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ctag'],
      ),
      syncToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_token'],
      ),
      syncEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_enabled'],
      )!,
    );
  }

  @override
  $CalendarsTable createAlias(String alias) {
    return $CalendarsTable(attachedDatabase, alias);
  }
}

class CalendarRow extends DataClass implements Insertable<CalendarRow> {
  final int id;

  /// 远端日历集合 URL（同步主键）
  final String url;
  final String displayName;
  final String color;
  final bool supportsVTodo;
  final bool supportsVEvent;
  final String owner;

  /// calendarserver CTag
  final String? ctag;

  /// WebDAV sync-token
  final String? syncToken;
  final bool syncEnabled;
  const CalendarRow({
    required this.id,
    required this.url,
    required this.displayName,
    required this.color,
    required this.supportsVTodo,
    required this.supportsVEvent,
    required this.owner,
    this.ctag,
    this.syncToken,
    required this.syncEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['url'] = Variable<String>(url);
    map['display_name'] = Variable<String>(displayName);
    map['color'] = Variable<String>(color);
    map['supports_v_todo'] = Variable<bool>(supportsVTodo);
    map['supports_v_event'] = Variable<bool>(supportsVEvent);
    map['owner'] = Variable<String>(owner);
    if (!nullToAbsent || ctag != null) {
      map['ctag'] = Variable<String>(ctag);
    }
    if (!nullToAbsent || syncToken != null) {
      map['sync_token'] = Variable<String>(syncToken);
    }
    map['sync_enabled'] = Variable<bool>(syncEnabled);
    return map;
  }

  CalendarsCompanion toCompanion(bool nullToAbsent) {
    return CalendarsCompanion(
      id: Value(id),
      url: Value(url),
      displayName: Value(displayName),
      color: Value(color),
      supportsVTodo: Value(supportsVTodo),
      supportsVEvent: Value(supportsVEvent),
      owner: Value(owner),
      ctag: ctag == null && nullToAbsent ? const Value.absent() : Value(ctag),
      syncToken: syncToken == null && nullToAbsent
          ? const Value.absent()
          : Value(syncToken),
      syncEnabled: Value(syncEnabled),
    );
  }

  factory CalendarRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarRow(
      id: serializer.fromJson<int>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      displayName: serializer.fromJson<String>(json['displayName']),
      color: serializer.fromJson<String>(json['color']),
      supportsVTodo: serializer.fromJson<bool>(json['supportsVTodo']),
      supportsVEvent: serializer.fromJson<bool>(json['supportsVEvent']),
      owner: serializer.fromJson<String>(json['owner']),
      ctag: serializer.fromJson<String?>(json['ctag']),
      syncToken: serializer.fromJson<String?>(json['syncToken']),
      syncEnabled: serializer.fromJson<bool>(json['syncEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'url': serializer.toJson<String>(url),
      'displayName': serializer.toJson<String>(displayName),
      'color': serializer.toJson<String>(color),
      'supportsVTodo': serializer.toJson<bool>(supportsVTodo),
      'supportsVEvent': serializer.toJson<bool>(supportsVEvent),
      'owner': serializer.toJson<String>(owner),
      'ctag': serializer.toJson<String?>(ctag),
      'syncToken': serializer.toJson<String?>(syncToken),
      'syncEnabled': serializer.toJson<bool>(syncEnabled),
    };
  }

  CalendarRow copyWith({
    int? id,
    String? url,
    String? displayName,
    String? color,
    bool? supportsVTodo,
    bool? supportsVEvent,
    String? owner,
    Value<String?> ctag = const Value.absent(),
    Value<String?> syncToken = const Value.absent(),
    bool? syncEnabled,
  }) => CalendarRow(
    id: id ?? this.id,
    url: url ?? this.url,
    displayName: displayName ?? this.displayName,
    color: color ?? this.color,
    supportsVTodo: supportsVTodo ?? this.supportsVTodo,
    supportsVEvent: supportsVEvent ?? this.supportsVEvent,
    owner: owner ?? this.owner,
    ctag: ctag.present ? ctag.value : this.ctag,
    syncToken: syncToken.present ? syncToken.value : this.syncToken,
    syncEnabled: syncEnabled ?? this.syncEnabled,
  );
  CalendarRow copyWithCompanion(CalendarsCompanion data) {
    return CalendarRow(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      color: data.color.present ? data.color.value : this.color,
      supportsVTodo: data.supportsVTodo.present
          ? data.supportsVTodo.value
          : this.supportsVTodo,
      supportsVEvent: data.supportsVEvent.present
          ? data.supportsVEvent.value
          : this.supportsVEvent,
      owner: data.owner.present ? data.owner.value : this.owner,
      ctag: data.ctag.present ? data.ctag.value : this.ctag,
      syncToken: data.syncToken.present ? data.syncToken.value : this.syncToken,
      syncEnabled: data.syncEnabled.present
          ? data.syncEnabled.value
          : this.syncEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarRow(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('displayName: $displayName, ')
          ..write('color: $color, ')
          ..write('supportsVTodo: $supportsVTodo, ')
          ..write('supportsVEvent: $supportsVEvent, ')
          ..write('owner: $owner, ')
          ..write('ctag: $ctag, ')
          ..write('syncToken: $syncToken, ')
          ..write('syncEnabled: $syncEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    url,
    displayName,
    color,
    supportsVTodo,
    supportsVEvent,
    owner,
    ctag,
    syncToken,
    syncEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarRow &&
          other.id == this.id &&
          other.url == this.url &&
          other.displayName == this.displayName &&
          other.color == this.color &&
          other.supportsVTodo == this.supportsVTodo &&
          other.supportsVEvent == this.supportsVEvent &&
          other.owner == this.owner &&
          other.ctag == this.ctag &&
          other.syncToken == this.syncToken &&
          other.syncEnabled == this.syncEnabled);
}

class CalendarsCompanion extends UpdateCompanion<CalendarRow> {
  final Value<int> id;
  final Value<String> url;
  final Value<String> displayName;
  final Value<String> color;
  final Value<bool> supportsVTodo;
  final Value<bool> supportsVEvent;
  final Value<String> owner;
  final Value<String?> ctag;
  final Value<String?> syncToken;
  final Value<bool> syncEnabled;
  const CalendarsCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.displayName = const Value.absent(),
    this.color = const Value.absent(),
    this.supportsVTodo = const Value.absent(),
    this.supportsVEvent = const Value.absent(),
    this.owner = const Value.absent(),
    this.ctag = const Value.absent(),
    this.syncToken = const Value.absent(),
    this.syncEnabled = const Value.absent(),
  });
  CalendarsCompanion.insert({
    this.id = const Value.absent(),
    required String url,
    this.displayName = const Value.absent(),
    this.color = const Value.absent(),
    this.supportsVTodo = const Value.absent(),
    this.supportsVEvent = const Value.absent(),
    this.owner = const Value.absent(),
    this.ctag = const Value.absent(),
    this.syncToken = const Value.absent(),
    this.syncEnabled = const Value.absent(),
  }) : url = Value(url);
  static Insertable<CalendarRow> custom({
    Expression<int>? id,
    Expression<String>? url,
    Expression<String>? displayName,
    Expression<String>? color,
    Expression<bool>? supportsVTodo,
    Expression<bool>? supportsVEvent,
    Expression<String>? owner,
    Expression<String>? ctag,
    Expression<String>? syncToken,
    Expression<bool>? syncEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (displayName != null) 'display_name': displayName,
      if (color != null) 'color': color,
      if (supportsVTodo != null) 'supports_v_todo': supportsVTodo,
      if (supportsVEvent != null) 'supports_v_event': supportsVEvent,
      if (owner != null) 'owner': owner,
      if (ctag != null) 'ctag': ctag,
      if (syncToken != null) 'sync_token': syncToken,
      if (syncEnabled != null) 'sync_enabled': syncEnabled,
    });
  }

  CalendarsCompanion copyWith({
    Value<int>? id,
    Value<String>? url,
    Value<String>? displayName,
    Value<String>? color,
    Value<bool>? supportsVTodo,
    Value<bool>? supportsVEvent,
    Value<String>? owner,
    Value<String?>? ctag,
    Value<String?>? syncToken,
    Value<bool>? syncEnabled,
  }) {
    return CalendarsCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      displayName: displayName ?? this.displayName,
      color: color ?? this.color,
      supportsVTodo: supportsVTodo ?? this.supportsVTodo,
      supportsVEvent: supportsVEvent ?? this.supportsVEvent,
      owner: owner ?? this.owner,
      ctag: ctag ?? this.ctag,
      syncToken: syncToken ?? this.syncToken,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (supportsVTodo.present) {
      map['supports_v_todo'] = Variable<bool>(supportsVTodo.value);
    }
    if (supportsVEvent.present) {
      map['supports_v_event'] = Variable<bool>(supportsVEvent.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (ctag.present) {
      map['ctag'] = Variable<String>(ctag.value);
    }
    if (syncToken.present) {
      map['sync_token'] = Variable<String>(syncToken.value);
    }
    if (syncEnabled.present) {
      map['sync_enabled'] = Variable<bool>(syncEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarsCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('displayName: $displayName, ')
          ..write('color: $color, ')
          ..write('supportsVTodo: $supportsVTodo, ')
          ..write('supportsVEvent: $supportsVEvent, ')
          ..write('owner: $owner, ')
          ..write('ctag: $ctag, ')
          ..write('syncToken: $syncToken, ')
          ..write('syncEnabled: $syncEnabled')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _calendarUrlMeta = const VerificationMeta(
    'calendarUrl',
  );
  @override
  late final GeneratedColumn<String> calendarUrl = GeneratedColumn<String>(
    'calendar_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
    'start',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<DateTime> due = GeneratedColumn<DateTime>(
    'due',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<DateTime> completed = GeneratedColumn<DateTime>(
    'completed',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NEEDS-ACTION'),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _percentMeta = const VerificationMeta(
    'percent',
  );
  @override
  late final GeneratedColumn<int> percent = GeneratedColumn<int>(
    'percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _categoriesMeta = const VerificationMeta(
    'categories',
  );
  @override
  late final GeneratedColumn<String> categories = GeneratedColumn<String>(
    'categories',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _parentUidMeta = const VerificationMeta(
    'parentUid',
  );
  @override
  late final GeneratedColumn<String> parentUid = GeneratedColumn<String>(
    'parent_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hrefMeta = const VerificationMeta('href');
  @override
  late final GeneratedColumn<String> href = GeneratedColumn<String>(
    'href',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<DateTime> created = GeneratedColumn<DateTime>(
    'created',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localModifiedAtMeta = const VerificationMeta(
    'localModifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localModifiedAt =
      GeneratedColumn<DateTime>(
        'local_modified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calendarUrl,
    uid,
    summary,
    description,
    start,
    due,
    completed,
    status,
    priority,
    percent,
    categories,
    parentUid,
    href,
    etag,
    created,
    lastModified,
    localModifiedAt,
    sortOrder,
    dirty,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('calendar_url')) {
      context.handle(
        _calendarUrlMeta,
        calendarUrl.isAcceptableOrUnknown(
          data['calendar_url']!,
          _calendarUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calendarUrlMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('percent')) {
      context.handle(
        _percentMeta,
        percent.isAcceptableOrUnknown(data['percent']!, _percentMeta),
      );
    }
    if (data.containsKey('categories')) {
      context.handle(
        _categoriesMeta,
        categories.isAcceptableOrUnknown(data['categories']!, _categoriesMeta),
      );
    }
    if (data.containsKey('parent_uid')) {
      context.handle(
        _parentUidMeta,
        parentUid.isAcceptableOrUnknown(data['parent_uid']!, _parentUidMeta),
      );
    }
    if (data.containsKey('href')) {
      context.handle(
        _hrefMeta,
        href.isAcceptableOrUnknown(data['href']!, _hrefMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('local_modified_at')) {
      context.handle(
        _localModifiedAtMeta,
        localModifiedAt.isAcceptableOrUnknown(
          data['local_modified_at']!,
          _localModifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {uid, calendarUrl},
  ];
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      calendarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_url'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start'],
      ),
      due: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      percent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}percent'],
      )!,
      categories: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories'],
      )!,
      parentUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_uid'],
      ),
      href: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}href'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified'],
      ),
      localModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_modified_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final int id;
  final String calendarUrl;

  /// iCalendar UID（全局唯一）
  final String uid;
  final String summary;
  final String description;
  final DateTime? start;
  final DateTime? due;
  final DateTime? completed;

  /// 状态：NEEDS-ACTION / IN-PROCESS / COMPLETED / CANCELLED
  final String status;

  /// 优先级：0/1/5/9
  final int priority;
  final int percent;

  /// 分类标签，以 JSON 数组字符串存储
  final String categories;
  final String? parentUid;

  /// 远端 .ics 资源 HREF
  final String? href;

  /// 远端 ETag
  final String? etag;
  final DateTime? created;
  final DateTime? lastModified;

  /// 本地最后修改时间
  final DateTime? localModifiedAt;

  /// 手动排序值（对应 iCalendar X-APPLE-SORT-ORDER，数字越小越靠前）
  final int? sortOrder;

  /// 是否待同步上传
  final bool dirty;

  /// 是否已被本地删除（待同步删除）
  final bool deleted;
  const TaskRow({
    required this.id,
    required this.calendarUrl,
    required this.uid,
    required this.summary,
    required this.description,
    this.start,
    this.due,
    this.completed,
    required this.status,
    required this.priority,
    required this.percent,
    required this.categories,
    this.parentUid,
    this.href,
    this.etag,
    this.created,
    this.lastModified,
    this.localModifiedAt,
    this.sortOrder,
    required this.dirty,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['calendar_url'] = Variable<String>(calendarUrl);
    map['uid'] = Variable<String>(uid);
    map['summary'] = Variable<String>(summary);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || start != null) {
      map['start'] = Variable<DateTime>(start);
    }
    if (!nullToAbsent || due != null) {
      map['due'] = Variable<DateTime>(due);
    }
    if (!nullToAbsent || completed != null) {
      map['completed'] = Variable<DateTime>(completed);
    }
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<int>(priority);
    map['percent'] = Variable<int>(percent);
    map['categories'] = Variable<String>(categories);
    if (!nullToAbsent || parentUid != null) {
      map['parent_uid'] = Variable<String>(parentUid);
    }
    if (!nullToAbsent || href != null) {
      map['href'] = Variable<String>(href);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<DateTime>(created);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<DateTime>(lastModified);
    }
    if (!nullToAbsent || localModifiedAt != null) {
      map['local_modified_at'] = Variable<DateTime>(localModifiedAt);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      calendarUrl: Value(calendarUrl),
      uid: Value(uid),
      summary: Value(summary),
      description: Value(description),
      start: start == null && nullToAbsent
          ? const Value.absent()
          : Value(start),
      due: due == null && nullToAbsent ? const Value.absent() : Value(due),
      completed: completed == null && nullToAbsent
          ? const Value.absent()
          : Value(completed),
      status: Value(status),
      priority: Value(priority),
      percent: Value(percent),
      categories: Value(categories),
      parentUid: parentUid == null && nullToAbsent
          ? const Value.absent()
          : Value(parentUid),
      href: href == null && nullToAbsent ? const Value.absent() : Value(href),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      localModifiedAt: localModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(localModifiedAt),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      dirty: Value(dirty),
      deleted: Value(deleted),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<int>(json['id']),
      calendarUrl: serializer.fromJson<String>(json['calendarUrl']),
      uid: serializer.fromJson<String>(json['uid']),
      summary: serializer.fromJson<String>(json['summary']),
      description: serializer.fromJson<String>(json['description']),
      start: serializer.fromJson<DateTime?>(json['start']),
      due: serializer.fromJson<DateTime?>(json['due']),
      completed: serializer.fromJson<DateTime?>(json['completed']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<int>(json['priority']),
      percent: serializer.fromJson<int>(json['percent']),
      categories: serializer.fromJson<String>(json['categories']),
      parentUid: serializer.fromJson<String?>(json['parentUid']),
      href: serializer.fromJson<String?>(json['href']),
      etag: serializer.fromJson<String?>(json['etag']),
      created: serializer.fromJson<DateTime?>(json['created']),
      lastModified: serializer.fromJson<DateTime?>(json['lastModified']),
      localModifiedAt: serializer.fromJson<DateTime?>(json['localModifiedAt']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'calendarUrl': serializer.toJson<String>(calendarUrl),
      'uid': serializer.toJson<String>(uid),
      'summary': serializer.toJson<String>(summary),
      'description': serializer.toJson<String>(description),
      'start': serializer.toJson<DateTime?>(start),
      'due': serializer.toJson<DateTime?>(due),
      'completed': serializer.toJson<DateTime?>(completed),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<int>(priority),
      'percent': serializer.toJson<int>(percent),
      'categories': serializer.toJson<String>(categories),
      'parentUid': serializer.toJson<String?>(parentUid),
      'href': serializer.toJson<String?>(href),
      'etag': serializer.toJson<String?>(etag),
      'created': serializer.toJson<DateTime?>(created),
      'lastModified': serializer.toJson<DateTime?>(lastModified),
      'localModifiedAt': serializer.toJson<DateTime?>(localModifiedAt),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'dirty': serializer.toJson<bool>(dirty),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  TaskRow copyWith({
    int? id,
    String? calendarUrl,
    String? uid,
    String? summary,
    String? description,
    Value<DateTime?> start = const Value.absent(),
    Value<DateTime?> due = const Value.absent(),
    Value<DateTime?> completed = const Value.absent(),
    String? status,
    int? priority,
    int? percent,
    String? categories,
    Value<String?> parentUid = const Value.absent(),
    Value<String?> href = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    Value<DateTime?> created = const Value.absent(),
    Value<DateTime?> lastModified = const Value.absent(),
    Value<DateTime?> localModifiedAt = const Value.absent(),
    Value<int?> sortOrder = const Value.absent(),
    bool? dirty,
    bool? deleted,
  }) => TaskRow(
    id: id ?? this.id,
    calendarUrl: calendarUrl ?? this.calendarUrl,
    uid: uid ?? this.uid,
    summary: summary ?? this.summary,
    description: description ?? this.description,
    start: start.present ? start.value : this.start,
    due: due.present ? due.value : this.due,
    completed: completed.present ? completed.value : this.completed,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    percent: percent ?? this.percent,
    categories: categories ?? this.categories,
    parentUid: parentUid.present ? parentUid.value : this.parentUid,
    href: href.present ? href.value : this.href,
    etag: etag.present ? etag.value : this.etag,
    created: created.present ? created.value : this.created,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    localModifiedAt: localModifiedAt.present
        ? localModifiedAt.value
        : this.localModifiedAt,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    dirty: dirty ?? this.dirty,
    deleted: deleted ?? this.deleted,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      calendarUrl: data.calendarUrl.present
          ? data.calendarUrl.value
          : this.calendarUrl,
      uid: data.uid.present ? data.uid.value : this.uid,
      summary: data.summary.present ? data.summary.value : this.summary,
      description: data.description.present
          ? data.description.value
          : this.description,
      start: data.start.present ? data.start.value : this.start,
      due: data.due.present ? data.due.value : this.due,
      completed: data.completed.present ? data.completed.value : this.completed,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      percent: data.percent.present ? data.percent.value : this.percent,
      categories: data.categories.present
          ? data.categories.value
          : this.categories,
      parentUid: data.parentUid.present ? data.parentUid.value : this.parentUid,
      href: data.href.present ? data.href.value : this.href,
      etag: data.etag.present ? data.etag.value : this.etag,
      created: data.created.present ? data.created.value : this.created,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      localModifiedAt: data.localModifiedAt.present
          ? data.localModifiedAt.value
          : this.localModifiedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('calendarUrl: $calendarUrl, ')
          ..write('uid: $uid, ')
          ..write('summary: $summary, ')
          ..write('description: $description, ')
          ..write('start: $start, ')
          ..write('due: $due, ')
          ..write('completed: $completed, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('percent: $percent, ')
          ..write('categories: $categories, ')
          ..write('parentUid: $parentUid, ')
          ..write('href: $href, ')
          ..write('etag: $etag, ')
          ..write('created: $created, ')
          ..write('lastModified: $lastModified, ')
          ..write('localModifiedAt: $localModifiedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('dirty: $dirty, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    calendarUrl,
    uid,
    summary,
    description,
    start,
    due,
    completed,
    status,
    priority,
    percent,
    categories,
    parentUid,
    href,
    etag,
    created,
    lastModified,
    localModifiedAt,
    sortOrder,
    dirty,
    deleted,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.calendarUrl == this.calendarUrl &&
          other.uid == this.uid &&
          other.summary == this.summary &&
          other.description == this.description &&
          other.start == this.start &&
          other.due == this.due &&
          other.completed == this.completed &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.percent == this.percent &&
          other.categories == this.categories &&
          other.parentUid == this.parentUid &&
          other.href == this.href &&
          other.etag == this.etag &&
          other.created == this.created &&
          other.lastModified == this.lastModified &&
          other.localModifiedAt == this.localModifiedAt &&
          other.sortOrder == this.sortOrder &&
          other.dirty == this.dirty &&
          other.deleted == this.deleted);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<int> id;
  final Value<String> calendarUrl;
  final Value<String> uid;
  final Value<String> summary;
  final Value<String> description;
  final Value<DateTime?> start;
  final Value<DateTime?> due;
  final Value<DateTime?> completed;
  final Value<String> status;
  final Value<int> priority;
  final Value<int> percent;
  final Value<String> categories;
  final Value<String?> parentUid;
  final Value<String?> href;
  final Value<String?> etag;
  final Value<DateTime?> created;
  final Value<DateTime?> lastModified;
  final Value<DateTime?> localModifiedAt;
  final Value<int?> sortOrder;
  final Value<bool> dirty;
  final Value<bool> deleted;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.calendarUrl = const Value.absent(),
    this.uid = const Value.absent(),
    this.summary = const Value.absent(),
    this.description = const Value.absent(),
    this.start = const Value.absent(),
    this.due = const Value.absent(),
    this.completed = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.percent = const Value.absent(),
    this.categories = const Value.absent(),
    this.parentUid = const Value.absent(),
    this.href = const Value.absent(),
    this.etag = const Value.absent(),
    this.created = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.localModifiedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.dirty = const Value.absent(),
    this.deleted = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    required String calendarUrl,
    required String uid,
    this.summary = const Value.absent(),
    this.description = const Value.absent(),
    this.start = const Value.absent(),
    this.due = const Value.absent(),
    this.completed = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.percent = const Value.absent(),
    this.categories = const Value.absent(),
    this.parentUid = const Value.absent(),
    this.href = const Value.absent(),
    this.etag = const Value.absent(),
    this.created = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.localModifiedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.dirty = const Value.absent(),
    this.deleted = const Value.absent(),
  }) : calendarUrl = Value(calendarUrl),
       uid = Value(uid);
  static Insertable<TaskRow> custom({
    Expression<int>? id,
    Expression<String>? calendarUrl,
    Expression<String>? uid,
    Expression<String>? summary,
    Expression<String>? description,
    Expression<DateTime>? start,
    Expression<DateTime>? due,
    Expression<DateTime>? completed,
    Expression<String>? status,
    Expression<int>? priority,
    Expression<int>? percent,
    Expression<String>? categories,
    Expression<String>? parentUid,
    Expression<String>? href,
    Expression<String>? etag,
    Expression<DateTime>? created,
    Expression<DateTime>? lastModified,
    Expression<DateTime>? localModifiedAt,
    Expression<int>? sortOrder,
    Expression<bool>? dirty,
    Expression<bool>? deleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calendarUrl != null) 'calendar_url': calendarUrl,
      if (uid != null) 'uid': uid,
      if (summary != null) 'summary': summary,
      if (description != null) 'description': description,
      if (start != null) 'start': start,
      if (due != null) 'due': due,
      if (completed != null) 'completed': completed,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (percent != null) 'percent': percent,
      if (categories != null) 'categories': categories,
      if (parentUid != null) 'parent_uid': parentUid,
      if (href != null) 'href': href,
      if (etag != null) 'etag': etag,
      if (created != null) 'created': created,
      if (lastModified != null) 'last_modified': lastModified,
      if (localModifiedAt != null) 'local_modified_at': localModifiedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (dirty != null) 'dirty': dirty,
      if (deleted != null) 'deleted': deleted,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<String>? calendarUrl,
    Value<String>? uid,
    Value<String>? summary,
    Value<String>? description,
    Value<DateTime?>? start,
    Value<DateTime?>? due,
    Value<DateTime?>? completed,
    Value<String>? status,
    Value<int>? priority,
    Value<int>? percent,
    Value<String>? categories,
    Value<String?>? parentUid,
    Value<String?>? href,
    Value<String?>? etag,
    Value<DateTime?>? created,
    Value<DateTime?>? lastModified,
    Value<DateTime?>? localModifiedAt,
    Value<int?>? sortOrder,
    Value<bool>? dirty,
    Value<bool>? deleted,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      calendarUrl: calendarUrl ?? this.calendarUrl,
      uid: uid ?? this.uid,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      start: start ?? this.start,
      due: due ?? this.due,
      completed: completed ?? this.completed,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      percent: percent ?? this.percent,
      categories: categories ?? this.categories,
      parentUid: parentUid ?? this.parentUid,
      href: href ?? this.href,
      etag: etag ?? this.etag,
      created: created ?? this.created,
      lastModified: lastModified ?? this.lastModified,
      localModifiedAt: localModifiedAt ?? this.localModifiedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      dirty: dirty ?? this.dirty,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (calendarUrl.present) {
      map['calendar_url'] = Variable<String>(calendarUrl.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (due.present) {
      map['due'] = Variable<DateTime>(due.value);
    }
    if (completed.present) {
      map['completed'] = Variable<DateTime>(completed.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (percent.present) {
      map['percent'] = Variable<int>(percent.value);
    }
    if (categories.present) {
      map['categories'] = Variable<String>(categories.value);
    }
    if (parentUid.present) {
      map['parent_uid'] = Variable<String>(parentUid.value);
    }
    if (href.present) {
      map['href'] = Variable<String>(href.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (created.present) {
      map['created'] = Variable<DateTime>(created.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (localModifiedAt.present) {
      map['local_modified_at'] = Variable<DateTime>(localModifiedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('calendarUrl: $calendarUrl, ')
          ..write('uid: $uid, ')
          ..write('summary: $summary, ')
          ..write('description: $description, ')
          ..write('start: $start, ')
          ..write('due: $due, ')
          ..write('completed: $completed, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('percent: $percent, ')
          ..write('categories: $categories, ')
          ..write('parentUid: $parentUid, ')
          ..write('href: $href, ')
          ..write('etag: $etag, ')
          ..write('created: $created, ')
          ..write('lastModified: $lastModified, ')
          ..write('localModifiedAt: $localModifiedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('dirty: $dirty, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CalendarsTable calendars = $CalendarsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [calendars, tasks];
}

typedef $$CalendarsTableCreateCompanionBuilder =
    CalendarsCompanion Function({
      Value<int> id,
      required String url,
      Value<String> displayName,
      Value<String> color,
      Value<bool> supportsVTodo,
      Value<bool> supportsVEvent,
      Value<String> owner,
      Value<String?> ctag,
      Value<String?> syncToken,
      Value<bool> syncEnabled,
    });
typedef $$CalendarsTableUpdateCompanionBuilder =
    CalendarsCompanion Function({
      Value<int> id,
      Value<String> url,
      Value<String> displayName,
      Value<String> color,
      Value<bool> supportsVTodo,
      Value<bool> supportsVEvent,
      Value<String> owner,
      Value<String?> ctag,
      Value<String?> syncToken,
      Value<bool> syncEnabled,
    });

class $$CalendarsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsVTodo => $composableBuilder(
    column: $table.supportsVTodo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsVEvent => $composableBuilder(
    column: $table.supportsVEvent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ctag => $composableBuilder(
    column: $table.ctag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncToken => $composableBuilder(
    column: $table.syncToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsVTodo => $composableBuilder(
    column: $table.supportsVTodo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsVEvent => $composableBuilder(
    column: $table.supportsVEvent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ctag => $composableBuilder(
    column: $table.ctag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncToken => $composableBuilder(
    column: $table.syncToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get supportsVTodo => $composableBuilder(
    column: $table.supportsVTodo,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsVEvent => $composableBuilder(
    column: $table.supportsVEvent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get ctag =>
      $composableBuilder(column: $table.ctag, builder: (column) => column);

  GeneratedColumn<String> get syncToken =>
      $composableBuilder(column: $table.syncToken, builder: (column) => column);

  GeneratedColumn<bool> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => column,
  );
}

class $$CalendarsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarsTable,
          CalendarRow,
          $$CalendarsTableFilterComposer,
          $$CalendarsTableOrderingComposer,
          $$CalendarsTableAnnotationComposer,
          $$CalendarsTableCreateCompanionBuilder,
          $$CalendarsTableUpdateCompanionBuilder,
          (
            CalendarRow,
            BaseReferences<_$AppDatabase, $CalendarsTable, CalendarRow>,
          ),
          CalendarRow,
          PrefetchHooks Function()
        > {
  $$CalendarsTableTableManager(_$AppDatabase db, $CalendarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<bool> supportsVTodo = const Value.absent(),
                Value<bool> supportsVEvent = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<String?> ctag = const Value.absent(),
                Value<String?> syncToken = const Value.absent(),
                Value<bool> syncEnabled = const Value.absent(),
              }) => CalendarsCompanion(
                id: id,
                url: url,
                displayName: displayName,
                color: color,
                supportsVTodo: supportsVTodo,
                supportsVEvent: supportsVEvent,
                owner: owner,
                ctag: ctag,
                syncToken: syncToken,
                syncEnabled: syncEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String url,
                Value<String> displayName = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<bool> supportsVTodo = const Value.absent(),
                Value<bool> supportsVEvent = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<String?> ctag = const Value.absent(),
                Value<String?> syncToken = const Value.absent(),
                Value<bool> syncEnabled = const Value.absent(),
              }) => CalendarsCompanion.insert(
                id: id,
                url: url,
                displayName: displayName,
                color: color,
                supportsVTodo: supportsVTodo,
                supportsVEvent: supportsVEvent,
                owner: owner,
                ctag: ctag,
                syncToken: syncToken,
                syncEnabled: syncEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarsTable,
      CalendarRow,
      $$CalendarsTableFilterComposer,
      $$CalendarsTableOrderingComposer,
      $$CalendarsTableAnnotationComposer,
      $$CalendarsTableCreateCompanionBuilder,
      $$CalendarsTableUpdateCompanionBuilder,
      (
        CalendarRow,
        BaseReferences<_$AppDatabase, $CalendarsTable, CalendarRow>,
      ),
      CalendarRow,
      PrefetchHooks Function()
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      required String calendarUrl,
      required String uid,
      Value<String> summary,
      Value<String> description,
      Value<DateTime?> start,
      Value<DateTime?> due,
      Value<DateTime?> completed,
      Value<String> status,
      Value<int> priority,
      Value<int> percent,
      Value<String> categories,
      Value<String?> parentUid,
      Value<String?> href,
      Value<String?> etag,
      Value<DateTime?> created,
      Value<DateTime?> lastModified,
      Value<DateTime?> localModifiedAt,
      Value<int?> sortOrder,
      Value<bool> dirty,
      Value<bool> deleted,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      Value<String> calendarUrl,
      Value<String> uid,
      Value<String> summary,
      Value<String> description,
      Value<DateTime?> start,
      Value<DateTime?> due,
      Value<DateTime?> completed,
      Value<String> status,
      Value<int> priority,
      Value<int> percent,
      Value<String> categories,
      Value<String?> parentUid,
      Value<String?> href,
      Value<String?> etag,
      Value<DateTime?> created,
      Value<DateTime?> lastModified,
      Value<DateTime?> localModifiedAt,
      Value<int?> sortOrder,
      Value<bool> dirty,
      Value<bool> deleted,
    });

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
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

  ColumnFilters<String> get calendarUrl => $composableBuilder(
    column: $table.calendarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentUid => $composableBuilder(
    column: $table.parentUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get href => $composableBuilder(
    column: $table.href,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localModifiedAt => $composableBuilder(
    column: $table.localModifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
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

  ColumnOrderings<String> get calendarUrl => $composableBuilder(
    column: $table.calendarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentUid => $composableBuilder(
    column: $table.parentUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get href => $composableBuilder(
    column: $table.href,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localModifiedAt => $composableBuilder(
    column: $table.localModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get calendarUrl => $composableBuilder(
    column: $table.calendarUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<DateTime> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get percent =>
      $composableBuilder(column: $table.percent, builder: (column) => column);

  GeneratedColumn<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentUid =>
      $composableBuilder(column: $table.parentUid, builder: (column) => column);

  GeneratedColumn<String> get href =>
      $composableBuilder(column: $table.href, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localModifiedAt => $composableBuilder(
    column: $table.localModifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, BaseReferences<_$AppDatabase, $TasksTable, TaskRow>),
          TaskRow,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> calendarUrl = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime?> start = const Value.absent(),
                Value<DateTime?> due = const Value.absent(),
                Value<DateTime?> completed = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> percent = const Value.absent(),
                Value<String> categories = const Value.absent(),
                Value<String?> parentUid = const Value.absent(),
                Value<String?> href = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> lastModified = const Value.absent(),
                Value<DateTime?> localModifiedAt = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                calendarUrl: calendarUrl,
                uid: uid,
                summary: summary,
                description: description,
                start: start,
                due: due,
                completed: completed,
                status: status,
                priority: priority,
                percent: percent,
                categories: categories,
                parentUid: parentUid,
                href: href,
                etag: etag,
                created: created,
                lastModified: lastModified,
                localModifiedAt: localModifiedAt,
                sortOrder: sortOrder,
                dirty: dirty,
                deleted: deleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String calendarUrl,
                required String uid,
                Value<String> summary = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime?> start = const Value.absent(),
                Value<DateTime?> due = const Value.absent(),
                Value<DateTime?> completed = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> percent = const Value.absent(),
                Value<String> categories = const Value.absent(),
                Value<String?> parentUid = const Value.absent(),
                Value<String?> href = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> lastModified = const Value.absent(),
                Value<DateTime?> localModifiedAt = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                calendarUrl: calendarUrl,
                uid: uid,
                summary: summary,
                description: description,
                start: start,
                due: due,
                completed: completed,
                status: status,
                priority: priority,
                percent: percent,
                categories: categories,
                parentUid: parentUid,
                href: href,
                etag: etag,
                created: created,
                lastModified: lastModified,
                localModifiedAt: localModifiedAt,
                sortOrder: sortOrder,
                dirty: dirty,
                deleted: deleted,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, BaseReferences<_$AppDatabase, $TasksTable, TaskRow>),
      TaskRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CalendarsTableTableManager get calendars =>
      $$CalendarsTableTableManager(_db, _db.calendars);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
}
