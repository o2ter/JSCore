# SwiftJSRunner CLI Documentation

SwiftJSRunner is a command-line interface for executing JavaScript code using the SwiftJS runtime. It provides a Node.js-like environment for running JavaScript files and evaluating JavaScript expressions directly from the command line.

**Auto-Termination**: SwiftJSRunner automatically terminates when all active operations (timers, network requests) complete, eliminating the need for explicit `process.exit()` calls in most cases.

## Installation

SwiftJSRunner is included with SwiftJS and can be built using Swift Package Manager:

```bash
# Build the runner
swift build

# Or run directly
swift run SwiftJSRunner
```

## Usage

### Basic Syntax

```bash
swift run SwiftJSRunner [options] [file] [arguments...]
```

### Command Options

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

#### Help

```bash
# Show help
swift run SwiftJSRunner -h
swift run SwiftJSRunner --help
```

## JavaScript Environment

SwiftJSRunner provides a complete JavaScript environment with:

### Global Objects

- **Standard JavaScript**: `Object`, `Array`, `Date`, `Math`, `JSON`, `Promise`, etc.
- **Console**: Enhanced `console` with formatting, timing, and grouping
- **Timers**: `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval`
- **Crypto**: `crypto.randomUUID()`, `crypto.randomBytes()`, etc.
- **Text Processing**: `TextEncoder`, `TextDecoder`, `btoa`, `atob`
- **Events**: `Event`, `EventTarget`, `AbortController`, `AbortSignal`

### Node.js-like APIs

- **Process**: Access to process information and control
- **File System**: Complete file operations through `SystemFS` class
- **Path**: Path manipulation utilities through `Path` class

### Web Standards APIs

- **Fetch**: HTTP requests with streaming support
- **Streams**: `ReadableStream`, `WritableStream`, `TransformStream`
- **File APIs**: `Blob`, `File`, `FileReader`
- **HTTP**: `XMLHttpRequest`, `Headers`, `Request`, `Response`
- **Form Data**: `FormData` for multipart/form-data handling

## Examples

### Hello World

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

### Command Line Arguments

Create `args.js`:
```javascript
console.log('Script name:', process.argv[0]);
console.log('All arguments:', process.argv);

// Process arguments
const args = process.argv.slice(1);
if (args.length === 0) {
    console.log('No arguments provided');
} else {
    args.forEach((arg, index) => {
        console.log(`Argument ${index + 1}: ${arg}`);
    });
}
```

Run it:
```bash
swift run SwiftJSRunner args.js hello world 123
```

### File Operations

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

// Get file stats
const stats = SystemFS.stat(fileName);
console.log('File size:', stats.size, 'bytes');
```

Run it:
```bash
swift run SwiftJSRunner file-ops.js
```

### HTTP Requests

Create `fetch-demo.js`:
```javascript
async function fetchData() {
    try {
        console.log('Fetching data...');
        const response = await fetch('https://jsonplaceholder.typicode.com/posts/1');
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log('Post title:', data.title);
        console.log('Post body:', data.body);
        
    } catch (error) {
        console.error('Fetch error:', error.message);
    }
}

fetchData().then(() => {
    console.log('Done!');
});
```

Run it:
```bash
swift run SwiftJSRunner fetch-demo.js
```

### Timers and Async Operations

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
        
        // Exit after a short delay
        setTimeout(() => {
            console.log('Exiting...');
            process.exit(0);
        }, 500);
    }
}, 1000);

console.log('Timer started, waiting for ticks...');
```

Run it:
```bash
swift run SwiftJSRunner timers.js
```

### Crypto Operations

Create `crypto-demo.js`:
```javascript
console.log('Crypto Demo');
console.log('===========');

// Generate UUID
const uuid = crypto.randomUUID();
console.log('Random UUID:', uuid);

// Generate random bytes
const randomBytes = crypto.randomBytes(16);
console.log('Random bytes:', Array.from(randomBytes).map(b => b.toString(16).padStart(2, '0')).join(''));

// Fill array with random values
const buffer = new Uint8Array(8);
crypto.getRandomValues(buffer);
console.log('Random buffer:', Array.from(buffer));

// Base64 encoding
const text = 'Hello, SwiftJS!';
const encoded = btoa(text);
const decoded = atob(encoded);
console.log('Original:', text);
console.log('Base64:', encoded);
console.log('Decoded:', decoded);
```

Run it:
```bash
swift run SwiftJSRunner crypto-demo.js
```

### Environment Variables

Create `env.js`:
```javascript
console.log('Environment Variables');
console.log('====================');

// Display all environment variables
console.log('All environment variables:');
for (const [key, value] of Object.entries(process.env)) {
    console.log(`${key}=${value}`);
}

// Access specific variables
console.log('\nSpecific variables:');
console.log('PATH:', process.env.PATH || 'not set');
console.log('HOME:', process.env.HOME || 'not set');
console.log('USER:', process.env.USER || 'not set');
```

Run it:
```bash
swift run SwiftJSRunner env.js
```

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
