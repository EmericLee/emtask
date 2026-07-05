// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'calendar.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Calendar _$CalendarFromJson(Map<String, dynamic> json) {
  return _Calendar.fromJson(json);
}

/// @nodoc
mixin _$Calendar {
  /// 本地数据库主键
  int get localId => throw _privateConstructorUsedError;

  /// 远端日历集合 URL（绝对或相对，作为同步标识）
  String get url => throw _privateConstructorUsedError;

  /// 显示名称（CALDAV:displayname）
  String get displayName => throw _privateConstructorUsedError;

  /// 日历颜色（CALDAV:calendar-color）
  String get color => throw _privateConstructorUsedError;

  /// 是否支持 VTODO（任务）
  bool get supportsTasks => throw _privateConstructorUsedError;

  /// 是否支持 VEVENT（事件）
  bool get supportsEvents => throw _privateConstructorUsedError;

  /// 所属账户的用户名
  String get owner => throw _privateConstructorUsedError;

  /// 远端 CTag（同步令牌，用于增量判断）
  String? get ctag => throw _privateConstructorUsedError;

  /// 远端 sync-token
  String? get syncToken => throw _privateConstructorUsedError;

  /// 是否启用同步
  bool get syncEnabled => throw _privateConstructorUsedError;

  /// Serializes this Calendar to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Calendar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CalendarCopyWith<Calendar> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CalendarCopyWith<$Res> {
  factory $CalendarCopyWith(Calendar value, $Res Function(Calendar) then) =
      _$CalendarCopyWithImpl<$Res, Calendar>;
  @useResult
  $Res call({
    int localId,
    String url,
    String displayName,
    String color,
    bool supportsTasks,
    bool supportsEvents,
    String owner,
    String? ctag,
    String? syncToken,
    bool syncEnabled,
  });
}

/// @nodoc
class _$CalendarCopyWithImpl<$Res, $Val extends Calendar>
    implements $CalendarCopyWith<$Res> {
  _$CalendarCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Calendar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? localId = null,
    Object? url = null,
    Object? displayName = null,
    Object? color = null,
    Object? supportsTasks = null,
    Object? supportsEvents = null,
    Object? owner = null,
    Object? ctag = freezed,
    Object? syncToken = freezed,
    Object? syncEnabled = null,
  }) {
    return _then(
      _value.copyWith(
            localId: null == localId
                ? _value.localId
                : localId // ignore: cast_nullable_to_non_nullable
                      as int,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as String,
            supportsTasks: null == supportsTasks
                ? _value.supportsTasks
                : supportsTasks // ignore: cast_nullable_to_non_nullable
                      as bool,
            supportsEvents: null == supportsEvents
                ? _value.supportsEvents
                : supportsEvents // ignore: cast_nullable_to_non_nullable
                      as bool,
            owner: null == owner
                ? _value.owner
                : owner // ignore: cast_nullable_to_non_nullable
                      as String,
            ctag: freezed == ctag
                ? _value.ctag
                : ctag // ignore: cast_nullable_to_non_nullable
                      as String?,
            syncToken: freezed == syncToken
                ? _value.syncToken
                : syncToken // ignore: cast_nullable_to_non_nullable
                      as String?,
            syncEnabled: null == syncEnabled
                ? _value.syncEnabled
                : syncEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CalendarImplCopyWith<$Res>
    implements $CalendarCopyWith<$Res> {
  factory _$$CalendarImplCopyWith(
    _$CalendarImpl value,
    $Res Function(_$CalendarImpl) then,
  ) = __$$CalendarImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int localId,
    String url,
    String displayName,
    String color,
    bool supportsTasks,
    bool supportsEvents,
    String owner,
    String? ctag,
    String? syncToken,
    bool syncEnabled,
  });
}

/// @nodoc
class __$$CalendarImplCopyWithImpl<$Res>
    extends _$CalendarCopyWithImpl<$Res, _$CalendarImpl>
    implements _$$CalendarImplCopyWith<$Res> {
  __$$CalendarImplCopyWithImpl(
    _$CalendarImpl _value,
    $Res Function(_$CalendarImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Calendar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? localId = null,
    Object? url = null,
    Object? displayName = null,
    Object? color = null,
    Object? supportsTasks = null,
    Object? supportsEvents = null,
    Object? owner = null,
    Object? ctag = freezed,
    Object? syncToken = freezed,
    Object? syncEnabled = null,
  }) {
    return _then(
      _$CalendarImpl(
        localId: null == localId
            ? _value.localId
            : localId // ignore: cast_nullable_to_non_nullable
                  as int,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as String,
        supportsTasks: null == supportsTasks
            ? _value.supportsTasks
            : supportsTasks // ignore: cast_nullable_to_non_nullable
                  as bool,
        supportsEvents: null == supportsEvents
            ? _value.supportsEvents
            : supportsEvents // ignore: cast_nullable_to_non_nullable
                  as bool,
        owner: null == owner
            ? _value.owner
            : owner // ignore: cast_nullable_to_non_nullable
                  as String,
        ctag: freezed == ctag
            ? _value.ctag
            : ctag // ignore: cast_nullable_to_non_nullable
                  as String?,
        syncToken: freezed == syncToken
            ? _value.syncToken
            : syncToken // ignore: cast_nullable_to_non_nullable
                  as String?,
        syncEnabled: null == syncEnabled
            ? _value.syncEnabled
            : syncEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CalendarImpl implements _Calendar {
  const _$CalendarImpl({
    required this.localId,
    required this.url,
    required this.displayName,
    this.color = '#2E7D32',
    this.supportsTasks = true,
    this.supportsEvents = false,
    required this.owner,
    this.ctag,
    this.syncToken,
    this.syncEnabled = true,
  });

  factory _$CalendarImpl.fromJson(Map<String, dynamic> json) =>
      _$$CalendarImplFromJson(json);

  /// 本地数据库主键
  @override
  final int localId;

  /// 远端日历集合 URL（绝对或相对，作为同步标识）
  @override
  final String url;

  /// 显示名称（CALDAV:displayname）
  @override
  final String displayName;

  /// 日历颜色（CALDAV:calendar-color）
  @override
  @JsonKey()
  final String color;

  /// 是否支持 VTODO（任务）
  @override
  @JsonKey()
  final bool supportsTasks;

  /// 是否支持 VEVENT（事件）
  @override
  @JsonKey()
  final bool supportsEvents;

  /// 所属账户的用户名
  @override
  final String owner;

  /// 远端 CTag（同步令牌，用于增量判断）
  @override
  final String? ctag;

  /// 远端 sync-token
  @override
  final String? syncToken;

  /// 是否启用同步
  @override
  @JsonKey()
  final bool syncEnabled;

  @override
  String toString() {
    return 'Calendar(localId: $localId, url: $url, displayName: $displayName, color: $color, supportsTasks: $supportsTasks, supportsEvents: $supportsEvents, owner: $owner, ctag: $ctag, syncToken: $syncToken, syncEnabled: $syncEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CalendarImpl &&
            (identical(other.localId, localId) || other.localId == localId) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.supportsTasks, supportsTasks) ||
                other.supportsTasks == supportsTasks) &&
            (identical(other.supportsEvents, supportsEvents) ||
                other.supportsEvents == supportsEvents) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.ctag, ctag) || other.ctag == ctag) &&
            (identical(other.syncToken, syncToken) ||
                other.syncToken == syncToken) &&
            (identical(other.syncEnabled, syncEnabled) ||
                other.syncEnabled == syncEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    localId,
    url,
    displayName,
    color,
    supportsTasks,
    supportsEvents,
    owner,
    ctag,
    syncToken,
    syncEnabled,
  );

  /// Create a copy of Calendar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CalendarImplCopyWith<_$CalendarImpl> get copyWith =>
      __$$CalendarImplCopyWithImpl<_$CalendarImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CalendarImplToJson(this);
  }
}

abstract class _Calendar implements Calendar {
  const factory _Calendar({
    required final int localId,
    required final String url,
    required final String displayName,
    final String color,
    final bool supportsTasks,
    final bool supportsEvents,
    required final String owner,
    final String? ctag,
    final String? syncToken,
    final bool syncEnabled,
  }) = _$CalendarImpl;

  factory _Calendar.fromJson(Map<String, dynamic> json) =
      _$CalendarImpl.fromJson;

  /// 本地数据库主键
  @override
  int get localId;

  /// 远端日历集合 URL（绝对或相对，作为同步标识）
  @override
  String get url;

  /// 显示名称（CALDAV:displayname）
  @override
  String get displayName;

  /// 日历颜色（CALDAV:calendar-color）
  @override
  String get color;

  /// 是否支持 VTODO（任务）
  @override
  bool get supportsTasks;

  /// 是否支持 VEVENT（事件）
  @override
  bool get supportsEvents;

  /// 所属账户的用户名
  @override
  String get owner;

  /// 远端 CTag（同步令牌，用于增量判断）
  @override
  String? get ctag;

  /// 远端 sync-token
  @override
  String? get syncToken;

  /// 是否启用同步
  @override
  bool get syncEnabled;

  /// Create a copy of Calendar
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CalendarImplCopyWith<_$CalendarImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
