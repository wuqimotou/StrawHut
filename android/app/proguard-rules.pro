# StrawHut ProGuard Rules

# Flutter Wrapper - 不压缩 Flutter 相关类
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 加密相关 - 保留原生加密插件与入口 Activity
-keep class com.strawhut.strawhut.CryptoPlugin { *; }
-keep class com.strawhut.strawhut.MainActivity { *; }

# flutter_secure_storage 及其传递依赖（关键）
# Android 端 EncryptedSharedPreferences 基于 Tink，Tink 通过反射注册 KeysetHandle 等，
# R8 混淆/裁剪这些类会导致启动或首次读写时 ClassNotFoundException / GeneralSecurityException
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }
-keep class androidx.security.crypto.** { *; }

# 其他注册插件 - 防止 R8 混淆其内部反射/序列化逻辑
-keep class xyz.luan.audioplayers.** { *; }
-keep class one.mixin.desktop.drop.** { *; }
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class com.jrai.flutter_keyboard_visibility_temp_fork.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.lazycatlabs.media_scanner.** { *; }
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class dev.flutterquill.quill_native_bridge.** { *; }
-keep class com.kasem.receive_sharing_intent.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class com.syncfusion.flutter.pdfviewer.** { *; }
-keep class com.syncfusion.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }

# MethodChannel 参数类型
-keep class * extends java.nio.ByteBuffer { *; }

# Kotlin 协程
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Flutter 引擎引用的 Play Core 类（本项目不使用，忽略警告）
-dontwarn com.google.android.play.core.**

# 通用规则
-dontwarn kotlinx.coroutines.**
