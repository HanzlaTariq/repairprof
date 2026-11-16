import java.util.Properties
plugins {
 id("com.android.application")
 id("dev.flutter.flutter-gradle-plugin")
}
val keyFile = rootProject.file("key.properties")
val key = Properties()
if (keyFile.exists()) keyFile.inputStream().use { key.load(it) }
android {
 namespace = "com.repairproof.app"
 compileSdk = flutter.compileSdkVersion
 ndkVersion = flutter.ndkVersion
 compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
 defaultConfig {
  applicationId = "com.repairproof.app"
  minSdk = 24
  targetSdk = 36
  versionCode = flutter.versionCode
  versionName = flutter.versionName
 }
 signingConfigs {
  if(keyFile.exists()) create("release") {
   keyAlias = key.getProperty("keyAlias")
   keyPassword = key.getProperty("keyPassword")
   storeFile = file(key.getProperty("storeFile"))
   storePassword = key.getProperty("storePassword")
  }
 }
 buildTypes { release {
  if(keyFile.exists()) signingConfig = signingConfigs.getByName("release")
 } }
}
kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
flutter { source = "../.." }
// A Play release must be deliberately signed with the owner's upload key.
gradle.taskGraph.whenReady {
 if(allTasks.any { it.name.contains("Release") } && !keyFile.exists()) {
  throw GradleException("Release signing missing: copy key.properties.example to key.properties and set your private upload key.")
 }
}
