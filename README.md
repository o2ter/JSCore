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
| **Web APIs** | Fetch, Crypto, Streams, File, Compression, Performance, URLPattern | Fetch, Crypto, Streams, File, Compression, Performance, URLPattern |
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

// Compression Streams API
js.evaluateScript("""
    // Compress data using gzip
    const input = new TextEncoder().encode('Hello, World! This is a test string for compression.');
    
    const compressedStream = new ReadableStream({
        start(controller) {
            controller.enqueue(input);
            controller.close();
        }
    }).pipeThrough(new CompressionStream('gzip'));
    
    // Read compressed data
    const reader = compressedStream.getReader();
    const chunks = [];
    
    (async () => {
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            chunks.push(value);
        }
        
        console.log('Compressed size:', chunks.reduce((sum, chunk) => sum + chunk.length, 0));
        
        // Decompress the data
        const compressedData = chunks[0]; // For simplicity, assume single chunk
        const decompressedStream = new ReadableStream({
            start(controller) {
                controller.enqueue(compressedData);
                controller.close();
            }
        }).pipeThrough(new DecompressionStream('gzip'));
        
        const decompressedReader = decompressedStream.getReader();
        const decompressedChunks = [];
        
        while (true) {
            const { done, value } = await decompressedReader.read();
            if (done) break;
            decompressedChunks.push(value);
        }
        
        const output = new TextDecoder().decode(decompressedChunks[0]);
        console.log('Decompressed:', output); // "Hello, World! This is a test string for compression."
    })();
""")

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
./gradlew :jscore-runner:run --args="script.js"
```

## Available APIs

Both SwiftJS and KotlinJS provide comprehensive JavaScript APIs:

### Core JavaScript
- **ECMAScript 2023**: Full modern JavaScript support
- **Global objects**: Object, Array, Date, Math, JSON, etc.
- **Promises**: Native Promise support with async/await
- **Error handling**: Try/catch with proper stack traces

### Web APIs
- **Compression Streams**: `CompressionStream`, `DecompressionStream` for gzip, deflate, and deflate-raw compression
- **Crypto**: `crypto.randomUUID()`, `crypto.randomBytes()`, `crypto.getRandomValues()`
- **Console**: `console.log/warn/error/info` with proper formatting
- **Fetch**: `fetch()` for HTTP requests (core functionality, excludes browser security features)
- **Performance API**: `performance.now()`, `performance.mark()`, `performance.measure()` for high-resolution timing
- **TextEncoder/TextDecoder**: UTF-8 encoding/decoding with streaming support (`TextEncoderStream`, `TextDecoderStream`)
- **Timers**: `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval`
- **URLPattern**: URL pattern matching with named groups and wildcards for routing
- **WebSocket**: `WebSocket` for bidirectional real-time communication
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

## Compression Streams API

Both SwiftJS and KotlinJS implement the [Web Compression Streams API](https://wicg.github.io/compression/) standard, providing efficient streaming compression and decompression.

### Supported Formats

- **`gzip`**: GZIP compression (RFC 1952) - Industry-standard compression with CRC32 checksums
- **`deflate`**: DEFLATE with zlib wrapper (RFC 1950) - Includes Adler-32 checksums
- **`deflate-raw`**: Raw DEFLATE (RFC 1951) - No wrapper, maximum compatibility

### CompressionStream

Compresses data using the specified format:

```javascript
// Create a compression stream
const compressionStream = new CompressionStream('gzip');

// Compress text data
const input = new TextEncoder().encode('Hello, World!');
const readableStream = new ReadableStream({
    start(controller) {
        controller.enqueue(input);
        controller.close();
    }
});

// Pipe through compression
const compressedStream = readableStream.pipeThrough(compressionStream);

// Read compressed data
const reader = compressedStream.getReader();
const chunks = [];

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
}

// Combine chunks
const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
const compressed = new Uint8Array(totalLength);
let offset = 0;
for (const chunk of chunks) {
    compressed.set(chunk, offset);
    offset += chunk.length;
}

console.log('Original size:', input.length);
console.log('Compressed size:', compressed.length);
```

### DecompressionStream

Decompresses data using the specified format:

```javascript
// Create a decompression stream
const decompressionStream = new DecompressionStream('gzip');

// Decompress data
const compressedStream = new ReadableStream({
    start(controller) {
        controller.enqueue(compressed); // Previously compressed data
        controller.close();
    }
});

// Pipe through decompression
const decompressedStream = compressedStream.pipeThrough(decompressionStream);

// Read decompressed data
const reader = decompressedStream.getReader();
const chunks = [];

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
}

// Decode result
const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
const decompressed = new Uint8Array(totalLength);
let offset = 0;
for (const chunk of chunks) {
    decompressed.set(chunk, offset);
    offset += chunk.length;
}

const output = new TextDecoder().decode(decompressed);
console.log('Decompressed:', output); // "Hello, World!"
```

### Practical Examples

#### Compress and Save to File (SwiftJS)

```javascript
const data = 'Large text content...'.repeat(1000);
const input = new TextEncoder().encode(data);

const compressedStream = new ReadableStream({
    start(controller) {
        controller.enqueue(input);
        controller.close();
    }
}).pipeThrough(new CompressionStream('gzip'));

// Read all compressed chunks
const reader = compressedStream.getReader();
const chunks = [];

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
}

// Combine and save
const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
const compressed = new Uint8Array(totalLength);
let offset = 0;
for (const chunk of chunks) {
    compressed.set(chunk, offset);
    offset += chunk.length;
}

SystemFS.writeFile('/tmp/data.gz', compressed);
console.log('Compression ratio:', (compressed.length / input.length * 100).toFixed(2) + '%');
```

#### HTTP Response Compression

```javascript
// Compress data before sending
async function compressResponse(data) {
    const input = new TextEncoder().encode(JSON.stringify(data));
    
    const compressedStream = new ReadableStream({
        start(controller) {
            controller.enqueue(input);
            controller.close();
        }
    }).pipeThrough(new CompressionStream('gzip'));
    
    const reader = compressedStream.getReader();
    const chunks = [];
    
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
    }
    
    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const compressed = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of chunks) {
        compressed.set(chunk, offset);
        offset += chunk.length;
    }
    
    return compressed;
}

// Usage
const response = { message: 'Hello', data: [1, 2, 3] };
const compressed = await compressResponse(response);
console.log('Compressed size:', compressed.length, 'bytes');
```

#### Format Comparison

```javascript
async function compareFormats(text) {
    const input = new TextEncoder().encode(text);
    const formats = ['gzip', 'deflate', 'deflate-raw'];
    
    for (const format of formats) {
        const compressed = await compress(input, format);
        console.log(`${format}: ${compressed.length} bytes (${(compressed.length/input.length*100).toFixed(1)}%)`);
    }
}

async function compress(data, format) {
    const stream = new ReadableStream({
        start(controller) {
            controller.enqueue(data);
            controller.close();
        }
    }).pipeThrough(new CompressionStream(format));
    
    const reader = stream.getReader();
    const chunks = [];
    
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
    }
    
    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of chunks) {
        result.set(chunk, offset);
        offset += chunk.length;
    }
    
    return result;
}

// Compare compression ratios
compareFormats('Lorem ipsum dolor sit amet...'.repeat(100));
```

### Error Handling

```javascript
try {
    // Invalid format
    const stream = new CompressionStream('invalid-format');
} catch (error) {
    console.error('Error:', error.message); // "Unsupported compression format"
}

try {
    // Decompressing invalid data
    const decompressStream = new DecompressionStream('gzip');
    const invalidData = new Uint8Array([1, 2, 3, 4, 5]);
    
    const stream = new ReadableStream({
        start(controller) {
            controller.enqueue(invalidData);
            controller.close();
        }
    }).pipeThrough(decompressStream);
    
    const reader = stream.getReader();
    await reader.read(); // May throw decompression error
} catch (error) {
    console.error('Decompression failed:', error.message);
}
```

### Performance Considerations

1. **Streaming is efficient**: Use streams for large data to avoid loading everything into memory
2. **Format selection**:
   - `gzip`: Best for file storage and HTTP compression (widely compatible)
   - `deflate`: Good balance of compression and speed
   - `deflate-raw`: Maximum compatibility, lowest overhead
3. **Compression ratio**: Longer text compresses better (minimum ~100 bytes for effective compression)
4. **Chunk processing**: Process data in chunks for better memory efficiency

### Platform-Specific Implementation

**SwiftJS**: Uses Apple's Compression framework with native performance on iOS/macOS
**KotlinJS**: Uses Java's GZIPOutputStream, DeflaterOutputStream, and Inflater for JVM/Android

Both implementations provide identical JavaScript APIs and behavior, ensuring cross-platform compatibility.

## Performance API

Both SwiftJS and KotlinJS implement the [User Timing API](https://w3c.github.io/user-timing/) standard, providing high-resolution timing measurements for performance monitoring.

### Overview

The Performance API enables precise measurement of code execution time, useful for:
- **Benchmarking**: Measure algorithm performance
- **Profiling**: Identify bottlenecks in your code
- **Monitoring**: Track application performance over time
- **Optimization**: Validate performance improvements

### High-Resolution Timing

#### performance.now()

Returns the current high-resolution timestamp in milliseconds:

```javascript
const start = performance.now();

// Execute some code
for (let i = 0; i < 1000000; i++) {
    Math.sqrt(i);
}

const end = performance.now();
console.log(`Execution took ${end - start} milliseconds`);
// Output: "Execution took 12.345 milliseconds"
```

**Resolution:**
- **SwiftJS**: Microsecond precision using `CACurrentMediaTime()`
- **KotlinJS**: Microsecond precision using `System.nanoTime()`

Both provide sub-millisecond accuracy for precise measurements.

### Performance Marks

#### performance.mark(name)

Creates a named timestamp marker:

```javascript
performance.mark('start-fetch');

const response = await fetch('https://api.example.com/data');
const data = await response.json();

performance.mark('end-fetch');

// Marks are stored for later measurement
console.log('Marks created');
```

### Performance Measures

#### performance.measure(name, startMark, endMark)

Calculates the duration between two marks:

```javascript
performance.mark('task-start');

// Perform some task
await processData();

performance.mark('task-end');

// Measure the duration
performance.measure('task-duration', 'task-start', 'task-end');

// Retrieve the measurement
const measures = performance.getEntriesByName('task-duration');
console.log(`Task took ${measures[0].duration} ms`);
```

### Retrieving Performance Entries

#### performance.getEntries()

Returns all performance entries (marks and measures):

```javascript
performance.mark('mark1');
performance.mark('mark2');
performance.measure('measure1', 'mark1', 'mark2');

const entries = performance.getEntries();
entries.forEach(entry => {
    console.log(`${entry.entryType}: ${entry.name} - ${entry.duration || 0}ms`);
});
// Output:
// "mark: mark1 - 0ms"
// "mark: mark2 - 0ms"
// "measure: measure1 - 5.123ms"
```

#### performance.getEntriesByType(type)

Returns entries of a specific type (`"mark"` or `"measure"`):

```javascript
const marks = performance.getEntriesByType('mark');
marks.forEach(mark => {
    console.log(`Mark: ${mark.name} at ${mark.startTime}ms`);
});

const measures = performance.getEntriesByType('measure');
measures.forEach(measure => {
    console.log(`Measure: ${measure.name} took ${measure.duration}ms`);
});
```

#### performance.getEntriesByName(name)

Returns all entries with a specific name:

```javascript
performance.mark('checkpoint');
performance.mark('checkpoint');  // Same name, different time
performance.mark('checkpoint');

const checkpoints = performance.getEntriesByName('checkpoint');
console.log(`Found ${checkpoints.length} checkpoints`);
// Output: "Found 3 checkpoints"

checkpoints.forEach((checkpoint, i) => {
    console.log(`Checkpoint ${i + 1}: ${checkpoint.startTime}ms`);
});
```

### Clearing Performance Entries

#### performance.clearMarks([name])

Clears performance marks:

```javascript
performance.mark('mark1');
performance.mark('mark2');

// Clear specific mark
performance.clearMarks('mark1');

// Clear all marks
performance.clearMarks();
```

#### performance.clearMeasures([name])

Clears performance measures:

```javascript
performance.measure('measure1', 'start', 'end');
performance.measure('measure2', 'start', 'end');

// Clear specific measure
performance.clearMeasures('measure1');

// Clear all measures
performance.clearMeasures();
```

### Practical Examples

#### Benchmarking Function Performance

```javascript
function benchmarkFunction(fn, iterations = 1000) {
    const markName = `bench-${Date.now()}`;
    const startMark = `${markName}-start`;
    const endMark = `${markName}-end`;
    const measureName = `${markName}-measure`;
    
    performance.mark(startMark);
    
    for (let i = 0; i < iterations; i++) {
        fn();
    }
    
    performance.mark(endMark);
    performance.measure(measureName, startMark, endMark);
    
    const measure = performance.getEntriesByName(measureName)[0];
    const avgTime = measure.duration / iterations;
    
    console.log(`Total: ${measure.duration.toFixed(3)}ms`);
    console.log(`Average: ${avgTime.toFixed(6)}ms per call`);
    
    // Cleanup
    performance.clearMarks(startMark);
    performance.clearMarks(endMark);
    performance.clearMeasures(measureName);
}

// Usage
benchmarkFunction(() => Math.sqrt(12345), 10000);
```

#### Multi-Stage Operation Tracking

```javascript
async function processWithTiming() {
    performance.mark('overall-start');
    
    // Stage 1: Fetch data
    performance.mark('fetch-start');
    const response = await fetch('https://api.example.com/data');
    const data = await response.json();
    performance.mark('fetch-end');
    performance.measure('fetch-duration', 'fetch-start', 'fetch-end');
    
    // Stage 2: Process data
    performance.mark('process-start');
    const processed = data.map(item => transform(item));
    performance.mark('process-end');
    performance.measure('process-duration', 'process-start', 'process-end');
    
    // Stage 3: Save results
    performance.mark('save-start');
    await saveResults(processed);
    performance.mark('save-end');
    performance.measure('save-duration', 'save-start', 'save-end');
    
    // Overall timing
    performance.mark('overall-end');
    performance.measure('total-duration', 'overall-start', 'overall-end');
    
    // Report results
    const measures = performance.getEntriesByType('measure');
    measures.forEach(measure => {
        console.log(`${measure.name}: ${measure.duration.toFixed(2)}ms`);
    });
}
```

#### Performance Monitoring Dashboard

```javascript
class PerformanceMonitor {
    constructor() {
        this.operations = new Map();
    }
    
    start(operationName) {
        const startMark = `${operationName}-start`;
        performance.mark(startMark);
        this.operations.set(operationName, { startMark });
    }
    
    end(operationName) {
        const op = this.operations.get(operationName);
        if (!op) {
            console.error(`No operation found: ${operationName}`);
            return;
        }
        
        const endMark = `${operationName}-end`;
        const measureName = `${operationName}-measure`;
        
        performance.mark(endMark);
        performance.measure(measureName, op.startMark, endMark);
        
        const measure = performance.getEntriesByName(measureName)[0];
        op.duration = measure.duration;
        op.endMark = endMark;
        op.measureName = measureName;
    }
    
    getReport() {
        const report = [];
        for (const [name, op] of this.operations) {
            if (op.duration !== undefined) {
                report.push({
                    operation: name,
                    duration: op.duration,
                    timestamp: new Date().toISOString()
                });
            }
        }
        return report;
    }
    
    clear() {
        for (const op of this.operations.values()) {
            if (op.startMark) performance.clearMarks(op.startMark);
            if (op.endMark) performance.clearMarks(op.endMark);
            if (op.measureName) performance.clearMeasures(op.measureName);
        }
        this.operations.clear();
    }
}

// Usage
const monitor = new PerformanceMonitor();

monitor.start('database-query');
await queryDatabase();
monitor.end('database-query');

monitor.start('image-processing');
await processImages();
monitor.end('image-processing');

console.log(JSON.stringify(monitor.getReport(), null, 2));
monitor.clear();
```

### Performance Entry Properties

Each performance entry (mark or measure) has the following properties:

```javascript
{
    name: string,           // Entry name
    entryType: string,      // "mark" or "measure"
    startTime: number,      // Start timestamp (ms)
    duration: number        // Duration (0 for marks, calculated for measures)
}
```

### Platform-Specific Implementation

**SwiftJS**: Uses `CACurrentMediaTime()` for high-resolution timing, thread-safe with `NSLock`
**KotlinJS**: Uses `System.nanoTime()` for nanosecond precision, thread-safe with `ConcurrentHashMap`

Both implementations provide identical JavaScript APIs and sub-millisecond accuracy.

## TextEncoderStream and TextDecoderStream

SwiftJS and KotlinJS implement streaming text encoding and decoding using the [Encoding API](https://encoding.spec.whatwg.org/) standard.

### Overview

Text streaming is essential for:
- **Large file processing**: Encode/decode files without loading into memory
- **Network streaming**: Handle text data from HTTP responses progressively
- **Pipeline efficiency**: Chain with other transform streams
- **Memory optimization**: Process data in chunks rather than all at once

### TextEncoderStream

Encodes a stream of strings into UTF-8 bytes:

```javascript
const encoder = new TextEncoderStream();

// Create a text source
const textStream = new ReadableStream({
    start(controller) {
        controller.enqueue('Hello, ');
        controller.enqueue('World!');
        controller.enqueue(' 你好世界');
        controller.close();
    }
});

// Pipe through encoder
const encodedStream = textStream.pipeThrough(encoder);

// Read encoded bytes
const reader = encodedStream.getReader();
while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    console.log('Encoded bytes:', value);
    // Uint8Array containing UTF-8 encoded bytes
}
```

### TextDecoderStream

Decodes a stream of UTF-8 bytes into strings:

```javascript
const decoder = new TextDecoderStream();

// Create a byte source
const byteStream = new ReadableStream({
    start(controller) {
        const bytes1 = new TextEncoder().encode('Hello, ');
        const bytes2 = new TextEncoder().encode('World!');
        controller.enqueue(bytes1);
        controller.enqueue(bytes2);
        controller.close();
    }
});

// Pipe through decoder
const decodedStream = byteStream.pipeThrough(decoder);

// Read decoded text
const reader = decodedStream.getReader();
const chunks = [];
while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
}

const text = chunks.join('');
console.log('Decoded text:', text);
// Output: "Hello, World!"
```

### Handling Multi-Byte Characters

TextDecoderStream correctly handles multi-byte UTF-8 sequences split across chunks:

```javascript
const decoder = new TextDecoderStream();

// Simulate split multi-byte character (你 = 0xE4 0xBD 0xA0)
const byteStream = new ReadableStream({
    start(controller) {
        controller.enqueue(new Uint8Array([0xE4]));        // First byte
        controller.enqueue(new Uint8Array([0xBD, 0xA0]));  // Remaining bytes
        controller.close();
    }
});

const decodedStream = byteStream.pipeThrough(decoder);
const reader = decodedStream.getReader();

// First read returns empty (incomplete character)
const { value: first } = await reader.read();
console.log('First chunk:', first); // "" (buffered incomplete sequence)

// Second read completes the character
const { value: second } = await reader.read();
console.log('Second chunk:', second); // "你"
```

### Practical Examples

#### Processing Large Text Files

```javascript
async function processLargeFile(filePath) {
    // Read file as byte stream
    const fileData = SystemFS.readFile(filePath);
    
    const byteStream = new ReadableStream({
        start(controller) {
            // Process in 1KB chunks
            const chunkSize = 1024;
            for (let i = 0; i < fileData.length; i += chunkSize) {
                const chunk = fileData.slice(i, i + chunkSize);
                controller.enqueue(chunk);
            }
            controller.close();
        }
    });
    
    // Decode to text
    const textStream = byteStream.pipeThrough(new TextDecoderStream());
    
    // Process line by line
    const reader = textStream.getReader();
    let buffer = '';
    let lineCount = 0;
    
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        buffer += value;
        const lines = buffer.split('\n');
        buffer = lines.pop(); // Keep incomplete line in buffer
        
        lineCount += lines.length;
    }
    
    console.log(`Processed ${lineCount} lines`);
}
```

#### HTTP Response Text Streaming

```javascript
async function streamTextResponse(url) {
    const response = await fetch(url);
    
    // Get response body as stream
    const bodyStream = response.body;
    
    // Decode bytes to text
    const textStream = bodyStream.pipeThrough(new TextDecoderStream());
    
    // Process text chunks as they arrive
    const reader = textStream.getReader();
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        // Process each text chunk immediately
        console.log('Received text chunk:', value);
        processChunk(value);
    }
}
```

#### Bidirectional Text/Byte Conversion Pipeline

```javascript
async function roundTripPipeline(text) {
    // Create text stream
    const textStream = new ReadableStream({
        start(controller) {
            controller.enqueue(text);
            controller.close();
        }
    });
    
    // Encode to bytes
    const encodedStream = textStream
        .pipeThrough(new TextEncoderStream());
    
    // Decode back to text
    const decodedStream = encodedStream
        .pipeThrough(new TextDecoderStream());
    
    // Read result
    const reader = decodedStream.getReader();
    const { value } = await reader.read();
    
    console.log('Original:', text);
    console.log('Round-trip:', value);
    console.log('Match:', text === value); // true
}

await roundTripPipeline('Hello, 世界! 🌍');
```

#### Compress and Encode Text Stream

```javascript
async function compressText(text) {
    // Create text source
    const textStream = new ReadableStream({
        start(controller) {
            controller.enqueue(text);
            controller.close();
        }
    });
    
    // Pipeline: Text → Bytes → Compressed Bytes
    const compressedStream = textStream
        .pipeThrough(new TextEncoderStream())
        .pipeThrough(new CompressionStream('gzip'));
    
    // Read compressed data
    const reader = compressedStream.getReader();
    const chunks = [];
    
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
    }
    
    // Combine chunks
    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const compressed = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of chunks) {
        compressed.set(chunk, offset);
        offset += chunk.length;
    }
    
    const originalSize = new TextEncoder().encode(text).length;
    console.log(`Original: ${originalSize} bytes`);
    console.log(`Compressed: ${compressed.length} bytes`);
    console.log(`Ratio: ${(compressed.length / originalSize * 100).toFixed(1)}%`);
    
    return compressed;
}
```

### Encoding Options

TextDecoderStream supports various encoding options:

```javascript
// Default UTF-8 decoder
const decoder = new TextDecoderStream();

// With specific encoding (UTF-8 is default and only widely supported)
const utf8Decoder = new TextDecoderStream('utf-8');

// Fatal mode (throw on invalid sequences)
const strictDecoder = new TextDecoderStream('utf-8', { fatal: true });

// Ignore BOM (byte order mark)
const noBomDecoder = new TextDecoderStream('utf-8', { ignoreBOM: true });
```

### Platform-Specific Implementation

Both SwiftJS and KotlinJS implement these streams as pure JavaScript using:
- `TransformStream` for streaming infrastructure
- `TextEncoder` and `TextDecoder` for the actual encoding/decoding
- Proper handling of incomplete UTF-8 sequences across chunk boundaries

The implementation is identical across both platforms, ensuring consistent behavior.

## URLPattern API

SwiftJS and KotlinJS implement the [URLPattern API](https://developer.mozilla.org/en-US/docs/Web/API/URLPattern) for powerful URL pattern matching and routing.

### Overview

URLPattern enables:
- **Route matching**: Define URL patterns with parameters
- **Parameter extraction**: Capture named parameters from URLs
- **Wildcard matching**: Match flexible URL structures
- **URL validation**: Test if URLs match specific patterns
- **Routing**: Build client and server-side routers

### Basic Usage

#### Creating URL Patterns

```javascript
// Simple pattern
const pattern = new URLPattern({ pathname: '/users/:id' });

// Full URL pattern
const fullPattern = new URLPattern({
    protocol: 'https',
    hostname: 'example.com',
    pathname: '/api/:version/users/:id'
});

// Shorthand string pattern
const stringPattern = new URLPattern('/posts/:postId/comments/:commentId');
```

#### Testing URLs

```javascript
const pattern = new URLPattern({ pathname: '/users/:id' });

// Test if URL matches
console.log(pattern.test({ pathname: '/users/123' }));        // true
console.log(pattern.test({ pathname: '/users/abc' }));        // true
console.log(pattern.test({ pathname: '/posts/123' }));        // false
console.log(pattern.test({ pathname: '/users' }));            // false
```

#### Extracting Parameters

```javascript
const pattern = new URLPattern({ pathname: '/users/:userId/posts/:postId' });

const result = pattern.exec({ pathname: '/users/42/posts/100' });

console.log(result.pathname.groups);
// Output: { userId: '42', postId: '100' }

console.log(result.pathname.groups.userId);   // '42'
console.log(result.pathname.groups.postId);   // '100'
```

### Pattern Syntax

#### Named Parameters

Capture parts of the URL with named parameters:

```javascript
const pattern = new URLPattern({ pathname: '/products/:category/:id' });

const result = pattern.exec({ pathname: '/products/electronics/laptop-123' });
console.log(result.pathname.groups);
// { category: 'electronics', id: 'laptop-123' }
```

#### Wildcards

Use `*` for single segment or `**` for multiple segments:

```javascript
// Single segment wildcard
const singleWild = new URLPattern({ pathname: '/files/*' });
console.log(singleWild.test({ pathname: '/files/document.pdf' }));     // true
console.log(singleWild.test({ pathname: '/files/folder/doc.pdf' }));   // false

// Multi-segment wildcard
const multiWild = new URLPattern({ pathname: '/files/**' });
console.log(multiWild.test({ pathname: '/files/document.pdf' }));      // true
console.log(multiWild.test({ pathname: '/files/folder/doc.pdf' }));    // true
console.log(multiWild.test({ pathname: '/files/a/b/c/doc.pdf' }));     // true
```

#### Optional Segments

Use `?` for optional parameters:

```javascript
const pattern = new URLPattern({ pathname: '/users/:id/:action?' });

console.log(pattern.test({ pathname: '/users/123' }));         // true
console.log(pattern.test({ pathname: '/users/123/edit' }));    // true

const result1 = pattern.exec({ pathname: '/users/123' });
console.log(result1.pathname.groups);  // { id: '123', action: undefined }

const result2 = pattern.exec({ pathname: '/users/123/edit' });
console.log(result2.pathname.groups);  // { id: '123', action: 'edit' }
```

#### Regular Expression Constraints

Constrain parameter values with regex:

```javascript
const pattern = new URLPattern({ pathname: '/users/:id(\\d+)' });

console.log(pattern.test({ pathname: '/users/123' }));    // true
console.log(pattern.test({ pathname: '/users/abc' }));    // false

const result = pattern.exec({ pathname: '/users/456' });
console.log(result.pathname.groups.id);  // '456'
```

### Practical Examples

#### Building a Router

```javascript
class Router {
    constructor() {
        this.routes = [];
    }
    
    addRoute(pattern, handler) {
        this.routes.push({
            pattern: new URLPattern({ pathname: pattern }),
            handler
        });
    }
    
    match(pathname) {
        for (const route of this.routes) {
            const result = route.pattern.exec({ pathname });
            if (result) {
                return {
                    handler: route.handler,
                    params: result.pathname.groups
                };
            }
        }
        return null;
    }
    
    async handle(pathname) {
        const match = this.match(pathname);
        if (match) {
            return await match.handler(match.params);
        }
        throw new Error('Route not found');
    }
}

// Usage
const router = new Router();

router.addRoute('/users/:id', async (params) => {
    return `User profile for ID: ${params.id}`;
});

router.addRoute('/posts/:postId/comments/:commentId', async (params) => {
    return `Comment ${params.commentId} on post ${params.postId}`;
});

router.addRoute('/api/:version/**', async (params) => {
    return `API version ${params.version}`;
});

// Route requests
const result1 = await router.handle('/users/123');
console.log(result1);  // "User profile for ID: 123"

const result2 = await router.handle('/posts/42/comments/7');
console.log(result2);  // "Comment 7 on post 42"
```

#### API Versioning

```javascript
const patterns = {
    v1: new URLPattern({ pathname: '/api/v1/**' }),
    v2: new URLPattern({ pathname: '/api/v2/**' }),
    latest: new URLPattern({ pathname: '/api/latest/**' })
};

function routeApiRequest(pathname) {
    if (patterns.v1.test({ pathname })) {
        return handleV1(pathname);
    } else if (patterns.v2.test({ pathname })) {
        return handleV2(pathname);
    } else if (patterns.latest.test({ pathname })) {
        return handleLatest(pathname);
    } else {
        throw new Error('Unknown API version');
    }
}
```

#### Resource Pattern Matching

```javascript
const resourcePattern = new URLPattern({
    pathname: '/:resourceType/:id/:action?'
});

function handleResourceRequest(pathname) {
    const result = resourcePattern.exec({ pathname });
    
    if (!result) {
        return { error: 'Invalid resource URL' };
    }
    
    const { resourceType, id, action } = result.pathname.groups;
    
    return {
        resourceType,
        id,
        action: action || 'view',
        operation: action ? `${action}-${resourceType}` : `view-${resourceType}`
    };
}

console.log(handleResourceRequest('/posts/123'));
// { resourceType: 'posts', id: '123', action: 'view', operation: 'view-posts' }

console.log(handleResourceRequest('/users/456/edit'));
// { resourceType: 'users', id: '456', action: 'edit', operation: 'edit-users' }
```

#### File Path Matching

```javascript
const patterns = {
    image: new URLPattern({ pathname: '/uploads/images/:filename.(jpg|png|gif)' }),
    document: new URLPattern({ pathname: '/uploads/docs/:filename.pdf' }),
    anyFile: new URLPattern({ pathname: '/uploads/**/:filename' })
};

function categorizeUpload(pathname) {
    if (patterns.image.test({ pathname })) {
        const result = patterns.image.exec({ pathname });
        return { type: 'image', filename: result.pathname.groups.filename };
    } else if (patterns.document.test({ pathname })) {
        const result = patterns.document.exec({ pathname });
        return { type: 'document', filename: result.pathname.groups.filename };
    } else if (patterns.anyFile.test({ pathname })) {
        const result = patterns.anyFile.exec({ pathname });
        return { type: 'unknown', filename: result.pathname.groups.filename };
    }
    return { type: 'invalid' };
}
```

#### URL Rewriting

```javascript
class URLRewriter {
    constructor() {
        this.rules = [];
    }
    
    addRule(pattern, rewrite) {
        this.rules.push({
            pattern: new URLPattern({ pathname: pattern }),
            rewrite
        });
    }
    
    rewrite(pathname) {
        for (const rule of this.rules) {
            const result = rule.pattern.exec({ pathname });
            if (result) {
                return rule.rewrite(result.pathname.groups);
            }
        }
        return pathname;
    }
}

// Usage
const rewriter = new URLRewriter();

// Rewrite legacy URLs to new format
rewriter.addRule('/old/users/:id', (params) => `/users/${params.id}`);
rewriter.addRule('/blog/:year/:month/:slug', (params) => 
    `/posts/${params.year}-${params.month}/${params.slug}`
);

console.log(rewriter.rewrite('/old/users/123'));
// Output: "/users/123"

console.log(rewriter.rewrite('/blog/2024/03/hello-world'));
// Output: "/posts/2024-03/hello-world"
```

### Full URL Matching

URLPattern can match all URL components:

```javascript
const pattern = new URLPattern({
    protocol: 'https',
    hostname: ':subdomain.example.com',
    pathname: '/api/:version/**',
    search: '*',
    hash: '*'
});

const result = pattern.exec({
    protocol: 'https',
    hostname: 'api.example.com',
    pathname: '/api/v2/users/123',
    search: '?sort=name',
    hash: '#details'
});

console.log(result.hostname.groups);  // { subdomain: 'api' }
console.log(result.pathname.groups);  // { version: 'v2' }
```

### URLPattern Result Structure

The `exec()` method returns an object with detailed match information:

```javascript
const pattern = new URLPattern({ pathname: '/users/:id' });
const result = pattern.exec({ pathname: '/users/123' });

console.log(result);
// {
//   pathname: {
//     input: '/users/123',
//     groups: { id: '123' }
//   },
//   protocol: { input: '', groups: {} },
//   hostname: { input: '', groups: {} },
//   port: { input: '', groups: {} },
//   search: { input: '', groups: {} },
//   hash: { input: '', groups: {} }
// }
```

### Platform-Specific Implementation

Both SwiftJS and KotlinJS implement URLPattern as pure JavaScript using:
- Regular expression compilation for pattern matching
- Named capture groups for parameter extraction
- Wildcard expansion for flexible matching
- Full URL component support (protocol, hostname, pathname, search, hash)

The implementation is identical across both platforms, ensuring consistent routing behavior.

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
5. Verify functionality: `./gradlew :jscore-runner:run --args="script.js"`
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
