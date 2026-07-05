// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'caldav_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CalDavAccount _$CalDavAccountFromJson(Map<String, dynamic> json) {
  return _CalDavAccount.fromJson(json);
}

/// @nodoc
mixin _$CalDavAccount {
  /// 服务端基础地址（不含路径，如 https://cloud.example.com）
  String get baseUrl => throw _privateConstructorUsedError;

  /// 用户名
  String get username => throw _privateConstructorUsedError;

  /// 应用密码 / 密码
  String get password => throw _privateConstructorUsedError;

  /// 是否信任自签名证书（内网部署 / UOS 本地部署常用）
  bool get trustSelfSignedCert => throw _privateConstructorUsedError;

  /// 显示名称
  String? get displayName => throw _privateConstructorUsedError;

  /// Serializes this CalDavAccount to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CalDavAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CalDavAccountCopyWith<CalDavAccount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CalDavAccountCopyWith<$Res> {
  factory $CalDavAccountCopyWith(
    CalDavAccount value,
    $Res Function(CalDavAccount) then,
  ) = _$CalDavAccountCopyWithImpl<$Res, CalDavAccount>;
  @useResult
  $Res call({
    String baseUrl,
    String username,
    String password,
    bool trustSelfSignedCert,
    String? displayName,
  });
}

/// @nodoc
class _$CalDavAccountCopyWithImpl<$Res, $Val extends CalDavAccount>
    implements $CalDavAccountCopyWith<$Res> {
  _$CalDavAccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CalDavAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = null,
    Object? username = null,
    Object? password = null,
    Object? trustSelfSignedCert = null,
    Object? displayName = freezed,
  }) {
    return _then(
      _value.copyWith(
            baseUrl: null == baseUrl
                ? _value.baseUrl
                : baseUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            username: null == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String,
            password: null == password
                ? _value.password
                : password // ignore: cast_nullable_to_non_nullable
                      as String,
            trustSelfSignedCert: null == trustSelfSignedCert
                ? _value.trustSelfSignedCert
                : trustSelfSignedCert // ignore: cast_nullable_to_non_nullable
                      as bool,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CalDavAccountImplCopyWith<$Res>
    implements $CalDavAccountCopyWith<$Res> {
  factory _$$CalDavAccountImplCopyWith(
    _$CalDavAccountImpl value,
    $Res Function(_$CalDavAccountImpl) then,
  ) = __$$CalDavAccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String baseUrl,
    String username,
    String password,
    bool trustSelfSignedCert,
    String? displayName,
  });
}

/// @nodoc
class __$$CalDavAccountImplCopyWithImpl<$Res>
    extends _$CalDavAccountCopyWithImpl<$Res, _$CalDavAccountImpl>
    implements _$$CalDavAccountImplCopyWith<$Res> {
  __$$CalDavAccountImplCopyWithImpl(
    _$CalDavAccountImpl _value,
    $Res Function(_$CalDavAccountImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CalDavAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = null,
    Object? username = null,
    Object? password = null,
    Object? trustSelfSignedCert = null,
    Object? displayName = freezed,
  }) {
    return _then(
      _$CalDavAccountImpl(
        baseUrl: null == baseUrl
            ? _value.baseUrl
            : baseUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        username: null == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        password: null == password
            ? _value.password
            : password // ignore: cast_nullable_to_non_nullable
                  as String,
        trustSelfSignedCert: null == trustSelfSignedCert
            ? _value.trustSelfSignedCert
            : trustSelfSignedCert // ignore: cast_nullable_to_non_nullable
                  as bool,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CalDavAccountImpl extends _CalDavAccount {
  const _$CalDavAccountImpl({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.trustSelfSignedCert = false,
    this.displayName,
  }) : super._();

  factory _$CalDavAccountImpl.fromJson(Map<String, dynamic> json) =>
      _$$CalDavAccountImplFromJson(json);

  /// 服务端基础地址（不含路径，如 https://cloud.example.com）
  @override
  final String baseUrl;

  /// 用户名
  @override
  final String username;

  /// 应用密码 / 密码
  @override
  final String password;

  /// 是否信任自签名证书（内网部署 / UOS 本地部署常用）
  @override
  @JsonKey()
  final bool trustSelfSignedCert;

  /// 显示名称
  @override
  final String? displayName;

  @override
  String toString() {
    return 'CalDavAccount(baseUrl: $baseUrl, username: $username, password: $password, trustSelfSignedCert: $trustSelfSignedCert, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CalDavAccountImpl &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.trustSelfSignedCert, trustSelfSignedCert) ||
                other.trustSelfSignedCert == trustSelfSignedCert) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    baseUrl,
    username,
    password,
    trustSelfSignedCert,
    displayName,
  );

  /// Create a copy of CalDavAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CalDavAccountImplCopyWith<_$CalDavAccountImpl> get copyWith =>
      __$$CalDavAccountImplCopyWithImpl<_$CalDavAccountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CalDavAccountImplToJson(this);
  }
}

abstract class _CalDavAccount extends CalDavAccount {
  const factory _CalDavAccount({
    required final String baseUrl,
    required final String username,
    required final String password,
    final bool trustSelfSignedCert,
    final String? displayName,
  }) = _$CalDavAccountImpl;
  const _CalDavAccount._() : super._();

  factory _CalDavAccount.fromJson(Map<String, dynamic> json) =
      _$CalDavAccountImpl.fromJson;

  /// 服务端基础地址（不含路径，如 https://cloud.example.com）
  @override
  String get baseUrl;

  /// 用户名
  @override
  String get username;

  /// 应用密码 / 密码
  @override
  String get password;

  /// 是否信任自签名证书（内网部署 / UOS 本地部署常用）
  @override
  bool get trustSelfSignedCert;

  /// 显示名称
  @override
  String? get displayName;

  /// Create a copy of CalDavAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CalDavAccountImplCopyWith<_$CalDavAccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
