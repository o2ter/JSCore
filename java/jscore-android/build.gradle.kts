//
//  build.gradle.kts
//
//  The MIT License
//  Copyright (c) 2021 - 2025 O2ter Limited. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import com.android.build.gradle.internal.dsl.BaseAppModuleExtension

plugins {
    id("com.android.library")
    kotlin("android")
}

group = "com.o2ter.jscore"

var rootAndroid: BaseAppModuleExtension? = null
{
    println("Searching for root android project...")
    var gradle = gradle.parent
    do {
        var appProj = gradle?.rootProject?.findProject(":app")
        var androidExt = appProj?.extensions?.findByType(BaseAppModuleExtension::class.java)
        if (androidExt != null) {
            rootAndroid = androidExt
            println("✓ Found root android project: ${gradle?.rootProject?.name}")
            break
        }
        gradle = gradle?.parent
    } while (gradle != null)
    if (rootAndroid == null) {
        println("✗ Root android project not found, using default configuration.")
    }
}()

android {
    namespace = "com.o2ter.jscore.android"
    compileSdk = rootAndroid?.compileSdk ?: 36

    // Check if ICU data file is available in source tree
    val icuFile = file("src/main/resources/com/o2ter/jscore/android/resource/icudtl.dat")
    val hasIcuData = icuFile.exists() && icuFile.length() > 1_000_000

    defaultConfig {

        minSdk = 24

        if (hasIcuData) {
            val sizeMB = String.format("%.2f", icuFile.length() / 1024.0 / 1024.0)
            println("✓ Android ICU data found in source tree ($sizeMB MB)")
        } else {
            throw GradleException("""
                ICU data file not found or invalid in source tree!
                Expected at: ${icuFile.absolutePath}
                
                The ICU data file must be present in the source tree for i18n support.
                Please ensure icudtl.dat is committed to the repository.
            """.trimIndent())
        }
    }
}

java { targetCompatibility = JavaVersion.VERSION_11 }

kotlin { jvmToolchain(17) }

dependencies {
    implementation(project(":jscore"))
    
    // ICU data is in source tree, so only use i18n variant with getV8I18nInstance()
    implementation(libs.javet.v8.android.i18n)
    
    implementation(libs.kotlin.stdlib)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.coroutines.android)
    
    // Android dependencies
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)

    testImplementation(libs.kotlin.test)
}

tasks.preBuild {
    var gradle: Gradle? = gradle
    do {
        val parentLocalPropertiesFile = gradle?.rootProject?.file("local.properties")
        if (parentLocalPropertiesFile?.exists() == true) {
            val localPropertiesFile = rootProject.file("local.properties")
            if (!localPropertiesFile.exists()) {
                println("Copying local.properties from $parentLocalPropertiesFile project to $localPropertiesFile")
                localPropertiesFile.createNewFile()
                parentLocalPropertiesFile.copyTo(localPropertiesFile, true)
            }
            break
        }
        gradle = gradle?.parent
    } while (gradle != null)
}