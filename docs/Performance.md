# SwiftJS Performance Guide

This guide covers performance optimization, best practices, and common pitfalls when usin### JavaScript Best Practices

#### Threading Model Understanding

**IMPORTANT**: SwiftJS timer operations called from JavaScript callbacks are thread-safe by design:

```javascript
// ✅ SAFE - timer creation from Promise callback
fetch('/api/data').then(response => {
    setTimeout(() => {
        console.log('Timer from Promise callback works correctly');
    }, 100);
});

// ✅ SAFE - timer operations from any JavaScript context
Promise.resolve().then(() => {
    const id = setTimeout(() => console.log('Timer fired'), 100);
    clearTimeout(id); // Also safe
});
```

**Why**: JavaScript callbacks always execute on the JavaScript context's single thread, making timer operations inherently thread-safe when called from JavaScript code.

#### Variable Declarations in Performance TestswiftJS.

## Table of Contents

- [Performance Fundamentals](#performance-fundamentals)
- [Value Bridging Optimization](#value-bridging-optimization)
- [JavaScript Best Practices](#javascript-best-practices)
- [Memory Management](#memory-management)
- [Async Operations](#async-operations)
- [File System Performance](#file-system-performance)
- [Networking Optimization](#networking-optimization)
- [Common Pitfalls](#common-pitfalls)
- [Benchmarking](#benchmarking)

## Performance Fundamentals

### SwiftJS Architecture Impact

SwiftJS performance is influenced by several layers:

```
JavaScript Code
    ↓ (Value Conversion)
SwiftJS Bridge
    ↓ (Native Calls)
Swift Libraries
    ↓ (System Calls)
Platform APIs
```

**Key Principle**: Minimize cross-layer transitions for best performance.

### JavaScriptCore Engine

SwiftJS uses Apple's JavaScriptCore, the same engine that powers Safari:

- **JIT Compilation**: Code is compiled to native machine code
- **Garbage Collection**: Automatic memory management
- **Optimization**: Modern JavaScript optimizations (inline caching, etc.)

## Value Bridging Optimization

### Efficient Value Conversion

Value conversion between Swift and JavaScript has overhead. Optimize by:

#### Cache Object References

```swift
// ❌ Inefficient - repeated conversions
for i in 0..<1000 {
    js.globalObject["array"][i] = "value\(i)"
}

// ✅ Efficient - cache the array reference
let array = js.globalObject["array"]
for i in 0..<1000 {
    array[i] = "value\(i)"
}
```

#### Batch Operations

```swift
// ❌ Inefficient - individual property sets
js.globalObject["a"] = 1
js.globalObject["b"] = 2
js.globalObject["c"] = 3

// ✅ Efficient - batch as object
js.globalObject["config"] = ["a": 1, "b": 2, "c": 3]
```

#### Use Appropriate Types

```swift
// ❌ Inefficient - unnecessary string conversion
let numbers = [1, 2, 3, 4, 5]
js.globalObject["data"] = numbers.map { "\($0)" }

// ✅ Efficient - direct number array
js.globalObject["data"] = numbers
```

### Method Invocation Performance

#### Always Use invokeMethod for JavaScript Methods

```swift
// ❌ WRONG - loses 'this' context, causes errors
let method = object["methodName"]
let result = method.call(withArguments: [])

// ✅ CORRECT - preserves 'this' context, more efficient
let result = object.invokeMethod("methodName", withArguments: [])
```

**Why**: `invokeMethod` is both correct and more efficient as it:
- Preserves JavaScript `this` binding
- Avoids unnecessary method extraction
- Uses optimized native call path

#### Minimize Argument Conversions

```swift
// ❌ Inefficient - each argument converted separately
let result = object.invokeMethod("process", withArguments: [
    complexObject1, complexObject2, complexObject3
])

// ✅ Efficient - batch arguments as single object
let result = object.invokeMethod("process", withArguments: [
    ["data1": complexObject1, "data2": complexObject2, "data3": complexObject3]
])
```

## JavaScript Best Practices

### Variable Declarations in Performance Tests

When using XCTest `measure` blocks or repeated execution:

```javascript
// ❌ WRONG - causes SyntaxError on repeated runs
const data = [1, 2, 3];

// ✅ CORRECT - works with repeated execution
var data = [1, 2, 3];
```

**Why**: `const` and `let` cannot be redeclared in the same scope, but `var` can be.

### Object Literal vs Block Statement

**CRITICAL**: Always wrap object literals in parentheses when they're the main return value:

```javascript
// ❌ WRONG - parsed as block statement, returns undefined
{
    original: original,
    encoded: encoded,
    decoded: decoded
}

// ✅ CORRECT - parsed as object literal
({
    original: original,
    encoded: encoded,
    decoded: decoded
})
```

**Performance Impact**: This prevents mysterious `undefined` returns that can break your application logic.

### Efficient Array Operations

```javascript
// ❌ Inefficient - creates intermediate arrays
const result = data
    .map(x => x * 2)
    .filter(x => x > 10)
    .reduce((a, b) => a + b, 0);

// ✅ Efficient - single pass
let result = 0;
for (const x of data) {
    const doubled = x * 2;
    if (doubled > 10) {
        result += doubled;
    }
}
```

### String Concatenation

```javascript
// ❌ Inefficient for many strings
let result = "";
for (let i = 0; i < 1000; i++) {
    result += `item ${i}\n`;
}

// ✅ Efficient - use array join
const parts = [];
for (let i = 0; i < 1000; i++) {
    parts.push(`item ${i}`);
}
const result = parts.join('\n');
```

## Memory Management

### JavaScript Garbage Collection

SwiftJS uses JavaScriptCore's garbage collector:

- **Generational GC**: Young objects collected more frequently
- **Incremental GC**: Reduces pause times
- **Weak References**: Automatic cleanup of unused objects

### Best Practices

#### Avoid Memory Leaks

```javascript
// ❌ Memory leak - timer keeps running
setInterval(() => {
    console.log('Running...');
}, 1000);

// ✅ Proper cleanup
const intervalId = setInterval(() => {
    console.log('Running...');
}, 1000);

// Clean up when done
setTimeout(() => {
    clearInterval(intervalId);
}, 10000);
```

#### Large Object Cleanup

```javascript
// ❌ Keeps large objects in memory
function processLargeData() {
    const largeArray = new Array(1000000).fill(0);
    // ... process data
    return result;
}

// ✅ Explicit cleanup for large objects
function processLargeData() {
    let largeArray = new Array(1000000).fill(0);
    // ... process data
    largeArray = null; // Help GC
    return result;
}
```

#### Event Listener Cleanup

```javascript
// ❌ Memory leak - listeners not removed
function setupHandlers() {
    document.addEventListener('click', handler);
}

// ✅ Proper cleanup
function setupHandlers() {
    const controller = new AbortController();
    document.addEventListener('click', handler, {
        signal: controller.signal
    });
    
    // Later: controller.abort(); // Removes all listeners
}
```

### Swift-Side Memory Management

```swift
// ❌ Potential retain cycles
class MyClass {
    let js = SwiftJS()
    
    init() {
        js.globalObject["callback"] = { [weak self] in
            // This creates a retain cycle if not weak
            self?.someMethod()
        }
    }
}

// ✅ Use weak references
class MyClass {
    let js = SwiftJS()
    
    init() {
        js.globalObject["callback"] = { [weak self] in
            self?.someMethod()
        }
    }
}
```

## Async Operations

### Timer Performance

```javascript
// ❌ Inefficient - many small timers
for (let i = 0; i < 100; i++) {
    setTimeout(() => {
        console.log(i);
    }, i * 10);
}

// ✅ Efficient - single timer with state
let i = 0;
const intervalId = setInterval(() => {
    console.log(i++);
    if (i >= 100) {
        clearInterval(intervalId);
    }
}, 10);
```

### Promise Performance

```javascript
// ❌ Inefficient - sequential execution
async function processItems(items) {
    const results = [];
    for (const item of items) {
        results.push(await processItem(item));
    }
    return results;
}

// ✅ Efficient - parallel execution
async function processItems(items) {
    return Promise.all(items.map(processItem));
}
```

### RunLoop Integration

```swift
// Ensure proper RunLoop handling for long-running scripts
let js = SwiftJS()

js.evaluateScript("""
    // Start async operations
    setTimeout(() => {
        console.log('Async work complete');
        process.exit(0); // Important: exit when done
    }, 1000);
""")

// Keep RunLoop active
RunLoop.main.run()
```

## File System Performance

### Efficient File Operations

#### Choose the Right Method

```javascript
// ❌ Inefficient for large files - loads entire file into memory
const content = SystemFS.readFile('/large/file.txt');

// ✅ Efficient for large files - streaming
const stream = SystemFS.createReadStream('/large/file.txt');
const reader = stream.getReader();

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    // Process chunk
}
```

#### Batch File Operations

```javascript
// ❌ Inefficient - multiple filesystem calls
const files = ['a.txt', 'b.txt', 'c.txt'];
for (const file of files) {
    if (SystemFS.exists(file)) {
        const content = SystemFS.readText(file);
        console.log(content);
    }
}

// ✅ Efficient - check existence first, batch reads
const existingFiles = files.filter(file => SystemFS.exists(file));
const contents = await Promise.all(
    existingFiles.map(file => SystemFS.readFile(file))
);
```

#### Use Appropriate File APIs

```javascript
// For small text files
const text = SystemFS.readFile(path);

// For small binary files (returns Uint8Array)
const bytes = SystemFS.readFile(path, { encoding: 'binary' });

// For large files (streaming)
const stream = SystemFS.createReadStream(path);

// Synchronous for simple operations
const content = SystemFS.readFile(path);
```

### Directory Operations

```javascript
// ❌ Inefficient - recursive manual traversal
// ❌ Inefficient - recursive traversal for large directory trees
function findAllFiles(dir) {
    const files = [];
    const items = SystemFS.readDir(dir);
    for (const item of items) {
        const fullPath = Path.join(dir, item);
        if (SystemFS.isFile(fullPath)) {
            files.push(fullPath);
        } else if (SystemFS.isDirectory(fullPath)) {
            files.push(...findAllFiles(fullPath));
        }
    }
    return files;
}

// ✅ Efficient - use manual traversal with batch processing
function findAllFilesBatch(dir, batchSize = 100) {
    const files = [];
    const stack = [dir];
    while (stack.length > 0) {
        const current = stack.pop();
        const items = SystemFS.readDir(current);
        for (const item of items) {
            const fullPath = Path.join(current, item);
            if (SystemFS.isFile(fullPath)) {
                files.push(fullPath);
            } else if (SystemFS.isDirectory(fullPath)) {
                stack.push(fullPath);
            }
        }
    }
    return files;
}
```
```

## Networking Optimization

### HTTP Request Performance

#### Use Streaming for Large Responses

```javascript
// ❌ Inefficient - loads entire response into memory
const response = await fetch('/large-file');
const data = await response.arrayBuffer();

// ✅ Efficient - process as stream
const response = await fetch('/large-file');
const reader = response.body.getReader();

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    // Process chunk incrementally
}
```

#### Request Optimization

```javascript
// ❌ Inefficient - sequential requests
const responses = [];
for (const url of urls) {
    responses.push(await fetch(url));
}

// ✅ Efficient - parallel requests
const responses = await Promise.all(
    urls.map(url => fetch(url))
);

// ✅ Even better - limited concurrency
async function fetchWithLimit(urls, limit = 5) {
    const results = [];
    for (let i = 0; i < urls.length; i += limit) {
        const batch = urls.slice(i, i + limit);
        const batchResults = await Promise.all(
            batch.map(url => fetch(url))
        );
        results.push(...batchResults);
    }
    return results;
}
```

#### Connection Reuse

```javascript
// ✅ Reuse connections by using the same domain
const baseUrl = 'https://api.example.com';
const endpoints = ['/users', '/posts', '/comments'];

const responses = await Promise.all(
    endpoints.map(endpoint => fetch(baseUrl + endpoint))
);
```

### AbortController for Timeouts

```javascript
// ✅ Efficient timeout handling
async function fetchWithTimeout(url, timeout = 5000) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);
    
    try {
        const response = await fetch(url, {
            signal: controller.signal
        });
        clearTimeout(timeoutId);
        return response;
    } catch (error) {
        clearTimeout(timeoutId);
        if (error.name === 'AbortError') {
            throw new Error('Request timeout');
        }
        throw error;
    }
}
```

## Common Pitfalls

### 1. Method Binding Issues

```javascript
// ❌ WRONG - method loses 'this' context
const getCurrentYear = new Date().getFullYear;
console.log(getCurrentYear()); // TypeError

// ✅ CORRECT - preserve binding
const date = new Date();
console.log(date.getFullYear()); // Works correctly
```

### 2. Object Literal Parsing

```javascript
// ❌ WRONG - returns undefined
function getData() {
    return {
        timestamp: Date.now(),
        value: 42
    };
}

// ✅ CORRECT - explicit return
function getData() {
    return ({
        timestamp: Date.now(),
        value: 42
    });
}
```

### 3. Async/Timer Management

```javascript
// ❌ WRONG - script hangs
setInterval(() => {
    console.log('Running forever...');
}, 1000);

// ✅ CORRECT - clean termination
let count = 0;
const intervalId = setInterval(() => {
    console.log('Running...', ++count);
    if (count >= 5) {
        clearInterval(intervalId);
        process.exit(0);
    }
}, 1000);
```

### 4. Error Handling in Async Code

```javascript
// ❌ WRONG - unhandled promise rejection
fetch('/api/data').then(response => {
    return response.json();
}).then(data => {
    console.log(data);
});

// ✅ CORRECT - proper error handling
fetch('/api/data')
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
    })
    .then(data => console.log(data))
    .catch(error => console.error('Error:', error));
```

### 5. File Path Handling

```javascript
// ❌ WRONG - platform-specific paths
const filePath = 'Documents\\file.txt'; // Windows-style

// ✅ CORRECT - use Path utilities
const filePath = Path.join('Documents', 'file.txt');
```

## Benchmarking

### Performance Testing Setup

```swift
import XCTest
@testable import SwiftJS

class PerformanceTests: XCTestCase {
    func testValueBridgingPerformance() {
        let js = SwiftJS()
        
        measure {
            // Use 'var' for repeated execution
            let script = """
                var data = [];
                for (var i = 0; i < 1000; i++) {
                    data.push(i);
                }
                data.length;
            """
            
            let result = js.evaluateScript(script)
            XCTAssertEqual(result.numberValue, 1000)
        }
    }
}
```

### JavaScript Benchmarking

```javascript
// Measure execution time
console.time('operation');

// Your code here
for (let i = 0; i < 100000; i++) {
    Math.sqrt(i);
}

console.timeEnd('operation'); // operation: 15.234ms
```

### Memory Usage Monitoring

```javascript
// Monitor memory usage patterns
function memoryTest() {
    const before = performance.now();
    
    // Create large data structure
    const largeArray = new Array(1000000).fill(0);
    
    // Process it
    for (let i = 0; i < largeArray.length; i++) {
        largeArray[i] = Math.random();
    }
    
    const after = performance.now();
    console.log(`Processing took ${after - before} milliseconds`);
    
    // Clean up
    largeArray.length = 0;
}
```

## Performance Monitoring Tools

### Built-in Console Methods

```javascript
// Timer methods
console.time('fetch-data');
await fetchData();
console.timeEnd('fetch-data');

// Performance marks (if supported)
performance.mark('start-processing');
// ... processing
performance.mark('end-processing');
performance.measure('processing-time', 'start-processing', 'end-processing');
```

### Custom Performance Utilities

```javascript
class PerformanceMonitor {
    static timers = new Map();
    
    static start(name) {
        this.timers.set(name, performance.now());
    }
    
    static end(name) {
        const start = this.timers.get(name);
        if (start) {
            const duration = performance.now() - start;
            console.log(`${name}: ${duration.toFixed(2)}ms`);
            this.timers.delete(name);
            return duration;
        }
    }
    
    static async measure(name, fn) {
        this.start(name);
        try {
            return await fn();
        } finally {
            this.end(name);
        }
    }
}

// Usage
await PerformanceMonitor.measure('data-processing', async () => {
    return await processLargeDataset();
});
```

## Summary

### Key Performance Principles

1. **Minimize Cross-Layer Calls**: Cache JavaScript object references in Swift
2. **Use Correct Method Invocation**: Always use `invokeMethod` for JavaScript methods  
3. **Handle Object Literals Properly**: Wrap returns in parentheses
4. **Manage Memory**: Clean up large objects and timers
5. **Use Streaming**: For large files and HTTP responses
6. **Batch Operations**: Combine multiple calls when possible
7. **Handle Async Properly**: Use proper Promise patterns and exit conditions

### Performance Checklist

- [ ] Use `invokeMethod` instead of property access + `call`
- [ ] Cache frequently accessed JavaScript objects
- [ ] Wrap object literal returns in parentheses
- [ ] Use `var` in performance test scripts
- [ ] Clean up timers and event listeners
- [ ] Use streaming for large data
- [ ] Handle errors in async code
- [ ] Exit scripts explicitly with `process.exit()`
- [ ] Use appropriate file system methods
- [ ] Implement proper timeout handling

Following these guidelines will help you build high-performance SwiftJS applications that make the most of the underlying JavaScriptCore engine and Swift platform integration.
