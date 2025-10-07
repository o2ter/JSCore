# Architecture Comparison

This guide compares the architectural approaches, capabilities, and design philosophies of SwiftJS and KotlinJS.

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [JavaScript Engine Comparison](#javascript-engine-comparison)
- [Value Bridging Systems](#value-bridging-systems)
- [Threading Models](#threading-models)
- [Memory Management](#memory-management)
- [Platform Integration](#platform-integration)
- [Performance Characteristics](#performance-characteristics)
- [When to Choose Which](#when-to-choose-which)

## High-Level Architecture

Both SwiftJS and KotlinJS follow similar architectural patterns while adapting to their respective platform ecosystems:

### SwiftJS Architecture

```
┌─────────────────────────────────────┐
│       Swift Application Layer       │
├─────────────────────────────────────┤
│    SwiftJS Context & Value Bridge   │
├─────────────────────────────────────┤
│      Native Swift Libraries         │
│  (Foundation, Network, CryptoKit)   │
├─────────────────────────────────────┤
│      Apple JavaScriptCore           │
│     (Same engine as Safari)         │
├─────────────────────────────────────┤
│         iOS/macOS Platform          │
└─────────────────────────────────────┘
```

### KotlinJS Architecture

```
┌─────────────────────────────────────┐
│    Kotlin Application Layer         │
├─────────────────────────────────────┤
│   JSBridge & Value Marshaling       │
├─────────────────────────────────────┤
│      Native Kotlin Libraries        │
│ (Platform Context Abstraction)      │
├─────────────────────────────────────┤
│        Javet V8 Engine              │
│     (Google V8 via Javet)           │
├─────────────────────────────────────┤
│      JVM/Android Platform           │
└─────────────────────────────────────┘
```

### Shared JavaScript Layer

Both platforms share the same JavaScript runtime layer:

```
┌─────────────────────────────────────┐
│         User JavaScript Code        │
├─────────────────────────────────────┤
│       Standard Web APIs             │
│  (Fetch, Crypto, Console, etc.)     │
├─────────────────────────────────────┤
│      Shared Polyfill Layer          │
│       (resources/polyfill.js)       │
├─────────────────────────────────────┤
│      Platform-Specific Bridge       │
│    (SwiftJS Context / JSBridge)     │
└─────────────────────────────────────┘
```

## JavaScript Engine Comparison

### JavaScriptCore (SwiftJS)

| Feature | Details |
|---------|---------|
| **Engine Origin** | Apple's WebKit JavaScript engine |
| **Performance** | Highly optimized for Apple hardware |
| **Memory Management** | Automatic garbage collection |
| **Integration** | Deep iOS/macOS integration |
| **Standards Compliance** | ES2020+ with Safari compatibility |
| **Threading** | Single-threaded with RunLoop integration |

**Advantages:**
- Native iOS/macOS performance
- Same engine as Safari (web compatibility)
- Excellent memory management
- Apple platform optimizations
- Integrated timer and RunLoop support

**Limitations:**
- Apple platforms only
- Limited property enumeration on Swift objects
- Requires RunLoop management for timers

### Javet V8 (KotlinJS)

| Feature | Details |
|---------|---------|
| **Engine Origin** | Google's V8 JavaScript engine via Javet |
| **Performance** | High performance across all platforms |
| **Memory Management** | V8 GC with Javet resource management |
| **Integration** | Cross-platform JVM/Android support |
| **Standards Compliance** | Latest ES2023+ features |
| **Threading** | Single V8 instance with executor threading |

**Advantages:**
- Cross-platform support (JVM, Android)
- Latest V8 features and performance
- Complete property enumeration support
- Advanced memory management controls
- Excellent internationalization (ICU)

**Limitations:**
- Additional dependency (Javet native libraries)
- More complex memory management patterns
- Platform context abstraction overhead

## Value Bridging Systems

### SwiftJS Value System

```swift
// Automatic bridging through SwiftJS.Value
let jsValue: SwiftJS.Value = "hello"        // String
let jsArray: SwiftJS.Value = [1, 2, 3]      // Array
let jsObject: SwiftJS.Value = ["key": "value"] // Object

// Method calls preserve 'this' context
let result = object.invokeMethod("method", withArguments: [arg])

// Type checking and extraction
if let stringValue = jsValue.stringValue {
    print("String: \(stringValue)")
}
```

**SwiftJS Characteristics:**
- Implicit conversion via value constructors
- Strong type safety with optional extraction
- Automatic bridging for most Swift types
- `invokeMethod` preserves JavaScript `this` context
- JSExport protocol for exposing Swift objects

### KotlinJS JSBridge System

```kotlin
// Explicit bridging through JSBridge
val bridge = engine.jsBridge
val jsObject = bridge.createObject {
    "key" to "value"
    "numbers" to listOf(1, 2, 3)
    "method".func1 { arg -> "Result: $arg" }
}

// Type-safe extraction with pattern matching
when (val result = engine.execute("...")) {
    is String -> println("String: $result")
    is Number -> println("Number: $result")
    is Map<*, *> -> println("Object: $result")
}
```

**KotlinJS Characteristics:**
- Explicit bridging via JSBridge API
- Seamless function binding with type inference
- Automatic marshaling for Kotlin collections
- Native V8 object behavior in JavaScript
- No property enumeration limitations

### Bridging Comparison

| Aspect | SwiftJS | KotlinJS |
|--------|---------|----------|
| **API Style** | Implicit via constructors | Explicit via JSBridge |
| **Type Safety** | Optional-based extraction | Pattern matching |
| **Function Binding** | JSExport protocols | Direct function binding |
| **Object Behavior** | Swift object semantics | Native JavaScript objects |
| **Property Access** | Limited enumeration | Full enumeration support |

## Threading Models

### SwiftJS Threading

```swift
// RunLoop integration for timers
let js = SwiftJS()
js.evaluateScript("setTimeout(() => console.log('Hello'), 1000)")
RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))

// Thread confinement (main thread recommended)
DispatchQueue.main.async {
    let result = js.evaluateScript("Math.sqrt(16)")
}
```

**SwiftJS Threading Characteristics:**
- JavaScript operations best performed on main thread
- RunLoop integration for timer support
- Simple threading model with iOS patterns
- Automatic cleanup when context deallocated

### KotlinJS Threading

```kotlin
// Dedicated JavaScript thread with executor
val engine = JavaScriptEngine(platformContext)

// Direct execution (on JS thread)
val result = engine.execute("Math.sqrt(16)")

// Async operations from background threads
Thread {
    val data = backgroundWork()
    engine.executeOnJSThreadAsync {
        bridge.setGlobal("data", data)
        engine.execute("processData(data)")
    }
}.start()
```

**KotlinJS Threading Characteristics:**
- Dedicated JavaScript thread via ExecutorService
- Thread confinement with automatic dispatching
- `executeOnJSThreadAsync` for background integration
- Explicit resource management with AutoCloseable

### Threading Comparison

| Aspect | SwiftJS | KotlinJS |
|--------|---------|----------|
| **Thread Model** | Main thread recommended | Dedicated JS thread |
| **Timer Integration** | RunLoop.main | Background Timer threads |
| **Async Operations** | DispatchQueue patterns | ExecutorService patterns |
| **Resource Cleanup** | Automatic | Explicit (AutoCloseable) |

## Memory Management

### SwiftJS Memory Model

```swift
// Automatic memory management
let js = SwiftJS()

// Values are automatically managed
let jsObject = js.evaluateScript("({data: 'value'})")
// jsObject can be GC'd when no longer referenced

// Avoid retain cycles with weak references
js.globalObject["callback"] = SwiftJS.Value(newFunctionIn: js.base) { [weak self] args, this in
    self?.handleCallback(args)
    return SwiftJS.Value(undefinedIn: js.base)
}
```

### KotlinJS Memory Model

```kotlin
// Explicit resource management
JavaScriptEngine(platformContext).use { engine ->
    // Automatic cleanup when block exits
}

// V8 scope for temporary objects
v8Runtime.v8Scope.use { scope ->
    val tempObject = scope.createV8ValueObject()
    // Automatically closed
}

// Weak references for long-lived callbacks
val handler = v8Values[0] as V8ValueFunction
handler.setWeak()  // V8 GC manages lifecycle
```

### Memory Management Comparison

| Aspect | SwiftJS | KotlinJS |
|--------|---------|----------|
| **Approach** | Automatic (ARC + GC) | Explicit (try-with-resource) |
| **Callback Management** | Weak references | V8 weak references |
| **Resource Cleanup** | Automatic | Manual (AutoCloseable) |
| **Large Objects** | Set to null | V8 scope patterns |

## Platform Integration

### SwiftJS Platform Features

```swift
// Native iOS/macOS integration
import Foundation
import CryptoKit

// Direct access to Apple frameworks
let data = Data("hello".utf8)
let hash = SHA256.hash(data: data)

// SwiftUI integration
struct ContentView: View {
    @StateObject private var jsContext = SwiftJS()
    
    var body: some View {
        Button("Execute JS") {
            jsContext.evaluateScript("console.log('Hello from SwiftUI')")
        }
    }
}
```

### KotlinJS Platform Features

```kotlin
// Cross-platform abstraction
interface PlatformContext {
    fun getLogger(): Logger
    fun getFileSystem(): FileSystemAccess
    fun getNetworkAccess(): NetworkAccess
}

// Android-specific implementation
class AndroidPlatformContext(private val context: Context) : PlatformContext {
    override fun getLogger() = AndroidLogger(context)
    // ...
}

// JVM-specific implementation
class JvmPlatformContext : PlatformContext {
    override fun getLogger() = JvmLogger()
    // ...
}
```

### Platform Comparison

| Aspect | SwiftJS | KotlinJS |
|--------|---------|----------|
| **Platform Support** | iOS 17+, macOS 14+ | JVM 11+, Android API 21+ |
| **Native Integration** | Direct Apple framework access | Abstracted platform context |
| **UI Integration** | SwiftUI, UIKit | Android Views, Compose |
| **Package Distribution** | Swift Package Manager | Maven/Gradle |

## Performance Characteristics

### SwiftJS Performance

- **Strengths:**
  - Native iOS/macOS optimization
  - Zero-copy value bridging for compatible types
  - Apple hardware-specific optimizations
  - Integrated memory management

- **Considerations:**
  - Property enumeration overhead on Swift objects
  - RunLoop overhead for timer operations
  - Single-threaded execution model

### KotlinJS Performance

- **Strengths:**
  - Latest V8 optimizations and features
  - Efficient cross-platform execution
  - Advanced memory management controls
  - Full JavaScript object semantics

- **Considerations:**
  - JNI overhead for Javet operations
  - Platform context abstraction cost
  - Memory management complexity

### Performance Comparison

| Metric | SwiftJS | KotlinJS |
|--------|---------|----------|
| **Startup Time** | Fast (native) | Moderate (Javet init) |
| **Execution Speed** | Platform-optimized | V8-optimized |
| **Memory Usage** | Low overhead | Moderate overhead |
| **Value Conversion** | Zero-copy (some types) | Efficient marshaling |

## When to Choose Which

### Choose SwiftJS When:

- **iOS/macOS exclusive applications**
- **Deep Apple ecosystem integration needed**
- **SwiftUI/UIKit integration required**
- **Minimal dependencies preferred**
- **Apple platform optimization critical**

### Choose KotlinJS When:

- **Cross-platform support required**
- **Android and JVM deployment needed**
- **Latest JavaScript features important**
- **Complex memory management requirements**
- **Server-side Kotlin integration**

### Decision Matrix

| Requirement | SwiftJS | KotlinJS |
|-------------|---------|----------|
| iOS/macOS only | ✅ Excellent | ❌ Unnecessary |
| Cross-platform | ❌ Not supported | ✅ Excellent |
| Native performance | ✅ Excellent | ✅ Good |
| Latest JS features | ✅ Good | ✅ Excellent |
| Simple integration | ✅ Excellent | ✅ Good |
| Complex memory needs | ✅ Good | ✅ Excellent |

## Migration Patterns

### SwiftJS to KotlinJS

```swift
// SwiftJS pattern
let js = SwiftJS()
js.globalObject["myAPI"] = createAPI()
let result = js.evaluateScript("myAPI.process(data)")
```

```kotlin
// KotlinJS equivalent
val engine = JavaScriptEngine(platformContext)
val bridge = engine.jsBridge
bridge.setGlobal("myAPI", createAPI(bridge))
val result = engine.execute("myAPI.process(data)")
```

### Common Migration Steps

1. **Replace context creation**: `SwiftJS()` → `JavaScriptEngine(platformContext)`
2. **Update value bridging**: Direct assignment → JSBridge API
3. **Modify function binding**: JSExport → JSBridge function creation
4. **Adapt threading**: Main thread → ExecutorService patterns
5. **Update memory management**: Automatic → explicit patterns

## Best Practices for Both Platforms

1. **Keep JavaScript code platform-agnostic** - use shared polyfill layer
2. **Abstract platform differences** - use consistent API patterns
3. **Handle errors consistently** - similar exception handling patterns
4. **Optimize for your platform** - leverage platform-specific strengths
5. **Plan for migration** - design APIs that work across both platforms

## Next Steps

- **[SwiftJS Fundamentals](swiftjs/fundamentals.md)** - Deep dive into SwiftJS
- **[KotlinJS Fundamentals](kotlinjs/fundamentals.md)** - Deep dive into KotlinJS
- **[Cross-Platform Patterns](cross-platform-patterns.md)** - Shared design patterns
- **[Migration Guide](migration-guide.md)** - Moving between platforms