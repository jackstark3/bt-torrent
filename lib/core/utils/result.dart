/// 统一的结果类型，用于表示操作成功或失败
/// [T] 成功时的数据类型
sealed class Result<T> {
  const Result();

  /// 是否成功
  bool get isSuccess => this is _Success<T>;
  bool get isError => this is _Error<T>;

  /// 获取成功值，如果为 Error 则返回 null
  T? get value => switch (this) {
        _Success<T>(value: final v) => v,
        _Error() => null,
      };

  /// 获取错误信息，如果为 Success 则返回 null
  String? get error => switch (this) {
        _Success() => null,
        _Error(message: final msg) => msg,
      };

  /// 在成功时执行 [action]
  Result<T> onSuccess(void Function(T value) action) {
    if (this is _Success<T>) {
      action((this as _Success<T>).value);
    }
    return this;
  }

  /// 在错误时执行 [action]
  Result<T> onError(void Function(String message) action) {
    if (this is _Error<T>) {
      action((this as _Error<T>).message);
    }
    return this;
  }

  /// 映射成功值到新类型
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      _Success(value: final v) => Result.success(transform(v)),
      _Error(message: final msg) => Result.error(msg),
    };
  }

  /// 获取值，如果为 Error 则返回 [defaultValue]
  T getOrDefault(T defaultValue) =>
      switch (this) { _Success(value: final v) => v, _Error() => defaultValue };

  factory Result.success(T value) = _Success<T>;
  factory Result.error(String message) = _Error<T>;
}

class _Success<T> extends Result<T> {
  final T value;
  const _Success(this.value);

  @override
  bool operator ==(Object other) =>
      other is _Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

class _Error<T> extends Result<T> {
  final String message;
  const _Error(this.message);

  @override
  bool operator ==(Object other) =>
      other is _Error<T> && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'Error($message)';
}
