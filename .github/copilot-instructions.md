# SwiftJS & KotlinJS - Cross-Platform JavaScript Runtimes

## 1. Project Overview

### Architecture Overview

Both SwiftJS and KotlinJS follow similar architectural patterns while adapting to their respective platform ecosystems.

#### SwiftJS Architecture
SwiftJS is a JavaScript runtime built on Apple's JavaScriptCore, providing a bridge between Swift and JavaScript with Node.js-like APIs:

- **Core Layer** (`swift/Sources/SwiftJS/core/`): JavaScript execution engine and value marshaling
- **Library Layer** (`swift/Sources/SwiftJS/lib/`): Native Swift implementations of JS APIs
- **Polyfill Layer** (`resources/polyfill.js`): Shared JavaScript polyfills for missing APIs

#### KotlinJS Architecture
KotlinJS is a JavaScript runtime built on Javet (Java + V8), providing a bridge between Kotlin and JavaScript with Node.js-like APIs:

- **Core Layer** (`java/jscore/`): JavaScript execution engine and value marshaling using Javet V8
- **Library Layer** (`java/jscore/`): Native Kotlin implementations of JS APIs via JSBridge
- **Platform Layer** (`java/jscore-android/`, `java/jscore-jvm/`): Platform-specific context implementations
- **Polyfill Layer** (`resources/polyfill.js`): Shared JavaScript polyfills for missing APIs

### Unified Project Structure

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

**CRITICAL**: Never create circular dependencies between modules. Core abstractions in `java/jscore/` must remain platform-independent, and shared resources in `resources/` should not depend on platform-specific implementations.

### Native Bridge Consistency

#### **CRITICAL:** Native Bridge Consistency Requirements

**Both engines MUST expose identical native bridge modules** to ensure the shared `polyfill.js` file works correctly across platforms:

1. **Synchronized Module Set**: All native bridge modules must be implemented in both SwiftJS and KotlinJS
2. **Identical API Signatures**: Each bridge module must expose the same methods and properties with identical behavior
3. **No Engine-Specific Modules**: Do not add native bridge modules to only one engine - either add to both or don't add at all
4. **Shared Polyfill Dependency**: The `resources/polyfill.js` file depends on these exact module names and APIs

#### Common Native APIs (Both Engines)
- `crypto`: Cryptographic functions (randomUUID, randomBytes, hashing)
- `processInfo`: Process information (PID, arguments, environment)
- `processControl`: Process control operations (exit, etc.)
- `deviceInfo`: Device identification
- `bundleInfo`: Application metadata
- `FileSystem`: File operations
- `URLSession`: HTTP requests
- `URLRequest`: HTTP request construction

**Important:** `__NATIVE_BRIDGE__` is passed as a private parameter to the polyfill system and is not exposed as a global object to user JavaScript code.

**When adding new native bridge modules:**
- Add the implementation to both `swift/Sources/SwiftJS/core/polyfill.swift` and `java/jscore/src/main/kotlin/com/o2ter/jscore/JavaScriptEngine.kt`
- Update this documentation to reflect the new common API
- Test with both SwiftJSRunner and jscore-runner to ensure compatibility

---

## 2. Core Implementation Patterns

### SwiftJS Critical Patterns

#### Context Management
- `SwiftJS` struct is the main entry point - creates a JS context with automatic polyfill injection
- `VirtualMachine` wraps JSVirtualMachine with RunLoop integration for timer support
- Always use `SwiftJS()` constructor which automatically calls `polyfill()` for full API setup

#### Value Bridging Pattern
```swift
// JavaScript values are automatically bridged
let jsValue: SwiftJS.Value = "hello"  // String literal
let jsArray: SwiftJS.Value = [1, 2, 3]  // Array literal
let jsObject: SwiftJS.Value = ["key": "value"]  // Dictionary literal
```

#### **CRITICAL:** Method Binding and `this` Context
When accessing JavaScript methods via subscript, the `this` context is lost, causing methods to fail:

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

#### JSExport Protocol Implementation
```swift
@objc protocol JSMyAPIExport: JSExport {
    func myMethod() -> String
}

@objc final class JSMyAPI: NSObject, JSMyAPIExport {
    func myMethod() -> String { return "result" }
}
```

**Important:** Swift static properties are automatically exposed as JavaScript functions, not properties. Tests should expect and call these as functions.

**JavaScriptCore Property Enumeration Limitation:** Swift-exposed objects cannot be enumerated using standard JavaScript methods:
- `Object.getOwnPropertyNames(swiftObject)` returns an empty array `[]`
- However, direct property access works: `swiftObject.myMethod()`

### KotlinJS Critical Patterns

#### Context Management
- `JavaScriptEngine` class is the main entry point - creates a JS context with automatic polyfill injection
- Uses Javet V8 with ICU data support for full internationalization
- Implements `AutoCloseable` for proper resource management
- **Long-lived pattern (most apps)**: Create once, reuse throughout application lifetime
- **Short-lived pattern (CLI tools)**: Use `.use {}` block for automatic cleanup

#### JSBridge Value Marshaling
```kotlin
// Use JSBridge for creating JavaScript objects
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

#### **CRITICAL:** V8ValueObject Property Binding Behavior
**V8ValueObject properties created with `.set()` are read-only by default and do not sync with Kotlin object fields.**

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

### Threading and Memory Management

#### **CRITICAL:** KotlinJS Javet Memory Management Patterns
Reference: [Javet Memory Management Documentation](https://www.caoccao.com/Javet/reference/resource_management/memory_management.html)

**⚠️ Debugging Note:** "Runtime is already closed" errors are often misleading - the engine may still execute JavaScript successfully. This error typically indicates threading or weak reference issues, not actual engine shutdown. Always test actual functionality before assuming the engine is broken.

**1. Try-with-resource (for objects you create and use immediately):**
```kotlin
v8Runtime.createV8ValueObject().use { v8ValueObject ->
    // Use object here
    // Automatically closed when block exits
}
```

**2. Weak Reference (for objects with undetermined lifecycle):**
```kotlin
val handler = v8Values[0] as V8ValueFunction
handler.setWeak()  // V8 GC will handle lifecycle automatically
progressHandlers[requestId] = handler

// Later, call the handler multiple times from background threads
engine.executeOnJSThreadAsync {
    if (!handler.isClosed) {
        handler.callVoid(null, args...)
    }
}
```

#### KotlinJS Threading Model

**CRITICAL: V8 Thread Confinement Requirement**
V8Runtime MUST be created and used on the same thread.

```kotlin
// All JS operations go through executeOnJSThread
private inline fun <T> executeOnJSThread(crossinline block: () -> T): T {
    // Deadlock prevention: if already on JS thread, execute directly
    if (Thread.currentThread() == jsThread) {
        return block()
    }
    return jsExecutor.submit(Callable { block() }).get()
}
```

#### SwiftJS Timer Management
**CRITICAL Threading Requirement:** Timer creation must happen on the JavaScript context's RunLoop thread:

```swift
// ❌ WRONG - creates timer on current thread (might be background Task)
context.timer[id] = Timer.scheduledTimer(...)

// ✅ CORRECT - ensures timer creation on JavaScript RunLoop thread
runLoop.perform {
    context.timer[id] = Timer.scheduledTimer(...)
}
```

**Threading Rules Summary:**
- **FROM JavaScript callbacks:** Direct access is safe (already on correct thread)
- **FROM Swift Task/async contexts:** Must use `runLoop.perform { }`
- **FROM Network completion handlers:** Must use `runLoop.perform { }`

---

## 3. Platform-Specific Details

### SwiftJS Implementation

#### Key Components
- **Engine**: Apple JavaScriptCore (same as Safari)
- **Integration**: Deep iOS/macOS platform integration
- **Memory**: Automatic (ARC + GC)
- **Threading**: Main thread recommended with RunLoop integration

#### Async/Promise Integration
```swift
// Swift async functions are automatically bridged to JavaScript Promises
SwiftJS.Value(newFunctionIn: context) { args, this in
    // Swift async code here
    return someAsyncResult
}
```

#### Resource Bundle Access
```swift
if let polyfillJs = Bundle.module.url(forResource: "polyfill", withExtension: "js"),
   let content = try? String(contentsOf: polyfillJs, encoding: .utf8) {
    self.evaluateScript(content, withSourceURL: polyfillJs)
}
```

### KotlinJS Implementation

#### Key Components
- **Engine**: Google V8 via Javet
- **Integration**: Cross-platform JVM/Android support
- **Memory**: Explicit (try-with-resource patterns)
- **Threading**: Dedicated JS thread via ExecutorService

#### Javet V8 Engine Integration
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

#### **CRITICAL:** HTTP Request Tracking
**Never track HTTP requests by thread - threads can be reused for multiple requests:**

```kotlin
// ❌ WRONG - Tracking by thread (causes bugs with thread pools)
engine.registerHttpThread(Thread.currentThread())

// ✅ CORRECT - Track by unique request ID
val requestId = "req_${nextRequestId++}"
engine.registerHttpRequest(requestId)
```

### Cross-Platform Considerations

#### **CRITICAL:** Streaming Implementation Principles
When implementing or modifying Blob, File, and HTTP operations:

1. **NEVER call blob.arrayBuffer() in streaming contexts** - Always use blob.stream()
2. **File objects with filePath use streaming APIs** - True disk streaming, not memory buffering
3. **HTTP uploads use streaming body** - Pass ReadableStream directly to URLRequest
4. **TextDecoder streaming for text operations** - Use `{ stream: true }`
5. **Response body streaming pipes blob.stream() directly** - No intermediate arrayBuffer()

---

## 4. Development Guidelines

### Code Style and Conventions

#### Naming Conventions
- **No underscore prefixes**: Never use underscore prefixes for internal fields or methods
- **Use symbols for internal APIs**: For polyfill internal fields that need cross-class access
- **Use `#` for class private fields**: For true private fields within a single class

#### **CRITICAL:** Avoiding globalThis Pollution
**Never pollute globalThis with internal implementation details:**

```swift
// ❌ WRONG - Exposing internal state on globalThis
context.evaluateScript("""
    globalThis.__timerCallbacks__ = {};
    globalThis.__executeTimerCallback__ = function(id) { ... };
""")

// ✅ CORRECT - Keep internal state in scope and pass objects
let timerNamespace = context.evaluateScript("""
    (function() {
        const timerNamespace = {
            callbacks: new Map(),
            executeCallback: function(id) { ... }
        };
        return timerNamespace;
    })();
""")
```

**Guidelines for globalThis usage:**
- **Only expose user-facing APIs**: `console`, `setTimeout`, `crypto`, `process`, etc.
- **Never expose internal state**: `__callbacks__`, `__namespace__`, `__internal__`, etc.
- **Use private closures**: Wrap implementation details in IIFEs
- **Pass objects through parameters**: Instead of global lookups

#### Code Reuse and Dead Code
- **Refactor repeating code**: Extract into small, well-named, reusable functions
- **Keep abstractions pragmatic**: Don't over-abstract
- **Remove unused code**: Always delete dead code before committing
- **Verify after removal**: Run build and tests to ensure nothing relied on removed code

### Web Standards Compliance

- Prioritize web standards and specifications (W3C, WHATWG, ECMAScript) over Node.js-specific behaviors
- Follow MDN Web Docs for API signatures, behavior, and error handling patterns
- Implement standard web APIs (Fetch, Crypto, Streams, etc.) according to their specifications
- Document any deviations from standards with clear reasoning

**IMPORTANT: No DOM-Specific APIs**
- SwiftJS/KotlinJS are server-side runtimes and do not implement DOM-specific APIs
- Use standard `Error` objects instead of DOM-specific errors like `DOMException`
- Focus on web standard APIs that work in non-DOM environments

### Platform and System Call Guidelines

**CRITICAL:** Always use POSIX-compliant approaches:

```swift
// ❌ WRONG - Darwin-specific
import Darwin
Darwin.exit(code)

// ✅ CORRECT - POSIX-compliant via Foundation
import Foundation
Foundation.exit(code)
```

### Error Handling and Debugging

#### SwiftJS Error Handling
```swift
js.base.exceptionHandler = { context, exception in
    if let error = exception?.toString() {
        print("JavaScript Error: \(error)")
    }
}
```

#### KotlinJS Error Handling
```kotlin
try {
    val result = engine.execute("throw new Error('Test error')")
} catch (e: JavetExecutionException) {
    println("JavaScript Error: ${e.message}")
    println("Line: ${e.lineNumber}, Column: ${e.columnNumber}")
}
```

---

## 5. AI Agent Guidelines

### Development Best Practices

#### Deprecated APIs
**CRITICAL:** Never use deprecated APIs or methods:
- Do not use deprecated functions, classes, or properties in new code
- Replace deprecated usages with current, supported APIs
- Document reasons if no replacement exists

#### Deep Thinking and Hypothesis Before Coding
**CRITICAL:** Before writing any code:
1. **Think deeply about the problem**: Analyze requirements, constraints, edge cases
2. **Formulate hypotheses**: Predict behavior, failure modes, success criteria
3. **Check existing code**: Inspect source files, tests, polyfills, documentation
4. **List proof steps**: Plan validation and testing approach
5. **Write code only after planning**: Clear intent and validation strategy
6. **Verify by running tests**: Validate correctness and expected behavior

#### **CRITICAL:** Error Message vs Root Cause Analysis
**Error messages often don't reflect the real problem - always investigate deeper:**

**Common Misleading Error Patterns:**
- **"Runtime is already closed"** in KotlinJS: Engine may still be running JavaScript successfully after this error
- **"Type error"** in SwiftJS: Often indicates lost `this` context in method calls, not actual type issues
- **Memory errors**: May indicate threading violations rather than actual memory problems
- **Network timeouts**: Could be caused by blocking operations on wrong threads

**Root Cause Investigation Process:**
1. **Don't trust the error message alone** - use it as a starting point, not conclusion
2. **Test actual functionality** - verify if the feature still works despite error messages
3. **Check threading context** - many "runtime" errors are actually thread confinement violations
4. **Verify resource lifecycle** - "closed" errors may indicate premature cleanup, not actual closure
5. **Trace execution flow** - follow the actual code path, not what error suggests
6. **Test minimal reproduction** - isolate the real triggering condition

**Example: KotlinJS "Runtime is already closed" Investigation:**
```kotlin
// Error says "Runtime is already closed" but engine still executes JS
try {
    val result = engine.execute("console.log('test')")
    // This succeeds despite the error message!
} catch (e: Exception) {
    // Error logged: "Runtime is already closed"
    // Real problem: Threading issue in Javet memory management
    // Solution: Proper weak reference patterns, not engine restart
}
```

#### **CRITICAL:** Debug Logging Best Practices
**Console logging is invaluable for debugging - use it liberally, but clean up afterward:**

**Debug Logging Guidelines:**
- **Add debug logs freely** during investigation to trace execution flow
- **Use descriptive prefixes** to identify log source: `[DEBUG-HTTP]`, `[DEBUG-TIMER]`, etc.
- **Log key state changes** and variable values at decision points
- **Add searchable comments** to mark temporary debug code for removal

**Debug Log Pattern with Cleanup Markers:**
```swift
// TODO: REMOVE DEBUG - Timer investigation
print("[DEBUG-TIMER] Creating timer with ID: \(id), interval: \(interval)")

// TODO: REMOVE DEBUG - HTTP request tracking  
print("[DEBUG-HTTP] Request \(requestId) status: \(status)")

// TODO: REMOVE DEBUG - Memory management
console.log("[DEBUG-MEMORY] Object created:", object.constructor.name);
```

**Cleanup Process:**
1. **Search for debug markers** before committing: `TODO: REMOVE DEBUG`
2. **Remove all temporary debug logs** after bug is fixed
3. **Keep only essential logging** for production debugging
4. **Convert useful debug logs** to proper logging with appropriate levels

#### Implementation Verification
**CRITICAL:** Always verify implementation behavior:
- Test actual behavior in runtime before documenting APIs
- Run code examples to confirm they work as described
- Use SwiftJSRunner/jscore-runner to validate functionality
- Don't rely on external documentation without verification

#### **CRITICAL:** Test Integrity Principle
**NEVER use fallbacks or permissive assertions to bypass test failures:**
- When tests fail, investigate and fix the root cause
- Don't add `|| acceptableStatus` conditions unless explicitly testing error scenarios
- Fallback logic in tests masks real issues and creates technical debt

### Documentation Requirements

#### **CRITICAL:** Documentation Update Requirements
**MANDATORY:** Always update documentation when making API changes:

**For JavaScript API Changes:**
- **SwiftJS**: Update `docs/guides/swiftjs/` with new or modified APIs
- **KotlinJS**: Update `docs/guides/kotlinjs/` with new or modified APIs
- Update method signatures, parameter descriptions, return values
- Add working code examples demonstrating API usage

**For Core Architecture Changes:**
- Update `README.md` if core functionality changes
- Update architectural diagrams and feature lists
- Update quick start examples if they no longer work

**Documentation Validation Process:**
1. **Test all code examples** after changes
2. **Run examples** with SwiftJSRunner/jscore-runner
3. **Check cross-references** between documentation files
4. **Verify API signatures** match actual implementation

### Task Execution Guidelines

#### Command Execution Best Practices
- **Always wait** for task completion before proceeding
- **Never use timeouts** to run commands - always failure-prone
- **Never repeat commands** while task is already running
- **CRITICAL: Never start new task** before previous one completely finished

#### Test Execution Guidelines
- **Always use provided tools** when available:
  - Use `runTests` tool for Swift test cases
  - Use `run_notebook_cell` for Jupyter cells
  - Use SwiftJSRunner via `run_in_terminal` for JavaScript
- **Test-specific best practices**:
  - Use specific file paths to avoid long test runs
  - Create test files in `.temp/` directory
  - Always wait for test completion before analyzing results

#### Task Status Verification
- If task appears stuck, ask user to confirm completion status
- **Never assume** task completed without explicit confirmation
- **Sequential execution mandatory**: Complete one task before starting next
- **Never try alternative output retrieval** - wait for proper tool results

### Common Mistakes to Avoid

#### Network Request Tracking Implementation Mistakes
1. **❌ NEVER expose internal tracking to JavaScript global objects**
2. **❌ NEVER use complex static tracking systems when simple instance references work**
3. **❌ NEVER use static variables for per-instance state**
4. **❌ NEVER misunderstand JSExport interface requirements**
5. **❌ NEVER use MainActor when unnecessary**

#### Test Quality Anti-Patterns
6. **❌ NEVER add fallback logic to bypass test failures**
7. **❌ NEVER accept error status codes as "normal" without investigation**
8. **❌ NEVER use permissive assertions that always pass**

#### General Architecture Anti-Patterns
9. **❌ NEVER overcomplicate simple paired relationships**
10. **❌ NEVER ignore existing JavaScript API expectations**

#### KotlinJS Platform Context Mistakes
11. **❌ NEVER bypass the platform context abstraction**
12. **❌ NEVER create static global state for per-instance functionality**
13. **❌ NEVER mix Javet V8 API patterns with other JavaScript engine patterns**
14. **❌ NEVER ignore ICU data requirements**
15. **❌ NEVER create circular module dependencies**

#### Key Lessons
- **KISS Principle**: Keep implementations as simple as possible
- **Check existing patterns**: Look before inventing new systems
- **Verify JavaScript contracts**: Always check `polyfill.js` expectations
- **Prefer instance state**: Use instance variables over static tracking
- **Avoid global pollution**: Never expose internal details to JavaScript globals

---

## 6. Testing and Quality Assurance

### Critical Testing Patterns

#### **CRITICAL:** Never Use Fallbacks to Bypass Test Failures
**Always fix the root cause instead of adding fallback logic:**

```swift
// ❌ WRONG - Adding fallbacks that hide broken functionality
if status == 200 {
    XCTAssertEqual(status, 200, "Should get 200 after redirect")
} else {
    // External service may have changed - accept 404 as okay
    XCTAssertTrue(status == 404, "Accept 404 as service change")
}

// ✅ CORRECT - Fix the actual problem
let status = Int(result["finalStatus"].numberValue ?? 0)
XCTAssertEqual(status, 200, "Should get 200 after redirect")
XCTAssertTrue(result["redirected"].boolValue ?? false, "Should be marked as redirected")
```

**Why fallbacks are dangerous:**
- Hide real bugs - test passes even when functionality is broken
- Reduce test reliability - tests become meaningless
- Mask API changes - external service issues treated as "normal"
- Create technical debt - future developers don't know what test validates
- Prevent regression detection - broken features go unnoticed

#### **CRITICAL:** Object Literal vs Block Statement Ambiguity
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
- Wrapping in parentheses `({ ... })` forces expression context, creating object literal
- This is standard JavaScript behavior, not a SwiftJS/KotlinJS limitation

#### **CRITICAL:** Test Timeout Requirements
**All asynchronous tests MUST have timeout parameters:**

```swift
// ❌ WRONG - missing timeout can cause indefinite hanging
wait(for: [expectation])

// ✅ CORRECT - always include appropriate timeout
wait(for: [expectation], timeout: 10.0)
```

**Timeout Guidelines by Test Type:**
- **5 seconds**: Quick operations, basic API calls
- **10 seconds**: Standard network requests, most async tests
- **15 seconds**: Complex operations, error recovery
- **30 seconds**: Concurrent connections, resource-intensive operations
- **60 seconds**: Large file uploads, performance-critical operations

#### **CRITICAL:** External Service Consistency in Tests
**Always use consistent external services:**

**Standard External Services by Test Type:**
- **Primary HTTP Testing**: `https://postman-echo.com` - reliable echo service
- **Status Code Testing**: `https://httpstat.us` - generates specific HTTP status codes
- **DNS/Connection Errors**: `https://nonexistent-domain-12345.com` - predictable failures
- **Mock URLs**: `https://example.com` - for Request construction without actual requests

#### **CRITICAL:** Test Case Content Verification
**Always verify that test cases actually test what they claim:**

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

### Platform-Specific Testing

#### Performance Testing with `measure` Blocks
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

#### KotlinJS Testing Patterns
```kotlin
// ❌ WRONG - Accepting null as "okay" when testing API calls
val result = engine.execute("crypto.randomUUID()")
if (result != null) {
    assertEquals(36, result.toString().length, "UUID should be 36 characters")
} else {
    assertTrue(true, "Accept null as service unavailable")
}

// ✅ CORRECT - Ensure proper configuration and expect correct behavior
val result = engine.execute("crypto.randomUUID()")
assertNotNull(result, "Crypto API should be available")
assertEquals(36, result.toString().length, "UUID should be 36 characters")
assertTrue(result.toString().contains("-"), "UUID should contain hyphens")
```

### Test Quality Guidelines

#### Test Content Verification Checklist
1. **Read the test name and expected behavior** - what should this test prove?
2. **Trace through the actual test code** - what does it actually test?
3. **Check assertions match the feature** - do they verify the right properties?
4. **Verify test data is appropriate** - does it exercise intended code paths?
5. **Ensure error cases are covered** - are failure modes tested?
6. **Review edge cases** - are boundary conditions included?

#### Anti-patterns to Avoid
- Tests that always pass regardless of implementation
- Tests that verify test setup rather than actual functionality
- Tests with misleading names that don't match behavior
- Tests that only check "does not crash" without verifying correctness
- Tests copied from other features without adaptation

#### When Reviewing Existing Tests
- Run tests individually to understand what they verify
- Check if disabling the feature causes test to fail
- Verify test names accurately describe what's being tested
- Look for tests that might be testing implementation details rather than behavior
- Ensure comprehensive coverage of API surface, not just code coverage

### Temporary Files for Testing
- Place all test scripts under `<project_root>/.temp/` for organization
- **SwiftJS**: Use SwiftJSRunner to execute: `swift run SwiftJSRunner <script.js>`
- **KotlinJS**: Use jscore-runner: `./gradlew :java:jscore-runner:run --args="script.js"`
- Both support eval mode: `-e "console.log('test')"`
- **Test Case Verification**: Always examine actual test content:
  - Read test files completely to understand logic and assertions
  - Verify test descriptions match what test actually does
  - **NEVER use fallback methods to bypass test cases**
  - **No test shortcuts or workarounds** - all tests must pass legitimately

### Temporary Debug Code
**CRITICAL:** Always remove all temporary debug code before committing:
- Ad-hoc print/log statements (use `TODO: REMOVE DEBUG` comments for easy searching)
- Temporary debug flags left enabled
- Throwaway test scripts outside proper `Tests/` directory
- Helper files in `.temp/` intended only for local debugging
- Large commented-out blocks or debugging shortcuts

**Debug Code Search Pattern:** Use `TODO: REMOVE DEBUG` comments to mark all temporary debug logging for easy cleanup with global search.

If durable debugging helpers are necessary, extract them into clearly documented utility modules with explicit feature flags.

---

## ⚠️ CRITICAL: Documentation Update Requirement

**ALWAYS UPDATE DOCUMENTATION WHEN MAKING API CHANGES**
- Any API modification requires corresponding documentation updates
- Test all documentation examples after changes
- This instruction file should be updated with architectural discoveries
- See "Documentation Update Requirements" section for full details