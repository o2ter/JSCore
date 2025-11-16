//
//  JavaScriptEngine.kt
//
//  The MIT License
//  Copyright (c) 2021 - 2025 O2ter Limited. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

package com.o2ter.jscore

import com.caoccao.javet.interop.V8Host
import com.caoccao.javet.interop.V8Runtime
import com.caoccao.javet.interop.options.V8RuntimeOptions
import com.caoccao.javet.interop.callback.IJavetDirectCallable
import com.caoccao.javet.interop.callback.JavetCallbackContext
import com.caoccao.javet.interop.callback.JavetCallbackType
import com.caoccao.javet.values.V8Value
import com.caoccao.javet.values.primitive.V8ValueInteger
import com.caoccao.javet.values.primitive.V8ValueLong
import com.caoccao.javet.values.primitive.V8ValueDouble
import com.caoccao.javet.values.reference.V8ValueArray
import com.caoccao.javet.values.reference.V8ValueFunction
import com.caoccao.javet.values.reference.V8ValueObject
import com.o2ter.jscore.lib.Compression
import com.o2ter.jscore.lib.Console
import com.o2ter.jscore.lib.Crypto
import com.o2ter.jscore.lib.DeviceInfo
import com.o2ter.jscore.lib.BundleInfo
import com.o2ter.jscore.lib.FileSystem
import com.o2ter.jscore.lib.Performance
import com.o2ter.jscore.lib.ProcessControl
import com.o2ter.jscore.lib.ProcessInfo
import com.o2ter.jscore.lib.JSTimer
import com.o2ter.jscore.lib.http.URLSession
import com.o2ter.jscore.lib.http.JSWebSocket
import com.o2ter.jscore.lib.http.setupWebSocketBridge
import java.util.Timer
import java.util.TimerTask
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Callable

/**
 * Helper function to invoke an IIFE with parameters
 * @param code JavaScript IIFE code (e.g., "(function(x) { return x * 2; })")
 * @param args Arguments to pass to the function
 * @return The result of the function invocation
 */
internal fun V8Runtime.invokeFunction(code: String, vararg args: Any?): V8Value {
    return this.getExecutor(code).execute<V8ValueFunction>().use { fn ->
        fn.call(null, *args)
    }
}

/**
 * JavaScript engine using Javet V8
 * Provides a bridge between Kotlin and JavaScript with Node.js-like APIs
 * 
 * Extends AutoCleanable for automatic resource cleanup on garbage collection.
 * While close() should always be called explicitly, the Cleaner provides a safety net.
 * 
 * ## Lifecycle Management
 * 
 * The engine should typically be **long-lived** and reused throughout your application:
 * 
 * ### Long-Lived Engines (Recommended for most apps):
 * ```kotlin
 * class MyApplication {
 *     // Keep engine alive for application lifetime
 *     private val engine = JavaScriptEngine(platformContext)
 *     
 *     fun executeScript(code: String) {
 *         return engine.execute(code)
 *     }
 *     
 *     fun shutdown() {
 *         engine.close() // Only when app is shutting down
 *     }
 * }
 * ```
 * 
 * ### Android Activity Example:
 * ```kotlin
 * class MainActivity : AppCompatActivity() {
 *     private lateinit var engine: JavaScriptEngine
 *     
 *     override fun onCreate(savedInstanceState: Bundle?) {
 *         super.onCreate(savedInstanceState)
 *         engine = JavaScriptEngine(AndroidPlatformContext(this))
 *     }
 *     
 *     fun runJavaScript(code: String) = engine.execute(code)
 *     
 *     override fun onDestroy() {
 *         super.onDestroy()
 *         engine.close()
 *     }
 * }
 * ```
 * 
 * ### Short-Lived Engines (CLI tools, one-off scripts):
 * ```kotlin
 * fun runScript(file: File) {
 *     JavaScriptEngine(platformContext).use { engine ->
 *         engine.execute(file.readText())
 *     }
 * }
 * ```
 * 
 * ## Threading Model
 * 
 * V8Runtime requires all operations to execute on the same thread that created it.
 * This class uses an ExecutorService to manage JavaScript execution:
 * 
 * - **Default mode**: Creates a single-threaded executor for non-blocking JS execution
 * - **Custom mode**: Accepts user-provided ExecutorService for custom threading
 * 
 * ### Thread Safety
 * 
 * All public methods (`execute()`, `set()`, `get()`) are thread-safe and automatically
 * dispatch to the JS thread. Internal deadlock prevention ensures initialization works
 * correctly even when calling JS operations from within the init block.
 * 
 * ### Usage Examples
 * 
 * ```kotlin
 * // LONG-LIVED: Keep engine alive for application lifetime (most common)
 * class MyService(platformContext: PlatformContext) {
 *     private val jsEngine = JavaScriptEngine(platformContext)
 *     
 *     fun processData(data: String): Any? {
 *         return jsEngine.execute("processData('$data')")
 *     }
 *     
 *     fun shutdown() {
 *         jsEngine.close()
 *     }
 * }
 * 
 * // SHORT-LIVED: For one-off scripts or CLI tools
 * fun executeScriptFile(file: File) {
 *     JavaScriptEngine(platformContext).use { engine ->
 *         engine.execute(file.readText())
 *     }
 * }
 * ```
 * 
 * ### For Native Bridge Implementers
 * 
 * Use `executeOnJSThreadAsync()` for async callbacks from background threads:
 * ```kotlin
 * Thread {
 *     val result = doBackgroundWork()
 *     engine.executeOnJSThreadAsync {
 *         // Safely access V8 from any thread
 *         resolver.resolve(result)
 *     }
 * }.start()
 * ```
 *
 * @param platformContext Platform-specific context for accessing system resources
 * @param executor Optional ExecutorService for running JS operations. If null, creates
 *                 a single-threaded daemon executor. Using your own executor allows
 *                 custom thread naming, priority, and lifecycle management.
 */
class JavaScriptEngine(
    private val platformContext: PlatformContext,
    executor: ExecutorService? = null
) : AutoCleanable() {
    
    private val ownedExecutor: ExecutorService?
    private val jsExecutor: ExecutorService
    
    // Store the thread that V8Runtime is created on to detect recursive calls
    @Volatile
    private var jsThread: Thread? = null
    
    companion object {
        private val icuConfigured = AtomicBoolean(false)
        
        /**
         * Configure ICU data file for i18n support
         * This must be called before the first V8 runtime is created
         * Returns true if ICU is configured (either just now or previously)
         */
        private fun configureIcu(icuDataPath: String?): Boolean {
            if (icuDataPath == null) {
                return false
            }
            
            // If already configured, return true
            if (icuConfigured.get()) {
                return true
            }
            
            // Try to configure (only first call will succeed)
            if (icuConfigured.compareAndSet(false, true)) {
                try {
                    V8RuntimeOptions.V8_FLAGS.setIcuDataFile(icuDataPath)
                    return true
                } catch (e: Exception) {
                    println("✗ Failed to configure ICU: ${e.message}")
                    icuConfigured.set(false) // Reset on failure
                    return false
                }
            }
            
            // Another thread configured it, that's fine
            return true
        }
    }
    
    // Native Kotlin API implementations - initialized lazily on JS thread
    private lateinit var v8Runtime: V8Runtime
    private lateinit var console: Console
    private lateinit var jsTimer: JSTimer
    private lateinit var performance: Performance
    private lateinit var crypto: Crypto
    private lateinit var compression: Compression
    private lateinit var fileSystem: FileSystem
    private lateinit var deviceInfo: DeviceInfo
    private lateinit var bundleInfo: BundleInfo
    private lateinit var processInfo: ProcessInfo
    private lateinit var processControl: ProcessControl
    private lateinit var urlSession: URLSession
    private lateinit var jsWebSocket: JSWebSocket
    private lateinit var nativeBridge: V8ValueObject // Native bridge object that holds all callback contexts
    
    /**
     * Public logger for accessing the platform's logging functionality
     * Provides access to the same logger used internally by the engine
     */
    val logger: PlatformLogger
        get() = platformContext.logger
    
    /**
     * Execute a block on the JavaScript thread and return the result
     * This fixes the type casting issue by properly handling Unit returns
     * 
     * IMPORTANT: Checks if already on JS thread to avoid deadlock during initialization
     */
    private inline fun <T> executeOnJSThread(crossinline block: () -> T): T {
        // Check if we're already on the JS thread to avoid deadlock
        if (Thread.currentThread() == jsThread) {
            return block()
        }
        return jsExecutor.submit(Callable { block() }).get()
    }
    
    /**
     * Execute a block on the JavaScript thread asynchronously (fire and forget)
     * Public so native bridges (like URLSession) can use it for async callbacks
     * 
     * Skips execution if engine is closed to prevent errors during shutdown.
     */
    fun executeOnJSThreadAsync(block: () -> Unit) {
        // Skip if engine is closed - no need to check again inside
        if (isClosed) return
        
        jsExecutor.submit {
            // Double-check: skip if engine was closed while this was queued
            if (isClosed) return@submit
            
            try {
                block()
            } catch (e: Exception) {
                // Silently ignore errors if engine is closed
                if (!isClosed) {
                    platformContext.logger.error("JavaScriptEngine", "Async operation failed: ${e.message}")
                }
            }
        }
    }
    
    /**
     * Check if there are any active JavaScript timers
     * Used by runner to determine when to exit
     */
    val hasActiveTimers: Boolean
        get() = jsTimer.hasActiveTimers
    
    /**
     * Get the count of active JavaScript timers
     */
    val activeTimerCount: Int
        get() = jsTimer.activeTimerCount
    
    /**
     * Check if there are active network requests
     * Used by runner to determine when to exit
     */
    val hasActiveNetworkRequests: Boolean
        get() = urlSession.hasActiveNetworkRequests
    
    /**
     * Get the count of active network requests
     */
    val activeNetworkRequestCount: Int
        get() = urlSession.activeNetworkRequestCount
    
    /**
     * Check if there are any active file handles
     * Used by runner to determine when to exit
     */
    val hasActiveFileHandles: Boolean
        get() = fileSystem.hasActiveFileHandles
    
    /**
     * Get the count of active file handles
     */
    val activeFileHandleCount: Int
        get() = fileSystem.activeFileHandleCount
    
    /**
     * Check if there are active WebSocket connections
     * Used by runner to determine when to exit
     */
    val hasActiveWebSockets: Boolean
        get() = jsWebSocket.hasActiveWebSockets
    
    /**
     * Get the count of active WebSocket connections
     */
    val activeWebSocketCount: Int
        get() = jsWebSocket.activeWebSocketCount
    
    /**
     * Check if there are any active async operations (timers, network, file handles, or WebSockets)
     * Used by runner to determine when to exit
     */
    val hasActiveOperations: Boolean
        get() = hasActiveTimers || hasActiveNetworkRequests || hasActiveFileHandles || hasActiveWebSockets
    
    init {
        // Setup executor
        if (executor == null) {
            ownedExecutor = Executors.newSingleThreadExecutor { r ->
                Thread(r, "JavaScriptEngine-Thread").apply { isDaemon = true }
            }
            jsExecutor = ownedExecutor
        } else {
            ownedExecutor = null
            jsExecutor = executor
        }
        
        // Initialize V8Runtime and bridges on the JS executor thread
        executeOnJSThread {
            // Capture the thread that V8Runtime is created on
            jsThread = Thread.currentThread()
            
            val icuPath = platformContext.getIcuDataPath()
            if (icuPath == null || icuPath.isEmpty()) {
                throw RuntimeException("ICU data not found. i18n support is required but ICU data path is not configured.")
            }
            
            val icuConfigured = configureIcu(icuPath)
            if (!icuConfigured) {
                throw RuntimeException("Failed to configure ICU data at: $icuPath")
            }
            
            // Create V8Runtime on this thread
            v8Runtime = try {
                V8Host.getV8I18nInstance().createV8Runtime()
            } catch (e: Exception) {
                platformContext.logger.error("JSEngine", "Failed to create V8 instance: ${e.message}")
                throw RuntimeException("Failed to initialize JavaScript engine with i18n support", e)
            }
            
            // Initialize everything else
            console = Console(v8Runtime, platformContext)
            jsTimer = JSTimer(v8Runtime, platformContext)
            performance = Performance(v8Runtime)
            crypto = Crypto(v8Runtime, platformContext)
            compression = Compression(v8Runtime)
            fileSystem = FileSystem(v8Runtime, platformContext)
            deviceInfo = DeviceInfo(v8Runtime, platformContext)
            bundleInfo = BundleInfo(v8Runtime, platformContext)
            processInfo = ProcessInfo(v8Runtime, platformContext)
            processControl = ProcessControl(v8Runtime, platformContext)
            urlSession = URLSession(v8Runtime, platformContext, this)
            jsWebSocket = JSWebSocket(v8Runtime, platformContext, this)
            
            // Create the __NATIVE_BRIDGE__ global object and store reference for cleanup
            nativeBridge = v8Runtime.createV8ValueObject()
            setupNativeBridges(nativeBridge)
            loadPolyfill(nativeBridge)
        }
    }
    
    private fun setupNativeBridges(nativeBridge: V8ValueObject) {
        // Core runtime bridges (console, timers, performance)
        console.setupBridge(nativeBridge)
        jsTimer.setupBridge(nativeBridge)
        performance.setupBridge(nativeBridge)
        
        // Platform information bridges (device, bundle, process)
        deviceInfo.setupBridge(nativeBridge)
        bundleInfo.setupBridge(nativeBridge)
        processInfo.setupBridge(nativeBridge)
        processControl.setupBridge(nativeBridge)
        
        // Cryptography and compression bridges
        crypto.setupBridge(nativeBridge)
        compression.setupBridge(nativeBridge)
        
        // File system bridge
        fileSystem.setupBridge(nativeBridge)
        
        // Network bridges (HTTP and WebSocket)
        urlSession.setupBridge(nativeBridge)
        setupWebSocketBridge(nativeBridge, jsWebSocket, v8Runtime)
    }
    
    private fun loadPolyfill(nativeBridge: V8ValueObject) {
        try {
            val polyfillCode = PolyfillLoader.getPolyfillCode()
            if (polyfillCode.isNotEmpty()) {
                v8Runtime.invokeFunction(polyfillCode, nativeBridge)
            } else {
                platformContext.logger.warning("JavaScriptEngine", "Polyfill code is empty")
            }
        } catch (e: Exception) {
            platformContext.logger.error("JavaScriptEngine", "Failed to load polyfill: ${e.message}")
            throw RuntimeException("Failed to load JavaScript polyfill", e)
        }
    }
    
    fun execute(code: String): Any? {
        return executeOnJSThread {
            try {
                v8Runtime.getExecutor(code).execute<V8Value>().use { result ->
                    result.toNative()
                }
            } catch (e: Exception) {
                platformContext.logger.error("JavaScriptEngine", "Execution failed: ${e.message}")
                throw RuntimeException("JavaScript execution failed", e)
            }
        }
    }
    
    fun executeVoid(code: String) {
        executeOnJSThread {
            try {
                v8Runtime.getExecutor(code).executeVoid()
            } catch (e: Exception) {
                platformContext.logger.error("JavaScriptEngine", "Execution failed: ${e.message}")
                throw RuntimeException("JavaScript execution failed", e)
            }
        }
    }

    /**
     * Execute JavaScript code with named arguments
     * 
     * @param namedArgs Map of argument names to values that will be available in the code
     * @param code JavaScript code that can use the named arguments
     * @return The result of the execution
     * 
     * Example:
     * ```kotlin
     * val result = engine.execute(mapOf(
     *     "url" to "https://example.com",
     *     "timeout" to 30
     * ), """
     *     fetch(url, { timeout: timeout }).then(r => r.json())
     * """)
     * ```
     */
    fun execute(namedArgs: Map<String, Any?>, code: String): Any? {
        return executeOnJSThread {
            try {
                // Build argument assignment code with proper indexing
                val argNames = namedArgs.keys.toList()
                val argAssignments = argNames.mapIndexed { index, name ->
                    "const $name = arguments[$index];"
                }.joinToString("\n")
                
                // Wrap code in IIFE with argument assignments
                val wrappedCode = """
                    (function() {
                        $argAssignments
                        return ($code);
                    })
                """.trimIndent()
                
                // Convert all arguments to proper V8Values for correct bridging
                val v8Args = namedArgs.values.map { value ->
                    v8Runtime.createJSObject(value)
                }.toTypedArray()
                
                try {
                    // Pass converted values as positional arguments in the same order as names
                    v8Runtime.invokeFunction(wrappedCode, *v8Args).use { result ->
                        result.toNative()
                    }
                } finally {
                    // Clean up all V8Values we created
                    v8Args.forEach { it.close() }
                }
            } catch (e: Exception) {
                platformContext.logger.error("JavaScriptEngine", "Execution failed: ${e.message}")
                throw RuntimeException("JavaScript execution failed", e)
            }
        }
    }
    
    fun set(name: String, value: Any?) {
        executeOnJSThread {
            v8Runtime.globalObject.use { globalObject ->
                v8Runtime.createJSObject(value).use { jsValue ->
                    globalObject.set(name, jsValue)
                }
            }
        }
    }
    
    fun get(name: String): Any? {
        return executeOnJSThread {
            v8Runtime.globalObject.use { globalObject ->
                globalObject.get<V8Value>(name).use { result ->
                    result.toNative()
                }
            }
        }
    }
    
    /**
     * Closes the JavaScript engine and releases all resources.
     * 
     * **When to call:**
     * - Application shutdown
     * - Activity/Fragment onDestroy (Android)
     * - Service cleanup
     * - End of CLI tool execution
     * - Automatically by .use {} block
     * 
     * **Do NOT call during normal operation** - the engine should be long-lived and reused.
     * 
     * This method:
     * - Cancels all active timers
     * - Closes file system resources
     * - Closes the V8Runtime (releases native memory)
     * - Shuts down owned ExecutorService
     * 
     * **Automatic Cleanup:** If you forget to call close(), the Cleaner will automatically
     * clean up when this object is garbage collected. However, explicit close() is always
     * preferred for predictable resource management.
     * 
     * **Thread Safety:** Safe to call from any thread. Safe to call multiple times.
     * 
     * Example:
     * ```kotlin
     * class MyApp {
     *     private val engine = JavaScriptEngine(context)
     *     
     *     fun onShutdown() {
     *         engine.close() // Explicit cleanup (recommended)
     *     }
     * }
     * 
     * // Or use .use {} pattern for automatic cleanup
     * JavaScriptEngine(context).use { engine ->
     *     engine.execute("console.log('hello')")
     * } // close() called automatically
     * ```
     */
    override fun close() {
        // Mark as closed first - prevents new operations from starting
        super.close()
        
        try {
            // Close timer manager
            if (::jsTimer.isInitialized) {
                jsTimer.close()
            }
            
            // Close file system
            if (::fileSystem.isInitialized) {
                fileSystem.close()
            }
            
            // Close URLSession
            if (::urlSession.isInitialized) {
                urlSession.close()
            }
            
            // Clean up native bridge
            // Module objects (crypto, FileSystem, etc.) were closed after setup
            // But we must still delete ALL properties to release callback contexts properly
            if (::nativeBridge.isInitialized && !nativeBridge.isClosed) {
                try {
                    // Delete all properties - this releases callback contexts
                    // Even though module objects were closed, their V8 references persist on nativeBridge
                    val propertyNames = listOf(
                        "consoleLog", "consoleError", "consoleWarn", "consoleDebug",
                        "setTimeout", "clearTimeout", "setInterval", "clearInterval",
                        "performanceNow",
                        "crypto", "FileSystem", "deviceInfo", "bundleInfo",
                        "processInfo", "processControl", "URLSession", "WebSocket", "compression"
                    )
                    propertyNames.forEach { nativeBridge.delete(it) }
                } catch (e: Exception) {
                    // Ignore errors during cleanup
                }
                nativeBridge.close()
            }
            
            // Close V8Runtime - this will naturally fail any pending callbacks
            if (::v8Runtime.isInitialized && !v8Runtime.isClosed) {
                // Trigger low memory notification to force GC and cleanup
                try {
                    v8Runtime.lowMemoryNotification()
                } catch (e: Exception) {
                    // Ignore if not supported
                }
                v8Runtime.close()
            }
        } catch (e: Exception) {
            platformContext.logger.error("JavaScriptEngine", "Cleanup failed: ${e.message}")
        }
        
        // Shutdown owned executor if we created it
        ownedExecutor?.shutdown()
    }
}
