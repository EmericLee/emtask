// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskImpl _$$TaskImplFromJson(Map<String, dynamic> json) => _$TaskImpl(
  localId: (json['localId'] as num).toInt(),
  calendarUrl: json['calendarUrl'] as String,
  uid: json['uid'] as String,
  summary: json['summary'] as String,
  description: json['description'] as String? ?? '',
  start: json['start'] == null ? null : DateTime.parse(json['start'] as String),
  due: json['due'] == null ? null : DateTime.parse(json['due'] as String),
  completed: json['completed'] == null
      ? null
      : DateTime.parse(json['completed'] as String),
  status:
      $enumDecodeNullable(_$TaskStatusEnumMap, json['status']) ??
      TaskStatus.needsAction,
  priority:
      $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']) ??
      TaskPriority.none,
  percent: (json['percent'] as num?)?.toInt() ?? 0,
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  parentUid: json['parentUid'] as String?,
  href: json['href'] as String?,
  etag: json['etag'] as String?,
  created: json['created'] == null
      ? null
      : DateTime.parse(json['created'] as String),
  lastModified: json['lastModified'] == null
      ? null
      : DateTime.parse(json['lastModified'] as String),
  localModifiedAt: json['localModifiedAt'] == null
      ? null
      : DateTime.parse(json['localModifiedAt'] as String),
  sortOrder: (json['sortOrder'] as num?)?.toInt(),
  dirty: json['dirty'] as bool? ?? false,
  deleted: json['deleted'] as bool? ?? false,
);

Map<String, dynamic> _$$TaskImplToJson(_$TaskImpl instance) =>
    <String, dynamic>{
      'localId': instance.localId,
      'calendarUrl': instance.calendarUrl,
      'uid': instance.uid,
      'summary': instance.summary,
      'description': instance.description,
      'start': instance.start?.toIso8601String(),
      'due': instance.due?.toIso8601String(),
      'completed': instance.completed?.toIso8601String(),
      'status': _$TaskStatusEnumMap[instance.status]!,
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'percent': instance.percent,
      'categories': instance.categories,
      'parentUid': instance.parentUid,
      'href': instance.href,
      'etag': instance.etag,
      'created': instance.created?.toIso8601String(),
      'lastModified': instance.lastModified?.toIso8601String(),
      'localModifiedAt': instance.localModifiedAt?.toIso8601String(),
      'sortOrder': instance.sortOrder,
      'dirty': instance.dirty,
      'deleted': instance.deleted,
    };

const _$TaskStatusEnumMap = {
  TaskStatus.needsAction: 'needsAction',
  TaskStatus.inProcess: 'inProcess',
  TaskStatus.completed: 'completed',
  TaskStatus.cancelled: 'cancelled',
};

const _$TaskPriorityEnumMap = {
  TaskPriority.none: 'none',
  TaskPriority.high: 'high',
  TaskPriority.medium: 'medium',
  TaskPriority.low: 'low',
};
