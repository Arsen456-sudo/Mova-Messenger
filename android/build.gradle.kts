import java.util.Properties

plugins {
    id("com.android.application")
    kotlin("android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val localConfig = Properties().apply {
    val configFile = rootProject.file("local.properties")
    if (configFile.exists()) configFile.inputStream().use { load(it) }
}
fun clientConfig(localProperty: String, environmentVariable: String): String =
    localConfig.getProperty(localProperty)
        ?: System.getenv(environmentVariable)
        ?: ""
fun buildConfigString(value: String): String = "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""
val supabaseUrl = buildConfigString(clientConfig("supabase.url", "SUPABASE_URL"))
val supabaseKey = buildConfigString(clientConfig("supabase.publishableKey", "SUPABASE_PUBLISHABLE_KEY"))

android {
    namespace = "app.messenger.android"
    compileSdk = 36
    defaultConfig { applicationId = "app.messenger.android"; minSdk = 26; targetSdk = 36; versionCode = 1; versionName = "0.1.0" }
    buildFeatures { compose = true; buildConfig = true }
    buildTypes {
        debug {
            buildConfigField("String", "SUPABASE_URL", supabaseUrl)
            buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", supabaseKey)
        }
        release {
            buildConfigField("String", "SUPABASE_URL", supabaseUrl)
            buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", supabaseKey)
        }
    }
}

dependencies {
    implementation(project(":shared"))
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("androidx.compose.ui:ui:1.9.0")
    implementation("androidx.compose.ui:ui-tooling-preview:1.9.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.2")
    debugImplementation("androidx.compose.ui:ui-tooling:1.9.0")
}

