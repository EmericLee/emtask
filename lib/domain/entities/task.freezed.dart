// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Task _$TaskFromJson(Map<String, dynamic> json) {
  return _Task.fromJson(json);
}

/// @nodoc
mixin _$Task {
  /// 本地数据库主键（本地生成，与服务端无关）
  int get localId => throw _privateConstructorUsedError;

  /// 远端日历 URL（标识所属日历）
  String get calendarUrl => throw _privateConstructorUsedError;

  /// iCalendar UID（全局唯一，CalDAV 同步主键）
  String get uid => throw _privateConstructorUsedError;

  /// 任务标题
  String get summary => throw _privateConstructorUsedError;

  /// 任务详情
  String get description => throw _privateConstructorUsedError;

  /// 开始时间
  DateTime? get start => throw _privateConstructorUsedError;

  /// 截止时间
  DateTime? get due => throw _privateConstructorUsedError;

  /// 完成时间
  DateTime? get completed => throw _privateConstructorUsedError;

  /// 状态
  TaskStatus get status => throw _privateConstructorUsedError;

  /// 优先级
  TaskPriority get priority => throw _privateConstructorUsedError;

  /// 完成百分比 0-100
  int get percent => throw _privateConstructorUsedError;

  /// 分类标签
  List<String> get categories => throw _privateConstructorUsedError;

  /// 父任务 UID（用于子任务）
  String? get parentUid => throw _privateConstructorUsedError;

  /// 远端 .ics 资源 HREF（相对路径）
  String? get href => throw _privateConstructorUsedError;

  /// 远端 ETag（同步用，乐观并发控制）
  String? get etag => throw _privateConstructorUsedError;

  /// 创建时间
  DateTime? get created => throw _privateConstructorUsedError;

  /// 最后修改时间
  DateTime? get lastModified => throw _privateConstructorUsedError;

  /// 本地最后修改时间（用于离线变更追踪）
  DateTime? get localModifiedAt => throw _privateConstructorUsedError;

  /// 手动排序值（对应 X-APPLE-SORT-ORDER，数字越小越靠前）
  int? get sortOrder => throw _privateConstructorUsedError;

  /// 是否待同步上传
  bool get dirty => throw _privateConstructorUsedError;

  /// 是否已被本地删除（待同步删除）
  bool get deleted => throw _privateConstructorUsedError;

  /// Serializes this Task to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskCopyWith<Task> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskCopyWith<$Res> {
  factory $TaskCopyWith(Task value, $Res Function(Task) then) =
      _$TaskCopyWithImpl<$Res, Task>;
  @useResult
  $Res call({
    int localId,
    String calendarUrl,
    String uid,
    String summary,
    String description,
    DateTime? start,
    DateTime? due,
    DateTime? completed,
    TaskStatus status,
    TaskPriority priority,
    int percent,
    List<String> categories,
    String? parentUid,
    String? href,
    String? etag,
    DateTime? created,
    DateTime? lastModified,
    DateTime? localModifiedAt,
    int? sortOrder,
    bool dirty,
    bool deleted,
  });
}

/// @nodoc
class _$TaskCopyWithImpl<$Res, $Val extends Task>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? localId = null,
    Object? calendarUrl = null,
    Object? uid = null,
    Object? summary = null,
    Object? description = null,
    Object? start = freezed,
    Object? due = freezed,
    Object? completed = freezed,
    Object? status = null,
    Object? priority = null,
    Object? percent = null,
    Object? categories = null,
    Object? parentUid = freezed,
    Object? href = freezed,
    Object? etag = freezed,
    Object? created = freezed,
    Object? lastModified = freezed,
    Object? localModifiedAt = freezed,
    Object? sortOrder = freezed,
    Object? dirty = null,
    Object? deleted = null,
  }) {
    return _then(
      _value.copyWith(
            localId: null == localId
                ? _value.localId
                : localId // ignore: cast_nullable_to_non_nullable
                      as int,
            calendarUrl: null == calendarUrl
                ? _value.calendarUrl
                : calendarUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            uid: null == uid
                ? _value.uid
                : uid // ignore: cast_nullable_to_non_nullable
                      as String,
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            start: freezed == start
                ? _value.start
                : start // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            due: freezed == due
                ? _value.due
                : due // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            completed: freezed == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TaskStatus,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as TaskPriority,
            percent: null == percent
                ? _value.percent
                : percent // ignore: cast_nullable_to_non_nullable
                      as int,
            categories: null == categories
                ? _value.categories
                : categories // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            parentUid: freezed == parentUid
                ? _value.parentUid
                : parentUid // ignore: cast_nullable_to_non_nullable
                      as String?,
            href: freezed == href
                ? _value.href
                : href // ignore: cast_nullable_to_non_nullable
                      as String?,
            etag: freezed == etag
                ? _value.etag
                : etag // ignore: cast_nullable_to_non_nullable
                      as String?,
            created: freezed == created
                ? _value.created
                : created // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastModified: freezed == lastModified
                ? _value.lastModified
                : lastModified // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            localModifiedAt: freezed == localModifiedAt
                ? _value.localModifiedAt
                : localModifiedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            sortOrder: freezed == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                      as int?,
            dirty: null == dirty
                ? _value.dirty
                : dirty // ignore: cast_nullable_to_non_nullable
                      as bool,
            deleted: null == deleted
                ? _value.deleted
                : deleted // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskImplCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$$TaskImplCopyWith(
    _$TaskImpl value,
    $Res Function(_$TaskImpl) then,
  ) = __$$TaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int localId,
    String calendarUrl,
    String uid,
    String summary,
    String description,
    DateTime? start,
    DateTime? due,
    DateTime? completed,
    TaskStatus status,
    TaskPriority priority,
    int percent,
    List<String> categories,
    String? parentUid,
    String? href,
    String? etag,
    DateTime? created,
    DateTime? lastModified,
    DateTime? localModifiedAt,
    int? sortOrder,
    bool dirty,
    bool deleted,
  });
}

/// @nodoc
class __$$TaskImplCopyWithImpl<$Res>
    extends _$TaskCopyWithImpl<$Res, _$TaskImpl>
    implements _$$TaskImplCopyWith<$Res> {
  __$$TaskImplCopyWithImpl(_$TaskImpl _value, $Res Function(_$TaskImpl) _then)
    : super(_value, _then);

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? localId = null,
    Object? calendarUrl = null,
    Object? uid = null,
    Object? summary = null,
    Object? description = null,
    Object? start = freezed,
    Object? due = freezed,
    Object? completed = freezed,
    Object? status = null,
    Object? priority = null,
    Object? percent = null,
    Object? categories = null,
    Object? parentUid = freezed,
    Object? href = freezed,
    Object? etag = freezed,
    Object? created = freezed,
    Object? lastModified = freezed,
    Object? localModifiedAt = freezed,
    Object? sortOrder = freezed,
    Object? dirty = null,
    Object? deleted = null,
  }) {
    return _then(
      _$TaskImpl(
        localId: null == localId
            ? _value.localId
            : localId // ignore: cast_nullable_to_non_nullable
                  as int,
        calendarUrl: null == calendarUrl
            ? _value.calendarUrl
            : calendarUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        uid: null == uid
            ? _value.uid
            : uid // ignore: cast_nullable_to_non_nullable
                  as String,
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        start: freezed == start
            ? _value.start
            : start // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        due: freezed == due
            ? _value.due
            : due // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        completed: freezed == completed
            ? _value.completed
            : completed // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TaskStatus,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as TaskPriority,
        percent: null == percent
            ? _value.percent
            : percent // ignore: cast_nullable_to_non_nullable
                  as int,
        categories: null == categories
            ? _value._categories
            : categories // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        parentUid: freezed == parentUid
            ? _value.parentUid
            : parentUid // ignore: cast_nullable_to_non_nullable
                  as String?,
        href: freezed == href
            ? _value.href
            : href // ignore: cast_nullable_to_non_nullable
                  as String?,
        etag: freezed == etag
            ? _value.etag
            : etag // ignore: cast_nullable_to_non_nullable
                  as String?,
        created: freezed == created
            ? _value.created
            : created // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastModified: freezed == lastModified
            ? _value.lastModified
            : lastModified // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        localModifiedAt: freezed == localModifiedAt
            ? _value.localModifiedAt
            : localModifiedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        sortOrder: freezed == sortOrder
            ? _value.sortOrder
            : sortOrder // ignore: cast_nullable_to_non_nullable
                  as int?,
        dirty: null == dirty
            ? _value.dirty
            : dirty // ignore: cast_nullable_to_non_nullable
                  as bool,
        deleted: null == deleted
            ? _value.deleted
            : deleted // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskImpl implements _Task {
  const _$TaskImpl({
    required this.localId,
    required this.calendarUrl,
    required this.uid,
    required this.summary,
    this.description = '',
    this.start,
    this.due,
    this.completed,
    this.status = TaskStatus.needsAction,
    this.priority = TaskPriority.none,
    this.percent = 0,
    final List<String> categories = const <String>[],
    this.parentUid,
    this.href,
    this.etag,
    this.created,
    this.lastModified,
    this.localModifiedAt,
    this.sortOrder,
    this.dirty = false,
    this.deleted = false,
  }) : _categories = categories;

  factory _$TaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskImplFromJson(json);

  /// 本地数据库主键（本地生成，与服务端无关）
  @override
  final int localId;

  /// 远端日历 URL（标识所属日历）
  @override
  final String calendarUrl;

  /// iCalendar UID（全局唯一，CalDAV 同步主键）
  @override
  final String uid;

  /// 任务标题
  @override
  final String summary;

  /// 任务详情
  @override
  @JsonKey()
  final String description;

  /// 开始时间
  @override
  final DateTime? start;

  /// 截止时间
  @override
  final DateTime? due;

  /// 完成时间
  @override
  final DateTime? completed;

  /// 状态
  @override
  @JsonKey()
  final TaskStatus status;

  /// 优先级
  @override
  @JsonKey()
  final TaskPriority priority;

  /// 完成百分比 0-100
  @override
  @JsonKey()
  final int percent;

  /// 分类标签
  final List<String> _categories;

  /// 分类标签
  @override
  @JsonKey()
  List<String> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  /// 父任务 UID（用于子任务）
  @override
  final String? parentUid;

  /// 远端 .ics 资源 HREF（相对路径）
  @override
  final String? href;

  /// 远端 ETag（同步用，乐观并发控制）
  @override
  final String? etag;

  /// 创建时间
  @override
  final DateTime? created;

  /// 最后修改时间
  @override
  final DateTime? lastModified;

  /// 本地最后修改时间（用于离线变更追踪）
  @override
  final DateTime? localModifiedAt;

  /// 手动排序值（对应 X-APPLE-SORT-ORDER，数字越小越靠前）
  @override
  final int? sortOrder;

  /// 是否待同步上传
  @override
  @JsonKey()
  final bool dirty;

  /// 是否已被本地删除（待同步删除）
  @override
  @JsonKey()
  final bool deleted;

  @override
  String toString() {
    return 'Task(localId: $localId, calendarUrl: $calendarUrl, uid: $uid, summary: $summary, description: $description, start: $start, due: $due, completed: $completed, status: $status, priority: $priority, percent: $percent, categories: $categories, parentUid: $parentUid, href: $href, etag: $etag, created: $created, lastModified: $lastModified, localModifiedAt: $localModifiedAt, sortOrder: $sortOrder, dirty: $dirty, deleted: $deleted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskImpl &&
            (identical(other.localId, localId) || other.localId == localId) &&
            (identical(other.calendarUrl, calendarUrl) ||
                other.calendarUrl == calendarUrl) &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.due, due) || other.due == due) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.percent, percent) || other.percent == percent) &&
            const DeepCollectionEquality().equals(
              other._categories,
              _categories,
            ) &&
            (identical(other.parentUid, parentUid) ||
                other.parentUid == parentUid) &&
            (identical(other.href, href) || other.href == href) &&
            (identical(other.etag, etag) || other.etag == etag) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.localModifiedAt, localModifiedAt) ||
                other.localModifiedAt == localModifiedAt) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.dirty, dirty) || other.dirty == dirty) &&
            (identical(other.deleted, deleted) || other.deleted == deleted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    localId,
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
    const DeepCollectionEquality().hash(_categories),
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

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      __$$TaskImplCopyWithImpl<_$TaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskImplToJson(this);
  }
}

abstract class _Task implements Task {
  const factory _Task({
    required final int localId,
    required final String calendarUrl,
    required final String uid,
    required final String summary,
    final String description,
    final DateTime? start,
    final DateTime? due,
    final DateTime? completed,
    final TaskStatus status,
    final TaskPriority priority,
    final int percent,
    final List<String> categories,
    final String? parentUid,
    final String? href,
    final String? etag,
    final DateTime? created,
    final DateTime? lastModified,
    final DateTime? localModifiedAt,
    final int? sortOrder,
    final bool dirty,
    final bool deleted,
  }) = _$TaskImpl;

  factory _Task.fromJson(Map<String, dynamic> json) = _$TaskImpl.fromJson;

  /// 本地数据库主键（本地生成，与服务端无关）
  @override
  int get localId;

  /// 远端日历 URL（标识所属日历）
  @override
  String get calendarUrl;

  /// iCalendar UID（全局唯一，CalDAV 同步主键）
  @override
  String get uid;

  /// 任务标题
  @override
  String get summary;

  /// 任务详情
  @override
  String get description;

  /// 开始时间
  @override
  DateTime? get start;

  /// 截止时间
  @override
  DateTime? get due;

  /// 完成时间
  @override
  DateTime? get completed;

  /// 状态
  @override
  TaskStatus get status;

  /// 优先级
  @override
  TaskPriority get priority;

  /// 完成百分比 0-100
  @override
  int get percent;

  /// 分类标签
  @override
  List<String> get categories;

  /// 父任务 UID（用于子任务）
  @override
  String? get parentUid;

  /// 远端 .ics 资源 HREF（相对路径）
  @override
  String? get href;

  /// 远端 ETag（同步用，乐观并发控制）
  @override
  String? get etag;

  /// 创建时间
  @override
  DateTime? get created;

  /// 最后修改时间
  @override
  DateTime? get lastModified;

  /// 本地最后修改时间（用于离线变更追踪）
  @override
  DateTime? get localModifiedAt;

  /// 手动排序值（对应 X-APPLE-SORT-ORDER，数字越小越靠前）
  @override
  int? get sortOrder;

  /// 是否待同步上传
  @override
  bool get dirty;

  /// 是否已被本地删除（待同步删除）
  @override
  bool get deleted;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
