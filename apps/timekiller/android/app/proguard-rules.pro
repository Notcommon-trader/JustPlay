# R8 rules for the release build.
#
# Shrinking is on because it meaningfully cuts download size, and download size
# is one of the few things that measurably moves install conversion on a casual
# game. The cost is that R8 failures are *runtime* failures — a stripped class
# throws when something reflects on it, long after the build went green — so
# anything reached reflectively has to be kept here explicitly.

# Flutter's embedding. The Gradle plugin contributes most of this already, but
# keeping it stated means a plugin version that stops doing so fails loudly at
# build time rather than silently at launch.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Plugin registration is reflective: GeneratedPluginRegistrant looks plugins up
# by name, so a shrunk plugin class fails at startup with a missing-class error
# that names something you never wrote.
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Play Core split-install. The Flutter engine references these classes from its
# deferred-components support, but the app does not use deferred components and
# does not ship the Play Core library — so R8 sees references with nothing behind
# them and fails the build outright.
#
# `-dontwarn` and not a dependency: pulling in Play Core to satisfy an unused
# code path would add a library to every install for nothing. The code that
# touches these classes is unreachable here, and R8 removes it.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication

# Keep annotations and signatures. Without them, generic types are erased in a
# way that breaks reflective type inspection in some plugins.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Line numbers in crash reports. Without SourceFile/LineNumberTable a stack
# trace from the field points at nothing, which is the moment you most need it.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
