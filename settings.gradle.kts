//
//  settings.gradle.kts
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

pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
    plugins {
        kotlin("jvm") version "2.2.21"
        kotlin("android") version "2.2.21"
        id("com.android.library") version "8.13.1"
        id("com.android.application") version "8.13.1"
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name="jscore"

include("jscore")
project(":jscore").projectDir = file("java/jscore")

// Include jscore-android when Java 11 is detected
val javaVersion = System.getProperty("java.version")
val javaMajorVersion = javaVersion.split(".").first().toIntOrNull() 
    ?: javaVersion.substringBefore(".").toIntOrNull() 
    ?: 0

val enableAndroidBuild = javaMajorVersion >= 11

// Store in gradle.extra for access in build.gradle.kts
gradle.extra["enableAndroidBuild"] = enableAndroidBuild

println("Java version: $javaVersion (major: $javaMajorVersion)")
println("Building with Android module: $enableAndroidBuild")

if (enableAndroidBuild) {
    include("jscore-android")
    project(":jscore-android").projectDir = file("java/jscore-android")
}

include("jscore-jvm")
project(":jscore-jvm").projectDir = file("java/jscore-jvm")

include("jscore-runner")
project(":jscore-runner").projectDir = file("java/jscore-runner")