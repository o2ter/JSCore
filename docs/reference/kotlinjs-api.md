# KotlinJS API Reference

Complete API reference for KotlinJS JSBridge, covering native bridge creation, value conversion, and Kotlin-JavaScript interop patterns.

## Table of Contents

- [Getting Started](#getting-started)
- [Value Conversion](#value-conversion)
- [Function Binding](#function-binding)
- [Object Creation](#object-creation)
- [Utility Methods](#utility-methods)
- [Extension Functions](#extension-functions)
- [Complete Examples](#complete-examples)

## Getting Started

The JSBridge is available through the `JavaScriptEngine.jsBridge` property:

```kotlin
val platformContext = JvmPlatformContext("MyApp")
val engine = JavaScriptEngine(platformContext)
val bridge = engine.jsBridge

// Now you can use the bridge to create native APIs
```

## Value Conversion

### Kotlin to JavaScript Conversion

The `toJS()` method automatically converts Kotlin values to JavaScript values:

```kotlin
bridge.toJS(42)           // JavaScript number
bridge.toJS("hello")      // JavaScript string
bridge.toJS(true)         // JavaScript boolean
bridge.toJS(null)         // JavaScript null
bridge.toJS(listOf(1,2,3)) // JavaScript Array
bridge.toJS(mapOf("key" to "value")) // JavaScript Object
bridge.toJS(byteArrayOf(1,2,3,4))    // JavaScript Uint8Array
```

**Supported Types:**
- `null` → `null`
- `Boolean` → `boolean`
- `Int`, `Long` → `number`
- `Float`, `Double` → `number`
- `String` → `string`
- `ByteArray` → `Uint8Array`
- `IntArray` → `Int32Array`
- `DoubleArray` → `Float64Array`
- `Array<*>`, `List<*>` → `Array`
- `Map<*, *>` → `Object`
- `V8Value` → unchanged

### JavaScript to Kotlin Conversion

The `fromJS()` method converts JavaScript values back to Kotlin:

```kotlin
val jsValue = bridge.eval("42")
val kotlinValue = bridge.fromJS(jsValue) // Returns 42 as Int
```

**Conversion Rules:**
- `null`, `undefined` → `null`
- `boolean` → `Boolean`
- `number` → `Int`, `Long`, or `Double` (as appropriate)
- `string` → `String`
- `Array` → `List<Any?>`
- `Object` → `Map<String, Any?>`

## Function Binding

### Basic Function Creation

Create JavaScript functions from Kotlin lambdas:

```kotlin
// Function with return value
val jsFunction = bridge.createFunction { args ->
    val input = args.getOrNull(0) as? String ?: ""
    "Hello, $input!"
}

// Void function (no return value)
val jsVoidFunction = bridge.createVoidFunction { args ->
    println("Called with: ${args.joinToString()}")
}
```

### Typed Function Helpers

For better type safety, use the typed function helpers:

```kotlin
// 0 arguments, with return value
val greet = bridge.createFunction0 {
    "Hello, World!"
}

// 1 argument, with return value
val square = bridge.createFunction1 { num ->
    val n = (num as? Number)?.toDouble() ?: 0.0
    n * n
}

// 2 arguments, with return value
val add = bridge.createFunction2 { a, b ->
    val numA = (a as? Number)?.toDouble() ?: 0.0
    val numB = (b as? Number)?.toDouble() ?: 0.0
    numA + numB
}

// Void functions (no return value)
val log = bridge.createVoidFunction1 { message ->
    println("Log: $message")
}
```

## Object Creation

### From Map

Create JavaScript objects from Kotlin Maps:

```kotlin
val map = mapOf(
    "name" to "John",
    "age" to 30,
    "active" to true
)
val jsObject = bridge.createObject(map)
```

### Using DSL Builder

Create objects using the convenient DSL syntax:

```kotlin
val apiObject = bridge.createObject {
    // Simple values
    "version" to "1.0.0"
    "enabled" to true
    
    // Functions
    "greet".func1 { name ->
        "Hello, $name!"
    }
    
    "calculate".func2 { a, b ->
        val numA = (a as? Number)?.toDouble() ?: 0.0
        val numB = (b as? Number)?.toDouble() ?: 0.0
        numA + numB
    }
    
    // Void functions
    "log".voidFunc1 { message ->
        println("API Log: $message")
    }
    
    // No-argument functions
    "getCurrentTime".func0 {
        System.currentTimeMillis()
    }
}
```

### Arrays and Typed Arrays

Create JavaScript arrays and typed arrays:

```kotlin
// Regular array
val jsArray = bridge.createArray(listOf(1, 2, 3, "hello"))

// Typed arrays
val uint8Array = bridge.createUint8Array(byteArrayOf(1, 2, 3, 4))
val int32Array = bridge.createTypedArray(intArrayOf(100, 200, 300))
val float64Array = bridge.createTypedArray(doubleArrayOf(1.5, 2.5, 3.5))
```

## Utility Methods

### Execute JavaScript Code

Execute JavaScript with automatic value conversion:

```kotlin
// Execute and get result
val result = bridge.eval("1 + 2 * 3") // Returns 7

// Execute without return value
bridge.evalVoid("console.log('Hello from Kotlin!')")
```

### Global Variables

Set and get global JavaScript variables:

```kotlin
// Set global variable
bridge.setGlobal("myData", mapOf("key" to "value"))

// Get global variable
val userData = bridge.getGlobal("userData") // Returns Map or null
```

## Extension Functions

The JSBridge includes convenient extension functions for V8ValueObject:

```kotlin
val nativeAPI = v8Runtime.createV8ValueObject()

// Add functions
nativeAPI.addFunction("multiply", bridge) { args ->
    val a = (args.getOrNull(0) as? Number)?.toDouble() ?: 0.0
    val b = (args.getOrNull(1) as? Number)?.toDouble() ?: 0.0
    a * b
}

// Add void functions
nativeAPI.addVoidFunction("logMessage", bridge) { args ->
    println("Native Log: ${args.getOrNull(0)}")
}

// Add values
nativeAPI.addValue("version", bridge, "2.1.0")
nativeAPI.addValue("config", bridge, mapOf("debug" to true))
```

## Complete Examples

### Creating a Math API

```kotlin
val mathAPI = bridge.createObject {
    "PI" to Math.PI
    "E" to Math.E
    
    "add".func2 { a, b ->
        val numA = (a as? Number)?.toDouble() ?: 0.0
        val numB = (b as? Number)?.toDouble() ?: 0.0
        numA + numB
    }
    
    "sqrt".func1 { num ->
        val n = (num as? Number)?.toDouble() ?: 0.0
        kotlin.math.sqrt(n)
    }
    
    "random".func0 {
        Math.random()
    }
    
    "randomInt".func1 { maxArg ->
        val max = (maxArg as? Number)?.toInt() ?: 100
        (Math.random() * max).toInt()
    }
}

// Add to global scope
bridge.setGlobal("MathAPI", mathAPI)
```

JavaScript usage:
```javascript
console.log(MathAPI.PI);           // 3.141592653589793
console.log(MathAPI.add(5, 3));    // 8
console.log(MathAPI.sqrt(16));     // 4
console.log(MathAPI.random());     // Random number 0-1
console.log(MathAPI.randomInt(10)); // Random int 0-9
```

### Creating a File System API

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
```

JavaScript usage:
```javascript
if (FileAPI.exists("/path/to/file.txt")) {
    const content = FileAPI.readFile("/path/to/file.txt");
    console.log("File content:", content);
}

FileAPI.writeFile("/path/to/output.txt", "Hello from JavaScript!");

const files = FileAPI.listFiles("/path/to/directory");
console.log("Files:", files);
```

### Error Handling

Always handle errors appropriately in your native functions:

```kotlin
val safeAPI = bridge.createObject {
    "parseJSON".func1 { jsonArg ->
        val jsonString = jsonArg?.toString() ?: ""
        try {
            // Use a JSON library like kotlinx.serialization or Gson
            // This is a simplified example
            if (jsonString.startsWith("{") && jsonString.endsWith("}")) {
                mapOf("parsed" to true, "data" to jsonString)
            } else {
                throw IllegalArgumentException("Invalid JSON format")
            }
        } catch (e: Exception) {
            // Create JavaScript Error object
            throw RuntimeException("JSON parsing failed: ${e.message}")
        }
    }
    
    "validateEmail".func1 { emailArg ->
        val email = emailArg?.toString() ?: ""
        val emailRegex = Regex("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}")
        emailRegex.matches(email)
    }
}
```

## Best Practices

1. **Resource Management**: The JSBridge automatically handles V8Value cleanup in most cases, but be aware that some operations may require manual resource management.

2. **Type Safety**: Always validate argument types in your native functions:
   ```kotlin
   "myFunction".func1 { arg ->
       val number = (arg as? Number)?.toDouble() 
           ?: throw IllegalArgumentException("Expected number, got ${arg?.javaClass?.simpleName}")
       // Use number safely
   }
   ```

3. **Error Handling**: Throw meaningful exceptions that will be converted to JavaScript errors:
   ```kotlin
   "riskyOperation".func0 {
       try {
           // Risky operation
           performOperation()
       } catch (e: Exception) {
           throw RuntimeException("Operation failed: ${e.message}")
       }
   }
   ```

4. **Performance**: For high-frequency operations, consider caching converted values or using more direct Javet APIs.

5. **Thread Safety**: The JSBridge is designed to work with the V8 runtime's single-threaded nature. Don't call JSBridge methods from other threads.

## Migration from Raw Javet API

If you're migrating from direct Javet API usage, here's how the JSBridge simplifies common patterns:

### Before (Raw Javet):
```kotlin
val callback = IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
    val arg = if (v8Values.isNotEmpty() && v8Values[0] is V8ValueString) {
        (v8Values[0] as V8ValueString).value
    } else ""
    v8Runtime.createV8ValueString("Hello, $arg!")
}
val function = v8Runtime.createV8ValueFunction(
    JavetCallbackContext("greet", JavetCallbackType.DirectCallNoThisAndResult, callback)
)
```

### After (JSBridge):
```kotlin
val function = bridge.createFunction1 { arg ->
    val name = arg?.toString() ?: ""
    "Hello, $name!"
}
```

The JSBridge reduces boilerplate code by 80% while providing better type safety and error handling.