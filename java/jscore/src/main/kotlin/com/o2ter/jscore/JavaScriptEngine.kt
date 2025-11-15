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
import com.o2ter.jscore.lib.Crypto
import com.o2ter.jscore.lib.DeviceInfo
import com.o2ter.jscore.lib.BundleInfo
import com.o2ter.jscore.lib.FileSystem
import com.o2ter.jscore.lib.ProcessControl
import com.o2ter.jscore.lib.ProcessInfo
import com.o2ter.jscore.lib.http.URLSession
import com.o2ter.jscore.lib.http.JSWebSocket
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
    
    private val timer = Timer("JSCoreTimer", true)
    private val activeTimers = ConcurrentHashMap<Int, TimerTask>()
    private val nextTimerId = AtomicInteger(0)
    
    // Track active HTTP requests by unique ID (not threads - threads can be reused!)
    private val activeHttpRequests = Collections.synchronizedSet(mutableSetOf<String>())
    
    // Track active WebSocket connections by socket ID
    private val activeWebSockets = Collections.synchronizedSet(mutableSetOf<String>())
    
    // Native Kotlin API implementations - initialized lazily on JS thread
    private lateinit var v8Runtime: V8Runtime
    private lateinit var crypto: Crypto
    private lateinit var fileSystem: FileSystem
    private lateinit var deviceInfo: DeviceInfo
    private lateinit var bundleInfo: BundleInfo
    private lateinit var processInfo: ProcessInfo
    private lateinit var processControl: ProcessControl
    private lateinit var timerNamespace: V8ValueObject // Timer namespace for proper cleanup
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
     * Register an HTTP request for lifecycle tracking
     * Internal use only - called by URLSession
     * @param requestId Unique identifier for this HTTP request
     */
    internal fun registerHttpRequest(requestId: String) {
        activeHttpRequests.add(requestId)
    }
    
    /**
     * Unregister an HTTP request after completion
     * Internal use only - called by URLSession
     * @param requestId Unique identifier for this HTTP request
     */
    internal fun unregisterHttpRequest(requestId: String) {
        activeHttpRequests.remove(requestId)
    }
    
    /**
     * Register a WebSocket connection for lifecycle tracking
     * Internal use only - called by WebSocket
     * @param socketId Unique identifier for this WebSocket connection
     */
    internal fun registerWebSocket(socketId: String) {
        activeWebSockets.add(socketId)
    }
    
    /**
     * Unregister a WebSocket connection after closure
     * Internal use only - called by WebSocket
     * @param socketId Unique identifier for this WebSocket connection
     */
    internal fun unregisterWebSocket(socketId: String) {
        activeWebSockets.remove(socketId)
    }
    
    /**
     * Check if there are any active JavaScript timers
     * Used by runner to determine when to exit
     */
    val hasActiveTimers: Boolean
        get() = activeTimers.isNotEmpty()
    
    /**
     * Get the count of active JavaScript timers
     */
    val activeTimerCount: Int
        get() = activeTimers.size
    
    /**
     * Check if there are active network requests
     * Used by runner to determine when to exit
     */
    val hasActiveNetworkRequests: Boolean
        get() = activeHttpRequests.isNotEmpty()
    
    /**
     * Get the count of active network requests
     */
    val activeNetworkRequestCount: Int
        get() = activeHttpRequests.size
    
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
        get() = activeWebSockets.isNotEmpty()
    
    /**
     * Get the count of active WebSocket connections
     */
    val activeWebSocketCount: Int
        get() = activeWebSockets.size
    
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
            crypto = Crypto(v8Runtime, platformContext)
            fileSystem = FileSystem(v8Runtime, platformContext)
            deviceInfo = DeviceInfo(v8Runtime, platformContext)
            bundleInfo = BundleInfo(v8Runtime, platformContext)
            processInfo = ProcessInfo(v8Runtime, platformContext)
            processControl = ProcessControl(v8Runtime, platformContext)
            
            // Create the __NATIVE_BRIDGE__ global object and store reference for cleanup
            nativeBridge = v8Runtime.createV8ValueObject()
            setupNativeBridges(nativeBridge)
            loadPolyfill(nativeBridge)
        }
    }
    
    private fun setupNativeBridges(nativeBridge: V8ValueObject) {
        // Setup modular native bridges
        crypto.setupBridge(nativeBridge)
        fileSystem.setupBridge(nativeBridge)
        deviceInfo.setupBridge(nativeBridge)
        bundleInfo.setupBridge(nativeBridge)
        processInfo.setupBridge(nativeBridge)
        processControl.setupBridge(nativeBridge)
        
        // Setup HTTP bridge - pass engine for thread-safe async operations
        URLSession.register(this, v8Runtime, platformContext, nativeBridge)
        
        // Setup WebSocket bridge
        val webSocketBridge = JSWebSocket.createNativeBridge(v8Runtime, platformContext, this)
        try {
            nativeBridge.set("WebSocket", webSocketBridge)
        } finally {
            webSocketBridge.close()
        }
        
        // Setup console and timer bridges (these remain here as they're core runtime features)
        setupConsoleBridge(nativeBridge)
        setupTimerBridges(nativeBridge)
        setupPerformanceBridge(nativeBridge)
    }
    
    private fun setupConsoleBridge(nativeBridge: V8ValueObject) {
        // Console API bridges
        nativeBridge.bindFunction(JavetCallbackContext("consoleLog", JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                val message = v8Values.joinToString(" ") { it.toString() }
                platformContext.logger.info("JSConsole", message)
            }))
        nativeBridge.bindFunction(JavetCallbackContext("consoleError", JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                val message = v8Values.joinToString(" ") { it.toString() }
                platformContext.logger.error("JSConsole", message)
            }))
        nativeBridge.bindFunction(JavetCallbackContext("consoleWarn", JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                val message = v8Values.joinToString(" ") { it.toString() }
                platformContext.logger.warning("JSConsole", message)
            }))
        nativeBridge.bindFunction(JavetCallbackContext("consoleDebug", JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                val message = v8Values.joinToString(" ") { it.toString() }
                platformContext.logger.debug("JSConsole", message)
            }))
        
        // Setup console forwarding
        v8Runtime.invokeFunction("""
            (function(nativeBridge) {
                if (!nativeBridge) return;
                
                globalThis.console = {
                    log: function(...args) { nativeBridge.consoleLog.apply(null, args); },
                    error: function(...args) { nativeBridge.consoleError.apply(null, args); },
                    warn: function(...args) { nativeBridge.consoleWarn.apply(null, args); },
                    debug: function(...args) { nativeBridge.consoleDebug.apply(null, args); },
                    info: function(...args) { nativeBridge.consoleLog.apply(null, args); }
                };
            })
        """.trimIndent(), nativeBridge)
    }
    
    private fun setupTimerBridges(nativeBridge: V8ValueObject) {
        
        // Create timer namespace object directly without globalThis pollution
        val timerNamespaceCode = """
            (function() {
                // Private timer namespace - never exposed to globalThis
                const timerNamespace = {
                    callbacks: new Map(),
                    executeCallback: function(id) {
                        const callback = this.callbacks.get(id);
                        if (callback) {
                            this.callbacks.delete(id);
                            callback();
                        }
                    },
                    executeIntervalCallback: function(id) {
                        const callback = this.callbacks.get(id);
                        if (callback) {
                            callback();
                        }
                    },
                    clearCallback: function(id) {
                        this.callbacks.delete(id);
                    },
                    setCallback: function(id, callback) {
                        this.callbacks.set(id, callback);
                    }
                };
                return timerNamespace;
            })();
        """
        
        // Get the timer namespace object directly and store it for cleanup
        // Don't use .use {} here because we need to keep the reference for the engine lifetime
        timerNamespace = v8Runtime.getExecutor(timerNamespaceCode).execute<V8ValueObject>()
        
        // Timer bridges - setTimeout
        val setTimeoutCallback = IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val id = nextTimerId.incrementAndGet()
            
            // Store callback using the timer namespace directly
            if (v8Values.isNotEmpty() && v8Values[0] is V8ValueFunction) {
                timerNamespace.invoke<V8Value>("setCallback", id, v8Values[0]).close()
            }
            
            val delay = if (v8Values.size > 1) {
                when (val delayValue = v8Values[1]) {
                    is V8ValueInteger -> delayValue.value.toLong()
                    is V8ValueLong -> delayValue.value
                    else -> 0L
                }
            } else 0L
            
            val task = object : TimerTask() {
                override fun run() {
                    try {
                        // Execute callback using the timer namespace directly
                        timerNamespace.invoke<V8Value>("executeCallback", id).close()
                    } catch (e: Exception) {
                        platformContext.logger.error("JSCore", "Timer execution failed: ${e.message}")
                    } finally {
                        activeTimers.remove(id)
                    }
                }
            }
            activeTimers[id] = task
            timer.schedule(task, delay)
            
            v8Runtime.createV8ValueInteger(id)
        }
        nativeBridge.bindFunction(JavetCallbackContext("setTimeout", JavetCallbackType.DirectCallNoThisAndResult, setTimeoutCallback))
        
        // clearTimeout
        val clearTimeoutCallback = IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
            val id = if (v8Values.isNotEmpty() && v8Values[0] is V8ValueInteger) {
                (v8Values[0] as V8ValueInteger).value
            } else 0
            activeTimers.remove(id)?.cancel()
            timerNamespace.invoke<V8Value>("clearCallback", id).close()
        }
        nativeBridge.bindFunction(JavetCallbackContext("clearTimeout", JavetCallbackType.DirectCallNoThisAndNoResult, clearTimeoutCallback))
        
        // setInterval
        val setIntervalCallback = IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val id = nextTimerId.incrementAndGet()
            
            // Store callback using the timer namespace directly
            if (v8Values.isNotEmpty() && v8Values[0] is V8ValueFunction) {
                timerNamespace.invoke<V8Value>("setCallback", id, v8Values[0]).close()
            }
            
            val delay = if (v8Values.size > 1) {
                when (val delayValue = v8Values[1]) {
                    is V8ValueInteger -> delayValue.value.toLong()
                    is V8ValueLong -> delayValue.value
                    else -> 0L
                }
            } else 0L
            
            val task = object : TimerTask() {
                override fun run() {
                    try {
                        // For intervals, callback stays in the registry
                        timerNamespace.invoke<V8Value>("executeIntervalCallback", id).close()
                    } catch (e: Exception) {
                        platformContext.logger.error("JSCore", "Interval execution failed: ${e.message}")
                    }
                }
            }
            activeTimers[id] = task
            timer.schedule(task, delay, delay)
            
            v8Runtime.createV8ValueInteger(id)
        }
        nativeBridge.bindFunction(JavetCallbackContext("setInterval", JavetCallbackType.DirectCallNoThisAndResult, setIntervalCallback))
        
        // clearInterval
        val clearIntervalCallback = IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
            val id = if (v8Values.isNotEmpty() && v8Values[0] is V8ValueInteger) {
                (v8Values[0] as V8ValueInteger).value
            } else 0
            activeTimers.remove(id)?.cancel()
            timerNamespace.invoke<V8Value>("clearCallback", id).close()
        }
        nativeBridge.bindFunction(JavetCallbackContext("clearInterval", JavetCallbackType.DirectCallNoThisAndNoResult, clearIntervalCallback))
        
        // Bridge timer functions to JavaScript
        v8Runtime.invokeFunction("""
            (function(nativeBridge) {
                if (!nativeBridge) return;
                
                globalThis.setTimeout = function(callback, delay, ...args) {
                    const wrappedCallback = args.length > 0 
                        ? function() { callback(...args); }
                        : callback;
                    return nativeBridge.setTimeout(wrappedCallback, delay || 0);
                };
                globalThis.clearTimeout = function(id) {
                    nativeBridge.clearTimeout(id);
                };
                globalThis.setInterval = function(callback, delay, ...args) {
                    const wrappedCallback = args.length > 0 
                        ? function() { callback(...args); }
                        : callback;
                    return nativeBridge.setInterval(wrappedCallback, delay || 0);
                };
                globalThis.clearInterval = function(id) {
                    nativeBridge.clearInterval(id);
                };
            })
        """.trimIndent(), nativeBridge)
    }
    
    private fun setupPerformanceBridge(nativeBridge: V8ValueObject) {
        
        // Performance API bridges
        val performanceNowCallback = IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
            v8Runtime.createV8ValueDouble(System.currentTimeMillis().toDouble())
        }
        nativeBridge.bindFunction(JavetCallbackContext("performanceNow", JavetCallbackType.DirectCallNoThisAndResult, performanceNowCallback))
        
        // Bridge performance API
        v8Runtime.invokeFunction("""
            (function(nativeBridge) {
                if (!nativeBridge || !nativeBridge.performanceNow) return;
                
                if (!globalThis.performance) {
                    globalThis.performance = {
                        now: function() { return nativeBridge.performanceNow(); }
                    };
                } else {
                    globalThis.performance.now = function() { return nativeBridge.performanceNow(); };
                }
            })
        """.trimIndent(), nativeBridge)
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
            // Cancel all timers and clear callbacks from timer namespace
            timer.cancel()
            activeTimers.values.forEach { it.cancel() }
            activeTimers.clear()
            
            // Clear all timer callbacks from the namespace to prevent memory leaks
            if (::timerNamespace.isInitialized && !timerNamespace.isClosed) {
                try {
                    timerNamespace.get<V8ValueObject>("callbacks")?.use { callbacks ->
                        callbacks.invoke<V8Value>("clear", *emptyArray<Any>()).close()
                    }
                } catch (e: Exception) {
                    // Ignore cleanup errors - engine is shutting down
                }
            }
            
            // Close file system
            if (::fileSystem.isInitialized) {
                fileSystem.close()
            }
            
            // Close timer namespace
            if (::timerNamespace.isInitialized && !timerNamespace.isClosed) {
                timerNamespace.close()
            }
            
            // CRITICAL: Close all module objects from native bridge BEFORE deleting properties
            // This properly releases V8 objects and prevents memory warnings
            if (::nativeBridge.isInitialized && !nativeBridge.isClosed) {
                try {
                    // Close module objects (V8ValueObjects stored on nativeBridge)
                    val moduleNames = listOf("crypto", "FileSystem", "deviceInfo", "bundleInfo", 
                                            "processInfo", "processControl", "URLSession")
                    moduleNames.forEach { moduleName ->
                        try {
                            nativeBridge.get<V8ValueObject>(moduleName)?.close()
                        } catch (e: Exception) {
                            // Ignore errors - object might not exist or already closed
                        }
                    }
                    
                    // Delete all bound functions to release callback contexts (one at a time)
                    nativeBridge.delete("consoleLog")
                    nativeBridge.delete("consoleError")
                    nativeBridge.delete("consoleWarn")
                    nativeBridge.delete("consoleDebug")
                    nativeBridge.delete("setTimeout")
                    nativeBridge.delete("clearTimeout")
                    nativeBridge.delete("setInterval")
                    nativeBridge.delete("clearInterval")
                    nativeBridge.delete("performanceNow")
                    nativeBridge.delete("crypto")
                    nativeBridge.delete("FileSystem")
                    nativeBridge.delete("deviceInfo")
                    nativeBridge.delete("bundleInfo")
                    nativeBridge.delete("processInfo")
                    nativeBridge.delete("processControl")
                    nativeBridge.delete("URLSession")
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
