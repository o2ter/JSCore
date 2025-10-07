# SwiftJS Fundamentals

This guide covers the core concepts, architecture, and essential patterns for working with SwiftJS.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [JavaScript Context Management](#javascript-context-management)
- [Value Bridging System](#value-bridging-system)
- [Method Invocation Patterns](#method-invocation-patterns)
- [Threading Model](#threading-model)
- [Memory Management](#memory-management)
- [Error Handling](#error-handling)

## Architecture Overview

SwiftJS follows a clean, layered architecture that bridges Swift and JavaScript seamlessly:

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

### Key Components

1. **JavaScriptCore Engine**: Apple's optimized JavaScript runtime (same as Safari)
2. **SwiftJS Bridge**: Value conversion and API exposure layer
3. **Native Libraries**: Swift implementations of web standards (Crypto, FileSystem, etc.)
4. **JavaScript Polyfills**: Web API implementations in JavaScript

## JavaScript Context Management

### Creating Contexts

```swift
import SwiftJS

// Basic context creation (includes polyfills automatically)
let js = SwiftJS()

// Custom virtual machine with specific RunLoop
let customRunLoop = RunLoop.current
let vm = VirtualMachine(runloop: customRunLoop)
let jsWithCustomVM = SwiftJS(vm)
```

### Context Lifecycle

```swift
class MyJavaScriptService {
    private let js: SwiftJS
    
    init() {
        // Context is created once and reused
        self.js = SwiftJS()
        setupJavaScriptEnvironment()
    }
    
    private func setupJavaScriptEnvironment() {
        // Set up any global objects or functions
        js.globalObject["myAPI"] = createMyAPI()
    }
    
    func executeScript(_ script: String) -> SwiftJS.Value {
        return js.evaluateScript(script)
    }
    
    // Context automatically cleaned up when instance is deallocated
}
```

### Global Object Access

```swift
let js = SwiftJS()

// Access the global object
let global = js.globalObject

// Set global variables
global["myData"] = ["key": "value"]
global["myFunction"] = SwiftJS.Value(newFunctionIn: js.base) { args, this in
    return "Called with \(args.count) arguments"
}

// Get global variables
let console = global["console"]
let Math = global["Math"]
```

## Value Bridging System

SwiftJS provides automatic conversion between Swift and JavaScript values:

### Automatic Type Conversion

| Swift Type | JavaScript Type | Conversion |
|------------|-----------------|------------|
| `String` | `string` | Automatic |
| `Int`, `Double` | `number` | Automatic |
| `Bool` | `boolean` | Automatic |
| `[Any]` | `Array` | Automatic |
| `[String: Any]` | `Object` | Automatic |
| `nil` | `null` | Automatic |
| `NSNull()` | `null` | Explicit |

### Value Creation Patterns

```swift
let js = SwiftJS()

// Creating JavaScript values from Swift
let jsString = SwiftJS.Value(string: "Hello", in: js.base)
let jsNumber = SwiftJS.Value(double: 42.0, in: js.base)
let jsBool = SwiftJS.Value(bool: true, in: js.base)
let jsArray = SwiftJS.Value(object: [1, 2, 3], in: js.base)
let jsObject = SwiftJS.Value(object: ["key": "value"], in: js.base)

// Special values
let jsNull = SwiftJS.Value(nullIn: js.base)
let jsUndefined = SwiftJS.Value(undefinedIn: js.base)
```

### Value Extraction

```swift
let js = SwiftJS()
let result = js.evaluateScript("({name: 'Alice', age: 30, active: true})")

// Type checking
if result.isObject {
    print("It's an object")
}

// Value extraction with type safety
if let name = result["name"].stringValue {
    print("Name: \(name)")
}

if let age = result["age"].numberValue {
    print("Age: \(Int(age))")
}

if let active = result["active"].boolValue {
    print("Active: \(active)")
}

// Direct access (may return nil)
let directName = result["name"].toString()
```

### Complex Object Bridging

```swift
let js = SwiftJS()

// Swift data structure
struct User {
    let name: String
    let age: Int
    let preferences: [String: Any]
}

let user = User(
    name: "Alice",
    age: 30,
    preferences: ["theme": "dark", "notifications": true]
)

// Convert to JavaScript-compatible format
let userData: [String: Any] = [
    "name": user.name,
    "age": user.age,
    "preferences": user.preferences
]

js.globalObject["currentUser"] = userData

// Use in JavaScript
js.evaluateScript("""
    console.log('User:', currentUser.name);
    console.log('Theme:', currentUser.preferences.theme);
""")
```

## Method Invocation Patterns

### Critical Pattern: Use invokeMethod

**Always use `invokeMethod` for JavaScript methods to preserve `this` context:**

```swift
let js = SwiftJS()

js.evaluateScript("""
    var calculator = {
        value: 0,
        add: function(n) {
            this.value += n;
            return this;
        },
        getValue: function() {
            return this.value;
        }
    };
""")

let calculator = js.globalObject["calculator"]

// ✅ CORRECT - preserves 'this' context
calculator.invokeMethod("add", withArguments: [5])
calculator.invokeMethod("add", withArguments: [3])
let result = calculator.invokeMethod("getValue", withArguments: [])
print(result.numberValue) // 8.0

// ❌ WRONG - loses 'this' context, causes TypeError
// let addMethod = calculator["add"]
// addMethod.call(withArguments: [5]) // TypeError: Type error
```

### Function Creation and Binding

```swift
let js = SwiftJS()

// Create Swift function accessible from JavaScript
let swiftFunction = SwiftJS.Value(newFunctionIn: js.base) { args, this in
    let input = args.first?.toString() ?? ""
    return "Swift processed: \(input)"
}

js.globalObject["processInSwift"] = swiftFunction

// Use from JavaScript
let result = js.evaluateScript("processInSwift('Hello from JS')")
print(result.toString()) // "Swift processed: Hello from JS"
```

### Async Function Integration

```swift
let js = SwiftJS()

// Create async Swift function
let asyncFunction = SwiftJS.Value(newFunctionIn: js.base) { args, this in
    // Swift async code here
    Task {
        // Simulate async work
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print("Async work completed")
    }
    return SwiftJS.Value(undefinedIn: js.base)
}

js.globalObject["doAsyncWork"] = asyncFunction
```

## Threading Model

### RunLoop Integration

SwiftJS integrates with the current RunLoop for timer support:

```swift
let js = SwiftJS()

// Execute code with timers
js.evaluateScript("""
    setTimeout(() => {
        console.log('Timer executed');
    }, 1000);
""")

// Keep RunLoop active for timers
RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
```

### Thread Safety Considerations

```swift
// ✅ CORRECT - JavaScript operations on main thread
let js = SwiftJS()
js.evaluateScript("console.log('Hello')")

// ❌ WRONG - JavaScript operations from background thread
DispatchQueue.global().async {
    // This can cause issues - JavaScriptCore is not thread-safe
    js.evaluateScript("console.log('Background')")
}

// ✅ CORRECT - dispatch to main thread
DispatchQueue.global().async {
    let data = performBackgroundWork()
    
    DispatchQueue.main.async {
        js.globalObject["backgroundData"] = data
        js.evaluateScript("processBackgroundData(backgroundData)")
    }
}
```

### Timer Management

```swift
let js = SwiftJS()

// Check active timers
print("Active timers: \(js.activeTimerCount)")
print("Has active timers: \(js.hasActiveTimers)")

// Execute script with timer cleanup
js.evaluateScript("""
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
```

## Memory Management

### Automatic Memory Management

```swift
// SwiftJS handles memory automatically
let js = SwiftJS()

// JavaScript objects are garbage collected
js.evaluateScript("""
    let largeObject = new Array(1000000).fill('data');
    // Object will be GC'd when no longer referenced
    largeObject = null;
""")

// SwiftJS.Value references don't prevent GC
let jsObject = js.evaluateScript("({data: 'temporary'})")
// jsObject can be GC'd in JavaScript when no JS references remain
```

### Avoiding Retain Cycles

```swift
class MyClass {
    let js = SwiftJS()
    
    init() {
        // ❌ WRONG - creates retain cycle
        js.globalObject["callback"] = SwiftJS.Value(newFunctionIn: js.base) { args, this in
            self.handleCallback(args) // 'self' creates retain cycle
            return SwiftJS.Value(undefinedIn: js.base)
        }
        
        // ✅ CORRECT - use weak reference
        js.globalObject["callback"] = SwiftJS.Value(newFunctionIn: js.base) { [weak self] args, this in
            self?.handleCallback(args)
            return SwiftJS.Value(undefinedIn: js.base)
        }
    }
    
    func handleCallback(_ args: [SwiftJS.Value]) {
        // Handle callback
    }
}
```

### Large Data Handling

```swift
let js = SwiftJS()

// For large data, process in chunks
let largeArray = Array(1...1000000)

// ❌ Inefficient - all at once
js.globalObject["hugeArray"] = largeArray

// ✅ Efficient - process in chunks
let chunkSize = 10000
for chunk in largeArray.chunked(into: chunkSize) {
    js.globalObject["chunk"] = chunk
    js.evaluateScript("processChunk(chunk)")
}
```

## Error Handling

### JavaScript Exception Handling

```swift
let js = SwiftJS()

// Set up global exception handler
js.base.exceptionHandler = { context, exception in
    if let error = exception?.toString() {
        print("JavaScript Error: \(error)")
        
        // Get stack trace if available
        if let stack = exception?["stack"]?.toString() {
            print("Stack trace: \(stack)")
        }
    }
}

// Execute potentially problematic code
js.evaluateScript("throw new Error('Something went wrong!')")

// Check for exceptions after evaluation
js.evaluateScript("nonExistentFunction()")
if !js.exception.isUndefined {
    print("Exception: \(js.exception.toString())")
}
```

### Swift Error Integration

```swift
let js = SwiftJS()

enum JavaScriptError: Error {
    case executionFailed(String)
    case conversionFailed(String)
}

func safeEvaluate(_ script: String) throws -> SwiftJS.Value {
    let result = js.evaluateScript(script)
    
    if !js.exception.isUndefined {
        let errorMessage = js.exception.toString()
        throw JavaScriptError.executionFailed(errorMessage)
    }
    
    return result
}

// Usage
do {
    let result = try safeEvaluate("Math.sqrt(16)")
    print("Result: \(result.numberValue)")
} catch JavaScriptError.executionFailed(let message) {
    print("JavaScript execution failed: \(message)")
} catch {
    print("Other error: \(error)")
}
```

### Error Propagation Patterns

```swift
let js = SwiftJS()

// Create Swift function that can throw JavaScript errors
let throwingFunction = SwiftJS.Value(newFunctionIn: js.base) { args, this in
    guard let input = args.first?.numberValue else {
        // Create JavaScript Error object
        return SwiftJS.Value(newErrorFromMessage: "Invalid input", in: js.base)
    }
    
    if input < 0 {
        return SwiftJS.Value(newErrorFromMessage: "Negative numbers not allowed", in: js.base)
    }
    
    return SwiftJS.Value(double: sqrt(input), in: js.base)
}

js.globalObject["safeSqrt"] = throwingFunction

// Handle errors in JavaScript
js.evaluateScript("""
    try {
        const result = safeSqrt(16);
        console.log('Result:', result);
    } catch (error) {
        console.error('Error:', error.message);
    }
""")
```

## Best Practices Summary

1. **Use `invokeMethod` for JavaScript methods** to preserve `this` context
2. **Cache frequently accessed objects** to minimize conversion overhead
3. **Handle errors appropriately** with proper exception handling
4. **Avoid retain cycles** when capturing `self` in closures
5. **Use RunLoop integration** for proper timer handling
6. **Keep JavaScript operations on main thread** for thread safety
7. **Clean up resources** by setting large objects to null when done
8. **Validate inputs** before passing to JavaScript

## Next Steps

- **[JavaScript APIs](javascript-apis.md)** - Available web standards APIs
- **[Native Integration](native-integration.md)** - Advanced Swift-JavaScript integration
- **[Async Programming](async-programming.md)** - Promises, timers, and async patterns
- **[Performance Guide](performance.md)** - Optimization techniques and best practices