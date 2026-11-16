pluginManagement {
 val flutterSdkPath = run {
  val properties = java.util.Properties()
  file("local.properties").inputStream().use { properties.load(it) }
  val sdk = properties.getProperty("flutter.sdk")
  require(sdk != null) { "Run flutter pub get first; flutter.sdk must be set in local.properties" }
  sdk
 }
 includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
 repositories { google(); mavenCentral(); gradlePluginPortal() }
}
plugins {
 id("dev.flutter.flutter-plugin-loader") version "1.0.0"
 id("com.android.application") version "9.1.0" apply false
 id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}
include(":app")
