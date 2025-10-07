# Migration Guide

This guide helps you migrate JavaScript code and integration patterns between SwiftJS and KotlinJS platforms.

## Table of Contents

- [When to Migrate](#when-to-migrate)
- [Code Pattern Migrations](#code-pattern-migrations)
- [Platform-Specific Adaptations](#platform-specific-adaptations)
- [JavaScript Code Compatibility](#javascript-code-compatibility)
- [Common Migration Challenges](#common-migration-challenges)
- [Step-by-Step Migration Process](#step-by-step-migration-process)

## When to Migrate

### From SwiftJS to KotlinJS

**Consider migration when:**
- Expanding from iOS/macOS to Android or server-side
- Need for latest V8 JavaScript features
- Complex memory management requirements
- Cross-platform team collaboration needs
- Server-side Kotlin integration required

### From KotlinJS to SwiftJS

**Consider migration when:**
- Focusing exclusively on iOS/macOS platforms
- Deep Apple ecosystem integration needed
- SwiftUI/UIKit integration required
- Minimizing dependencies and complexity
- Optimizing for Apple hardware performance

## Code Pattern Migrations

### Engine Initialization

**SwiftJS Pattern:**
```swift
import SwiftJS

let js = SwiftJS()
// Polyfills automatically included
```

**KotlinJS Equivalent:**
```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.platform.jvm.JvmPlatformContext

val platformContext = JvmPlatformContext()
val engine = JavaScriptEngine(platformContext)
// Polyfills automatically included
```

### Global Object Access

**SwiftJS Pattern:**
```swift
// Set global
js.globalObject["myData"] = ["key": "value"]

// Get global
let console = js.globalObject["console"]
```

**KotlinJS Equivalent:**
```kotlin
val bridge = engine.jsBridge

// Set global
bridge.setGlobal("myData", mapOf("key" to "value"))

// Get global
val console = bridge.getGlobal("console")
```

### Function Creation and Binding

**SwiftJS Pattern:**
```swift
let swiftFunction = SwiftJS.Value(newFunctionIn: js.base) { args, this in
    let input = args.first?.toString() ?? ""
    return "Processed: \(input)"
}

js.globalObject["processData"] = swiftFunction
```

**KotlinJS Equivalent:**
```kotlin
bridge.setGlobal("processData") { args ->
    val input = args.firstOrNull()?.toString() ?: ""
    "Processed: $input"
}
```

### Object Creation

**SwiftJS Pattern:**
```swift
let userObject = SwiftJS.Value(object: [
    "name": "Alice",
    "age": 30,
    "preferences": ["theme": "dark"]
], in: js.base)

js.globalObject["user"] = userObject
```

**KotlinJS Equivalent:**
```kotlin
val userObject = bridge.createObject {
    "name" to "Alice"
    "age" to 30
    "preferences" to mapOf("theme" to "dark")
}

bridge.setGlobal("user", userObject)
```

### Method Invocation

**SwiftJS Pattern:**
```swift
// CRITICAL: Use invokeMethod to preserve 'this' context
let result = object.invokeMethod("methodName", withArguments: [arg1, arg2])
```

**KotlinJS Equivalent:**
```kotlin
// JavaScript methods work naturally - no special invocation needed
val result = engine.execute("object.methodName(arg1, arg2)")

// Or if you have the object in Kotlin:
val methodResult = (jsObject as Map<String, Any>)["methodName"]
// Call through JavaScript for proper 'this' binding
```

### Value Extraction

**SwiftJS Pattern:**
```swift
let result = js.evaluateScript("({name: 'Alice', age: 30})")

if let name = result["name"].stringValue {
    print("Name: \(name)")
}

if let age = result["age"].numberValue {
    print("Age: \(Int(age))")
}
```

**KotlinJS Equivalent:**
```kotlin
val result = engine.execute("({name: 'Alice', age: 30})")

when (result) {
    is Map<*, *> -> {
        val name = result["name"] as? String
        val age = result["age"] as? Number
        
        println("Name: $name")
        println("Age: ${age?.toInt()}")
    }
}
```

### Complex API Objects

**SwiftJS Pattern:**
```swift
@objc protocol JSMyAPIExport: JSExport {
    func processData(_ data: String) -> String
    static var version: String { get }
}

@objc final class JSMyAPI: NSObject, JSMyAPIExport {
    func processData(_ data: String) -> String {
        return "Processed: \(data)"
    }
    
    static var version: String { return "1.0.0" }
}

js.globalObject["MyAPI"] = JSMyAPI()
```

**KotlinJS Equivalent:**
```kotlin
val myAPI = bridge.createObject {
    "processData".func1 { data ->
        "Processed: ${data}"
    }
    
    "version" to "1.0.0"
    
    "getInfo".func0 {
        mapOf(
            "name" to "MyAPI",
            "version" to "1.0.0"
        )
    }
}

bridge.setGlobal("MyAPI", myAPI)
```

## Platform-Specific Adaptations

### Threading Patterns

**SwiftJS Threading:**
```swift
// Main thread recommended
DispatchQueue.main.async {
    let result = js.evaluateScript("Math.sqrt(16)")
}

// Background work with main thread callback
DispatchQueue.global().async {
    let data = performBackgroundWork()
    
    DispatchQueue.main.async {
        js.globalObject["backgroundData"] = data
        js.evaluateScript("processBackgroundData(backgroundData)")
    }
}
```

**KotlinJS Threading:**
```kotlin
// Direct execution (already on JS thread)
val result = engine.execute("Math.sqrt(16)")

// Background work with JS thread callback
Thread {
    val data = performBackgroundWork()
    
    engine.executeOnJSThreadAsync {
        bridge.setGlobal("backgroundData", data)
        engine.execute("processBackgroundData(backgroundData)")
    }
}.start()
```

### Resource Management

**SwiftJS Resource Management:**
```swift
class MyService {
    private let js = SwiftJS()
    
    // Automatic cleanup when deallocated
    deinit {
        // Cleanup happens automatically
    }
}
```

**KotlinJS Resource Management:**
```kotlin
class MyService : AutoCloseable {
    private val engine = JavaScriptEngine(platformContext)
    
    override fun close() {
        engine.close()
    }
}

// Usage
MyService().use { service ->
    // Automatic cleanup when block exits
}
```

### Error Handling

**SwiftJS Error Handling:**
```swift
js.base.exceptionHandler = { context, exception in
    if let error = exception?.toString() {
        print("JavaScript Error: \(error)")
    }
}

let result = js.evaluateScript("throw new Error('Test error')")
if !js.exception.isUndefined {
    print("Exception occurred: \(js.exception.toString())")
}
```

**KotlinJS Error Handling:**
```kotlin
try {
    val result = engine.execute("throw new Error('Test error')")
} catch (e: JavetExecutionException) {
    println("JavaScript Error: ${e.message}")
    println("Line: ${e.lineNumber}, Column: ${e.columnNumber}")
}
```

## JavaScript Code Compatibility

### Shared APIs

Both platforms support the same JavaScript APIs through shared polyfills:

```javascript
// ✅ Works identically on both platforms
const uuid = crypto.randomUUID();
const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode('hello'));

// ✅ Fetch API works the same
const response = await fetch('https://api.example.com/data');
const data = await response.json();

// ✅ Console and timers
console.log('Hello from JavaScript');
setTimeout(() => console.log('Timer fired'), 1000);

// ✅ File system operations
const content = await FileSystem.readFile('/path/to/file.txt');
await FileSystem.writeFile('/path/to/output.txt', 'data');
```

### Platform-Specific Differences

**Minor differences to be aware of:**

```javascript
// Object property enumeration
// SwiftJS: Limited enumeration on Swift-exposed objects
// KotlinJS: Full enumeration support on all objects

const swiftObject = SwiftExposedObject;
const kotlinObject = KotlinExposedObject;

// This may return [] on SwiftJS, full list on KotlinJS
Object.keys(swiftObject);  // Limited on SwiftJS
Object.keys(kotlinObject); // Full enumeration on KotlinJS

// Solution: Access properties directly rather than enumerating
const value = swiftObject.someProperty; // Works on both
```

### Migration-Safe JavaScript Patterns

```javascript
// ✅ Platform-agnostic patterns
function createAPI() {
    return {
        process: function(data) {
            return `Processed: ${data}`;
        },
        
        version: '1.0.0',
        
        getInfo: function() {
            return {
                name: 'API',
                version: this.version
            };
        }
    };
}

// ✅ Direct property access (works on both)
const api = globalThis.MyAPI;
const result = api.process('data');

// ❌ Avoid enumeration-dependent code
// for (const key in api) { ... } // May not work on SwiftJS

// ✅ Use explicit property access instead
const methods = ['process', 'getInfo'];
methods.forEach(method => {
    if (typeof api[method] === 'function') {
        // Use the method
    }
});
```

## Common Migration Challenges

### Challenge 1: Property Enumeration

**Problem:** SwiftJS has limited property enumeration on Swift objects.

**Solution:**
```javascript
// Instead of enumeration-based discovery
// ❌ This may not work on SwiftJS
Object.keys(swiftObject).forEach(key => { ... });

// ✅ Use explicit property access
const knownProperties = ['method1', 'method2', 'property1'];
knownProperties.forEach(prop => {
    if (swiftObject[prop] !== undefined) {
        // Use the property
    }
});
```

### Challenge 2: Threading Model Differences

**Problem:** Different threading approaches between platforms.

**Solution:**
```swift
// SwiftJS: Abstract threading differences
class JavaScriptExecutor {
    private let js: SwiftJS
    
    func executeAsync(_ script: String, completion: @escaping (SwiftJS.Value) -> Void) {
        DispatchQueue.main.async {
            let result = self.js.evaluateScript(script)
            completion(result)
        }
    }
}
```

```kotlin
// KotlinJS: Similar abstraction
class JavaScriptExecutor(private val engine: JavaScriptEngine) {
    fun executeAsync(script: String, completion: (Any?) -> Unit) {
        engine.executeOnJSThreadAsync {
            val result = engine.execute(script)
            completion(result)
        }
    }
}
```

### Challenge 3: Value Type Differences

**Problem:** Different type systems and conversion patterns.

**Solution:**
```swift
// SwiftJS: Helper for consistent value extraction
extension SwiftJS.Value {
    func extractString() -> String? {
        return self.stringValue
    }
    
    func extractNumber() -> Double? {
        return self.numberValue
    }
    
    func extractObject() -> [String: Any]? {
        // Convert to dictionary
        return nil // Implementation details
    }
}
```

```kotlin
// KotlinJS: Helper for consistent value extraction
fun Any?.extractString(): String? = this as? String
fun Any?.extractNumber(): Double? = (this as? Number)?.toDouble()
fun Any?.extractObject(): Map<String, Any>? = this as? Map<String, Any>
```

## Step-by-Step Migration Process

### Phase 1: Analysis and Planning

1. **Audit existing JavaScript code** for platform-specific dependencies
2. **Identify native API usage** and plan equivalent implementations
3. **Review threading patterns** and plan for platform differences
4. **Plan resource management** strategy for target platform

### Phase 2: Core Engine Migration

1. **Update engine initialization** code
2. **Migrate global object access** patterns
3. **Convert value bridging** to target platform API
4. **Update function binding** patterns

### Phase 3: API Migration

1. **Migrate custom API objects** to target platform patterns
2. **Update method invocation** code
3. **Convert error handling** to platform conventions
4. **Test basic functionality**

### Phase 4: Threading and Performance

1. **Update threading patterns** for target platform
2. **Migrate timer and async** operations
3. **Update resource management** patterns
4. **Performance testing and optimization**

### Phase 5: Testing and Validation

1. **Create comprehensive test suite** for both platforms
2. **Validate JavaScript API compatibility**
3. **Test error handling** scenarios
4. **Performance benchmarking**

### Migration Checklist

- [ ] Engine initialization updated
- [ ] Global object access migrated
- [ ] Value bridging converted
- [ ] Function binding updated
- [ ] Method invocation patterns adapted
- [ ] Threading model updated
- [ ] Resource management implemented
- [ ] Error handling converted
- [ ] JavaScript code tested
- [ ] Performance validated

## Best Practices for Migration

1. **Start with JavaScript code** - ensure it's platform-agnostic
2. **Use abstraction layers** - hide platform differences behind common interfaces
3. **Test incrementally** - migrate and test in small chunks
4. **Keep both versions** - maintain parallel implementations during transition
5. **Document differences** - note any behavior changes from migration
6. **Plan for rollback** - maintain ability to revert if needed

## Next Steps

- **[SwiftJS Fundamentals](swiftjs/fundamentals.md)** - Understanding SwiftJS patterns
- **[KotlinJS Fundamentals](kotlinjs/fundamentals.md)** - Understanding KotlinJS patterns
- **[Architecture Comparison](architecture-comparison.md)** - Detailed platform comparison
- **[Cross-Platform Patterns](cross-platform-patterns.md)** - Shared design patterns