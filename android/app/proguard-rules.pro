# Flutter eklentilerinin Java tarafındaki sınıfları Flutter motoru tarafından
# adlarıyla yüklenebildiği için bu sınıfları koru.
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.DefaultLifecycleObserver { *; }
