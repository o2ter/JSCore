# SwiftJS API Reference

Complete API reference for SwiftJS, covering all JavaScript APIs, Swift integration patterns, and value bridging mechanisms.

## Table of Contents

- [Core SwiftJS Classes](#core-swiftjs-classes)
- [Value Bridging](#value-bridging)
- [JavaScript APIs](#javascript-apis)
- [Native Swift APIs](#native-swift-apis)
- [Error Handling](#error-handling)
- [Performance Considerations](#performance-considerations)

## Core SwiftJS Classes

### SwiftJS

The main entry point for JavaScript execution.

```swift
public struct SwiftJS {
    public let virtualMachine: VirtualMachine
    public init(_ virtualMachine: VirtualMachine = VirtualMachine())
}
```

#### Properties

- `virtualMachine: VirtualMachine` - The underlying JavaScript virtual machine
- `globalObject: SwiftJS.Value` - Access to the JavaScript global object
- `exception: SwiftJS.Value` - The last JavaScript exception (if any)
- `runloop: RunLoop` - The RunLoop for timer integration
- `hasActiveTimers: Bool` - Whether there are active JavaScript timers
- `activeTimerCount: Int` - Count of active JavaScript timers

#### Methods

```swift
// Execute JavaScript code
@discardableResult
func evaluateScript(_ script: String) -> SwiftJS.Value

@discardableResult  
func evaluateScript(_ script: String, withSourceURL sourceURL: URL) -> SwiftJS.Value
```

#### Example

```swift
let js = SwiftJS()
let result = js.evaluateScript("Math.PI * 2")
print(result.numberValue) // 6.283185307179586
```

### SwiftJS.Value

Represents JavaScript values with automatic Swift conversion.

```swift
public struct Value {
    // Value type checking
    var isUndefined: Bool
    var isNull: Bool
    var isBool: Bool
    var isNumber: Bool
    var isString: Bool
    var isArray: Bool
    var isObject: Bool
    var isFunction: Bool
    
    // Value conversion
    var boolValue: Bool?
    var numberValue: Double?
    var stringValue: String?
    var dateValue: Date?
    
    // Method calls
    func call(withArguments args: [Any]) -> SwiftJS.Value
    func invokeMethod(_ method: String, withArguments args: [Any]) -> SwiftJS.Value
    
    // Property access
    subscript(key: String) -> SwiftJS.Value
    subscript(index: Int) -> SwiftJS.Value
}
```

#### Critical Pattern: Method Invocation

**IMPORTANT:** Use `invokeMethod` instead of subscript access for JavaScript methods to preserve `this` context:

```swift
// ❌ WRONG - loses 'this' context
let method = object["methodName"]
let result = method.call(withArguments: [])  // TypeError

// ✅ CORRECT - preserves 'this' context
let result = object.invokeMethod("methodName", withArguments: [])
```

### VirtualMachine

Wraps JSVirtualMachine with RunLoop integration.

```swift
public final class VirtualMachine {
    public let base: JSVirtualMachine
    public let runloop: RunLoop
    
    public init(runloop: RunLoop = .current)
}
```

## Value Bridging

SwiftJS automatically converts values between Swift and JavaScript:

### Automatic Conversions

| Swift Type | JavaScript Type | Example |
|------------|-----------------|---------|
| `String` | `string` | `"hello"` |
| `Int`, `Double` | `number` | `42`, `3.14` |
| `Bool` | `boolean` | `true`, `false` |
| `[Any]` | `Array` | `[1, 2, 3]` |
| `[String: Any]` | `Object` | `{"key": "value"}` |
| `nil` | `null` | `null` |
| `SwiftJS.Value.undefined` | `undefined` | `undefined` |

### Examples

```swift
let js = SwiftJS()

// Swift to JavaScript
js.globalObject["swiftArray"] = [1, 2, 3]
js.globalObject["swiftDict"] = ["name": "Alice", "age": 30]
js.globalObject["swiftString"] = "Hello from Swift"

// JavaScript to Swift
js.evaluateScript("var jsData = {numbers: [1,2,3], text: 'Hello'}")
let jsObject = js.globalObject["jsData"]
let numbers = jsObject["numbers"] // SwiftJS.Value representing the array
let text = jsObject["text"].stringValue // "Hello"
```

## JavaScript APIs

SwiftJS provides comprehensive JavaScript APIs through polyfills and native implementations.

### Core JavaScript (ECMAScript)

Standard JavaScript features are fully supported:

- **Global objects**: `Object`, `Array`, `Date`, `Math`, `JSON`, `RegExp`
- **Functions**: Arrow functions, async/await, generators
- **Promises**: Native Promise support with proper async handling
- **Error handling**: `try`/`catch` with stack traces
- **Modules**: Basic module support (CommonJS-style)

### Web Standards APIs

#### Console API

Enhanced console with formatting and grouping:

```javascript
// Basic logging
console.log("Hello", "World");
console.error("Error message");
console.warn("Warning message");
console.info("Info message");

// Timing
console.time("operation");
// ... some operation
console.timeEnd("operation"); // operation: 45ms

// Counting
console.count("requests");     // requests: 1
console.count("requests");     // requests: 2
console.countReset("requests");

// Grouping
console.group("API Requests");
console.log("GET /users");
console.log("POST /users");
console.groupEnd();

// Assertions
console.assert(value > 0, "Value must be positive");

// Object inspection
console.table([{name: "Alice", age: 30}, {name: "Bob", age: 25}]);
console.dir(complexObject);
```

#### Crypto API (Web Crypto)

```javascript
// Random UUID generation
const id = crypto.randomUUID();
console.log(id); // "f47ac10b-58cc-4372-a567-0e02b2c3d479"

// Random bytes
const bytes = crypto.randomBytes(16);
console.log(bytes); // Uint8Array(16)

// Secure random values
const buffer = new Uint8Array(16);
crypto.getRandomValues(buffer);
```

#### Text Encoding/Decoding

```javascript
// Text encoding
const encoder = new TextEncoder();
const bytes = encoder.encode("Hello, 世界!");

// Text decoding  
const decoder = new TextDecoder();
const text = decoder.decode(bytes);
```

#### Base64 Encoding

```javascript
// Encode to base64
const encoded = btoa("Hello World");
console.log(encoded); // "SGVsbG8gV29ybGQ="

// Decode from base64
const decoded = atob(encoded);
console.log(decoded); // "Hello World"
```

#### Timers

```javascript
// Single execution
const timeoutId = setTimeout(() => {
    console.log("Delayed execution");
}, 1000);

// Repeated execution
const intervalId = setInterval(() => {
    console.log("Repeated execution");
}, 1000);

// Cancellation
clearTimeout(timeoutId);
clearInterval(intervalId);
```

#### Events

```javascript
// Event creation
const event = new Event('custom', { 
    bubbles: true, 
    cancelable: true 
});

// Event target
class MyTarget extends EventTarget {
    triggerEvent() {
        this.dispatchEvent(new Event('trigger'));
    }
}

const target = new MyTarget();
target.addEventListener('trigger', (event) => {
    console.log('Event triggered!');
});
target.triggerEvent();
```

#### AbortController & AbortSignal

```javascript
// Cancellation pattern
const controller = new AbortController();
const signal = controller.signal;

// Use with fetch or other async operations
fetch('/api/data', { signal })
    .then(response => response.json())
    .catch(error => {
        if (error.name === 'AbortError') {
            console.log('Request was aborted');
        }
    });

// Cancel the operation
controller.abort();
```

### File and Blob APIs

#### Blob

```javascript
// Create blob from data
const blob = new Blob(['Hello, World!'], { 
    type: 'text/plain' 
});

// Read blob data
const text = await blob.text();
const buffer = await blob.arrayBuffer();

// Slice blob
const slice = blob.slice(0, 5, 'text/plain');

// Stream blob
const stream = blob.stream();
const reader = stream.getReader();
while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    console.log(value); // Uint8Array chunks
}
```

#### File

```javascript
// Create file
const file = new File(['content'], 'test.txt', { 
    type: 'text/plain',
    lastModified: Date.now()
});

console.log(file.name);         // "test.txt"
console.log(file.size);         // 7
console.log(file.type);         // "text/plain"
console.log(file.lastModified); // timestamp

// Create from file system path (SwiftJS extension)
const diskFile = File.fromPath('/path/to/file.txt');
```

#### FileReader

```javascript
const reader = new FileReader();

reader.onload = (event) => {
    console.log('File loaded:', event.target.result);
};

reader.onerror = (event) => {
    console.error('Error reading file:', event.target.error);
};

reader.onprogress = (event) => {
    const percent = (event.loaded / event.total) * 100;
    console.log(`Loading: ${percent}%`);
};

// Read as different formats
reader.readAsText(file);           // String
reader.readAsArrayBuffer(file);    // ArrayBuffer
reader.readAsDataURL(file);        // data: URL
reader.readAsBinaryString(file);   // Binary string

// SwiftJS extensions for direct file system access
reader.readAsTextFromPath('/path/to/file.txt');
reader.readAsArrayBufferFromPath('/path/to/file.txt');
```

### HTTP APIs

#### XMLHttpRequest

```javascript
const xhr = new XMLHttpRequest();

xhr.onreadystatechange = function() {
    if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200) {
            console.log('Response:', xhr.responseText);
        }
    }
};

xhr.onprogress = function(event) {
    if (event.lengthComputable) {
        const percent = (event.loaded / event.total) * 100;
        console.log(`Progress: ${percent}%`);
    }
};

xhr.open('GET', 'https://api.example.com/data');
xhr.setRequestHeader('Content-Type', 'application/json');
xhr.send();

// Upload with progress
xhr.upload.onprogress = function(event) {
    console.log(`Upload: ${(event.loaded/event.total)*100}%`);
};
```

**Note:** SwiftJS XMLHttpRequest focuses on core HTTP functionality. Browser-specific features like `withCredentials` and `overrideMimeType()` are not implemented as they're not relevant in mobile app environments.

#### Fetch API

```javascript
// Simple GET request
const response = await fetch('/api/data');
const data = await response.json();

// POST request with body
const response = await fetch('/api/users', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
    },
    body: JSON.stringify({ name: 'Alice', age: 30 })
});

// Request with timeout/cancellation
const controller = new AbortController();
setTimeout(() => controller.abort(), 5000); // 5 second timeout

const response = await fetch('/api/data', {
    signal: controller.signal
});

// Form data upload
const formData = new FormData();
formData.append('file', file);
formData.append('name', 'upload');

const response = await fetch('/api/upload', {
    method: 'POST',
    body: formData
});

// Streaming response
const response = await fetch('/api/large-file');
const reader = response.body.getReader();

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    console.log('Received chunk:', value);
}
```

**Note:** SwiftJS implements the core Fetch API for practical HTTP requests. The following web browser-specific features are not implemented:
- CORS enforcement (`mode`, `credentials` properties are not enforced)
- HTTP cache control (`cache` property is not used)
- Automatic redirect handling (`redirect` property is not used)
- Subresource integrity validation (`integrity` property is not used)
- Referrer policy (`referrer` property is not used)

These limitations are intentional for mobile app environments where such browser security policies are not applicable.

#### Headers

```javascript
// Create headers
const headers = new Headers({
    'Content-Type': 'application/json',
    'Authorization': 'Bearer token123'
});

// Header manipulation
headers.append('X-Custom', 'value');
headers.set('Content-Type', 'application/xml');
headers.delete('Authorization');

// Check headers
console.log(headers.has('Content-Type')); // true
console.log(headers.get('Content-Type')); // "application/xml"

// Iterate headers
for (const [key, value] of headers) {
    console.log(`${key}: ${value}`);
}
```

#### Request & Response

```javascript
// Create request
const request = new Request('/api/data', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ key: 'value' })
});

// Use request with fetch
const response = await fetch(request);

// Create response
const response = new Response('Hello World', {
    status: 200,
    statusText: 'OK',
    headers: { 'Content-Type': 'text/plain' }
});

console.log(response.ok);        // true
console.log(response.status);    // 200
console.log(response.statusText); // "OK"
```

### FormData

```javascript
const formData = new FormData();

// Add form fields
formData.append('name', 'Alice');
formData.append('email', 'alice@example.com');
formData.append('file', file, 'document.pdf');

// Query form data
console.log(formData.get('name'));    // "Alice"
console.log(formData.getAll('file')); // [File object]
console.log(formData.has('email'));   // true

// Iterate form data
for (const [key, value] of formData) {
    console.log(`${key}: ${value}`);
}

// Use with fetch
const response = await fetch('/api/submit', {
    method: 'POST',
    body: formData
});
```

### Streams API

#### ReadableStream

```javascript
// Create readable stream
const stream = new ReadableStream({
    start(controller) {
        controller.enqueue('chunk 1');
        controller.enqueue('chunk 2');
        controller.close();
    }
});

// Read stream
const reader = stream.getReader();
while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    console.log('Chunk:', value);
}

// Transform stream
const transformed = stream.pipeThrough(new TransformStream({
    transform(chunk, controller) {
        controller.enqueue(chunk.toUpperCase());
    }
}));
```

#### WritableStream

```javascript
const stream = new WritableStream({
    write(chunk) {
        console.log('Writing:', chunk);
    },
    close() {
        console.log('Stream closed');
    }
});

const writer = stream.getWriter();
await writer.write('Hello');
await writer.write('World');
await writer.close();
```

#### Advanced Streams Features

**Queuing Strategies:**
```javascript
// Count-based queuing
const countStrategy = new CountQueuingStrategy({ highWaterMark: 5 });
const stream1 = new ReadableStream({...}, countStrategy);

// Byte-length based queuing
const byteStrategy = new ByteLengthQueuingStrategy({ highWaterMark: 1024 });
const stream2 = new ReadableStream({...}, byteStrategy);
```

**BYOB (Bring Your Own Buffer) Readers:**
```javascript
const stream = new ReadableStream({
    type: 'bytes',
    pull(controller) {
        const buffer = new Uint8Array(1024);
        // Fill buffer with data...
        controller.enqueue(buffer);
    }
});

const reader = stream.getReader({ mode: 'byob' });
const buffer = new Uint8Array(512);
const { value, done } = await reader.read(buffer);
```

**Backpressure Handling:**
```javascript
const writable = new WritableStream({
    write(chunk, controller) {
        // Slow processing simulation
        return new Promise(resolve => setTimeout(resolve, 100));
    }
}, new CountQueuingStrategy({ highWaterMark: 3 }));

const writer = writable.getWriter();

// Check backpressure
if (writer.desiredSize <= 0) {
    await writer.ready; // Wait for backpressure to be relieved
}
await writer.write(data);
```

**Advanced Transform Streams:**
```javascript
const compressionTransform = new TransformStream({
    start(controller) {
        this.buffer = '';
    },
    transform(chunk, controller) {
        this.buffer += chunk;
        // Batch processing
        if (this.buffer.length >= 100) {
            controller.enqueue(this.buffer.toUpperCase());
            this.buffer = '';
        }
    },
    flush(controller) {
        if (this.buffer) {
            controller.enqueue(this.buffer.toUpperCase());
        }
    }
});
```

## Node.js-like APIs

SwiftJS provides Node.js-compatible APIs for server-side development patterns:

### Process API

```javascript
// Process information
console.log('PID:', process.pid);
console.log('Arguments:', process.argv);
console.log('Environment:', process.env);

// Working directory
console.log('Current dir:', process.cwd());
process.chdir('/tmp');

// Exit process
process.exit(0); // Exit with code 0
process.exit(1); // Exit with error code
```

### Path Utilities

```javascript
// Path operations
const path = Path.join('usr', 'local', 'bin');
console.log(path); // "usr/local/bin"

const resolved = Path.resolve('..', 'documents', 'file.txt');
const normalized = Path.normalize('usr//local/../local/bin');

// Path components
console.log(Path.dirname('/usr/local/bin/node'));  // "/usr/local/bin"
console.log(Path.basename('/usr/local/bin/node')); // "node"
console.log(Path.extname('file.txt'));             // ".txt"

// Path checks
console.log(Path.isAbsolute('/usr/local'));        // true
console.log(Path.isAbsolute('local/bin'));         // false
```

### FileSystem API

Direct file system operations (non-web standard):

```javascript
// Directory information
console.log('Home:', SystemFS.home);
console.log('Temp:', SystemFS.temp);
console.log('CWD:', SystemFS.cwd);

// File operations
if (SystemFS.exists('/path/to/file')) {
    const content = SystemFS.readFile('/path/to/file');
    console.log('File content:', content);
}

// Binary file operations
const data = new Uint8Array([1, 2, 3, 4]);
SystemFS.writeFile('/tmp/binary.dat', data);
const readData = SystemFS.readFile('/tmp/binary.dat', { encoding: 'binary' });

// Directory operations
const files = SystemFS.readDir('/some/directory');
SystemFS.mkdir('/new/directory', { recursive: true });
SystemFS.rmdir('/old/directory', { recursive: true });

// File manipulation
SystemFS.copy('/source/file', '/dest/file');
SystemFS.move('/old/path', '/new/path');
SystemFS.remove('/file/to/delete');

// File stats
const stats = SystemFS.stat('/path/to/file');
console.log('Size:', stats.size);
console.log('Modified:', stats.lastModified);

// Streaming for large files
const readStream = SystemFS.createReadStream('/large/file');
const writeStream = SystemFS.createWriteStream('/output/file');

readStream.pipeTo(writeStream);

// Path utilities - use Path class instead of SystemFS methods
const fullPath = Path.join('/home', 'user', 'file.txt');
const dir = Path.dirname(fullPath);  // '/home/user'
const base = Path.basename(fullPath);  // 'file.txt'
const ext = Path.extname(fullPath);  // '.txt'
```
```

## Native Swift APIs

SwiftJS exposes Swift platform capabilities through internal native APIs. While the polyfill system uses an internal `__NATIVE_BRIDGE__` parameter (not a global object), user code should access these capabilities through the standard global APIs like `crypto`, `process`, etc.

**Note:** `__NATIVE_BRIDGE__` is an internal implementation detail passed as a private parameter to the polyfill system and is not exposed as a global object to user JavaScript code.

### Device Information

```javascript
// Access device info through process object (recommended)
console.log('Device model:', process.platform);
console.log('Process ID:', process.pid);

// Internal implementation (not recommended for user code):
// const deviceInfo = __NATIVE_BRIDGE__.deviceInfo;
// console.log('Device model:', deviceInfo.model);
// console.log('System name:', deviceInfo.systemName);
// console.log('System version:', deviceInfo.systemVersion);
```

### Process Information

```javascript
// Access process info through standard process object (recommended)
console.log('Process ID:', process.pid);
console.log('Arguments:', process.argv);
console.log('Environment:', process.env);

// Internal implementation (not recommended for user code):
// const processInfo = __NATIVE_BRIDGE__.processInfo;
// console.log('Process ID:', processInfo.processIdentifier);
// console.log('Arguments:', processInfo.arguments);
// console.log('Environment:', processInfo.environment);
```

### Cryptography

```javascript
// Generate random data
const uuid = crypto.randomUUID();
const randomBytes = crypto.randomBytes(32);

// Secure random for arrays
const buffer = new Uint8Array(16);
crypto.getRandomValues(buffer);
```

## Error Handling

### JavaScript Exceptions

SwiftJS captures JavaScript exceptions and provides proper error handling:

```swift
let js = SwiftJS()
js.evaluateScript("throw new Error('Something went wrong')")

let exception = js.exception
if !exception.isUndefined {
    print("JavaScript Error:", exception.toString())
    let stack = exception["stack"]
    if !stack.isUndefined {
        print("Stack trace:", stack.toString())
    }
}
```

### Custom Error Handling

```swift
let js = SwiftJS()
js.base.exceptionHandler = { context, exception in
    if let error = exception?.toString() {
        print("JavaScript Exception:", error)
    }
}
```

### Async Error Handling

```javascript
// Promise error handling
fetch('/api/data')
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        return response.json();
    })
    .catch(error => {
        console.error('Fetch failed:', error.message);
    });

// Async/await error handling
try {
    const response = await fetch('/api/data');
    const data = await response.json();
} catch (error) {
    if (error.name === 'AbortError') {
        console.log('Request was cancelled');
    } else {
        console.error('Request failed:', error.message);
    }
}
```

## Performance Considerations

### Value Bridging Performance

- Use appropriate value types to minimize conversion overhead
- Prefer `invokeMethod` over property access + `call` for JavaScript methods
- Cache frequently accessed objects in Swift variables

```swift
// ❌ Inefficient - multiple conversions
for i in 0..<1000 {
    js.globalObject["array"][i] = "value\(i)"
}

// ✅ Efficient - cache the array reference
let array = js.globalObject["array"]
for i in 0..<1000 {
    array[i] = "value\(i)"
}
```

### Memory Management

- JavaScript objects are automatically garbage collected
- SwiftJS.Value references don't prevent JavaScript GC
- Clean up large data structures when no longer needed

### Async Operations

- Use RunLoop integration for proper timer handling
- Avoid blocking the main thread with long-running JavaScript code
- Use streaming APIs for large data processing

```swift
let js = SwiftJS()

// Execute async JavaScript
js.evaluateScript("""
    setTimeout(() => {
        console.log('Timer executed');
    }, 1000);
""")

// Keep the RunLoop active for timers
RunLoop.main.run()
```

### Best Practices

1. **Method Calls**: Always use `invokeMethod` for JavaScript methods
2. **Object Literals**: Wrap object returns in parentheses: `({key: value})`
3. **Performance Testing**: Use `var` instead of `const`/`let` in measured code
4. **Error Handling**: Check for exceptions after script evaluation
5. **Resource Management**: Close streams and file handles properly
6. **Async Patterns**: Use proper Promise and async/await patterns

---

For more examples and advanced usage patterns, see the [examples](../examples/) directory.
