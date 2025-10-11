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

import org.gradle.internal.os.OperatingSystem
import java.util.Base64

plugins {
    kotlin("jvm")
}

group = "com.o2ter.jscore"

java { targetCompatibility = JavaVersion.VERSION_11 }

kotlin { 
    jvmToolchain(17)
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

// Check if ICU data file is available at build time in source tree
val icuDataFile = file("src/main/resources/com/o2ter/jscore/jvm/resource/icudtl.dat")
val hasIcuData = icuDataFile.exists() && icuDataFile.length() > 1_000_000

dependencies {
    api(project(":jscore"))

    // Detect platform and architecture dynamically for Javet native library
    val os = OperatingSystem.current()
    val arch = System.getProperty("os.arch")
    val osType = when {
        os.isWindows -> "windows"
        os.isMacOsX -> "macos"
        os.isLinux -> "linux"
        else -> ""
    }
    val archType = when (arch) {
        "aarch64", "arm64" -> "arm64"
        else -> "x86_64"
    }
    
    // ICU data is in source tree, so only use i18n variant with getV8I18nInstance()
    implementation("com.caoccao.javet:javet-v8-$osType-$archType-i18n:5.0.0")
    
    implementation(libs.slf4j.api)
    implementation(libs.logback.classic)

    testImplementation(libs.jetbrains.kotlin.test)
}

// Generate compile-time constants for ICU configuration
val generateIcuConfig by tasks.registering {
    group = "build"
    description = "Generate compile-time ICU configuration based on source tree"
    
    // ICU data is in source tree
    val icuFile = file("src/main/resources/com/o2ter/jscore/jvm/resource/icudtl.dat")
    val outputDir = file("${layout.buildDirectory.get().asFile}/generated/kotlin")
    val outputFile = file("${outputDir}/com/o2ter/jscore/jvm/IcuConfig.kt")
    
    inputs.files(icuFile)
    outputs.file(outputFile)
    outputs.upToDateWhen { 
        outputFile.exists() && icuFile.exists() && icuFile.length() > 1_000_000 && icuFile.length() < 50_000_000
    }
    
    doLast {
        // Create directories
        outputDir.mkdirs()
        outputFile.parentFile.mkdirs()
        
        // Check if ICU data file is valid
        val hasValidIcu = icuFile.exists() && icuFile.length() > 1_000_000 && icuFile.length() < 50_000_000
        
        if (!hasValidIcu) {
            throw GradleException("""
                ICU data file not found or invalid in source tree!
                Expected at: ${icuFile.absolutePath}
                
                The ICU data file must be present in the source tree for i18n support.
                Please ensure icudtl.dat is committed to the repository.
            """.trimIndent())
        }
        
        // Use resource path for runtime access (will be packaged in JAR)
        val icuResourcePath = "com/o2ter/jscore/jvm/resource/icudtl.dat"
        
        val sizeMB = String.format("%.2f", icuFile.length() / 1024.0 / 1024.0)
        println("✓ ICU data file found in source tree ($sizeMB MB)")
        
        // Generate Kotlin source file with compile-time constants
        outputFile.writeText("""
            //
            // IcuConfig.kt
            // Auto-generated - DO NOT EDIT
            //
            // Generated at build time based on ICU data in source tree
            //
            
            package com.o2ter.jscore.jvm
            
            /**
             * Compile-time ICU configuration
             * ICU data is embedded in source tree and packaged in JAR
             */
            internal object IcuConfig {
                /**
                 * Resource path to ICU data file (packaged in JAR)
                 */
                const val ICU_DATA_RESOURCE_PATH: String = "$icuResourcePath"
            }
        """.trimIndent())
    }
}



// Register generated source directory
kotlin.sourceSets.main {
    kotlin.srcDir("${layout.buildDirectory.get().asFile}/generated/kotlin")
}

// Generate ICU config before compilation
tasks.named("compileKotlin") {
    dependsOn(generateIcuConfig)
}

tasks.test {
    testLogging {
        showStandardStreams = true
    }
}