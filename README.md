# JSCore - Cross-Platform JavaScript Runtimes

**Execute JavaScript seamlessly from Swift and Kotlin with native performance and web standards compliance.**

SwiftJS provides JavaScript execution on iOS/macOS using Apple's JavaScriptCore, while KotlinJS delivers modern JavaScript support on JVM/Android using Javet V8.

[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Kotlin 1.9+](https://img.shields.io/badge/Kotlin-1.9+-purple.svg)](https://kotlinlang.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20Android%20|%20JVM-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Quick Start

### SwiftJS (iOS/macOS)

```swift
import SwiftJS

let js = SwiftJS()
let result = js.evaluateScript("Math.PI * 2")
print(result.numberValue) // 6.283185307179586
```

### KotlinJS (JVM/Android)

```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext

val engine = JavaScriptEngine(JvmPlatformContext("MyApp"))
val result = engine.execute("Math.PI * 2")
println(result) // 6.283185307179586
```

## Features

| Feature | SwiftJS | KotlinJS |
|---------|---------|----------|
| **Engine** | Apple JavaScriptCore | Javet V8 |
| **Performance** | Native Safari engine | Native Chrome/Node.js engine |
| **JavaScript Support** | ES6+ | ES6+ |
| **Web APIs** | Fetch, Crypto, Streams, File | Fetch, Crypto, Streams, File |
| **Async Support** | Promises, async/await | Promises, async/await |
| **Platform Integration** | iOS/macOS native APIs | JVM/Android native APIs |
| **CLI Tool** | SwiftJSRunner | jscore-runner |

## Documentation

### 🚀 Getting Started
- **[Installation](docs/getting-started/installation.md)** - Setup for both platforms
- **[SwiftJS Quick Start](docs/getting-started/quick-start-swift.md)** - iOS/macOS setup and first steps
- **[KotlinJS Quick Start](docs/getting-started/quick-start-kotlin.md)** - JVM/Android setup and first steps
- **[Examples](docs/getting-started/examples/)** - Simple code examples and demos

### 📖 Platform Guides

**SwiftJS (iOS/macOS)**
- [Fundamentals](docs/guides/swiftjs/fundamentals.md) - Core concepts, value bridging, threading model
- [JavaScript APIs](docs/guides/swiftjs/javascript-apis.md) - Available web standards APIs
- [Native Integration](docs/guides/swiftjs/native-integration.md) - Swift-JavaScript integration
- [Async Programming](docs/guides/swiftjs/async-programming.md) - Promises, timers, async patterns
- [File Operations](docs/guides/swiftjs/file-operations.md) - File system APIs
- [Networking](docs/guides/swiftjs/networking.md) - HTTP requests and streaming
- [Performance](docs/guides/swiftjs/performance.md) - Optimization and best practices

**KotlinJS (JVM/Android)**
- [Fundamentals](docs/guides/kotlinjs/fundamentals.md) - Memory management, platform contexts
- [Platform Contexts](docs/guides/kotlinjs/platform-contexts.md) - JVM vs Android differences
- [JavaScript Environment](docs/guides/kotlinjs/javascript-environment.md) - V8 capabilities
- [Native Bridges](docs/guides/kotlinjs/native-bridges.md) - Creating custom APIs
- [Resource Management](docs/guides/kotlinjs/resource-management.md) - Memory and cleanup

**Cross-Platform**
- [Architecture Comparison](docs/guides/architecture-comparison.md) - Platform differences, when to choose which
- [Migration Guide](docs/guides/migration-guide.md) - Moving code between SwiftJS and KotlinJS
- [Shared Concepts](docs/guides/cross-platform/shared-concepts.md) - Common patterns

### 📚 Reference
- **[SwiftJS API Reference](docs/reference/swiftjs-api.md)** - Complete SwiftJS API documentation
- **[KotlinJS API Reference](docs/reference/kotlinjs-api.md)** - Complete KotlinJS API documentation
- **[JavaScript Globals](docs/reference/javascript-globals.md)** - All available JavaScript APIs
- **[CLI Tools](docs/reference/cli-tools.md)** - SwiftJSRunner and jscore-runner

### 🔧 Advanced Topics
- [Performance Optimization](docs/advanced/performance-optimization.md) - Advanced performance techniques
- [Memory Management](docs/advanced/memory-management.md) - Deep dive into memory patterns
- [Threading Models](docs/advanced/threading-models.md) - Threading behavior and best practices
- [Troubleshooting](docs/advanced/troubleshooting.md) - Common issues and solutions

## Installation

## Installation

### SwiftJS - Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/o2ter/JSCore.git", from: "1.0.0")
]
```

### KotlinJS - Gradle

Add to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.o2ter.jscore:jscore:1.0.0")
    implementation("com.o2ter.jscore:jscore-jvm:1.0.0")     // For JVM
    implementation("com.o2ter.jscore:jscore-android:1.0.0") // For Android
}
```

## Command Line Tools

### SwiftJSRunner
```bash
# Execute JavaScript files
swift run SwiftJSRunner script.js

# Evaluate expressions
swift run SwiftJSRunner -e "console.log('Hello World')"
```

### jscore-runner
```bash
# Execute JavaScript files
./gradlew :jscore-runner:run --args="script.js"

# Evaluate expressions  
./gradlew :jscore-runner:run --args="-e 'console.log(\"Hello World\")'"
```

## Platform Support

| Platform | SwiftJS | KotlinJS |
|----------|---------|----------|
| **iOS** | 17.0+ | ❌ |
| **macOS** | 14.0+ | ❌ |
| **JVM** | ❌ | Java 11+ |
| **Android** | ❌ | API 21+ |

## Contributing

We welcome contributions! See [Development Setup](docs/contributing/development-setup.md) and [Testing Guidelines](docs/contributing/testing-guidelines.md) to get started.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- **SwiftJS**: Built on Apple's [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore)
- **KotlinJS**: Powered by [Javet](https://github.com/caoccao/Javet) (V8)

---

**Get started:** Choose your platform and follow the [installation guide](docs/getting-started/installation.md)!

## Quick Start

### SwiftJS - Basic Usage

```swift
import SwiftJS

// Create a JavaScript context
let js = SwiftJS()

// Execute JavaScript code
let result = js.evaluateScript("Math.PI * 2")
print(result.numberValue) // 6.283185307179586

// Work with JavaScript objects
js.evaluateScript("const user = { name: 'Alice', age: 30 }")
let name = js.globalObject["user"]["name"]
print(name.toString()) // "Alice"
```

### KotlinJS - JVM Usage (Long-Lived Engine)

For applications, services, or any long-running program:

```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext

class MyApplication {
    private val platformContext = JvmPlatformContext("MyApp")
    private val jsEngine = JavaScriptEngine(platformContext)
    
    fun processData(input: String): Any? {
        // Reuse the same engine for multiple operations
        return jsEngine.execute("processData('$input')")
    }
    
    fun runExample() {
        // Execute JavaScript code
        val result = jsEngine.execute("1 + 2 + 3")
        println("Result: $result") // Output: 6
        
        // Access JavaScript console
        jsEngine.executeVoid("console.log('Hello from JS!')")
        
        // Use timers
        jsEngine.executeVoid("""
            setTimeout(() => {
                console.log('Timer executed!');
            }, 1000);
        """)
    }
    
    fun shutdown() {
        jsEngine.close() // Only call when application is terminating
    }
}
```

### KotlinJS - Android Usage

```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.android.AndroidPlatformContext

class MainActivity : AppCompatActivity() {
    private lateinit var jsEngine: JavaScriptEngine
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val platformContext = AndroidPlatformContext(this)
        jsEngine = JavaScriptEngine(platformContext)
        
        val result = jsEngine.execute("Math.random()")
        Log.d("JSCore", "Random number: $result")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        jsEngine.close() // Clean up when Activity is destroyed
    }
}
```

### SwiftJS - Value Bridging

SwiftJS automatically converts between Swift and JavaScript values:

```swift
let js = SwiftJS()

// Swift to JavaScript
js.globalObject["swiftArray"] = [1, 2, 3]
js.globalObject["swiftDict"] = ["key": "value"]
js.globalObject["swiftString"] = "Hello from Swift"

// JavaScript to Swift
js.evaluateScript("var jsResult = { numbers: [1, 2, 3], text: 'Hello' }")
let jsObject = js.globalObject["jsResult"]
let numbers = jsObject["numbers"] // SwiftJS.Value representing the array
let text = jsObject["text"].toString() // "Hello"
```

### SwiftJS - Native APIs

SwiftJS provides access to native platform capabilities:

```swift
let js = SwiftJS()

// Cryptography
js.evaluateScript("""
    const id = crypto.randomUUID();
    console.log('ID:', id);
""")

// File System
js.evaluateScript("""
    SystemFS.writeFile('/tmp/test.txt', 'Hello from JavaScript');
    const content = SystemFS.readFile('/tmp/test.txt');
    console.log('File content:', content);
""")

// HTTP Requests
js.evaluateScript("""
    fetch('https://api.github.com/user', {
        headers: { 'User-Agent': 'SwiftJS' }
    })
    .then(response => response.json())
    .then(data => console.log('API Response:', data))
    .catch(error => console.error('Error:', error));
""")
```

### SwiftJS - Async Operations

SwiftJS fully supports JavaScript Promises and async/await:

```swift
let js = SwiftJS()

js.evaluateScript("""
    async function fetchData() {
        try {
            const response = await fetch('https://jsonplaceholder.typicode.com/posts/1');
            const post = await response.json();
            console.log('Post title:', post.title);
            return post;
        } catch (error) {
            console.error('Fetch error:', error);
        }
    }
    
    fetchData();
""")

// Keep the run loop active for async operations
RunLoop.main.run()
```

## Command Line Tools

### SwiftJSRunner CLI

SwiftJS includes a command-line runner for executing JavaScript files:

```bash
# Execute a JavaScript file
swift run SwiftJSRunner script.js

# Execute JavaScript code directly
swift run SwiftJSRunner -e "console.log('Hello, World!')"

# Pass arguments to your script
swift run SwiftJSRunner script.js arg1 arg2
```

#### Example Script

Create `hello.js`:

```javascript
console.log('Hello from SwiftJS!');
console.log('Process ID:', process.pid);
console.log('Arguments:', process.argv);

// Use crypto
const id = crypto.randomUUID();
console.log('Random ID:', id);

// File operations
SystemFS.writeFile('/tmp/swiftjs-test.txt', `Generated at ${new Date()}`);
console.log('File written successfully');

// Async operation
setTimeout(() => {
    console.log('Timer executed after 1 second');
    process.exit(0);
}, 1000);
```

Run it:

```bash
swift run SwiftJSRunner hello.js
```

### KotlinJS - Testing and Running

```bash
# Clone and navigate to project
cd KotlinJS

# Run all tests
./gradlew test

# Run tests for specific module
./gradlew :jscore:test
./gradlew :jscore-jvm:test

# Build all modules
./gradlew build

# Test JavaScript execution
./gradlew :jscore-runner:run --args="jscore/src/test/resources/test-basic.js"
```

## Available APIs

Both SwiftJS and KotlinJS provide comprehensive JavaScript APIs:

### Core JavaScript
- **ECMAScript 2023**: Full modern JavaScript support
- **Global objects**: Object, Array, Date, Math, JSON, etc.
- **Promises**: Native Promise support with async/await
- **Error handling**: Try/catch with proper stack traces

### Web APIs
- **Crypto**: `crypto.randomUUID()`, `crypto.randomBytes()`, `crypto.getRandomValues()`
- **Console**: `console.log/warn/error/info` with proper formatting
- **Fetch**: `fetch()` for HTTP requests (core functionality, excludes browser security features)
- **TextEncoder/TextDecoder**: UTF-8 encoding/decoding
- **Timers**: `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval`
- **Event**: `Event`, `EventTarget`, `addEventListener`

### Node.js-like APIs
- **Process**: `process.pid`, `process.argv`, `process.env`, `process.exit()`
- **File System**: `SystemFS.readFile()`, `SystemFS.writeFile()`, etc.
- **Path**: `Path.join()`, `Path.dirname()`, path manipulation utilities
- **Streams**: Full Web Streams API (ReadableStream, WritableStream, TransformStream with backpressure, BYOB readers, and queuing strategies)

### Platform APIs
- **Device Info**: Hardware and system information
- **Native Crypto**: Direct access to platform crypto functions
- **HTTP Client**: Advanced networking with streaming support

### KotlinJS Platform APIs

KotlinJS provides platform-specific APIs through a private `__NATIVE_BRIDGE__` object that is passed to the polyfill and used internally to expose global APIs.

## Platform Support

### SwiftJS
- **iOS 17.0+**
- **macOS 14.0+** 
- **Mac Catalyst 17.0+**
- **Swift 6.0+**

### KotlinJS
- **JVM 11+**
- **Android API 21+**
- **Kotlin 1.9+**
- **Gradle 8.0+**

## Performance

Both engines are built for performance:

### SwiftJS Performance
- Native JavaScriptCore engine (same as Safari)
- Optimized value bridging with minimal overhead
- Streaming support for large data processing
- Efficient timer management with RunLoop integration
- Memory-safe operation with proper cleanup

### KotlinJS Performance  
- Native V8 engine via Javet (same as Node.js and Chrome)
- Unified architecture reduces abstraction overhead
- Direct Kotlin-JavaScript value bridging
- Efficient coroutine integration for async operations
- Single engine instance reduces memory footprint

See [Performance Guide](docs/Performance.md) for benchmarks and optimization tips.

## Architecture

### SwiftJS Architecture

SwiftJS follows a clean, layered architecture:

```
┌─────────────────────────────────────┐
│          JavaScript Layer           │
│     (polyfill.js + user code)      │
├─────────────────────────────────────┤
│         SwiftJS Bridge Layer        │
│    (Value conversion, API exposure) │
├─────────────────────────────────────┤
│        Native Swift Libraries       │
│   (Crypto, FileSystem, Networking)  │
├─────────────────────────────────────┤
│         JavaScriptCore Engine       │
│      (Apple's JS execution)         │
└─────────────────────────────────────┘
```

Key components:
- **Core**: JavaScript execution and value marshaling
- **Library**: Native Swift implementations of JavaScript APIs
- **Resources**: JavaScript polyfills for missing web APIs

### KotlinJS Architecture

KotlinJS uses a unified architecture with Javet V8 engine:

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   jscore-runner │  │ jscore-android  │  │   jscore-jvm    │
│   (Executable)  │  │(Platform Context)│  │(Platform Context)│
└─────────┬───────┘  └─────────┬───────┘  └─────────┬───────┘
          │                    │                    │
          └──────────────────┐ │ ┌──────────────────┘
                             │ │ │
                    ┌────────▼─▼─▼───────┐
                    │      jscore        │
                    │  Unified Javet V8  │
                    │   Engine + Core    │
                    └────────────────────┘
```

#### KotlinJS Modules

- **`jscore`**: Core module with unified Javet V8 JavaScript engine
- **`jscore-android`**: Android-specific platform context implementations
- **`jscore-jvm`**: JVM-specific platform context implementations  
- **`jscore-runner`**: Executable demo and testing application

## Testing

### SwiftJS Testing

Run the comprehensive test suite:

```bash
# Run all tests
swift test

# Run specific test categories
swift test --filter "CryptoTests"
swift test --filter "PerformanceTests"
swift test --filter "ThreadingTests"

# Run with the test runner
swift run SwiftJSTests
```

The test suite includes:
- **Core functionality**: JavaScript execution and value bridging
- **Web APIs**: Fetch, Crypto, Streams, File operations
- **Performance tests**: Benchmarks and optimization verification
- **Threading tests**: Timer operations from various JavaScript contexts
- **Integration tests**: End-to-end scenarios with networking and file system

### KotlinJS Testing

The project uses a focused testing approach:

```bash
# All platform tests
./gradlew test

# Specific module tests
./gradlew :jscore-jvm:test  # JVM platform tests

# With clean build
./gradlew clean build test
```

- **Platform-Specific Tests**: Each platform context (JVM, Android) contains comprehensive tests
- **Unified Engine**: Single Javet V8 engine implementation tested across all platforms
- **JavaScript Execution Tests**: Validate modern ES6+ JavaScript execution capabilities
- **Integration Tests**: Test JavaScript execution and platform integration

**Key Test Files:**
- `test-basic.js`: Basic JavaScript execution, variables, and functions
- `test-timers.js`: Timer functionality (setTimeout, setInterval, clearInterval)
- `test-console.js`: Console logging and output verification

## Documentation

- **[JavaScript Environment Analysis](docs/JavaScriptEnvironment.md)**: Detailed analysis of native Javet V8 environment and available APIs (KotlinJS)
- **[SwiftJS API Reference](docs/API.md)**: Complete SwiftJS JavaScript API documentation
- **[Performance Guide](docs/Performance.md)**: Benchmarks and optimization tips for both engines
- **[SwiftJSRunner Guide](docs/SwiftJSRunner.md)**: CLI usage and examples

## Contributing

### Contributing to SwiftJS

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

#### Development Guidelines for SwiftJS

- Follow Swift API design guidelines
- Prioritize web standards over Node.js-specific behaviors
- Include comprehensive tests for new features
- Update documentation for API changes
- Ensure compatibility across all supported platforms

### Contributing to KotlinJS

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./gradlew test`
5. Verify functionality: `./gradlew :jscore-runner:run --args="jscore/src/test/resources/test-basic.js"`
6. Submit a pull request

#### Development Guidelines for KotlinJS

- Follow Kotlin coding conventions
- Maintain cross-platform compatibility (JVM and Android)
- Use platform abstraction through PlatformContext interfaces
- Include tests for both JVM and Android contexts
- Document new platform APIs and bridge patterns

## License

Both SwiftJS and KotlinJS are released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

### SwiftJS
- Built on Apple's [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore)
- Crypto operations powered by [Swift Crypto](https://github.com/apple/swift-crypto)
- Networking with [Swift NIO](https://github.com/apple/swift-nio)
- HTTP client using [Async HTTP Client](https://github.com/swift-server/async-http-client)

### KotlinJS  
- JavaScript engine powered by [Javet](https://github.com/caoccao/Javet) (V8)
- Cross-platform Kotlin development
- Modern ES6+ JavaScript execution

---

**SwiftJS & KotlinJS** - Bringing the power of JavaScript to Swift and Kotlin applications with native performance and cross-platform compatibility.
