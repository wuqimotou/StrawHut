import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'locale_provider.g.dart';

@riverpod
class AppLocale extends _$AppLocale {
  @override
  Locale build() {
    return const Locale('zh');
  }

  void setLocale(Locale locale) {
    state = locale;
  }
}
