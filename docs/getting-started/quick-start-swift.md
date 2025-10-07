# SwiftJS Quick Start

Get up and running with SwiftJS in minutes. This guide covers the essentials for iOS and macOS development.

## Prerequisites

- **iOS 17.0+** or **macOS 14.0+**
- **Swift 6.0+**
- **Xcode 15.0+**

If you haven't installed SwiftJS yet, see the [Installation Guide](installation.md).

## Basic Usage

### Creating a JavaScript Context

```swift
import SwiftJS

// Create a JavaScript context (includes polyfills automatically)
let js = SwiftJS()

// Execute simple JavaScript
let result = js.evaluateScript("2 + 3")
print(result.numberValue) // Output: 5.0
```

### Working with JavaScript Values

```swift
let js = SwiftJS()

// JavaScript to Swift
js.evaluateScript("var message = 'Hello from JavaScript!'")
let message = js.globalObject["message"]
print(message.stringValue) // Output: "Hello from JavaScript!"

// Swift to JavaScript
js.globalObject["swiftData"] = ["name": "Alice", "age": 30]
js.evaluateScript("console.log('Name:', swiftData.name, 'Age:', swiftData.age)")
// Output: Name: Alice Age: 30
```

### Method Invocation

**Important:** Always use `invokeMethod` for JavaScript methods to preserve `this` context:

```swift
let js = SwiftJS()

js.evaluateScript("""
    var calculator = {
        value: 0,
        add: function(n) { 
            this.value += n; 
            return this; 
        },
        multiply: function(n) { 
            this.value *= n; 
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
calculator.invokeMethod("multiply", withArguments: [3])
let result = calculator.invokeMethod("getValue", withArguments: [])
print(result.numberValue) // Output: 15.0

// ❌ WRONG - loses 'this' context, causes TypeError
// let addMethod = calculator["add"]
// addMethod.call(withArguments: [5])  // TypeError!
```

## Available JavaScript APIs

SwiftJS provides comprehensive web standards APIs:

### Console and Logging

```swift
let js = SwiftJS()

js.evaluateScript("""
    console.log('Basic logging');
    console.error('Error message');
    console.warn('Warning message');
    console.info('Info message');
    
    // Timing
    console.time('operation');
    // ... some operation
    console.timeEnd('operation');
    
    // Counting
    console.count('requests');
    console.count('requests');
    
    // Grouping
    console.group('API Calls');
    console.log('GET /users');
    console.log('POST /users');
    console.groupEnd();
""")
```

### Crypto Operations

```swift
let js = SwiftJS()

js.evaluateScript("""
    // Generate UUID
    const id = crypto.randomUUID();
    console.log('UUID:', id);
    
    // Random bytes
    const bytes = crypto.randomBytes(16);
    console.log('Random bytes length:', bytes.length);
    
    // Random values for arrays
    const buffer = new Uint8Array(8);
    crypto.getRandomValues(buffer);
    console.log('Random buffer:', Array.from(buffer));
""")
```

### Text Processing

```swift
let js = SwiftJS()

js.evaluateScript("""
    // Base64 encoding
    const text = 'Hello, SwiftJS!';
    const encoded = btoa(text);
    const decoded = atob(encoded);
    console.log('Original:', text);
    console.log('Encoded:', encoded);
    console.log('Decoded:', decoded);
    
    // Text encoding/decoding
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();
    
    const bytes = encoder.encode('Hello, 世界!');
    const restored = decoder.decode(bytes);
    console.log('UTF-8 roundtrip:', restored);
""")
```

### File System Operations

```swift
let js = SwiftJS()

js.evaluateScript("""
    // File operations
    const fileName = '/tmp/swiftjs-demo.txt';
    const content = `Generated at ${new Date().toISOString()}`;
    
    // Write file
    SystemFS.writeFile(fileName, content);
    console.log('File written to:', fileName);
    
    // Read file
    const readContent = SystemFS.readFile(fileName);
    console.log('File content:', readContent);
    
    // Check if file exists
    console.log('File exists:', SystemFS.exists(fileName));
    
    // Get file stats
    const stats = SystemFS.stat(fileName);
    console.log('File size:', stats.size, 'bytes');
""")
```

## Async Operations

### Timers

```swift
let js = SwiftJS()

js.evaluateScript("""
    console.log('Starting timer demo...');
    
    // Single execution
    setTimeout(() => {
        console.log('Timer fired after 1 second');
    }, 1000);
    
    // Repeated execution
    let count = 0;
    const intervalId = setInterval(() => {
        count++;
        console.log(`Interval tick: ${count}`);
        
        if (count >= 3) {
            clearInterval(intervalId);
            console.log('Interval stopped');
        }
    }, 500);
""")

// Keep the RunLoop active for timers
RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
```

### HTTP Requests

```swift
let js = SwiftJS()

js.evaluateScript("""
    async function fetchExample() {
        try {
            console.log('Making HTTP request...');
            const response = await fetch('https://jsonplaceholder.typicode.com/posts/1');
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            console.log('Post title:', data.title);
            console.log('Post body:', data.body.substring(0, 50) + '...');
            
        } catch (error) {
            console.error('Fetch error:', error.message);
        }
    }
    
    fetchExample();
""")

// Keep the RunLoop active for async operations
RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
```

## Working with Objects and Arrays

### Creating JavaScript Objects from Swift

```swift
let js = SwiftJS()

// Simple values
js.globalObject["config"] = [
    "apiUrl": "https://api.example.com",
    "timeout": 5000,
    "retries": 3
]

// Arrays
js.globalObject["numbers"] = [1, 2, 3, 4, 5]

// Nested structures
js.globalObject["userData"] = [
    "user": [
        "name": "Alice",
        "preferences": [
            "theme": "dark",
            "notifications": true
        ]
    ],
    "permissions": ["read", "write"]
]

js.evaluateScript("""
    console.log('API URL:', config.apiUrl);
    console.log('User name:', userData.user.name);
    console.log('Theme:', userData.user.preferences.theme);
    console.log('Permissions:', userData.permissions.join(', '));
""")
```

### Extracting Data from JavaScript

```swift
let js = SwiftJS()

js.evaluateScript("""
    var result = {
        success: true,
        data: {
            items: [
                { id: 1, name: 'Item 1' },
                { id: 2, name: 'Item 2' }
            ],
            total: 2
        },
        message: 'Operation completed successfully'
    };
""")

let result = js.globalObject["result"]
let success = result["success"].boolValue // true
let total = result["data"]["total"].numberValue // 2.0
let message = result["message"].stringValue // "Operation completed successfully"
let firstItemName = result["data"]["items"][0]["name"].stringValue // "Item 1"

print("Success: \(success)")
print("Total: \(total)")
print("Message: \(message)")
print("First item: \(firstItemName)")
```

## Error Handling

### JavaScript Exceptions

```swift
let js = SwiftJS()

// Set up exception handler
js.base.exceptionHandler = { context, exception in
    if let error = exception?.toString() {
        print("JavaScript Error: \(error)")
        if let stack = exception?["stack"]?.toString() {
            print("Stack trace: \(stack)")
        }
    }
}

// Execute code that might throw
js.evaluateScript("""
    try {
        throw new Error('Something went wrong!');
    } catch (error) {
        console.error('Caught error:', error.message);
    }
""")

// Check for exceptions after evaluation
js.evaluateScript("invalidFunction()")
if !js.exception.isUndefined {
    print("Exception occurred: \(js.exception.toString())")
}
```

### Swift Error Handling

```swift
let js = SwiftJS()

do {
    let result = js.evaluateScript("Math.sqrt(-1)")
    print("Result: \(result.numberValue)") // NaN is valid in JavaScript
} catch {
    print("Swift error: \(error)")
}
```

## Practical Examples

### Simple Calculator

```swift
import SwiftJS

class JavaScriptCalculator {
    private let js = SwiftJS()
    
    init() {
        // Set up calculator object in JavaScript
        js.evaluateScript("""
            var calculator = {
                add: function(a, b) { return a + b; },
                subtract: function(a, b) { return a - b; },
                multiply: function(a, b) { return a * b; },
                divide: function(a, b) { 
                    if (b === 0) throw new Error('Division by zero');
                    return a / b; 
                },
                power: function(base, exponent) { return Math.pow(base, exponent); },
                sqrt: function(n) { 
                    if (n < 0) throw new Error('Square root of negative number');
                    return Math.sqrt(n); 
                }
            };
        """)
    }
    
    func add(_ a: Double, _ b: Double) -> Double {
        let calculator = js.globalObject["calculator"]
        let result = calculator.invokeMethod("add", withArguments: [a, b])
        return result.numberValue ?? 0
    }
    
    func divide(_ a: Double, _ b: Double) throws -> Double {
        let calculator = js.globalObject["calculator"]
        let result = calculator.invokeMethod("divide", withArguments: [a, b])
        
        // Check for JavaScript exception
        if !js.exception.isUndefined {
            let errorMessage = js.exception.toString()
            throw NSError(domain: "CalculatorError", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        return result.numberValue ?? 0
    }
}

// Usage
let calc = JavaScriptCalculator()
print(calc.add(5, 3)) // 8.0

do {
    let result = try calc.divide(10, 2)
    print(result) // 5.0
} catch {
    print("Error: \(error)")
}
```

### Data Processing Script

```swift
let js = SwiftJS()

// Load sample data
let sampleData = [
    ["name": "Alice", "age": 30, "city": "New York"],
    ["name": "Bob", "age": 25, "city": "San Francisco"],
    ["name": "Charlie", "age": 35, "city": "New York"],
    ["name": "Diana", "age": 28, "city": "Boston"]
]

js.globalObject["data"] = sampleData

// Process data with JavaScript
let processedResult = js.evaluateScript("""
    // Group by city
    const groupedByCity = data.reduce((acc, person) => {
        const city = person.city;
        if (!acc[city]) acc[city] = [];
        acc[city].push(person);
        return acc;
    }, {});
    
    // Calculate average age per city
    const cityStats = Object.entries(groupedByCity).map(([city, people]) => ({
        city: city,
        count: people.length,
        averageAge: people.reduce((sum, p) => sum + p.age, 0) / people.length,
        people: people.map(p => p.name)
    }));
    
    cityStats;
""")

// Extract results back to Swift
if processedResult.isArray {
    for i in 0..<Int(processedResult["length"].numberValue ?? 0) {
        let cityData = processedResult[i]
        let city = cityData["city"].stringValue ?? ""
        let count = Int(cityData["count"].numberValue ?? 0)
        let avgAge = cityData["averageAge"].numberValue ?? 0
        
        print("\(city): \(count) people, average age \(String(format: "%.1f", avgAge))")
    }
}
```

## Best Practices

### Performance Tips

1. **Cache object references** to avoid repeated value conversions:
   ```swift
   // ✅ Efficient
   let array = js.globalObject["largeArray"]
   for i in 0..<1000 {
       array[i] = "value\(i)"
   }
   
   // ❌ Inefficient
   for i in 0..<1000 {
       js.globalObject["largeArray"][i] = "value\(i)"
   }
   ```

2. **Use `invokeMethod` for JavaScript methods** to preserve `this` binding and improve performance

3. **Batch operations** when possible:
   ```swift
   // ✅ Better
   js.globalObject["config"] = ["a": 1, "b": 2, "c": 3]
   
   // ❌ Less efficient
   js.globalObject["a"] = 1
   js.globalObject["b"] = 2
   js.globalObject["c"] = 3
   ```

### Memory Management

1. **SwiftJS handles memory automatically** - JavaScript objects are garbage collected
2. **Avoid retain cycles** when capturing `self` in closures:
   ```swift
   js.globalObject["callback"] = { [weak self] in
       self?.someMethod()
   }
   ```
3. **Clean up long-running timers**:
   ```javascript
   const id = setInterval(() => {}, 1000);
   // Later: clearInterval(id);
   ```

### Error Handling

1. **Always check for exceptions** after evaluating potentially problematic code
2. **Use try-catch in JavaScript** for expected errors
3. **Set up exception handlers** for debugging

## Next Steps

- **[Fundamentals Guide](../guides/swiftjs/fundamentals.md)** - Deep dive into SwiftJS concepts
- **[JavaScript APIs](../guides/swiftjs/javascript-apis.md)** - Complete API reference
- **[Examples](examples/)** - More practical code examples
- **[SwiftJSRunner Guide](../reference/cli-tools.md)** - Command-line tool usage

## Common Issues

### Script Doesn't Exit
If your script hangs, ensure all timers are cleared and async operations complete:
```javascript
setTimeout(() => {
    console.log('Done!');
    process.exit(0); // Force exit if needed
}, 1000);
```

### Method Call Errors
Always use `invokeMethod` instead of extracting methods:
```swift
// ✅ Correct
object.invokeMethod("method", withArguments: [])

// ❌ Wrong - causes TypeError
let method = object["method"]
method.call(withArguments: [])
```

### Object Literal Returns
Wrap object returns in parentheses:
```javascript
// ✅ Correct
({key: value, other: data})

// ❌ Wrong - returns undefined
{key: value, other: data}
```