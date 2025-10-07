# Installation Guide

This guide covers installation and setup for both SwiftJS (iOS/macOS) and KotlinJS (JVM/Android) platforms.

## SwiftJS Installation

### Requirements

- **iOS 17.0+** or **macOS 14.0+**
- **Swift 6.0+**
- **Xcode 15.0+** (for iOS/macOS development)

### Swift Package Manager

#### Package.swift

Add SwiftJS to your `Package.swift` dependencies:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyProject",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/o2ter/JSCore.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyProject",
            dependencies: [
                .product(name: "SwiftJS", package: "JSCore")
            ]
        )
    ]
)
```

#### Xcode Project

1. **Open your Xcode project**
2. **File → Add Package Dependencies**
3. **Enter the repository URL:**
   ```
   https://github.com/o2ter/JSCore.git
   ```
4. **Select version rule:** "Up to Next Major Version" from "1.0.0"
5. **Add to target:** Select your app target
6. **Click "Add Package"**

### Verify Installation

Create a simple test file:

```swift
import SwiftJS

let js = SwiftJS()
let result = js.evaluateScript("Math.PI * 2")
print("SwiftJS result: \(result.numberValue)")
```

### SwiftJSRunner CLI

The SwiftJSRunner command-line tool is included automatically:

```bash
# Build the runner
swift build

# Test the runner
swift run SwiftJSRunner -e "console.log('SwiftJS is working!')"
```

## KotlinJS Installation

### Requirements

- **JDK 11+** (for JVM projects)
- **Android SDK API 21+** (for Android projects)
- **Kotlin 1.9+**
- **Gradle 8.0+**

### Gradle Setup

#### build.gradle.kts (JVM Project)

```kotlin
plugins {
    kotlin("jvm") version "1.9.25"
    application
}

repositories {
    mavenCentral()
    // Add when published to Maven Central
    // For now, use local or custom repository
}

dependencies {
    implementation("com.o2ter:jscore:1.0.0")
    implementation("com.o2ter:jscore-jvm:1.0.0")
    
    // Optional: For testing
    testImplementation(kotlin("test"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.8.2")
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(11))
    }
}

kotlin {
    jvmToolchain(11)
}

application {
    mainClass.set("com.yourcompany.MainKt")
}
```

#### build.gradle.kts (Android Project)

Add to your app-level `build.gradle.kts`:

```kotlin
android {
    compileSdk 34
    
    defaultConfig {
        minSdk 21
        targetSdk 34
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    
    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    implementation("com.o2ter:jscore:1.0.0")
    implementation("com.o2ter:jscore-android:1.0.0")
    
    // Standard Android dependencies
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
}
```

### Verify Installation

#### JVM Verification

Create `src/main/kotlin/Main.kt`:

```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext

fun main() {
    val platformContext = JvmPlatformContext("TestApp")
    JavaScriptEngine(platformContext).use { engine ->
        val result = engine.execute("Math.PI * 2")
        println("KotlinJS result: $result")
    }
}
```

Run with:
```bash
./gradlew run
```

#### Android Verification

Add to your `MainActivity.kt`:

```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.android.AndroidPlatformContext
import android.util.Log

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val platformContext = AndroidPlatformContext(this)
        JavaScriptEngine(platformContext).use { engine ->
            val result = engine.execute("Math.PI * 2")
            Log.d("KotlinJS", "Result: $result")
        }
    }
}
```

### jscore-runner CLI

Test the command-line runner:

```bash
# Build the project
./gradlew build

# Test the runner
./gradlew :java:jscore-runner:run --args="-e 'console.log(\"KotlinJS is working!\")'"
```

## Local Development Setup

If you're contributing to JSCore or want to use a local version:

### Swift Development

```bash
# Clone the repository
git clone https://github.com/o2ter/JSCore.git
cd JSCore

# Build SwiftJS
swift build

# Run tests
swift test

# Test the runner
swift run SwiftJSRunner -e "console.log('Development build working!')"
```

### Kotlin Development

```bash
# Clone the repository (if not already done)
git clone https://github.com/o2ter/JSCore.git
cd JSCore

# Build KotlinJS
./gradlew build

# Run tests
./gradlew test

# Test the runner
./gradlew :java:jscore-runner:run --args="-e 'console.log(\"Development build working!\")'"
```

### Local Package References

#### Swift - Local Package

In `Package.swift`, use a local path:

```swift
dependencies: [
    .package(path: "../JSCore")  // Relative path to cloned repo
]
```

#### Kotlin - Local Module

In `settings.gradle.kts`:

```kotlin
includeBuild("../JSCore/java") {
    dependencySubstitution {
        substitute(module("com.o2ter:jscore")).using(project(":jscore"))
        substitute(module("com.o2ter:jscore-jvm")).using(project(":jscore-jvm"))
        substitute(module("com.o2ter:jscore-android")).using(project(":jscore-android"))
    }
}
```

## Troubleshooting

### Swift Issues

#### Missing JavaScriptCore Framework
**Error:** "No such module 'JavaScriptCore'"

**Solution:** SwiftJS automatically imports JavaScriptCore. Ensure you're targeting iOS 17+ or macOS 14+.

#### Build Errors on Older Platforms
**Error:** "SwiftJS is only available in iOS 17.0 or newer"

**Solution:** Update your deployment target:
```swift
platforms: [
    .iOS(.v17),
    .macOS(.v14)
]
```

### Kotlin Issues

#### Missing JDK
**Error:** "Unsupported Java version"

**Solution:** Install JDK 11 or higher:
```bash
# macOS with Homebrew
brew install openjdk@11

# Ubuntu/Debian
sudo apt-get install openjdk-11-jdk
```

#### Android SDK Issues
**Error:** "Android SDK not found"

**Solution:** Set ANDROID_HOME environment variable:
```bash
export ANDROID_HOME=/path/to/android/sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

#### Gradle Version Issues
**Error:** "This version of Gradle requires Java 11"

**Solution:** Use Gradle 8.0+ or update your Java version:
```bash
./gradlew wrapper --gradle-version 8.5
```

### Common Issues

#### Network Access During Build
Some builds may require internet access to download dependencies.

**Swift:** Xcode may need to download Swift packages
**Kotlin:** Gradle will download dependencies from Maven repositories

#### Memory Issues
Large JavaScript operations may require increased memory:

**Swift:** Use Instruments to profile memory usage
**Kotlin:** Increase JVM heap size: `-Xmx2g`

## Next Steps

Once installation is complete:

- **SwiftJS:** Continue with [SwiftJS Quick Start](quick-start-swift.md)
- **KotlinJS:** Continue with [KotlinJS Quick Start](quick-start-kotlin.md)
- **Both:** Explore [Examples](examples/) for practical code samples

## Platform Capabilities Summary

| Feature | SwiftJS | KotlinJS |
|---------|---------|----------|
| **Installation** | Swift Package Manager, Xcode | Gradle, Maven |
| **Platform Support** | iOS 17+, macOS 14+ | JVM 11+, Android API 21+ |
| **CLI Tool** | SwiftJSRunner | jscore-runner |
| **Development Environment** | Xcode, VS Code | IntelliJ IDEA, Android Studio, VS Code |
| **Dependency Management** | SPM | Gradle |
| **Build System** | Swift Package Manager | Gradle |