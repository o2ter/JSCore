# Command Line Tools

Both SwiftJS and KotlinJS provide command-line tools for executing JavaScript code, testing, and development.

## SwiftJSRunner

SwiftJSRunner is a command-line interface for executing JavaScript code using the SwiftJS runtime on iOS/macOS platforms.

**Auto-Termination**: SwiftJSRunner automatically terminates when all active operations (timers, network requests) complete, eliminating the need for explicit `process.exit()` calls in most cases.

### Installation

SwiftJSRunner is included with SwiftJS:

```bash
# Build the runner
swift build

# Or run directly
swift run SwiftJSRunner
```

### Usage

#### Basic Syntax

```bash
swift run SwiftJSRunner [options] [file] [arguments...]
```

#### Execute JavaScript Files

```bash
# Run a JavaScript file
swift run SwiftJSRunner script.js

# Run a file with arguments
swift run SwiftJSRunner script.js arg1 arg2 arg3
```

#### Evaluate JavaScript Code Directly

```bash
# Short form
swift run SwiftJSRunner -e "console.log('Hello, World!')"

# Long form
swift run SwiftJSRunner --eval "console.log('Hello, World!')"

# With arguments
swift run SwiftJSRunner -e "console.log('Args:', process.argv)" arg1 arg2
```

## jscore-runner

jscore-runner is a command-line interface for executing JavaScript code using the KotlinJS runtime on JVM/Android platforms.

### Installation

jscore-runner is included with KotlinJS:

```bash
# Build the runner
./gradlew build

# Test the runner
./gradlew :java:jscore-runner:run --args="--help"
```

### Usage

#### Basic Syntax

```bash
./gradlew :java:jscore-runner:run --args="[options] [file] [arguments...]"
```

#### Execute JavaScript Files

```bash
# Run a JavaScript file
./gradlew :java:jscore-runner:run --args="script.js"

# Run a file with arguments (note: arguments need proper escaping)
./gradlew :java:jscore-runner:run --args="script.js arg1 arg2 arg3"
```

#### Evaluate JavaScript Code Directly

```bash
# Evaluate JavaScript expression
./gradlew :java:jscore-runner:run --args="-e 'console.log(\"Hello, World!\")'"

# With arguments
./gradlew :java:jscore-runner:run --args="-e 'console.log(\"Args:\", process.argv)' arg1 arg2"
```

## JavaScript Environment

Both tools provide comprehensive JavaScript environments:

### Global Objects

- **Standard JavaScript**: `Object`, `Array`, `Date`, `Math`, `JSON`, `Promise`, etc.
- **Console**: Enhanced `console` with formatting, timing, and grouping
- **Timers**: `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval`
- **Crypto**: `crypto.randomUUID()`, `crypto.randomBytes()`, etc.
- **Text Processing**: `TextEncoder`, `TextDecoder`, `btoa`, `atob`
- **Events**: `Event`, `EventTarget`, `AbortController`, `AbortSignal`

### Node.js-like APIs

- **Process**: Access to process information and control
- **File System**: Complete file operations (platform-specific implementations)
- **Path**: Path manipulation utilities

### Web Standards APIs

- **Fetch**: HTTP requests with streaming support
- **Streams**: `ReadableStream`, `WritableStream`, `TransformStream`
- **File APIs**: `Blob`, `File`, `FileReader`
- **HTTP**: `XMLHttpRequest`, `Headers`, `Request`, `Response`
- **Form Data**: `FormData` for multipart/form-data handling

## Examples

### SwiftJSRunner Examples

#### Hello World

Create `hello.js`:
```javascript
console.log('Hello from SwiftJS!');
console.log('Process ID:', process.pid);
console.log('Current directory:', process.cwd());
```

Run it:
```bash
swift run SwiftJSRunner hello.js
```

#### File Operations

Create `file-ops.js`:
```javascript
const fileName = '/tmp/swiftjs-demo.txt';
const content = `Generated at ${new Date().toISOString()}`;

// Write file
SystemFS.writeFile(fileName, content);
console.log('File written:', fileName);

// Read file back
const readContent = SystemFS.readFile(fileName);
console.log('File content:', readContent);

// Check file exists
console.log('File exists:', SystemFS.exists(fileName));
```

Run it:
```bash
swift run SwiftJSRunner file-ops.js
```

### jscore-runner Examples

#### Hello World

Create `hello.js`:
```javascript
console.log('Hello from KotlinJS!');
console.log('Process ID:', process.pid);
console.log('Platform:', process.platform);
```

Run it:
```bash
./gradlew :java:jscore-runner:run --args="hello.js"
```

#### Timer Demo

Create `timers.js`:
```javascript
console.log('Starting timer demo...');

let count = 0;
const intervalId = setInterval(() => {
    count++;
    console.log(`Timer tick: ${count}`);
    
    if (count >= 3) {
        clearInterval(intervalId);
        console.log('Timer completed');
    }
}, 1000);
```

Run it:
```bash
./gradlew :java:jscore-runner:run --args="timers.js"
```

## Platform Differences

| Feature | SwiftJSRunner | jscore-runner |
|---------|---------------|---------------|
| **Platform** | iOS/macOS | JVM/Android |
| **Engine** | JavaScriptCore | Javet V8 |
| **File System** | SystemFS class | File system access varies by platform |
| **Auto-termination** | Yes | Manual termination |
| **Native Integration** | Swift APIs | Kotlin APIs |
| **Build Command** | `swift run SwiftJSRunner` | `./gradlew :java:jscore-runner:run` |

## Advanced Usage

### SwiftJSRunner Advanced Features

#### Environment Variables

```bash
export DEBUG=1
swift run SwiftJSRunner -e "console.log('Debug mode:', process.env.DEBUG)"
```

#### Performance Measurement

```javascript
console.time('operation');
for (let i = 0; i < 1000000; i++) {
    Math.sqrt(i);
}
console.timeEnd('operation');
```

### jscore-runner Advanced Features

#### Gradle Properties

You can pass JVM options through Gradle:

```bash
./gradlew :java:jscore-runner:run --args="script.js" -Dorg.gradle.jvmargs="-Xmx2g"
```

#### Platform Context

The runner automatically detects and uses the appropriate platform context (JVM).

## Troubleshooting

### SwiftJSRunner Issues

#### Script Doesn't Exit
SwiftJSRunner features auto-termination, but if your script hangs:
```javascript
// Force exit if needed
setTimeout(() => {
    console.log('Force exit');
    process.exit(0);
}, 5000);
```

#### Permission Errors
```bash
# Check file permissions
chmod +r script.js
```

### jscore-runner Issues

#### Gradle Build Errors
```bash
# Clean and rebuild
./gradlew clean build
```

#### Memory Issues
```bash
# Increase heap size
./gradlew :java:jscore-runner:run --args="script.js" -Dorg.gradle.jvmargs="-Xmx4g"
```

#### Class Path Issues
Ensure all dependencies are properly built:
```bash
./gradlew :java:jscore:build :java:jscore-jvm:build
```

## Best Practices

### Cross-Platform Scripts

Write scripts that work on both platforms:

```javascript
// Check platform capabilities
const platform = typeof process !== 'undefined' ? process.platform : 'unknown';
console.log('Running on:', platform);

// Use common APIs
console.log('Random UUID:', crypto.randomUUID());

// Graceful timer handling
setTimeout(() => {
    console.log('Timer executed');
    if (typeof process !== 'undefined' && process.exit) {
        process.exit(0);
    }
}, 1000);
```

### Error Handling

```javascript
process.on('uncaughtException', (error) => {
    console.error('Uncaught exception:', error.message);
    process.exit(1);
});

try {
    // Your code here
} catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
}
```

### Performance

1. **Use appropriate timer cleanup** for both platforms
2. **Handle large data efficiently** with streaming APIs
3. **Monitor memory usage** for long-running scripts

## Integration with IDEs

### VS Code

Both runners work well with VS Code:

1. **Configure tasks** in `.vscode/tasks.json`:
   ```json
   {
     "version": "2.0.0",
     "tasks": [
       {
         "label": "Run with SwiftJSRunner",
         "type": "shell",
         "command": "swift",
         "args": ["run", "SwiftJSRunner", "${file}"],
         "group": "build"
       },
       {
         "label": "Run with jscore-runner", 
         "type": "shell",
         "command": "./gradlew",
         "args": [":java:jscore-runner:run", "--args=${file}"],
         "group": "build"
       }
     ]
   }
   ```

2. **Use debugging features** with proper error output
3. **Leverage terminal integration** for quick testing

---

For more information:
- **[SwiftJS API Reference](swiftjs-api.md)** - Complete SwiftJS API documentation
- **[KotlinJS API Reference](kotlinjs-api.md)** - Complete KotlinJS API documentation
- **[Getting Started](../getting-started/)** - Installation and quick start guides

## Process Control

### Exit Codes

```javascript
// Exit with success
process.exit(0);

// Exit with error
process.exit(1);

// Exit with custom code
process.exit(42);
```

### Auto-Termination

SwiftJSRunner features intelligent auto-termination that monitors active operations:

- **Timers**: `setTimeout` and `setInterval` operations
- **Network Requests**: HTTP requests via `fetch()` or `XMLHttpRequest`
- **Cleanup**: Automatic cleanup of completed `setTimeout` timers

The runner will automatically exit when no active operations remain, making simple scripts work without explicit exit calls:

```javascript
// This script will auto-terminate after the timer fires
setTimeout(() => {
    console.log('Timer executed, script will auto-terminate');
}, 1000);
```

For complex scripts or when you need immediate termination, you can still use explicit exit:

```javascript
console.log('Done!');
process.exit(0); // Immediate termination
```

### Signal Handling

SwiftJSRunner automatically handles SIGINT (Ctrl+C) for graceful termination:

```javascript
console.log('Press Ctrl+C to terminate...');

// Long-running operation
setInterval(() => {
    console.log('Working...', new Date().toISOString());
}, 1000);

// The runner will detect Ctrl+C and exit gracefully
```

## Error Handling

### JavaScript Errors

```javascript
try {
    throw new Error('Something went wrong');
} catch (error) {
    console.error('Caught error:', error.message);
    console.error('Stack trace:', error.stack);
}
```

### Unhandled Errors

SwiftJSRunner automatically catches unhandled JavaScript errors and displays them with stack traces:

```javascript
// This will be caught and displayed
setTimeout(() => {
    throw new Error('Unhandled async error');
}, 1000);
```

## Advanced Features

### Module-like Structure

While SwiftJSRunner doesn't support ES modules or CommonJS `require()`, you can structure code using IIFEs:

```javascript
// Create a module-like structure
const MyModule = (function() {
    function privateFunction() {
        return 'This is private';
    }
    
    return {
        publicFunction() {
            return 'This is public: ' + privateFunction();
        }
    };
})();

console.log(MyModule.publicFunction());
```

### Performance Measurement

```javascript
console.time('operation');

// Simulate work
for (let i = 0; i < 1000000; i++) {
    Math.sqrt(i);
}

console.timeEnd('operation');
```

## Differences from Node.js

SwiftJSRunner is not a drop-in replacement for Node.js. Key differences:

### Missing Features
- No `require()` or ES module system
- No npm package support
- No Node.js built-in modules (`fs`, `path`, `http`, etc.)
- No global `Buffer` class

### Different APIs
- File system operations use `SystemFS` class instead of `fs` module
- Path operations use `Path` class instead of `path` module
- No streams compatibility with Node.js streams

### Unique Features
- Integrated with iOS/macOS RunLoop for timers
- Web standards APIs (Fetch, Streams, etc.)

## Troubleshooting

### Script Doesn't Exit

SwiftJSRunner features auto-termination, but if your script hangs:

1. **Check for active operations**: Ensure all timers are cleared and network requests complete
2. **Force exit if needed**: Use explicit `process.exit()` for immediate termination

```javascript
// If auto-termination isn't working, check for:
// - Unclosed intervals: clearInterval(intervalId)
// - Pending network requests
// - Long-running operations

// Force exit as last resort
setTimeout(() => {
    console.log('Force exit');
    process.exit(0);
}, 5000);
```

### File Not Found

```bash
# Ensure the file exists and path is correct
ls -la script.js
swift run SwiftJSRunner script.js
```

### Permission Errors

```bash
# Check file permissions
chmod +x script.js  # Not required, but good practice
```

### Memory Issues

For long-running scripts or large data processing:

```javascript
// Explicitly clean up large objects
let largeObject = new Array(1000000).fill('data');
// ... use the object
largeObject = null; // Help GC
```

## Best Practices

1. **Leverage Auto-Termination**: Let SwiftJSRunner automatically terminate when operations complete
2. **Exit Explicitly When Needed**: Call `process.exit()` for immediate termination or error conditions
3. **Handle Errors**: Use try/catch for error handling and provide meaningful error messages
4. **Use Timers Wisely**: Clear intervals when no longer needed; `setTimeout` auto-cleans up
5. **Check File Existence**: Always check if files exist before reading
6. **Validate Arguments**: Check `process.argv` length before accessing arguments
7. **Use Async Patterns**: Prefer async/await for asynchronous operations

---

SwiftJSRunner provides a powerful JavaScript execution environment with native platform integration, making it ideal for scripting, automation, and prototyping on Apple platforms.
