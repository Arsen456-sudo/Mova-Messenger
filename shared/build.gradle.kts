plugins {
    kotlin("multiplatform")
    kotlin("plugin.serialization")
    id("com.android.library")
}

val supabaseVersion = "3.9.0"
val ktorVersion = "3.4.3"

kotlin {
    androidTarget()
    iosArm64 { binaries.framework { baseName = "MessengerShared"; isStatic = true } }
    iosSimulatorArm64 { binaries.framework { baseName = "MessengerShared"; isStatic = true } }
    iosX64 { binaries.framework { baseName = "MessengerShared"; isStatic = true } }

    sourceSets {
        commonMain.dependencies {
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
            implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
            implementation("io.github.jan-tennert.supabase:auth-kt:$supabaseVersion")
            implementation("io.github.jan-tennert.supabase:postgrest-kt:$supabaseVersion")
            implementation("io.github.jan-tennert.supabase:realtime-kt:$supabaseVersion")
        }
        androidMain.dependencies { implementation("io.ktor:ktor-client-android:$ktorVersion") }
        iosMain.dependencies { implementation("io.ktor:ktor-client-darwin:$ktorVersion") }
    }
}

android { namespace = "app.messenger.shared"; compileSdk = 36; defaultConfig { minSdk = 26 } }
