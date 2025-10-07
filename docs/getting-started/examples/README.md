# Examples

This directory contains practical examples for both SwiftJS and KotlinJS platforms.

## SwiftJS Examples

### [Hello World](swift-hello-world.md)
Basic JavaScript execution and console output.

### [File Operations](swift-file-operations.md)
Reading, writing, and manipulating files from JavaScript.

### [HTTP Requests](swift-http-requests.md)
Making HTTP requests with fetch API and handling responses.

### [Calculator](swift-calculator.md)
Building a JavaScript-powered calculator with error handling.

### [Data Processing](swift-data-processing.md)
Processing JSON data and working with arrays and objects.

## KotlinJS Examples

### [Hello World](kotlin-hello-world.md)
Basic JavaScript execution and console output.

### [JSBridge API](kotlin-jsbridge-api.md)
Creating native APIs accessible from JavaScript.

### [Configuration Manager](kotlin-config-manager.md)
JavaScript-powered configuration validation and processing.

### [Data Processor](kotlin-data-processor.md)
Processing data with JavaScript functions from Kotlin.

### [Android Integration](kotlin-android-integration.md)
Using KotlinJS in Android applications.

## Cross-Platform Examples

### [Crypto Operations](crypto-operations.md)
Cryptographic functions that work on both platforms.

### [Timer Management](timer-management.md)
Working with timers and async operations.

### [Error Handling](error-handling.md)
Best practices for handling errors in JavaScript and native code.

## Running Examples

### SwiftJS
```bash
# Clone the repository
git clone https://github.com/o2ter/JSCore.git
cd JSCore

# Run examples with SwiftJSRunner
swift run SwiftJSRunner docs/getting-started/examples/[example-file].js
```

### KotlinJS
```bash
# Clone the repository
git clone https://github.com/o2ter/JSCore.git
cd JSCore

# Build the project
./gradlew build

# Run examples with jscore-runner
./gradlew :java:jscore-runner:run --args="docs/getting-started/examples/[example-file].js"
```

## Example Categories

| Category | SwiftJS | KotlinJS | Description |
|----------|---------|----------|-------------|
| **Basic Usage** | ✅ | ✅ | Simple JavaScript execution |
| **File I/O** | ✅ | ✅ | File system operations |
| **HTTP** | ✅ | ✅ | Network requests and responses |
| **Native APIs** | ✅ | ✅ | Platform-specific functionality |
| **Error Handling** | ✅ | ✅ | Exception and error management |
| **Async Operations** | ✅ | ✅ | Timers, promises, async/await |
| **Data Processing** | ✅ | ✅ | JSON, arrays, objects |
| **Mobile Integration** | ✅ iOS/macOS | ✅ Android | Platform-specific features |

## Contributing Examples

When adding new examples:

1. **Keep them simple** - Focus on one concept per example
2. **Include both platforms** - Provide SwiftJS and KotlinJS versions when applicable
3. **Add clear comments** - Explain what each part does
4. **Test thoroughly** - Ensure examples work as documented
5. **Follow naming conventions** - Use descriptive filenames
6. **Include error handling** - Show proper error management

## Example Template

### JavaScript File Template
```javascript
// Example: [Description]
// Platform: Both SwiftJS and KotlinJS
// Purpose: [What this example demonstrates]

console.log('Starting [example name]...');

try {
    // Main example code here
    
    console.log('Example completed successfully');
} catch (error) {
    console.error('Example failed:', error.message);
    process.exit(1);
}
```

### SwiftJS Integration Template
```swift
import SwiftJS

func runExample() {
    let js = SwiftJS()
    
    // Set up any native data or APIs
    
    let result = js.evaluateScript("""
        // JavaScript code here
    """)
    
    print("Result: \(result)")
}
```

### KotlinJS Integration Template
```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext

fun runExample() {
    val platformContext = JvmPlatformContext("ExampleApp")
    JavaScriptEngine(platformContext).use { engine ->
        // Set up any native APIs with JSBridge
        
        val result = engine.execute("""
            // JavaScript code here
        """)
        
        println("Result: $result")
    }
}
```