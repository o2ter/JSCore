# SwiftJS

**A powerful JavaScript runtime for Swift, built on Apple's JavaScriptCore**

SwiftJS provides a seamless bridge between Swift and JavaScript, offering Node.js-like APIs and web standards compliance. Execute JavaScript code from Swift with full access to native iOS/macOS capabilities including cryptography, file systems, networking, and more.

[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20macCatalyst%2017+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **🚀 High Performance**: Built on Apple's optimized JavaScriptCore engine
- **🌐 Web Standards**: Implements standard web APIs (Fetch, Crypto, Streams, etc.)
- **🔒 Security**: Full access to Swift Crypto for cryptographic operations
- **📁 File System**: Complete file system access with Node.js-like APIs
- **🌍 Networking**: HTTP/HTTPS requests with streaming support
- **⏰ Timers**: Full setTimeout/setInterval support with RunLoop integration
- **🔄 Value Bridging**: Seamless Swift ↔ JavaScript value conversion
- **📱 Platform Integration**: Native iOS/macOS device and process information
- **🧪 Testing**: Comprehensive test suite with performance benchmarks

## Installation

### Swift Package Manager

Add SwiftJS to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/o2ter/SwiftJS.git", from: "1.0.0")
]
```

### Xcode

1. File → Add Package Dependencies
2. Enter: `https://github.com/o2ter/SwiftJS.git`
3. Add to your target

## Quick Start

### Basic Usage

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

### Value Bridging

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

### Native APIs

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

### Async Operations

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

## SwiftJSRunner CLI

SwiftJS includes a command-line runner for executing JavaScript files:

```bash
# Execute a JavaScript file
swift run SwiftJSRunner script.js

# Execute JavaScript code directly
swift run SwiftJSRunner -e "console.log('Hello, World!')"

# Pass arguments to your script
swift run SwiftJSRunner script.js arg1 arg2
```

### Example Script

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

## Available APIs

SwiftJS provides comprehensive JavaScript APIs:

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
- **Native Crypto**: Direct access to Swift Crypto functions
- **HTTP Client**: Advanced networking with streaming support

## Platform Support

- **iOS 17.0+**
- **macOS 14.0+** 
- **Mac Catalyst 17.0+**
- **Swift 6.0+**

## Performance

SwiftJS is built for performance with:

- Native JavaScriptCore engine (same as Safari)
- Optimized value bridging with minimal overhead
- Streaming support for large data processing
- Efficient timer management with RunLoop integration
- Memory-safe operation with proper cleanup

See [Performance Guide](docs/Performance.md) for benchmarks and optimization tips.

## Architecture

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

## Testing

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

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Swift API design guidelines
- Prioritize web standards over Node.js-specific behaviors
- Include comprehensive tests for new features
- Update documentation for API changes
- Ensure compatibility across all supported platforms

## License

SwiftJS is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built on Apple's [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore)
- Crypto operations powered by [Swift Crypto](https://github.com/apple/swift-crypto)
- Networking with [Swift NIO](https://github.com/apple/swift-nio)
- HTTP client using [Async HTTP Client](https://github.com/swift-server/async-http-client)

---

**SwiftJS** - Bringing the power of JavaScript to Swift applications with native performance and platform integration.
