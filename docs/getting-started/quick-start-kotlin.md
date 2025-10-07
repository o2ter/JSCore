# KotlinJS Quick Start

Get up and running with KotlinJS in minutes. This guide covers the essentials for JVM and Android development.

## Prerequisites

- **JDK 11+** (for JVM projects)
- **Android SDK API 21+** (for Android projects)
- **Kotlin 1.9+**
- **Gradle 8.0+**

If you haven't installed KotlinJS yet, see the [Installation Guide](installation.md).

## Basic Usage

### Creating a JavaScript Engine

```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext

// Create a JavaScript engine with platform context
val platformContext = JvmPlatformContext("MyApp")
val engine = JavaScriptEngine(platformContext)

// Execute simple JavaScript
val result = engine.execute("2 + 3")
println("Result: $result") // Output: Result: 5
```

### Resource Management Patterns

KotlinJS supports two main usage patterns:

#### Pattern 1: Long-Lived Engine (Recommended for Applications)

```kotlin
class MyService {
    private val platformContext = JvmPlatformContext("MyService")
    private val jsEngine = JavaScriptEngine(platformContext)
    
    fun processData(input: String): Any? {
        return jsEngine.execute("'Processed: ' + '$input'")
    }
    
    fun shutdown() {
        jsEngine.close() // Call when service is shutting down
    }
}
```

#### Pattern 2: Scoped Usage (Recommended for Scripts)

```kotlin
fun processScript(script: String): Any? {
    val platformContext = JvmPlatformContext("ScriptProcessor")
    return JavaScriptEngine(platformContext).use { engine ->
        engine.execute(script)
    } // Engine automatically closed when exiting use block
}
```

### Android Usage

```kotlin
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.android.AndroidPlatformContext

class MainActivity : AppCompatActivity() {
    private lateinit var jsEngine: JavaScriptEngine
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create engine with Android context
        val platformContext = AndroidPlatformContext(this)
        jsEngine = JavaScriptEngine(platformContext)
        
        // Execute JavaScript
        val result = jsEngine.execute("Math.random()")
        Log.d("JSCore", "Random number: $result")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        jsEngine.close() // Clean up when Activity is destroyed
    }
}
```

## Working with JavaScript Values

### Basic Value Conversion

```kotlin
val engine = JavaScriptEngine(platformContext)

// Kotlin to JavaScript
engine.executeVoid("var message = 'Hello from Kotlin!'")

// JavaScript to Kotlin
val result = engine.execute("message")
println(result) // Output: Hello from Kotlin!

// Numbers
val number = engine.execute("Math.PI * 2")
println(number) // Output: 6.283185307179586

// Booleans
val isTrue = engine.execute("5 > 3")
println(isTrue) // Output: true

// Arrays
val array = engine.execute("[1, 2, 3, 4, 5]")
println(array) // Output: [1, 2, 3, 4, 5]

// Objects
val obj = engine.execute("({name: 'Alice', age: 30})")
println(obj) // Output: {name=Alice, age=30}
```

### Using JSBridge for Complex Objects

```kotlin
val engine = JavaScriptEngine(platformContext)
val bridge = engine.jsBridge

// Create JavaScript object from Kotlin data
val userData = bridge.createObject {
    "name" to "Alice"
    "age" to 30
    "preferences" to mapOf(
        "theme" to "dark",
        "notifications" to true
    )
}

// Set as global variable
bridge.setGlobal("user", userData)

// Use in JavaScript
engine.executeVoid("""
    console.log('User:', user.name, 'Age:', user.age);
    console.log('Theme:', user.preferences.theme);
""")
```

## Available JavaScript APIs

KotlinJS provides comprehensive web standards APIs:

### Console and Logging

```kotlin
engine.executeVoid("""
    console.log('Basic logging');
    console.error('Error message');
    console.warn('Warning message');
    console.info('Info message');
    
    // Timing
    console.time('operation');
    for (let i = 0; i < 1000; i++) {
        Math.sqrt(i);
    }
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

```kotlin
engine.executeVoid("""
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

### Process Information

```kotlin
engine.executeVoid("""
    console.log('Process ID:', process.pid);
    console.log('Platform:', process.platform);
    console.log('Arguments:', process.argv);
    
    // Environment variables (platform-dependent)
    console.log('Environment keys:', Object.keys(process.env).length);
""")
```

## Creating Native APIs with JSBridge

The JSBridge API makes it easy to expose Kotlin functionality to JavaScript:

### Simple API

```kotlin
val engine = JavaScriptEngine(platformContext)
val bridge = engine.jsBridge

// Create a math API
val mathAPI = bridge.createObject {
    "PI" to Math.PI
    "E" to Math.E
    
    "add".func2 { a, b ->
        val numA = (a as? Number)?.toDouble() ?: 0.0
        val numB = (b as? Number)?.toDouble() ?: 0.0
        numA + numB
    }
    
    "multiply".func2 { a, b ->
        val numA = (a as? Number)?.toDouble() ?: 0.0
        val numB = (b as? Number)?.toDouble() ?: 0.0
        numA * numB
    }
    
    "randomInt".func1 { maxArg ->
        val max = (maxArg as? Number)?.toInt() ?: 100
        (Math.random() * max).toInt()
    }
}

// Expose to JavaScript
bridge.setGlobal("MathAPI", mathAPI)

// Use from JavaScript
val result = engine.execute("""
    MathAPI.add(MathAPI.multiply(3, 4), MathAPI.PI)
""")
println("Calculation result: $result")
```

### File System API

```kotlin
val fileAPI = bridge.createObject {
    "readFile".func1 { pathArg ->
        val path = pathArg?.toString() ?: ""
        try {
            File(path).readText()
        } catch (e: Exception) {
            throw RuntimeException("Failed to read file: ${e.message}")
        }
    }
    
    "writeFile".func2 { pathArg, contentArg ->
        val path = pathArg?.toString() ?: ""
        val content = contentArg?.toString() ?: ""
        try {
            File(path).writeText(content)
            true
        } catch (e: Exception) {
            throw RuntimeException("Failed to write file: ${e.message}")
        }
    }
    
    "exists".func1 { pathArg ->
        val path = pathArg?.toString() ?: ""
        File(path).exists()
    }
    
    "listFiles".func1 { dirArg ->
        val dir = dirArg?.toString() ?: ""
        try {
            File(dir).listFiles()?.map { it.name } ?: emptyList()
        } catch (e: Exception) {
            emptyList<String>()
        }
    }
}

bridge.setGlobal("FileAPI", fileAPI)

// Use from JavaScript
engine.executeVoid("""
    FileAPI.writeFile('/tmp/test.txt', 'Hello from KotlinJS!');
    if (FileAPI.exists('/tmp/test.txt')) {
        const content = FileAPI.readFile('/tmp/test.txt');
        console.log('File content:', content);
    }
    
    const files = FileAPI.listFiles('/tmp');
    console.log('Files in /tmp:', files.slice(0, 5)); // Show first 5
""")
```

## Async Operations

### Timers

```kotlin
engine.executeVoid("""
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

// Give time for timers to execute
Thread.sleep(5000)
```

### Promises and Async/Await

```kotlin
engine.executeVoid("""
    // Promise example
    function delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    
    async function asyncExample() {
        console.log('Starting async operation...');
        await delay(1000);
        console.log('Async operation completed!');
        return 'Success';
    }
    
    asyncExample().then(result => {
        console.log('Promise resolved with:', result);
    });
""")

Thread.sleep(2000) // Wait for async operations
```

## Error Handling

### JavaScript Exceptions

```kotlin
val engine = JavaScriptEngine(platformContext)

try {
    // This will throw a JavaScript error
    engine.execute("invalidFunction()")
} catch (e: Exception) {
    println("JavaScript error: ${e.message}")
}

// Handle errors in JavaScript
engine.executeVoid("""
    try {
        throw new Error('Something went wrong!');
    } catch (error) {
        console.error('Caught error:', error.message);
        console.error('Stack:', error.stack);
    }
""")
```

### Native API Error Handling

```kotlin
val safeAPI = bridge.createObject {
    "divide".func2 { aArg, bArg ->
        val a = (aArg as? Number)?.toDouble() ?: 0.0
        val b = (bArg as? Number)?.toDouble() ?: 0.0
        
        if (b == 0.0) {
            throw RuntimeException("Division by zero")
        }
        a / b
    }
    
    "parseJSON".func1 { jsonArg ->
        val jsonString = jsonArg?.toString() ?: ""
        try {
            // Simple JSON validation (in real code, use a proper JSON library)
            if (jsonString.trim().startsWith("{") && jsonString.trim().endsWith("}")) {
                mapOf("success" to true, "data" to jsonString)
            } else {
                throw IllegalArgumentException("Invalid JSON format")
            }
        } catch (e: Exception) {
            throw RuntimeException("JSON parsing failed: ${e.message}")
        }
    }
}

bridge.setGlobal("SafeAPI", safeAPI)

engine.executeVoid("""
    try {
        const result = SafeAPI.divide(10, 2);
        console.log('Division result:', result);
        
        SafeAPI.divide(10, 0); // This will throw
    } catch (error) {
        console.error('Native API error:', error.message);
    }
""")
```

## Practical Examples

### Data Processing Service

```kotlin
class DataProcessor {
    private val platformContext = JvmPlatformContext("DataProcessor")
    private val engine = JavaScriptEngine(platformContext)
    private val bridge = engine.jsBridge
    
    init {
        // Set up JavaScript environment
        bridge.setGlobal("processor", bridge.createObject {
            "transform".func1 { data ->
                // Convert Kotlin data for JavaScript processing
                data
            }
        })
        
        // Load processing logic
        engine.executeVoid("""
            function processArray(arr) {
                return arr
                    .filter(item => item % 2 === 0)  // Even numbers only
                    .map(item => item * 2)           // Double them
                    .reduce((sum, item) => sum + item, 0); // Sum
            }
            
            function analyzeText(text) {
                const words = text.toLowerCase().split(/\s+/);
                const wordCount = words.length;
                const uniqueWords = new Set(words).size;
                const avgLength = words.reduce((sum, word) => sum + word.length, 0) / wordCount;
                
                return {
                    totalWords: wordCount,
                    uniqueWords: uniqueWords,
                    averageLength: Math.round(avgLength * 100) / 100
                };
            }
        """)
    }
    
    fun processNumbers(numbers: List<Int>): Int {
        bridge.setGlobal("inputData", numbers)
        val result = engine.execute("processArray(inputData)")
        return (result as? Number)?.toInt() ?: 0
    }
    
    fun analyzeText(text: String): Map<String, Any> {
        bridge.setGlobal("inputText", text)
        val result = engine.execute("analyzeText(inputText)")
        return (result as? Map<String, Any>) ?: emptyMap()
    }
    
    fun close() {
        engine.close()
    }
}

// Usage
val processor = DataProcessor()

val numbers = listOf(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
val result = processor.processNumbers(numbers)
println("Processed numbers result: $result") // Sum of even numbers doubled

val analysis = processor.analyzeText("Hello world! This is a test message with some repeated words.")
println("Text analysis: $analysis")

processor.close()
```

### Configuration Manager

```kotlin
class JSConfigManager {
    private val engine: JavaScriptEngine
    private val bridge: JSBridge
    
    constructor(platformContext: PlatformContext) {
        engine = JavaScriptEngine(platformContext)
        bridge = engine.jsBridge
        setupConfigEnvironment()
    }
    
    private fun setupConfigEnvironment() {
        engine.executeVoid("""
            // Configuration validation and processing
            const configValidator = {
                validate(config) {
                    const required = ['name', 'version'];
                    const missing = required.filter(key => !config[key]);
                    if (missing.length > 0) {
                        throw new Error(`Missing required fields: ${missing.join(', ')}`);
                    }
                    return true;
                },
                
                setDefaults(config) {
                    return {
                        timeout: 5000,
                        retries: 3,
                        debug: false,
                        ...config
                    };
                },
                
                process(rawConfig) {
                    this.validate(rawConfig);
                    const config = this.setDefaults(rawConfig);
                    
                    // Additional processing
                    if (config.timeout < 1000) {
                        console.warn('Timeout is very low, minimum recommended is 1000ms');
                    }
                    
                    return config;
                }
            };
        """)
    }
    
    fun processConfig(rawConfig: Map<String, Any>): Map<String, Any> {
        bridge.setGlobal("rawConfig", rawConfig)
        val result = engine.execute("configValidator.process(rawConfig)")
        return (result as? Map<String, Any>) ?: emptyMap()
    }
    
    fun validateConfig(config: Map<String, Any>): Boolean {
        bridge.setGlobal("config", config)
        return try {
            val result = engine.execute("configValidator.validate(config)")
            result as? Boolean ?: false
        } catch (e: Exception) {
            println("Validation error: ${e.message}")
            false
        }
    }
    
    fun close() {
        engine.close()
    }
}

// Usage
val configManager = JSConfigManager(JvmPlatformContext("ConfigManager"))

val rawConfig = mapOf(
    "name" to "MyApp",
    "version" to "1.0.0",
    "timeout" to 3000
)

val processedConfig = configManager.processConfig(rawConfig)
println("Processed config: $processedConfig")

configManager.close()
```

## Best Practices

### Threading and Resource Management

1. **Use appropriate lifecycle patterns**:
   - Long-lived engines for services
   - `.use {}` blocks for script processing

2. **Thread safety**: All JavaScript operations happen on a single dedicated thread

3. **Resource cleanup**: Always call `close()` when done with long-lived engines

### Performance Tips

1. **Reuse engines** for multiple operations instead of creating new ones
2. **Batch JavaScript operations** to minimize context switching
3. **Use JSBridge** for complex object creation and manipulation
4. **Cache frequently used objects** in JavaScript variables

### Error Handling

1. **Validate inputs** in native functions before passing to JavaScript
2. **Use meaningful error messages** that help debugging
3. **Handle both Kotlin and JavaScript exceptions**

## Common Patterns

### Singleton Engine Pattern

```kotlin
object JSEngine {
    private val platformContext = JvmPlatformContext("GlobalEngine")
    private val engine = JavaScriptEngine(platformContext)
    
    fun execute(script: String): Any? = engine.execute(script)
    fun executeVoid(script: String) = engine.executeVoid(script)
    
    val jsBridge get() = engine.jsBridge
}

// Usage anywhere in your application
val result = JSEngine.execute("Math.random()")
```

### Plugin System Pattern

```kotlin
class PluginManager {
    private val engine = JavaScriptEngine(JvmPlatformContext("PluginManager"))
    private val bridge = engine.jsBridge
    
    fun loadPlugin(pluginCode: String, pluginName: String) {
        // Set up plugin environment
        bridge.setGlobal("pluginAPI", bridge.createObject {
            "log".voidFunc1 { message -> 
                println("[$pluginName] $message") 
            }
            "getData".func0 { 
                mapOf("timestamp" to System.currentTimeMillis()) 
            }
        })
        
        // Execute plugin code
        engine.executeVoid(pluginCode)
    }
    
    fun callPlugin(functionName: String, vararg args: Any): Any? {
        val argsArray = bridge.createArray(args.toList())
        bridge.setGlobal("args", argsArray)
        return engine.execute("$functionName(...args)")
    }
}
```

## Next Steps

- **[Fundamentals Guide](../guides/kotlinjs/fundamentals.md)** - Deep dive into KotlinJS concepts
- **[JSBridge API](../guides/kotlinjs/jsbridge-api.md)** - Complete JSBridge documentation
- **[Examples](examples/)** - More practical code examples
- **[Platform Contexts](../guides/kotlinjs/platform-contexts.md)** - JVM vs Android differences

## Common Issues

### Engine Won't Close
Ensure all references to the engine are released and no background operations are running.

### JavaScript Errors
Always wrap potentially problematic JavaScript code in try-catch blocks and validate inputs.

### Memory Issues
Use `.use {}` blocks for short-lived operations and call `close()` explicitly for long-lived engines.

### Thread Issues
All JavaScript operations happen on the engine's dedicated thread. Don't call JavaScript methods from multiple threads simultaneously.