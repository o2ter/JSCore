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

plugins {
    kotlin("jvm")
}

group = "com.o2ter.jscore"

java { 
    targetCompatibility = JavaVersion.VERSION_11
    sourceCompatibility = JavaVersion.VERSION_11
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

// Copy polyfill.js from root resources to module resources
val copyPolyfill = tasks.register<Copy>("copyPolyfill") {
    from(layout.projectDirectory.dir("../../resources"))
    include("polyfill.js")
    into(layout.buildDirectory.dir("resources/main"))
}

// Ensure polyfill is copied before processing resources
tasks.named("processResources") {
    dependsOn(copyPolyfill)
}

dependencies {
    implementation(libs.jetbrains.kotlin.stdlib)
    implementation(libs.kotlinx.coroutines.core)
    
    // Javet - Unified V8 engine for both JVM and Android
    implementation(libs.javet)
    
    // SLF4J for logging
    implementation(libs.slf4j.api)
}
