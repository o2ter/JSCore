# KotlinJS Fundamentals

This guide covers the core concepts, architecture, and essential patterns for working with KotlinJS.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [JavaScript Engine Management](#javascript-engine-management)
- [JSBridge System](#jsbridge-system)
- [Value Marshaling](#value-marshaling)
- [Threading Model](#threading-model)
- [Memory Management](#memory-management)
- [Error Handling](#error-handling)

## Architecture Overview

KotlinJS follows a clean, layered architecture that bridges Kotlin and JavaScript seamlessly:

```
┌─────────────────────────────────────┐
│          JavaScript Layer           │
│     (polyfill.js + user code)      │
├─────────────────────────────────────┤
│         KotlinJS Bridge Layer       │
│    (JSBridge, Value conversion)     │
├─────────────────────────────────────┤
│        Native Kotlin Libraries      │
│   (Crypto, FileSystem, Networking)  │
├─────────────────────────────────────┤
│          Javet V8 Engine            │
│      (Google V8 via Javet)          │
└─────────────────────────────────────┘
```

### Key Components

1. **Javet V8 Engine**: Google's V8 JavaScript engine via Javet bindings
2. **JSBridge**: Seamless Kotlin-JavaScript value conversion and function binding
3. **Platform Context**: Abstraction layer for JVM/Android differences
4. **Native Libraries**: Kotlin implementations of web standards (Crypto, FileSystem, etc.)
5. **JavaScript Polyfills**: Web API implementations in JavaScript

## JavaScript Engine Management

### Creating Engines

```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.platform.jvm.JvmPlatformContext

// Basic engine creation (includes polyfills automatically)
val platformContext = JvmPlatformContext()
val engine = JavaScriptEngine(platformContext)

// Custom executor for threading control
val customExecutor = Executors.newSingleThreadExecutor()
val engineWithCustomExecutor = JavaScriptEngine(platformContext, customExecutor)
```

### Engine Lifecycle Patterns

#### Long-lived Pattern (Recommended for Applications)

```kotlin
class JavaScriptService {
    private val platformContext = JvmPlatformContext()
    private val engine = JavaScriptEngine(platformContext)
    
    init {
        setupJavaScriptEnvironment()
    }
    
    private fun setupJavaScriptEnvironment() {
        // Set up any global objects or functions
        val bridge = engine.jsBridge
        bridge.setGlobal("myAPI", createMyAPI())
    }
    
    fun executeScript(script: String): Any? {
        return engine.execute(script)
    }
    
    fun close() {
        engine.close()
    }
}
```

#### Short-lived Pattern (For CLI Tools)

```kotlin
fun processScript(script: String) {
    val platformContext = JvmPlatformContext()
    
    // Automatic cleanup with .use {}
    JavaScriptEngine(platformContext).use { engine ->
        engine.execute(script)
        // Engine automatically closed when block exits
    }
}
```

### Global Object Access

```kotlin
val engine = JavaScriptEngine(platformContext)
val bridge = engine.jsBridge

// Set global variables
bridge.setGlobal("myData", mapOf("key" to "value"))
bridge.setGlobal("myFunction") { args ->
    "Called with ${args.size} arguments"
}

// Get global variables
val console = bridge.getGlobal("console")
val Math = bridge.getGlobal("Math")
```

## JSBridge System

The JSBridge provides seamless value conversion and function binding between Kotlin and JavaScript.

### Basic Value Creation

```kotlin
val engine = JavaScriptEngine(platformContext)
val bridge = engine.jsBridge

// Creating JavaScript objects
val jsObject = bridge.createObject {
    "name" to "Alice"
    "age" to 30
    "active" to true
    "preferences" to mapOf(
        "theme" to "dark",
        "notifications" to true
    )
    "scores" to listOf(95, 87, 92)
}

// Set as global
bridge.setGlobal("user", jsObject)
```

### Function Binding

```kotlin
val bridge = engine.jsBridge

// Simple function
bridge.setGlobal("greet") { args ->
    val name = args.getOrNull(0)?.toString() ?: "World"
    "Hello, $name!"
}

// Typed function binding with specific parameter counts
bridge.setGlobal("add".func2 { a, b ->
    val numA = (a as? Number)?.toDouble() ?: 0.0
    val numB = (b as? Number)?.toDouble() ?: 0.0
    numA + numB
})

// Function with access to engine context
bridge.setGlobal("evaluateExpression") { args ->
    val expression = args.firstOrNull()?.toString() ?: "1 + 1"
    engine.execute(expression)
}
```

### Complex Object Bridging

```kotlin
data class User(
    val name: String,
    val age: Int,
    val preferences: Map<String, Any>
)

val user = User(
    name = "Alice",
    age = 30,
    preferences = mapOf("theme" to "dark", "notifications" to true)
)

// Convert to JavaScript-compatible object
val userBridge = bridge.createObject {
    "name" to user.name
    "age" to user.age
    "preferences" to user.preferences
    
    // Add methods
    "getDisplayName".func0 {
        "${user.name} (${user.age})"
    }
    
    "updatePreference".func2 { key, value ->
        // In real app, this would update the actual user object
        println("Updating ${key} to ${value}")
        true
    }
}

bridge.setGlobal("currentUser", userBridge)

// Use in JavaScript
engine.execute("""
    console.log('User:', currentUser.getDisplayName());
    currentUser.updatePreference('theme', 'light');
""")
```

### API Object Creation

```kotlin
// Create a complete API object
val mathAPI = bridge.createObject {
    "PI" to Math.PI
    "E" to Math.E
    
    "add".func2 { a, b ->
        val numA = (a as? Number)?.toDouble() ?: 0.0
        val numB = (b as? Number)?.toDouble() ?: 0.0
        numA + numB
    }
    
    "multiply".func2 { a, b ->
        val numA = (a as? Number)?.toDouble() ?: 0.0
        val numB = (b as? Number)?.toDouble() ?: 0.0
        numA * numB
    }
    
    "factorial".func1 { n ->
        val num = (n as? Number)?.toInt() ?: 0
        if (num <= 1) 1 else (2..num).fold(1) { acc, i -> acc * i }
    }
}

bridge.setGlobal("MathAPI", mathAPI)
```

## Value Marshaling

KotlinJS provides automatic conversion between Kotlin and JavaScript values:

### Automatic Type Conversion

| Kotlin Type | JavaScript Type | Conversion |
|-------------|-----------------|------------|
| `String` | `string` | Automatic |
| `Int`, `Double`, `Float` | `number` | Automatic |
| `Boolean` | `boolean` | Automatic |
| `List<Any>` | `Array` | Automatic |
| `Map<String, Any>` | `Object` | Automatic |
| `null` | `null` | Automatic |

### Type-Safe Value Extraction

```kotlin
val result = engine.execute("""
    ({
        name: 'Alice',
        age: 30,
        active: true,
        scores: [95, 87, 92],
        preferences: {
            theme: 'dark',
            notifications: true
        }
    })
""")

// Type-safe extraction
when (result) {
    is Map<*, *> -> {
        val name = result["name"] as? String
        val age = result["age"] as? Number
        val active = result["active"] as? Boolean
        val scores = result["scores"] as? List<*>
        val preferences = result["preferences"] as? Map<*, *>
        
        println("Name: $name, Age: $age, Active: $active")
        println("Scores: $scores")
        println("Preferences: $preferences")
    }
    else -> println("Unexpected result type: ${result?.javaClass}")
}
```

### Custom Value Marshaling

```kotlin
// Custom data class marshaling
data class Person(val name: String, val age: Int, val email: String)

fun Person.toJavaScript(bridge: JSBridge): Any {
    return bridge.createObject {
        "name" to this@toJavaScript.name
        "age" to this@toJavaScript.age
        "email" to this@toJavaScript.email
        
        "toString".func0 {
            "${this@toJavaScript.name} <${this@toJavaScript.email}>"
        }
        
        "getAgeGroup".func0 {
            when {
                this@toJavaScript.age < 18 -> "minor"
                this@toJavaScript.age < 65 -> "adult"
                else -> "senior"
            }
        }
    }
}

val person = Person("Alice", 30, "alice@example.com")
bridge.setGlobal("person", person.toJavaScript(bridge))
```

## Threading Model

### Thread Confinement

**CRITICAL:** V8Runtime must be created and used on the same thread.

```kotlin
val engine = JavaScriptEngine(platformContext)

// ✅ CORRECT - Execute on JS thread
val result = engine.execute("Math.sqrt(16)")

// ❌ WRONG - Direct V8 access from other threads will fail
Thread {
    engine.execute("console.log('This will fail')") // IllegalStateException
}.start()

// ✅ CORRECT - Use executeOnJSThreadAsync for background operations
Thread {
    val data = performBackgroundWork()
    
    engine.executeOnJSThreadAsync {
        bridge.setGlobal("backgroundData", data)
        engine.execute("processBackgroundData(backgroundData)")
    }
}.start()
```

### Async Operation Patterns

```kotlin
// Async operations that callback to JavaScript
fun performAsyncNetworkRequest(
    url: String,
    callback: (Map<String, Any>) -> Unit
) {
    Thread {
        try {
            val response = performHttpRequest(url)
            
            // Callback to JS thread
            engine.executeOnJSThreadAsync {
                callback(mapOf(
                    "success" to true,
                    "data" to response
                ))
            }
        } catch (e: Exception) {
            engine.executeOnJSThreadAsync {
                callback(mapOf(
                    "success" to false,
                    "error" to e.message
                ))
            }
        }
    }.start()
}

// Register async function
bridge.setGlobal("fetchData") { args ->
    val url = args.firstOrNull()?.toString() ?: return@setGlobal null
    val callback = args.getOrNull(1) // JavaScript function
    
    performAsyncNetworkRequest(url) { result ->
        // callback is a JavaScript function - call it on JS thread
        engine.execute("(${callback})(${JSONObject(result)})")
    }
    
    "Request started" // Return immediately
}
```

### Timer Integration

```kotlin
// Timers are automatically handled by the engine
engine.execute("""
    setTimeout(() => {
        console.log('Timer executed');
    }, 1000);
    
    let count = 0;
    const intervalId = setInterval(() => {
        count++;
        console.log('Tick:', count);
        
        if (count >= 5) {
            clearInterval(intervalId);
            console.log('Timer cleaned up');
        }
    }, 1000);
""")

// Check active timers
println("Active timers: ${engine.activeTimerCount}")
```

## Memory Management

### Javet Memory Management Patterns

#### V8 Object Lifecycle

```kotlin
// ✅ CORRECT - Try-with-resource for short-lived objects
v8Runtime.v8Scope.use { scope ->
    val tempObject = scope.createV8ValueObject()
    // Use tempObject here
    // Automatically closed when scope exits
}

// ✅ CORRECT - Weak references for long-lived callbacks
val handler = v8Values[0] as V8ValueFunction
handler.setWeak()  // V8 GC will handle lifecycle
longLivedHandlers[id] = handler
```

#### Callback Memory Management

```kotlin
// ✅ CORRECT - Long-lived callback pattern
bridge.setGlobal("registerProgressHandler") { args ->
    val handler = args.firstOrNull() as? V8ValueFunction ?: return@setGlobal false
    
    // Mark as weak reference for GC management
    handler.setWeak()
    progressHandlers[requestId] = handler
    
    // Later, call the handler from background threads
    performLongRunningOperation { progress ->
        engine.executeOnJSThreadAsync {
            if (!handler.isClosed) {
                // Safe to call - GC manages lifecycle
                handler.callVoid(null, progress)
            }
        }
    }
    
    true
}
```

### Resource Cleanup

```kotlin
class JavaScriptService : AutoCloseable {
    private val platformContext = JvmPlatformContext()
    private val engine = JavaScriptEngine(platformContext)
    
    fun processData(data: List<Map<String, Any>>) {
        // Process large datasets efficiently
        data.chunked(1000).forEach { chunk ->
            bridge.setGlobal("chunk", chunk)
            engine.execute("""
                processChunk(chunk);
                chunk = null; // Help GC
            """)
        }
    }
    
    override fun close() {
        // Clean up engine resources
        engine.close()
    }
}
```

### Large Data Handling

```kotlin
// ✅ Efficient - process in chunks
val largeDataset = (1..1_000_000).map { mapOf("id" to it, "value" to "data_$it") }

largeDataset.chunked(10_000).forEach { chunk ->
    bridge.setGlobal("chunk", chunk)
    engine.execute("""
        processChunk(chunk);
        chunk = null; // Release for GC
    """)
}

// ❌ Inefficient - all at once
// bridge.setGlobal("hugeDataset", largeDataset) // May cause memory issues
```

## Error Handling

### JavaScript Exception Handling

```kotlin
try {
    val result = engine.execute("nonExistentFunction()")
    println("Result: $result")
} catch (e: JavetExecutionException) {
    println("JavaScript Error: ${e.message}")
    
    // Get detailed error information
    val scriptSource = e.scriptSource
    val lineNumber = e.lineNumber
    val columnNumber = e.columnNumber
    
    println("Error at line $lineNumber, column $columnNumber")
    println("Script: $scriptSource")
}
```

### Kotlin Error Integration

```kotlin
enum class JavaScriptError(message: String) : Exception(message) {
    EXECUTION_FAILED("JavaScript execution failed"),
    CONVERSION_FAILED("Value conversion failed"),
    ENGINE_CLOSED("JavaScript engine is closed")
}

fun safeExecute(script: String): Result<Any?> {
    return try {
        if (engine.isClosed) {
            Result.failure(JavaScriptError.ENGINE_CLOSED)
        } else {
            val result = engine.execute(script)
            Result.success(result)
        }
    } catch (e: JavetExecutionException) {
        Result.failure(JavaScriptError.EXECUTION_FAILED)
    } catch (e: Exception) {
        Result.failure(JavaScriptError.CONVERSION_FAILED)
    }
}

// Usage
safeExecute("Math.sqrt(16)").fold(
    onSuccess = { result -> println("Result: $result") },
    onFailure = { error -> println("Error: ${error.message}") }
)
```

### Error Propagation Patterns

```kotlin
// Create function that can throw JavaScript errors
bridge.setGlobal("safeDivide") { args ->
    val a = (args.getOrNull(0) as? Number)?.toDouble()
    val b = (args.getOrNull(1) as? Number)?.toDouble()
    
    when {
        a == null || b == null -> {
            throw IllegalArgumentException("Both arguments must be numbers")
        }
        b == 0.0 -> {
            throw ArithmeticException("Division by zero")
        }
        else -> a / b
    }
}

// Handle errors in JavaScript
engine.execute("""
    try {
        const result = safeDivide(10, 2);
        console.log('Result:', result);
        
        const errorResult = safeDivide(10, 0);
    } catch (error) {
        console.error('Error:', error.message);
    }
""")
```

## Advanced Patterns

### Native Bridge Creation

```kotlin
// Create custom native bridge module
fun createFileSystemBridge(bridge: JSBridge): Any {
    return bridge.createObject {
        "readFile".func1 { path ->
            try {
                val content = File(path.toString()).readText()
                mapOf("success" to true, "content" to content)
            } catch (e: Exception) {
                mapOf("success" to false, "error" to e.message)
            }
        }
        
        "writeFile".func2 { path, content ->
            try {
                File(path.toString()).writeText(content.toString())
                mapOf("success" to true)
            } catch (e: Exception) {
                mapOf("success" to false, "error" to e.message)
            }
        }
        
        "exists".func1 { path ->
            File(path.toString()).exists()
        }
    }
}

// Register the bridge
bridge.setGlobal("FileSystem", createFileSystemBridge(bridge))
```

### Platform-Specific Features

```kotlin
// Check platform capabilities
when (platformContext) {
    is AndroidPlatformContext -> {
        // Android-specific features
        bridge.setGlobal("platform", "android")
        bridge.setGlobal("getDeviceInfo") {
            mapOf(
                "model" to Build.MODEL,
                "version" to Build.VERSION.RELEASE
            )
        }
    }
    is JvmPlatformContext -> {
        // JVM-specific features
        bridge.setGlobal("platform", "jvm")
        bridge.setGlobal("getSystemInfo") {
            mapOf(
                "os" to System.getProperty("os.name"),
                "java" to System.getProperty("java.version")
            )
        }
    }
}
```

## Best Practices Summary

1. **Use JSBridge for all value conversion** - seamless Kotlin-JavaScript interop
2. **Manage engine lifecycle properly** - long-lived for apps, short-lived for tools
3. **Respect thread confinement** - V8 operations must stay on JS thread
4. **Use weak references for callbacks** - let V8 GC manage lifecycle
5. **Handle exceptions appropriately** - wrap operations in try-catch blocks
6. **Process large data in chunks** - avoid memory exhaustion
7. **Clean up resources** - implement AutoCloseable for long-lived services
8. **Validate inputs** - check types and values before processing

## Next Steps

- **[JavaScript APIs](javascript-apis.md)** - Available web standards APIs
- **[Native Integration](native-integration.md)** - Advanced Kotlin-JavaScript integration
- **[Async Programming](async-programming.md)** - Promises, timers, and async patterns
- **[Platform Contexts](platform-contexts.md)** - JVM vs Android differences
- **[Performance Guide](performance.md)** - Optimization techniques and best practices