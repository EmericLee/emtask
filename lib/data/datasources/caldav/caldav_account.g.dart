// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caldav_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CalDavAccountImpl _$$CalDavAccountImplFromJson(Map<String, dynamic> json) =>
    _$CalDavAccountImpl(
      baseUrl: json['baseUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      trustSelfSignedCert: json['trustSelfSignedCert'] as bool? ?? false,
      displayName: json['displayName'] as String?,
    );

Map<String, dynamic> _$$CalDavAccountImplToJson(_$CalDavAccountImpl instance) =>
    <String, dynamic>{
      'baseUrl': instance.baseUrl,
      'username': instance.username,
      'password': instance.password,
      'trustSelfSignedCert': instance.trustSelfSignedCert,
      'displayName': instance.displayName,
    };
