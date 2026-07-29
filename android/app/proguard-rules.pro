# StrawHut ProGuard Rules

# Flutter Wrapper - 不压缩 Flutter 相关类
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 加密相关 - 保留原生加密插件
-keep class com.strawhut.strawhut.CryptoPlugin { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# MethodChannel 参数类型
-keep class * extends java.nio.ByteBuffer { *; }

# Kotlin 协程
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Flutter 引擎引用的 Play Core 类（本项目不使用，忽略警告）
-dontwarn com.google.android.play.core.**

# 通用规则
-dontwarn kotlinx.coroutines.**
