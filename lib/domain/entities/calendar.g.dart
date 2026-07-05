// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CalendarImpl _$$CalendarImplFromJson(Map<String, dynamic> json) =>
    _$CalendarImpl(
      localId: (json['localId'] as num).toInt(),
      url: json['url'] as String,
      displayName: json['displayName'] as String,
      color: json['color'] as String? ?? '#2E7D32',
      supportsTasks: json['supportsTasks'] as bool? ?? true,
      supportsEvents: json['supportsEvents'] as bool? ?? false,
      owner: json['owner'] as String,
      ctag: json['ctag'] as String?,
      syncToken: json['syncToken'] as String?,
      syncEnabled: json['syncEnabled'] as bool? ?? true,
    );

Map<String, dynamic> _$$CalendarImplToJson(_$CalendarImpl instance) =>
    <String, dynamic>{
      'localId': instance.localId,
      'url': instance.url,
      'displayName': instance.displayName,
      'color': instance.color,
      'supportsTasks': instance.supportsTasks,
      'supportsEvents': instance.supportsEvents,
      'owner': instance.owner,
      'ctag': instance.ctag,
      'syncToken': instance.syncToken,
      'syncEnabled': instance.syncEnabled,
    };
