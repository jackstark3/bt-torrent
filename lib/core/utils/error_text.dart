import 'package:flutter/services.dart';

/// 把异常/错误对象转成简短、可读的错误信息
/// 去掉 PlatformException 的详情/堆栈，避免报错框刷屏。
String friendlyError(Object error) {
  String message;
  if (error is PlatformException) {
    message = error.message ?? error.code;
  } else {
    message = error.toString();
  }

  // 去掉常见前缀
  message = message
      .replaceAll(
        RegExp(r'^(?:Exception|Error|DioException|PlatformException)\s*[:：]?\s*',
            caseSensitive: false),
        '',
      )
      .trim();

  // 只保留第一行，避免堆栈刷屏
  final firstLine = message.split('\n').first.trim();
  return firstLine.isEmpty ? '未知错误' : firstLine;
}
