# SwiftJS & KotlinJS - Cross-Platform JavaScript Runtimes

## ⚠️ CRITICAL: Documentation Update Requirement
**ALWAYS UPDATE DOCUMENTATION WHEN MAKING API CHANGES**
- Any API modification requires corresponding documentation updates
- Test all documentation examples after changes
- See "Documentation Update Requirements" section for full details

## Architecture Overview

### SwiftJS Architecture
SwiftJS is a JavaScript runtime built on Apple's JavaScriptCore, providing a bridge between Swift and JavaScript with Node.js-like APIs. The architecture follows a layered approach:

- **Core Layer** (`swift/Sources/SwiftJS/core/`): JavaScript execution engine and value marshaling
- **Library Layer** (`swift/Sources/SwiftJS/lib/`): Native Swift implementations of JS APIs
- **Polyfill Layer** (`resources/polyfill.js`): Shared JavaScript polyfills for missing APIs

### KotlinJS Architecture
KotlinJS is a JavaScript runtime built on Javet (Java + V8), providing a bridge between Kotlin and JavaScript with Node.js-like APIs. The architecture follows a layered approach:

- **Core Layer** (`java/jscore/`): JavaScript execution engine and value marshaling using Javet V8
- **Library Layer** (`java/jscore/`): Native Kotlin implementations of JS APIs via JSBridge
- **Platform Layer** (`java/jscore-android/`, `java/jscore-jvm/`): Platform-specific context implementations
- **Polyfill Layer** (`resources/polyfill.js`): Shared JavaScript polyfills for missing APIs

### Unified Project Structure
The project now uses a unified structure with shared resources:

```
JSCore/
├── swift/                     # SwiftJS implementation
│   ├── Sources/SwiftJS/       # Swift source code
│   ├── Sources/SwiftJSRunner/ # Swift CLI runner
│   └── Tests/                 # Swift test suite
├── java/                      # KotlinJS implementation
│   ├── jscore/               # Core Kotlin module
│   ├── jscore-android/       # Android platform context
│   ├── jscore-jvm/           # JVM platform context
│   └── jscore-runner/        # Kotlin CLI runner
└── resources/                 # Shared JavaScript resources
    └── polyfill.js           # Common polyfills for both platforms
```

## Key Components

### SwiftJS Context Management
- `SwiftJS` struct is the main entry point - creates a JS context with automatic polyfill injection
- `VirtualMachine` wraps JSVirtualMachine with RunLoop integration for timer support
- Always use `SwiftJS()` constructor which automatically calls `polyfill()` for full API setup

### KotlinJS Context Management
- `JavaScriptEngine` class is the main entry point - creates a JS context with automatic polyfill injection
- Uses Javet V8 with ICU data support for full internationalization
- Implements `AutoCloseable` for proper resource management
- **Long-lived pattern (most apps)**: Create once, reuse throughout application lifetime
- **Short-lived pattern (CLI tools)**: Use `.use {}` block for automatic cleanup
- Example (long-lived): `val engine = JavaScriptEngine(platformContext)` then reuse
- Example (short-lived): `JavaScriptEngine(platformContext).use { engine -> /* code */ }`

### SwiftJS Value Bridging Pattern
The `SwiftJS.Value` system provides seamless Swift ↔ JavaScript value conversion:
```swift
// JavaScript values are automatically bridged
let jsValue: SwiftJS.Value = "hello"  // String literal
let jsArray: SwiftJS.Value = [1, 2, 3]  // Array literal
let jsObject: SwiftJS.Value = ["key": "value"]  // Dictionary literal
```

### KotlinJS Value Bridging Pattern
The `JSBridge` system provides seamless Kotlin ↔ JavaScript value conversion:
```kotlin
// JavaScript values are automatically bridged via JSBridge
val bridge = engine.jsBridge
val jsObject = bridge.createObject {
    "key" to "value"
    "number" to 42
    "array" to listOf(1, 2, 3)
}
```

### Native API Exposure via `__NATIVE_BRIDGE__`
Both SwiftJS and KotlinJS expose native APIs to JavaScript through an internal `__NATIVE_BRIDGE__` parameter (not a global object):

#### SwiftJS Native APIs
- `crypto`: Cryptographic functions (randomUUID, randomBytes, hashing)
- `processInfo`: Process information (PID, arguments, environment)
- `deviceInfo`: Device identification
- `FileSystem`: File operations
- `URLSession`: HTTP requests

#### KotlinJS Native APIs
- `crypto`: Cryptographic functions (randomUUID, randomBytes, hashing)
- `processInfo`: Process information (PID, arguments, environment)
- `deviceInfo`: Device identification
- `bundleInfo`: Application metadata
- `secureStorage`: Persistent key-value storage

**Important:** `__NATIVE_BRIDGE__` is passed as a private parameter to the polyfill system and is not exposed as a global object to user JavaScript code. User code should access these capabilities through the standard global APIs (`crypto`, `process`, etc.).

## Critical Patterns

### SwiftJS Method Binding and `this` Context
**CRITICAL:** When accessing JavaScript methods via subscript, the `this` context is lost, causing methods to fail:

```swift
// ❌ WRONG - loses 'this' context, causes TypeError
let method = object["methodName"]
let result = method.call(withArguments: [])  // TypeError: Type error

// ✅ CORRECT - preserves 'this' context  
let result = object.invokeMethod("methodName", withArguments: [])
```

**Why this happens:**
- JavaScript method extraction unbinds the method from its object
- Native methods like `Date.getFullYear()` require their original object as `this`
- `invokeMethod` calls the method directly on the object, preserving the binding
- This is standard JavaScript behavior, not a SwiftJS limitation

### KotlinJS JSBridge Object Creation and Value Marshaling
**CRITICAL:** Use the JSBridge API for seamless Kotlin ↔ JavaScript value conversion:

```kotlin
// ✅ CORRECT - Use JSBridge for creating JavaScript objects
val bridge = engine.jsBridge
val mathAPI = bridge.createObject {
    "PI" to Math.PI
    
    "add".func2 { a, b ->
        val numA = (a as? Number)?.toDouble() ?: 0.0
        val numB = (b as? Number)?.toDouble() ?: 0.0
        numA + numB
    }
}

// Expose to JavaScript global scope
bridge.setGlobal("MathAPI", mathAPI)
```

**Why this pattern works:**
- JSBridge handles all type conversion between Kotlin and JavaScript
- Automatic marshaling of primitives, collections, and functions
- Proper object lifecycle management within V8 context
- Type-safe function binding with automatic parameter conversion

### KotlinJS V8ValueObject Property Binding
**CRITICAL:** For native bridges that need JavaScript-writable properties, use property descriptors instead of `.set()`. See detailed explanation in "V8ValueObject Property Binding Behavior" section below.

### KotlinJS Javet V8 Engine Integration
All native objects exposed to JavaScript work through Javet's callback system:
```kotlin
// Native bridges use Javet's IJavetDirectCallable interface
val nativeBridge = v8Runtime.createV8ValueObject()
nativeBridge.bindFunction(JavetCallbackContext("consoleLog", 
    JavetCallbackType.DirectCallNoThisAndNoResult,
    IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
        val message = v8Values.joinToString(" ") { it.toString() }
        platformContext.logger.info("JSConsole", message)
    }))
```

**Important:** Unlike Swift's JavaScriptCore, Javet provides direct V8 integration:
- Functions are bound using `JavetCallbackContext` instead of JSExport protocols
- Value conversion happens through `V8Value` types and `convertV8ValueToKotlin()`
- No property enumeration limitations - V8 objects behave like standard JavaScript objects
- Timer management uses direct V8 callback execution with `__executeTimerCallback__(id)`

### **CRITICAL:** V8ValueObject Property Binding Behavior
**V8ValueObject properties created with `.set()` are read-only by default and do not sync with Kotlin object fields.**

**Problem:** When you set a property on a V8ValueObject, JavaScript can read/write to that property, but changes don't affect the underlying Kotlin object:
```kotlin
// ❌ WRONG - Creates disconnected property
val bridge = v8Runtime.createV8ValueObject()
bridge.set("httpMethod", request.httpMethod)  // Read-only property

// JavaScript can set: urlRequest.httpMethod = "POST"  
// But request.httpMethod still shows "GET" in Kotlin!
```

**Solution:** Use `Object.defineProperty()` with getter/setter to create bidirectional property binding:
```kotlin
// ✅ CORRECT - Creates synchronized property with native callback
bridge.bindFunction(JavetCallbackContext(
    "_setHttpMethod",
    JavetCallbackType.DirectCallNoThisAndNoResult,
    IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
        if (v8Values.isNotEmpty()) {
            request.httpMethod = v8Values[0].toString()
        }
    }
))

v8Runtime.globalObject.set("__tempBridge", bridge)
v8Runtime.getExecutor("""
    Object.defineProperty(__tempBridge, 'httpMethod', {
        get: function() { return '${request.httpMethod}'; },
        set: function(value) { this._setHttpMethod(value); },
        enumerable: true,
        configurable: true
    });
    delete globalThis.__tempBridge;
""").executeVoid()
```

**Why this happens:**
- V8ValueObject properties are V8-native and isolated from Kotlin object state
- `.set()` creates a V8 property that exists only in the JavaScript context
- Kotlin object fields and V8 object properties are completely separate
- Property descriptors with native callbacks provide the bridge between the two contexts

**Real-world impact:** This issue caused HTTP POST requests to be sent as GET requests because JavaScript's `urlRequest.httpMethod = "POST"` didn't update the underlying URLRequest object.

### SwiftJS JSExport Protocol Implementation
All native objects exposed to JavaScript must conform to `JSExport`:
```swift
@objc protocol JSMyAPIExport: JSExport {
    func myMethod() -> String
}

@objc final class JSMyAPI: NSObject, JSMyAPIExport {
    func myMethod() -> String { return "result" }
}
```

**Important:** Swift static properties (including computed properties with getters) are automatically exposed as JavaScript functions, not properties. This means:
- Swift `static var myProperty: String { get }` becomes JavaScript `myObject.myProperty()` (callable function)
- Swift `static func myMethod() -> String` also becomes JavaScript `myObject.myMethod()` (callable function)
- Tests should expect and call these as functions: `typeof myObject.myProperty === 'function'` and `myObject.myProperty()`

**JavaScriptCore Property Enumeration Limitation:** Swift-exposed objects cannot be enumerated using standard JavaScript methods:
- `Object.getOwnPropertyNames(swiftObject)` returns an empty array `[]`
- `for...in` loops do not iterate over Swift-exposed properties/methods
- `Object.keys(swiftObject)` returns an empty array `[]`
- However, direct property access works: `swiftObject.myMethod()` and `typeof swiftObject.myMethod === 'function'`
- Tests should verify functionality directly rather than relying on property enumeration

### **CRITICAL:** KotlinJS Javet Memory Management Patterns
**Understanding Javet's memory management is essential for preventing memory leaks and "Runtime is already closed" errors.**

Reference: [Javet Memory Management Documentation](https://www.caoccao.com/Javet/reference/resource_management/memory_management.html)

#### The Two Core Memory Management Patterns

**1. Try-with-resource (for objects you create and use immediately):**
```kotlin
// ✅ CORRECT - Direct try-with-resource for single objects
try (V8ValueObject v8ValueObject = v8Runtime.createV8ValueObject()) {
    // Do whatever you want to do with this object
    // v8ValueObject.close() is called automatically at the end of the block.
}

// Or in Kotlin with .use {}
v8Runtime.createV8ValueObject().use { v8ValueObject ->
    // Use object here
    // Automatically closed when block exits
}
```

**2. Weak Reference (for objects with undetermined lifecycle):**
```kotlin
// ✅ CORRECT - For objects with undetermined lifecycle
val handler = v8Values[0] as V8ValueFunction
handler.setWeak()  // V8 GC will handle lifecycle automatically
progressHandlers[requestId] = handler

// Later, call the handler multiple times from background threads
engine.executeOnJSThreadAsync {
    if (!handler.isClosed) {
        handler.callVoid(null, args...)
    }
}

// No manual .close() needed - V8 GC handles it
progressHandlers.remove(requestId)
```

#### V8Scope - How to Escape from try-with-resource

V8Scope is NOT for auto-closing objects - it's for **escaping objects from automatic cleanup**. From Javet docs: "Sometimes V8 objects to be returned to V8 cannot be closed, but if there is an exception thrown between V8 object creation and return, those V8 objects are not closed."

**Escapable Scope (returning objects from a function):**
```kotlin
// ✅ CORRECT - When creating objects to return from a function
fun createHandler(): V8ValueFunction {
    return v8Runtime.v8Scope.use { scope ->
        val handler = scope.createV8ValueFunction(...)
        scope.setEscapable()  // Mark scope as escapable - prevents auto-close on normal return
        handler  // Returns without auto-closing (but WILL close on exception)
    }
}
```

**Key Insight from Javet docs:** V8Scope with `setEscapable()`:
- **Prevents auto-close on normal return** - object escapes the scope
- **Still closes on exception** - prevents memory leaks when errors occur
- **Use case:** When you CREATE objects inside a scope and want to return them

**Important:** `setEscapable()` is NOT for escaping objects passed INTO the callback - those are already managed by the caller's scope. Use `setEscapable()` only when you CREATE objects inside a scope and want to return them. For callback parameters with undetermined lifecycle, use `setWeak()` instead.

#### Common Memory Management Mistakes

**❌ WRONG - Storing V8ValueFunction without setWeak():**
```kotlin
// BAD: May cause issues with lifecycle management
val handler = v8Values[0] as V8ValueFunction
handlers[id] = handler  // Handler may become invalid

// Later...
handler.callVoid(...)  // May fail if handler was closed
```

**❌ WRONG - Manual close on weak references:**
```kotlin
// BAD: Weak references are managed by V8 GC
handler.setWeak()
handlers[id] = handler
// ... use it ...
handler.close()  // Don't manually close weak refs!
```

**❌ WRONG - Not using scope for temporary objects:**
```kotlin
// BAD: Manual close management is error-prone
val typedArray = v8Runtime.createV8ValueTypedArray(...)
try {
    handler.callVoid(null, typedArray)
} finally {
    typedArray.close()  // Easy to forget, causes leaks
}

// GOOD: Use scope instead
v8Runtime.v8Scope.use { scope ->
    val typedArray = scope.createV8ValueTypedArray(...)
    handler.callVoid(null, typedArray)
}
```

#### When to Use Each Pattern

| Pattern | Use Case | Example |
|---------|----------|---------|
| **Try-with-resource** | Short-lived objects (single or multiple) | Creating V8 objects for immediate use |
| **Weak Reference (setWeak)** | Long-lived callbacks with undetermined lifecycle | Progress handlers, event listeners, timers |
| **V8Scope + setEscapable()** | Return objects from factory functions (prevent leaks on exception) | Bridge object constructors, API wrappers |

#### Key Rules

1. **Never store V8 objects from callbacks without `.setWeak()`** - They auto-close when callback returns
2. **Always use `v8Scope` for temporary objects** - Automatic cleanup prevents leaks
3. **Check `!handler.isClosed` before calling** - Weak refs may be GC'd at any time
4. **Don't manually close weak references** - Let V8 GC handle it
5. **Don't pollute globalThis for memory management** - Use proper Javet patterns instead

### SwiftJS Async/Promise Integration
Swift async functions are automatically bridged to JavaScript Promises:
```swift
// This creates a JavaScript function that returns a Promise
SwiftJS.Value(newFunctionIn: context) { args, this in
    // Swift async code here
    return someAsyncResult
}
```

### KotlinJS Threading Model

#### **CRITICAL: V8 Thread Confinement Requirement**
**V8Runtime MUST be created and used on the same thread.** This is a fundamental V8 constraint that cannot be violated.

#### ExecutorService-Based Threading Architecture
KotlinJS uses an ExecutorService to run all JavaScript operations on a dedicated thread, avoiding blocking the main thread:

```kotlin
// Default: Creates own single-threaded executor
val engine = JavaScriptEngine(platformContext)

// Custom: User provides their own executor for custom threading
val customExecutor = Executors.newSingleThreadExecutor()
val engine = JavaScriptEngine(platformContext, customExecutor)
```

#### How Threading Works

**Initialization:**
1. Constructor accepts optional `executor: ExecutorService?`
2. If null, creates `Executors.newSingleThreadExecutor()` with daemon thread
3. Submits initialization task to executor that:
   - Captures the executing thread in `jsThread` field
   - Configures ICU on that thread
   - Creates V8Runtime on that thread
   - Initializes all bridges on that thread

**Execution:**
- All JS operations go through `executeOnJSThread<T>(block: () -> T)` 
- Method checks if `Thread.currentThread() == jsThread`
  - If yes: executes directly (already on JS thread, avoid deadlock)
  - If no: submits to `jsExecutor` and waits for result
- Async operations use `executeOnJSThreadAsync(block: () -> Unit)` (fire-and-forget)

**Deadlock Prevention:**
The thread identity check is **critical** to prevent deadlock during initialization:
```kotlin
private inline fun <T> executeOnJSThread(crossinline block: () -> T): T {
    // Deadlock prevention: if already on JS thread, execute directly
    if (Thread.currentThread() == jsThread) {
        return block()
    }
    return jsExecutor.submit(Callable { block() }).get()
}
```

Without this check, calling `execute()` from within `init` would deadlock because:
1. Init runs on JS thread
2. Calls `execute()` → `executeOnJSThread()`
3. Submits task to executor and waits
4. But executor thread is blocked in init, waiting for itself ⚠️

**Native Bridge Async Callbacks:**
URLSession and other bridges that perform background work use `executeOnJSThreadAsync()`:
```kotlin
Thread {
    val response = executeRequestSync(nativeRequest)
    engine.executeOnJSThreadAsync {
        // Resolve promise on JS thread
        resolver.resolve(responseBridge)
    }
}.start()
```

#### Threading Best Practices
1. **Never access V8Runtime from non-JS threads** - always use `executeOnJSThread`
2. **Use executeOnJSThreadAsync for callbacks** - network, timers, etc.
3. **Let users provide ExecutorService** - for custom threading strategies
4. **Store thread identity, not name** - `Thread.currentThread() == jsThread` not string comparison

#### **CRITICAL:** HTTP Request Tracking (Not Thread Tracking!)
**Never track HTTP requests by thread - threads can be reused for multiple requests:**

**❌ WRONG - Tracking by thread (causes bugs with thread pools):**
```kotlin
// BAD: Thread pools reuse threads, causing incorrect lifecycle tracking
engine.registerHttpThread(Thread.currentThread())
// Later: another request on same thread causes conflict
engine.unregisterHttpThread(Thread.currentThread()) // Removes thread even if other requests are still active!
```

**✅ CORRECT - Track by unique request ID:**
```kotlin
// GOOD: Each request has unique ID, no conflicts
val requestId = "req_${nextRequestId++}"
engine.registerHttpRequest(requestId)

// Later: only this specific request is unregistered
engine.unregisterHttpRequest(requestId)
```

**Why this matters:**
- **Thread reuse**: ExecutorService and thread pools reuse threads for multiple tasks
- **Race conditions**: Request A completes and removes thread while Request B is still using that thread
- **Incorrect tracking**: System thinks no requests are active when there actually are
- **Solution**: Track each HTTP request by unique ID, not by thread reference

### SwiftJS Timer Management
Timers are managed through the `SwiftJS.Context` class and automatically cleaned up. The polyfill provides `setTimeout`/`setInterval` that work with the RunLoop.

**CRITICAL Threading Requirement:** Timer creation must happen on the JavaScript context's RunLoop thread:
```swift
// ❌ WRONG - creates timer on current thread (might be background Task)
context.timer[id] = Timer.scheduledTimer(...)

// ✅ CORRECT - ensures timer creation on JavaScript RunLoop thread
runLoop.perform {
    context.timer[id] = Timer.scheduledTimer(...)
}
```

**Why this matters:**
- JavaScript context runs in its own dedicated thread with its own RunLoop
- Network requests execute Promise callbacks in background Task contexts
- `setTimeout`/`setInterval` called from fetch callbacks must schedule timers on the correct RunLoop
- Without `runLoop.perform`, timers created from async callbacks will never execute

**CRITICAL Threading Insight - JavaScript Callback Context:**
When JavaScript callback functions (like setTimeout, setInterval callbacks) are executed by JavaScriptCore, they **always run on the JavaScript context's single thread**. This means:

```swift
// When called from JavaScript callbacks - ALREADY thread-safe:
// - setTimeout/setInterval callback functions
// - Promise then/catch/finally callbacks  
// - Event handler callbacks
// - Timer fire callbacks

// These contexts are ALREADY on JavaScriptCore thread:
self.globalObject["setTimeout"] = .init(in: self) { arguments, _ in
    // This closure runs on JavaScript thread - no runLoop.perform needed
    // Can safely access context.timer directly
    // JSContext.current() is always available and correct
}
```

**Threading Rules Summary:**
- **FROM JavaScript callbacks:** Direct access is safe (already on correct thread)
- **FROM Swift Task/async contexts:** Must use `runLoop.perform { }`
- **FROM Network completion handlers:** Must use `runLoop.perform { }`
- **Timer fire callbacks:** Always safe (scheduled on correct RunLoop)

**Code Simplification Implications:**
- Timer creation functions called from JavaScript don't need `runLoop.perform`
- Can use `JSContext.current()` safely in JavaScript callback contexts
- Only external async operations need threading protection

### KotlinJS Timer Management and Threading
Timers are managed through the `JavaScriptEngine` class and automatically cleaned up when the engine is closed:

```kotlin
// Timer setup (internal implementation)
val task = object : TimerTask() {
    override fun run() {
        try {
            v8Runtime.getExecutor("__executeTimerCallback__($id)").executeVoid()
        } catch (e: Exception) {
            platformContext.logger.error("JSCore", "Timer execution failed: ${e.message}")
        } finally {
            activeTimers.remove(id)
        }
    }
}
```

**Timer threading:**
- Timers fire on Java Timer thread (background)
- Timer callbacks execute V8 code directly (V8 is thread-safe for execution)
- No need to wrap in `executeOnJSThreadAsync` for timers
- Platform context logging is thread-safe across all implementations

### Resource Bundle Access
JavaScript resources are bundled and accessed via `Bundle.module`:
```swift
if let polyfillJs = Bundle.module.url(forResource: "polyfill", withExtension: "js"),
   let content = try? String(contentsOf: polyfillJs, encoding: .utf8) {
    self.evaluateScript(content, withSourceURL: polyfillJs)
}
```

## Module Structure & Dependencies
```
JSCore/                       # Unified cross-platform JavaScript runtime project
├── swift/                    # SwiftJS implementation (iOS/macOS)
│   ├── Sources/SwiftJS/      # Core Swift JavaScript engine
│   ├── Sources/SwiftJSRunner/# Swift CLI runner
│   └── Tests/               # Swift test suite
├── java/                     # KotlinJS implementation (JVM/Android)
│   ├── jscore/              # Core module with unified Javet V8 engine
│   │   ├── JavaScriptEngine # Unified V8-based engine for all platforms
│   │   ├── PlatformContext  # Platform abstraction interfaces
│   │   └── JSBridge         # Kotlin-JavaScript interop API
│   ├── jscore-android/      # Android-specific platform context
│   │   └── AndroidPlatformContext # Android implementations
│   ├── jscore-jvm/          # JVM-specific platform context  
│   │   └── JvmPlatformContext # JVM implementations
│   └── jscore-runner/       # CLI runner for demos and testing
└── resources/               # Shared JavaScript resources
    └── polyfill.js         # Modern Web API polyfills (shared by both platforms)
```

**CRITICAL**: Never create circular dependencies between modules. Core abstractions in `java/jscore/` must remain platform-independent, and shared resources in `resources/` should not depend on platform-specific implementations.

## Project Conventions

### Code Style and Naming
- **No underscore prefixes**: Never use underscore prefixes (like `_originalBody`) for internal fields or methods
- **Use symbols for internal APIs**: For polyfill internal fields that need cross-class access, use symbols defined in the `SYMBOLS` object
- **Use `#` for class private fields**: For true private fields within a single class, use JavaScript private field syntax with `#`
- **Example pattern**:
  ```javascript
  // ❌ WRONG - underscore prefix
  get _originalBody() { return this.#originalBody; }
  
  // ✅ CORRECT - use symbol for cross-class access
  this[SYMBOLS.requestOriginalBody] = init.body;
  
  // ✅ CORRECT - use # for true private fields
  #body = null;
  ```

### **CRITICAL:** Avoiding globalThis Pollution
**Never pollute globalThis with internal implementation details - pass objects through scope instead:**

- **❌ WRONG - Exposing internal state on globalThis:**
  ```swift
  // BAD - Internal timer callbacks exposed globally
  context.evaluateScript("""
      globalThis.__timerCallbacks__ = {};
      globalThis.__executeTimerCallback__ = function(id) { ... };
  """)
  ```

- **✅ CORRECT - Keep internal state in scope and pass objects:**
  ```swift
  // GOOD - Create objects in closure and pass them around
  let timerNamespace = context.evaluateScript("""
      (function() {
          const timerNamespace = {
              callbacks: new Map(),
              executeCallback: function(id) { ... }
          };
          return timerNamespace;
      })();
  """)
  
  // Use the object directly without exposing it globally
  timerNamespace?.invokeMethod("setCallback", withArguments: [id, callback])
  ```

- **Guidelines for globalThis usage:**
  - **Only expose user-facing APIs**: `console`, `setTimeout`, `crypto`, `process`, etc.
  - **Never expose internal state**: `__callbacks__`, `__namespace__`, `__internal__`, etc.
  - **Use private closures**: Wrap implementation details in IIFEs and return clean interfaces
  - **Pass objects through parameters**: Instead of global lookups, pass objects as function parameters
  - **Clean up references**: Store references as instance variables for proper lifecycle management

- **✅ GOOD EXAMPLE - `__NATIVE_BRIDGE__` pattern:**
  ```swift
  // CORRECT - Pass native bridge as parameter to polyfill
  self.evaluateScript(polyfillCode).call(withArguments: [nativeBridge])
  ```
  ```javascript
  // polyfill.js - __NATIVE_BRIDGE__ is private parameter, not global
  (function (__NATIVE_BRIDGE__) {
      // Use private bridge to create clean global APIs
      globalThis.crypto = {
          randomUUID: () => __NATIVE_BRIDGE__.crypto.randomUUID(),
          // ... other APIs
      };
  })
  ```

- **Timer system example (correct approach):**
  ```swift
  // Create namespace in scope, store as instance variable
  private var timerNamespace: SwiftJS.Value?
  
  // Initialize without globalThis pollution
  timerNamespace = context.evaluateScript("""
      (function() {
          return {
              callbacks: new Map(),
              setCallback: function(id, cb) { this.callbacks.set(id, cb); },
              executeCallback: function(id) {
                  const cb = this.callbacks.get(id);
                  if (cb) { this.callbacks.delete(id); cb(); }
              }
          };
      })();
  """)
  
  // Use namespace directly in timer callbacks
  timerNamespace?.invokeMethod("setCallback", withArguments: [id, callback])
  ```

- **Benefits of this approach:**
  - **Cleaner global scope**: Only user-facing APIs are exposed
  - **Better encapsulation**: Internal implementation is hidden
  - **Easier debugging**: Clear separation between public and private APIs
  - **Memory management**: Easier to clean up and prevent leaks
  - **Testing**: Simpler to test without global side effects

### Code Reuse and Dead Code
- **Refactor repeating code**: When you find the same or similar code in multiple places, extract it into a small, well-named, reusable function or utility module. Reuse reduces bugs, improves readability, and makes testing easier. Prefer composition over duplication.
- **Keep abstractions pragmatic**: Don't over-abstract. If code repeats but has meaningful differences, prefer a focused helper with clear parameters rather than a complex, one-size-fits-all abstraction.
- **Remove unused code**: Always delete dead code, unused functions, and commented-out blocks before committing. Unused code increases maintenance burden, hides real behavior, and can mask broken assumptions. If you must keep something experimental, move it to a clearly labeled experimental file or the `.temp/` area and document why it remains.
- **Verify after removal**: After deleting code, run the build and tests to ensure nothing relied on the removed code. Update documentation and examples that referenced the previous implementation.


### Web Standards Compliance
- When implementing APIs, prioritize web standards and specifications (W3C, WHATWG, ECMAScript) over Node.js-specific behaviors
- Follow MDN Web Docs for API signatures, behavior, and error handling patterns
- Implement standard web APIs (Fetch, Crypto, Streams, etc.) according to their specifications
- Only deviate from web standards when necessary for Swift/Apple platform integration
- Document any deviations from standards with clear reasoning

**IMPORTANT: No DOM-Specific APIs**
- SwiftJS is a server-side runtime and does not implement DOM-specific APIs
- Use standard `Error` objects instead of DOM-specific errors like `DOMException`
- Avoid DOM-related concepts like `window`, `document`, `HTMLElement`, etc.
- Focus on web standard APIs that work in non-DOM environments (workers, Node.js-like runtime)
- When web specs reference DOM concepts, implement the non-DOM portions or provide appropriate alternatives

### Platform and System Call Guidelines
**CRITICAL:** Always use POSIX-compliant approaches for system calls and platform-specific operations:

- **Prefer POSIX over platform-specific APIs**: Use standard POSIX functions instead of Darwin/macOS-specific calls when possible
- **Use Foundation wrappers**: `Foundation.exit()` instead of `Darwin.exit()` for better portability
- **Examples of POSIX-compliant patterns**:
  ```swift
  // ❌ WRONG - Darwin-specific
  import Darwin
  Darwin.exit(code)
  
  // ✅ CORRECT - POSIX-compliant via Foundation
  import Foundation
  Foundation.exit(code)
  ```
- **Why POSIX compliance matters**:
  - Better portability across Unix-like systems
  - More standard and widely supported APIs
  - Easier to maintain and understand for developers familiar with POSIX
  - Foundation provides appropriate abstractions over platform differences
- **When to deviate**: Only use platform-specific APIs when POSIX alternatives don't exist or when Apple-specific functionality is explicitly required
- **Document platform dependencies**: Clearly note when platform-specific code is necessary and why

### Error Handling
- JavaScript exceptions are captured via `JSContext.exceptionHandler`
- Swift functions exposed to JS should throw `SwiftJS.Value` errors for proper JS error handling
- Use `SwiftJS.Value(newErrorFromMessage:)` for creating JS-compatible errors

### Sendable Compliance
- All types are marked `@unchecked Sendable` for Swift 6 concurrency
- `JSValue` and `JSContext` are retroactively marked Sendable
- Async JavaScript functions use `@Sendable` closures

### Naming Conventions
- Native Swift APIs use `JS` prefix when exposed to JavaScript (e.g., `JSCrypto`, `JSURLSession`)
- JavaScript polyfill objects mirror Node.js/Web APIs (`process`, `crypto`, `console`)
- Swift types follow standard conventions (`SwiftJS.Value`, `SwiftJS.VirtualMachine`)

## Integration Points

### JavaScript ↔ Swift Value Marshaling
Values cross the boundary through `SwiftJS.ValueBase` enum that handles all JavaScript types. Use `toJSValue(inContext:)` for Swift→JS and direct `SwiftJS.Value` constructors for JS→Swift.

### RunLoop Integration
JavaScript timers integrate with the current RunLoop via `VirtualMachine.runloop`. Tests run `RunLoop.main.run()` to keep timers active.

### Resource Management
- JavaScript resources are copied (not processed) in Package.swift
- Swift resources use `.copy()` to preserve exact content
- Both library and test targets have separate resource bundles

## Temporary Files for Testing
- When creating temporary files to test JavaScript code, place all test scripts under `<project_root>/.temp/` to keep the workspace organized and avoid conflicts with the main codebase.
- **Important:** The `.temp/` directory is only for JavaScript test files, not Swift/Kotlin code. Swift code must be run within proper test cases in the `Tests/` directory, and Kotlin code must be run within proper test cases in the `src/test/` directories.
- **SwiftJS**: Use SwiftJSRunner to execute JavaScript test files: `swift run SwiftJSRunner <script.js>`
- SwiftJSRunner supports both file execution and eval mode: `swift run SwiftJSRunner -e "console.log('test')"`
- All SwiftJS APIs are available in SwiftJSRunner including crypto, fetch, file system, and timers
- **KotlinJS**: Use jscore-runner to execute JavaScript test files: `./gradlew :java:jscore-runner:run --args="script.js"`
- jscore-runner supports both file execution and eval mode: `./gradlew :java:jscore-runner:run --args="-e 'console.log(\"test\")'"`
- All KotlinJS APIs are available in jscore-runner including crypto, fetch, file system, and timers
- **Test Case Verification**: Always examine the actual content of test cases to ensure they're testing what they're supposed to test:
  - Read test files completely to understand test logic and assertions
  - Verify that test descriptions match what the test actually does
  - Check that assertions are testing the correct behavior and edge cases
  - Ensure mocks and test data are appropriate for the scenario being tested
  - Look for missing test cases or gaps in coverage for critical functionality
  - Validate that tests would actually fail if the implementation was broken
  - **NEVER use fallback methods to bypass test cases** - if tests are failing, fix the implementation or the tests, don't circumvent them
  - **No test shortcuts or workarounds** - all tests must pass legitimately through proper implementation

## Temporary debug code — remove before committing

**CRITICAL:** Always remove all temporary debug code and artifacts before committing or opening a pull request. This includes but is not limited to:
- ad-hoc print/log statements (e.g., `print`, `console.log`),
- temporary debug flags or switches left enabled,
- throwaway test harness scripts placed outside the proper `Tests/` directory,
- helper files placed in `.temp/` that were only intended for local debugging, and
- large commented-out blocks or shortcuts that were added solely to debug an issue.

If durable debugging helpers are necessary, extract them into clearly documented utility modules, gate them behind explicit feature flags, and add a note in the changelist documenting why they remain. Never leave transient debug code in main branches or release builds.

## AI Agent Guidelines
### Deprecated APIs
**CRITICAL:** Never use deprecated APIs or methods.
- Do not use deprecated functions, classes, or properties in new code.
- Replace deprecated usages with the current, supported API when available.
- If no replacement exists, document the reason, open an issue for a supported alternative, and add tests demonstrating the chosen approach.
- During refactors, remove or replace deprecated usages and run the test suite to ensure behavior is preserved.

### Deep Thinking and Hypothesis Before Coding
**CRITICAL:** Before writing any code, agents must:
1. **Think deeply about the problem:** Analyze requirements, constraints, and possible edge cases.
2. **Formulate hypotheses:** Predict how the code should behave, including possible failure modes and success criteria.
3. **Check existing code to verify hypotheses:** Inspect relevant source files, tests, polyfills, and documentation to confirm assumptions before implementing. Look for related utilities, existing patterns, and any previous fixes that affect your approach.
3. **List out proof steps:** Plan how to simulate or reason about the result in mind before implementation. This includes outlining the logic, expected outcomes, and how each part will be validated.
4. **Write code only after planning:** Only begin coding once the above steps are clear and the approach is well-structured.
5. **Verify by running tests or scripts:** After implementation, always validate the code using relevant tests or scripts to ensure correctness and expected behavior.

**Why this matters:**
- Prevents shallow or rushed solutions that miss critical details
- Reduces bugs and rework by catching issues in the planning phase
- Ensures code is written with clear intent and validation strategy
- Improves reliability and maintainability of the codebase

**Example workflow:**
1. Read and analyze the requirements
2. Brainstorm possible approaches and edge cases
3. Write out hypotheses and expected results
4. Plan proof steps (how to test, what to check)
5. Implement the code
6. Run tests/scripts to confirm behavior
7. Refine as needed based on results

### Implementation Verification
**CRITICAL:** Always verify implementation behavior before writing documentation or making assumptions:
- Test actual behavior in SwiftJS runtime before documenting APIs
- Run code examples to confirm they work as described
- Use SwiftJSRunner or test cases to validate functionality
- Don't rely on external documentation without verification - JavaScriptCore has unique behaviors
- Document any discrepancies between expected and actual behavior

### **CRITICAL:** Test Integrity Principle
**NEVER use fallbacks or permissive assertions to bypass test failures:**
- When tests fail, investigate and fix the root cause (broken endpoints, implementation bugs, incorrect assumptions)
- Don't add `|| acceptableStatus` conditions unless explicitly testing error scenarios
- Fallback logic in tests masks real issues and creates technical debt
- Every test assertion should validate actual functionality, not work around problems
- See "Critical Testing Patterns" section for detailed examples and anti-patterns

### **CRITICAL:** Documentation Update Requirements
**MANDATORY:** Always update documentation when making API changes:

**For JavaScript API Changes:**
- **SwiftJS**: Update `docs/API.md` with new or modified JavaScript APIs, including examples
- **KotlinJS**: Update `docs/JavaScriptEnvironment.md` with new or modified JavaScript APIs, including examples
- Update method signatures, parameter descriptions, and return values
- Add or update code examples demonstrating the API usage
- Document any breaking changes or migration requirements

**For Performance-Related Changes:**
- Update `docs/Performance.md` with new optimization patterns or pitfalls
- Add benchmarking information for significant performance improvements
- Document any performance regressions and mitigation strategies

**For SwiftJSRunner Changes:**
- Update `docs/SwiftJSRunner.md` for CLI behavior modifications
- Update command-line options, examples, and troubleshooting sections
- Document any changes to auto-termination or error handling behavior

**For JSBridge Changes (KotlinJS):**
- Update `docs/JSBridge.md` for native bridge modifications
- Update examples and API patterns for creating native bridges
- Document any changes to value marshaling or function binding

**For Core Architecture Changes:**
- Update `README.md` if core functionality, installation, or basic usage changes
- Update architectural diagrams and feature lists for major changes
- Update quick start examples if they no longer work

**For Implementation Insights:**
- Update `.github/copilot-instructions.md` with architectural discoveries
- **SwiftJS**: Document threading model insights, JavaScriptCore behaviors, or performance patterns
- **KotlinJS**: Document threading model insights, Javet behaviors, or performance patterns
- Add critical implementation details that future developers need to know

**Documentation Validation Process:**
1. **Test all code examples** in the documentation after changes
2. **SwiftJS**: Run SwiftJSRunner with documented examples to ensure they work
3. **KotlinJS**: Run jscore-runner with documented examples to ensure they work
4. **Check cross-references** between documentation files for consistency
5. **Verify API signatures** match the actual implementation
6. **Update version-specific information** if compatibility changes

**Documentation Quality Standards:**
- Include working code examples for all new APIs
- Provide both basic and advanced usage patterns
- Document error conditions and exception handling
- Explain performance implications and best practices
- Use consistent terminology across all documentation files

### JavaScriptCore Behavior Documentation
When discovering important JavaScriptCore facts or behaviors during development:
- Add detailed notes to `.github/copilot-instructions.md` under relevant sections
- Include code examples demonstrating the behavior
- Explain why the behavior occurs and its implications
- Note any workarounds or special handling required
- Mark critical behaviors with **CRITICAL:** or **Important:** tags

### Javet V8 Behavior Documentation
When discovering important Javet V8 facts or behaviors during development:
- Add detailed notes to `.github/copilot-instructions.md` under relevant sections
- Include code examples demonstrating the behavior
- Explain why the behavior occurs and its implications
- Note any workarounds or special handling required
- Mark critical behaviors with **CRITICAL:** or **Important:** tags

## **Important:** Task Execution Guidelines
When running any command or task as an AI agent:

### Command Execution Best Practices
- **Always wait** for the task to complete before proceeding with any subsequent actions
- **Never use timeouts** to run commands - it's always failure-prone and unreliable
- **Never repeat or re-run** the same command while a task is already running
- **CRITICAL: Never start a new task before the previous one has completely finished**
  - Wait for explicit confirmation that the previous task has completed successfully or failed
  - Do not assume a task is finished just because you don't see output for a while
  - Multiple concurrent tasks can cause conflicts, resource contention, and unpredictable behavior
- **Monitor task status** carefully and don't make assumptions about completion

### Test Execution Guidelines
- **Always use the provided tools** when available instead of running commands manually:
  - Use `runTests` tool for running Swift test cases instead of `swift test` command
  - Use `run_notebook_cell` tool for executing Jupyter cells instead of terminal commands
  - Use `SwiftJSRunner` via `run_in_terminal` for JavaScript file execution
- **Test-specific best practices:**
  - When running test suites, use the `runTests` tool with specific file paths to avoid unnecessarily long test runs
  - For JavaScript testing, create test files in `.temp/` directory and use `SwiftJSRunner`
  - Never run `swift test` manually when the `runTests` tool is available
  - Always wait for test completion before analyzing results or running additional tests

### Task Status Verification
- If you cannot see the output or the task appears to be still running, you are **required** to ask the user to confirm the task has completed or is stuck
- If the task is stuck or hanging, ask the user to terminate the task and try again
- **Never assume** a task has completed successfully without explicit confirmation
- Always ask the user to confirm task completion or termination if the status is unclear
- **Sequential execution is mandatory:** Do not queue or pipeline tasks - complete one fully before starting the next
- **Never try to get the terminal output using a different approach or alternative method** always wait for the result using the provided tools and instructions. Do not attempt workarounds or alternate output retrieval.

### Error Handling
- If a command fails, read the error output completely before suggesting fixes
- Don't retry failed commands without understanding and addressing the root cause
- Ask for user confirmation before attempting alternative approaches
- **Never run alternative commands while a failed task is still running or in an unknown state**

## **CRITICAL:** Common AI Agent Mistakes to Avoid

### Network Request Tracking Implementation Mistakes
**These are real mistakes made during SwiftJSRunner network tracking implementation - DO NOT REPEAT:**

1. **❌ NEVER expose internal tracking to JavaScript global objects**
   - **Mistake:** Adding `_swiftJSContext` to `__NATIVE_BRIDGE__` parameter for internal tracking
   - **Why wrong:** Pollutes internal APIs with implementation details, `__NATIVE_BRIDGE__` is for standard platform APIs only
   - **✅ Correct:** Keep all tracking purely on Swift side using instance references

2. **❌ NEVER use complex static tracking systems when simple instance references work**
   - **Mistake:** Creating `NetworkRequestTracker` class with static dictionaries and `ObjectIdentifier` keys
   - **Why wrong:** Overcomplicated, concurrency issues, unnecessary abstraction
   - **✅ Correct:** Each `JSURLSession` instance holds direct reference to its `SwiftJS.Context`

3. **❌ NEVER use static variables for per-instance state**
   - **Mistake:** Using `private static var swiftJSContext: SwiftJS.Context?` in JSURLSession
   - **Why wrong:** Multiple SwiftJS instances will interfere with each other
   - **✅ Correct:** Use instance variables: `private let swiftJSContext: SwiftJS.Context`

4. **❌ NEVER misunderstand JSExport interface requirements**
   - **Mistake:** Adding `static func shared()` to protocol when JavaScript expects instance method
   - **Why wrong:** JavaScript calls `URLSession.shared()` on the exposed instance, not class
   - **✅ Correct:** Add `func shared() -> JSURLSession { return self }` as instance method

5. **❌ NEVER use MainActor when unnecessary**
   - **Mistake:** Wrapping simple property access in `await MainActor.run { }`
   - **Why wrong:** Adds complexity and potential deadlocks for thread-safe operations
   - **✅ Correct:** Use direct access for thread-safe operations, locks where needed

### Test Quality Anti-Patterns 
**These are real mistakes made during redirect testing - DO NOT REPEAT:**

6. **❌ NEVER add fallback logic to bypass test failures**
   - **Mistake:** Adding `if status == 404 { XCTAssertTrue(true, "Accept 404 as service change") }`
   - **Why wrong:** Masks real bugs, makes tests meaningless, hides broken functionality
   - **✅ Correct:** Fix the root cause - use working endpoints, fix implementation bugs, update test data

7. **❌ NEVER accept error status codes as "normal" without investigation**
   - **Mistake:** Treating 404 responses as "external service changes" instead of broken test endpoints
   - **Why wrong:** Tests become unreliable, real issues go undetected, technical debt accumulates
   - **✅ Correct:** Investigate why tests fail, use reliable endpoints, validate actual functionality

8. **❌ NEVER use permissive assertions that always pass**
   - **Mistake:** Using `XCTAssertTrue(status == 200 || status == 404, "Accept any result")`
   - **Why wrong:** Tests provide no validation, regressions go unnoticed, false confidence in code quality
   - **✅ Correct:** Test specific expected behavior with precise assertions

### General Architecture Anti-Patterns
6. **❌ NEVER overcomplicate simple paired relationships**
   - **Mistake:** Building tracking systems for 1:1 relationships that already exist
   - **Why wrong:** Each SwiftJS instance already has its Context and JSContext paired
   - **✅ Correct:** Use existing relationships instead of creating new tracking mechanisms

7. **❌ NEVER ignore existing JavaScript API expectations**
   - **Mistake:** Changing the JavaScript interface without checking the polyfill code
   - **Why wrong:** Breaking existing JavaScript code that expects specific API patterns
   - **✅ Correct:** Always check how JavaScript polyfill uses the exposed APIs first

### Key Lessons
- **KISS Principle:** Keep implementations as simple as possible - if it feels complex, you're probably overengineering
- **Check existing patterns:** Look at how timers are tracked before inventing new tracking systems
- **Verify JavaScript contracts:** Always check `polyfill.js` to understand expected API interfaces
- **Prefer instance state:** Use instance variables over static tracking whenever possible
- **Avoid global pollution:** Never expose internal implementation details to JavaScript globals

### KotlinJS Common AI Agent Mistakes to Avoid

#### Platform Context Implementation Mistakes
**These are architectural patterns to avoid when working with KotlinJS:**

1. **❌ NEVER bypass the platform context abstraction**
   - **Mistake:** Direct platform-specific calls from `jscore/` module
   - **Why wrong:** Breaks cross-platform compatibility and module boundaries
   - **✅ Correct:** Always use `PlatformContext` interfaces for platform-specific functionality

2. **❌ NEVER create static global state for per-instance functionality**
   - **Mistake:** Using companion objects or static variables for engine state
   - **Why wrong:** Multiple `JavaScriptEngine` instances will interfere with each other
   - **✅ Correct:** Use instance variables and proper lifecycle management

3. **❌ NEVER mix Javet V8 API patterns with other JavaScript engine patterns**
   - **Mistake:** Trying to use JSExport-style patterns from JavaScriptCore
   - **Why wrong:** Javet uses different callback mechanisms and value conversion
   - **✅ Correct:** Use `IJavetDirectCallable` and `JavetCallbackContext` patterns

4. **❌ NEVER ignore ICU data requirements**
   - **Mistake:** Creating V8Runtime without proper ICU configuration
   - **Why wrong:** Internationalization features will fail silently or crash
   - **✅ Correct:** Always configure ICU data path via `PlatformContext.getIcuDataPath()`

5. **❌ NEVER create circular module dependencies**
   - **Mistake:** Having `jscore-jvm` depend on `jscore-android` or vice versa
   - **Why wrong:** Violates the clean architecture and makes builds fail
   - **✅ Correct:** Both platform modules depend only on `jscore`, never each other

#### General Architecture Anti-Patterns for KotlinJS
6. **❌ NEVER overcomplicate simple bridging patterns**
   - **Mistake:** Building complex tracking systems when `JSBridge` handles it automatically
   - **Why wrong:** JSBridge already provides seamless Kotlin-JavaScript value conversion
   - **✅ Correct:** Use `JSBridge.createObject{}` and built-in marshaling patterns

7. **❌ NEVER ignore existing polyfill contracts**
   - **Mistake:** Changing native bridge APIs without checking polyfill.js expectations
   - **Why wrong:** Breaking existing JavaScript code that expects specific API patterns
   - **✅ Correct:** Always check how polyfill.js uses the native APIs before changes

### Key Lessons

### **CRITICAL:** Streaming Implementation Principles
When implementing or modifying Blob, File, and HTTP operations, follow these principles to maintain memory-efficient streaming:

1. **NEVER call blob.arrayBuffer() in streaming contexts**
   - Always use blob.stream() and process chunks individually
   - Large files (GB+) will cause memory exhaustion otherwise

2. **File objects with filePath use Swift FileSystem streaming APIs**
   - createReadFileHandle() + readFileHandleChunk() for true disk streaming
   - Never load entire file into memory before streaming

3. **HTTP uploads use streaming body, not buffered body**
   - Pass ReadableStream directly to URLRequest
   - Avoid await body.arrayBuffer() for uploads

4. **TextDecoder streaming for text operations**
   - Use { stream: true } to handle encoding boundaries across chunks
   - Accumulate text progressively, not all-at-once

5. **Response body streaming pipes blob.stream() directly**
   - No intermediate arrayBuffer() materialization
   - Preserve memory-efficient chunk processing

**FUTURE DEVELOPERS:** If you find yourself calling .arrayBuffer() in streaming code, you're probably doing it wrong. Use .stream() and process chunks.

## Critical Testing Patterns

### **CRITICAL:** Never Use Fallbacks to Bypass Test Failures
**Always fix the root cause instead of adding fallback logic that masks real issues:**

**❌ WRONG - Adding fallbacks that hide broken functionality:**
```swift
// BAD: Accepting 404 as "okay" when testing redirects
if status == 200 {
    XCTAssertEqual(status, 200, "Should get 200 after redirect")
} else {
    // External service may have changed - accept 404 as okay
    XCTAssertTrue(status == 404, "Accept 404 as service change")
}
```

**✅ CORRECT - Fix the actual problem:**
```swift
// GOOD: Use working endpoints and expect correct behavior
let status = Int(result["finalStatus"].numberValue ?? 0)
XCTAssertEqual(status, 200, "Should get 200 after redirect")
XCTAssertTrue(result["redirected"].boolValue ?? false, "Should be marked as redirected")
```

**Why fallbacks are dangerous:**
- **Hide real bugs**: Test passes even when core functionality is broken
- **Reduce test reliability**: Tests become meaningless if they accept any result
- **Mask API changes**: External service issues get treated as "normal" instead of being investigated
- **Create technical debt**: Future developers don't know what the test actually validates
- **Prevent regression detection**: Broken features go unnoticed because tests still pass

**When encountering test failures:**
1. **Investigate the root cause** - why is the test getting unexpected results?
2. **Fix the implementation** - if there's a bug in the code, fix it
3. **Update the test data** - if external services changed, use working endpoints
4. **Improve error handling** - if it's a legitimate error case, test it properly
5. **Never add "|| acceptable_error_status"** - this always indicates a deeper problem

**Real-world example from redirect testing:**
- **Problem**: Tests failing because `/redirect/3` endpoint returns 404
- **Bad solution**: Accept 404 as "external service change" 
- **Good solution**: Use working `/redirect-to?url=...` endpoint instead
- **Result**: Tests now validate actual redirect behavior instead of masking broken endpoints

**Exception**: The only time to accept multiple status codes is when **explicitly testing error handling**:
```swift
// This is OK - we're specifically testing error scenarios
XCTAssertTrue([400, 404, 500].contains(status), "Should return client or server error")
```

### Performance Testing with `measure` Blocks
When using XCTest `measure` blocks, scripts are executed multiple times for performance measurement. This creates important constraints:

```swift
// ❌ WRONG - const/let variables cause redeclaration errors on repeated runs
let script = """
    const data = [1, 2, 3];  // SyntaxError on second run
    data
"""

// ✅ CORRECT - use var for variables that may be redeclared
let script = """
    var data = [1, 2, 3];    // Works on repeated runs
    data
"""
```

**Key Points:**
- `measure` blocks execute the same code multiple times in the same JavaScript context
- `const` and `let` declarations cannot be redeclared, causing `SyntaxError` on subsequent runs
- Always use `var` for variables in scripts that will be executed multiple times
- This applies to performance tests and any code that may run repeatedly in the same context

### **CRITICAL:** Object Literal vs Block Statement Ambiguity
**A fundamental JavaScript parsing rule that frequently causes test failures:**

```swift
// ❌ WRONG - bare object literal parsed as block statement
let script = """
    {
        original: original,
        encoded: encoded,
        decoded: decoded
    }
"""
// Returns: undefined (parsed as labeled statements in a block)

// ✅ CORRECT - parentheses force object literal parsing
let script = """
    ({
        original: original,
        encoded: encoded,
        decoded: decoded
    })
"""
// Returns: object with properties
```

**Why this happens:**
- JavaScript parser interprets `{` at start of statement as beginning of block statement
- `original:`, `encoded:`, etc. become statement labels, not object properties
- Expressions after labels are evaluated but the block returns `undefined`
- Wrapping in parentheses `({ ... })` forces expression context, creating object literal
- This is standard JavaScript behavior, not a SwiftJS limitation

**IMPORTANT - Debugging Philosophy:**
When encountering mysterious "undefined" returns or unexpected behavior in JavaScript code, always consider fundamental JavaScript parsing and evaluation rules first:
- Is the code being parsed as intended? (statement vs expression context)
- Are there implicit type conversions happening?
- Is the execution context (this binding, scope) what you expect?
- Many "SwiftJS bugs" are actually standard JavaScript behaviors that need deeper understanding

**Comparing Success vs Failure Cases:**
Understanding why some tests pass while others fail reveals the parsing issue:

```swift
// ✅ SUCCESS - Simple expressions work fine
"typeof btoa"           // Returns: "function"
"btoa('hello')"         // Returns: "aGVsbG8="
"atob('aGVsbG8=')"      // Returns: "hello"

// ❌ FAILURE - Bare object literals return undefined
"{original: 'test'}"    // Returns: undefined (block statement)

// ✅ SUCCESS - Parentheses fix the parsing
"({original: 'test'})"  // Returns: {original: 'test'} (object literal)
```

**Key insight:** The difference is not in the function implementation (btoa/atob work perfectly), but in how JavaScript parses the return value structure. Simple expressions work, but object returns need parentheses to force correct parsing context.

**Common symptoms:**
- Test assertions fail with "undefined" when expecting object properties
- `result["property"]` returns undefined even though script logic appears correct
- Functions like `btoa`/`atob` work individually but fail in object return contexts

**Testing implications:**
- Always wrap object literals in parentheses when they're the main return value
- Particularly important in test scripts that return result objects for assertion
- Use `({ ... })` pattern consistently in all test object returns

### **CRITICAL:** Test Timeout Requirements
**All asynchronous tests MUST have timeout parameters to prevent hanging:**

```swift
// ❌ WRONG - missing timeout can cause indefinite hanging
wait(for: [expectation])

// ✅ CORRECT - always include appropriate timeout
wait(for: [expectation], timeout: 10.0)
```

**Timeout Guidelines by Test Type:**
- **5 seconds**: Quick data parsing, simple operations, basic API calls
- **10 seconds**: Standard network requests, stream operations, most async tests
- **15 seconds**: Complex stream processing, error recovery, multi-step operations
- **30 seconds**: Concurrent connections, resource-intensive operations
- **60 seconds**: Large file uploads, performance-critical operations

**Why timeouts are essential:**
- JavaScript async operations can hang indefinitely due to network issues
- Tests without timeouts block the entire test suite
- Debugging becomes impossible when tests hang without feedback
- CI/CD systems may timeout at the process level, giving less useful error information

**Common timeout scenarios:**
- Network requests to unreachable endpoints
- Stream operations waiting for data that never arrives
- Timer-based operations with incorrect JavaScript logic
- Promise chains with unhandled rejections
- Event listeners that are never triggered

**Timeout detection patterns:**
Use grep to find missing timeouts:
```bash
# Find all wait calls without timeout
grep -r "wait(for: \[expectation\])$" Tests/

# Verify all have timeouts
grep -r "wait(for:.*timeout:" Tests/
```

**Bulk timeout fixes:**
For files with many missing timeouts, use sed for bulk replacement:
```bash
sed -i '' 's/wait(for: \[expectation\])$/wait(for: [expectation], timeout: 10.0)/g' filename.swift
```

**Testing best practices:**
- Always add timeouts when creating new async tests
- Review existing tests for missing timeouts during refactoring
- Use appropriate timeout values based on operation complexity
- Consider network conditions and CI environment performance
- Prefer shorter timeouts for faster feedback, but ensure reliability

### **CRITICAL:** External Service Consistency in Tests
**Always use consistent external services across test cases to maintain reliability and predictable behavior:**

**Standard External Services by Test Type:**
- **Primary HTTP Testing**: `https://postman-echo.com` - reliable echo service for GET, POST, headers, data validation
- **Status Code Testing**: `https://httpstat.us` - generates specific HTTP status codes and timing scenarios  
- **DNS/Connection Errors**: `https://nonexistent-domain-12345.com` or `http://localhost:99999` - predictable failures
- **Mock URLs (non-network)**: `https://example.com` - for Request object construction without actual requests
- **Email Placeholders**: `test@example.com` - standard placeholder email format

**Service-Specific Usage Patterns:**
```swift
// ✅ CORRECT - postman-echo.com for data echo and validation
fetch('https://postman-echo.com/post', {
    method: 'POST',
    body: JSON.stringify({test: 'data'})
}).then(r => r.json()).then(data => data.json.test)  // Echoes back the sent data

// ✅ CORRECT - httpstat.us for specific status codes
fetch('https://httpstat.us/404')  // Returns 404 status
fetch('https://httpstat.us/200?sleep=1000')  // Delayed response

// ✅ CORRECT - example.com for mock URLs (no actual request)
const request = new Request('https://example.com', {method: 'POST'})
```

**Why Service Consistency Matters:**
- **Predictable APIs**: Each service has known behavior patterns and response formats
- **Reliability**: Well-established services have better uptime than random test endpoints
- **Maintenance**: Easier to update tests when using consistent service patterns
- **Debugging**: Familiar response formats make test failures easier to diagnose
- **CI/CD Stability**: Reduces flaky tests due to service inconsistencies

**❌ AVOID these inconsistent patterns:**
- Mixing different echo services (`httpbin.org` vs `postman-echo.com`) without clear reason
- Using random websites that might change or become unavailable
- Creating unnecessary service dependencies when existing ones work
- Using production APIs for testing (respect rate limits and terms of service)

**Service Selection Guidelines:**
1. **Check existing tests first** - use the same services already established in the test suite
2. **Use minimal services** - don't introduce new external dependencies unnecessarily  
3. **Document service requirements** - if a new service is needed, explain why in comments
4. **Consider offline alternatives** - use mock data when external services aren't required
5. **Test service behavior** - verify the external service works as expected before writing tests

### **CRITICAL:** Test Case Content Verification
**Always verify that test cases are actually testing what they claim to test:**

```swift
// ❌ WRONG - test name suggests redirect testing but only tests basic fetch
func testRedirectFollowing() {
    let script = """
        fetch('https://postman-echo.com/get').then(r => r.json())
    """
    // This doesn't test redirects at all!
}

// ✅ CORRECT - test actually verifies redirect behavior
func testRedirectFollowing() {
    let script = """
        fetch('https://httpstat.us/redirect/2').then(r => ({
            url: r.url,
            redirected: r.redirected,
            status: r.status
        }))
    """
    // Verifies final URL, redirect flag, and status after following redirects
}
```

**Common test verification failures:**
- **Test names don't match behavior**: Method named `testErrorHandling` but only tests success cases
- **Assertions don't verify the feature**: Testing that a promise resolves but not checking the actual result
- **Mock/stub data isn't realistic**: Using simplified test data that doesn't exercise edge cases
- **Missing negative test cases**: Only testing happy path without error conditions
- **Incomplete feature coverage**: Testing one parameter but ignoring others in the same API
- **Copy-paste errors**: Duplicated test logic that doesn't match the test name

**Test content verification checklist:**
1. **Read the test name and expected behavior** - what should this test prove?
2. **Trace through the actual test code** - what does it actually test?
3. **Check assertions match the feature** - do they verify the right properties?
4. **Verify test data is appropriate** - does it exercise the intended code paths?
5. **Ensure error cases are covered** - are failure modes tested?
6. **Review edge cases** - are boundary conditions included?

**Example verification patterns:**
```swift
// For redirect tests - verify redirect-specific properties
XCTAssertTrue(result["redirected"].toBool())
XCTAssertNotEqual(result["url"].toString(), originalUrl)

// For error handling tests - actually trigger and verify errors
XCTAssertTrue(result["error"].isObject)
XCTAssertEqual(result["error"]["name"].toString(), "TypeError")

// For performance tests - measure the right metrics
measure { /* code that should be optimized */ }
// Not just: measure { someUnrelatedSetup() }
```

**Anti-patterns to avoid:**
- Tests that always pass regardless of implementation
- Tests that verify test setup rather than actual functionality  
- Tests with misleading names that don't match their actual behavior
- Tests that only check basic "does not crash" without verifying correctness
- Tests copied from other features without adaptation to the specific use case

**When reviewing existing tests:**
- Run tests individually to understand what they actually verify
- Check if disabling the feature being tested causes the test to fail
- Verify test names accurately describe what's being tested
- Look for tests that might be testing implementation details rather than behavior
- Ensure comprehensive coverage of the API surface, not just code coverage

### **CRITICAL:** KotlinJS Additional Testing Patterns
**Adapted from SwiftJS testing patterns for KotlinJS-specific scenarios:**

#### **CRITICAL:** Never Use Fallbacks to Bypass Test Failures (KotlinJS)
**Always fix the root cause instead of adding fallback logic that masks real issues:**

**❌ WRONG - Adding fallbacks that hide broken functionality:**
```kotlin
// BAD: Accepting null as "okay" when testing API calls
val result = engine.execute("crypto.randomUUID()")
if (result != null) {
    assertEquals(36, result.toString().length, "UUID should be 36 characters")
} else {
    // Crypto may not be available - accept null as okay
    assertTrue(true, "Accept null as service unavailable")
}
```

**✅ CORRECT - Fix the actual problem:**
```kotlin
// GOOD: Ensure crypto is properly configured and expect correct behavior
val result = engine.execute("crypto.randomUUID()")
assertNotNull(result, "Crypto API should be available")
assertEquals(36, result.toString().length, "UUID should be 36 characters")
assertTrue(result.toString().contains("-"), "UUID should contain hyphens")
```

**Why fallbacks are dangerous:**
- **Hide real bugs**: Test passes even when core functionality is broken
- **Reduce test reliability**: Tests become meaningless if they accept any result
- **Mask configuration issues**: Platform setup problems get treated as "normal"
- **Create technical debt**: Future developers don't know what the test actually validates
- **Prevent regression detection**: Broken features go unnoticed because tests still pass

**When encountering test failures:**
1. **Investigate the root cause** - why is the test getting unexpected results?
2. **Fix the implementation** - if there's a bug in the code, fix it
3. **Update the configuration** - if platform setup is wrong, fix the platform context
4. **Improve error handling** - if it's a legitimate error case, test it properly
5. **Never add "|| acceptable_fallback_result"** - this always indicates a deeper problem

**Exception**: The only time to accept multiple results is when **explicitly testing error handling**:
```kotlin
// This is OK - we're specifically testing error scenarios
assertThrows<RuntimeException> { engine.execute("invalid.syntax.here") }
```

#### **CRITICAL:** Object Literal vs Block Statement Ambiguity (KotlinJS)
**A fundamental JavaScript parsing rule that frequently causes test failures:**

**❌ WRONG - bare object literal parsed as block statement:**
```kotlin
val script = """
    {
        uuid: crypto.randomUUID(),
        bytes: crypto.randomBytes(16),
        success: true
    }
"""
// Returns: undefined (parsed as labeled statements in a block)
```

**✅ CORRECT - parentheses force object literal parsing:**
```kotlin
val script = """
    ({
        uuid: crypto.randomUUID(),
        bytes: crypto.randomBytes(16),
        success: true
    })
"""
// Returns: object with properties
```

**Why this happens:**
- JavaScript parser interprets `{` at start of statement as beginning of block statement
- `uuid:`, `bytes:`, etc. become statement labels, not object properties
- Expressions after labels are evaluated but the block returns `undefined`
- Wrapping in parentheses `({ ... })` forces expression context, creating object literal
- This is standard JavaScript behavior, not a KotlinJS limitation

**Testing implications:**
- Always wrap object literals in parentheses when they're the main return value
- Particularly important in test scripts that return result objects for assertion
- Use `({ ... })` pattern consistently in all test object returns

#### **CRITICAL:** External Service Consistency in Tests (KotlinJS)
**Always use consistent external services across test cases to maintain reliability:**

**Standard External Services by Test Type:**
- **Primary HTTP Testing**: `https://postman-echo.com` - reliable echo service for testing fetch/HTTP functionality
- **Status Code Testing**: `https://httpstat.us` - generates specific HTTP status codes
- **DNS/Connection Errors**: `https://nonexistent-domain-12345.com` - predictable failures
- **Mock URLs (non-network)**: `https://example.com` - for Request object construction without actual requests

**Service Selection Guidelines:**
1. **Check existing tests first** - use the same services already established in the test suite
2. **Use minimal services** - don't introduce new external dependencies unnecessarily  
3. **Document service requirements** - if a new service is needed, explain why in comments
4. **Consider offline alternatives** - use mock data when external services aren't required
5. **Test service behavior** - verify the external service works as expected before writing tests