//
//  Main.kt
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

package com.o2ter.jscore.runner

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.system.exitProcess

fun printUsage() {
    println("JSCoreRunner - JavaScript Runtime for Kotlin/JVM")
    println("")
    println("Usage:")
    println("  JSCoreRunner <javascript-file> [arguments...]")
    println("  JSCoreRunner -e <javascript-code> [arguments...]")
    println("  JSCoreRunner --eval <javascript-code> [arguments...]")
    println("  JSCoreRunner -h | --help")
    println("")
    println("Options:")
    println("  -e, --eval <code>    Execute JavaScript code directly")
    println("  -h, --help           Show this help message")
    println("")
    println("Arguments:")
    println("  Any additional arguments will be available in JavaScript as process.argv")
    println("")
    println("Examples:")
    println("  JSCoreRunner script.js")
    println("  JSCoreRunner script.js arg1 arg2")
    println("  JSCoreRunner -e \"console.log('Hello, World!')\"")
    println("  JSCoreRunner --eval \"console.log(process.argv)\" arg1 arg2")
}

fun exitWithError(message: String, code: Int = 1): Nothing {
    System.err.println("Error: $message")
    exitProcess(code)
}

fun main(args: Array<String>) = runBlocking {
    val arguments = args.toList()
    
    // Handle help option
    if (arguments.isEmpty() || arguments.contains("-h") || arguments.contains("--help")) {
        printUsage()
        exitProcess(if (arguments.isEmpty()) 1 else 0)
    }
    
    // Create platform context and JavaScript engine with automatic resource management
    val platformContext = JvmPlatformContext("JSCoreRunner")
    
    JavaScriptEngine(platformContext).use { engine ->
        try {
            // Parse command line arguments
            var sourceCode: String = ""
            var isEvalMode = false
        
        if (arguments[0] == "-e" || arguments[0] == "--eval") {
            // Eval mode
            if (arguments.size < 2) {
                exitWithError("Option ${arguments[0]} requires JavaScript code")
            }
            isEvalMode = true
            sourceCode = arguments[1]
        } else {
            // File mode
            val scriptPath = arguments[0]
            
            // Resolve relative paths against current working directory
            val scriptFile = File(scriptPath).let { file ->
                if (file.isAbsolute) file else File(System.getProperty("user.dir"), scriptPath)
            }.canonicalFile
            
            // Check if file exists
            if (!scriptFile.exists()) {
                exitWithError("JavaScript file not found: ${scriptFile.absolutePath}")
            }
            
            // Read the JavaScript file
            try {
                sourceCode = scriptFile.readText()
            } catch (e: Exception) {
                exitWithError("Failed to read JavaScript file: ${e.message}")
            }
        }
        
        // Note: process.argv is now automatically populated by the polyfill from __NATIVE_BRIDGE__.processInfo.arguments
        // The polyfill reads JVM arguments, so command-line arguments passed to the runner are automatically available
        
        // Execute the JavaScript code
        val result = engine.execute(sourceCode)
        
        // If the result is defined and not null, print it (like Node.js REPL)
        if (isEvalMode && result != null && result.toString() != "undefined" && result.toString() != "null") {
            println(result.toString())
        }
        
        // Keep the thread running to handle any async operations (timers, etc.)
        val shouldExit = AtomicBoolean(false)
        
        // Set up signal handling for graceful termination
        Runtime.getRuntime().addShutdownHook(Thread {
            println("\nReceived shutdown signal, shutting down gracefully...")
            shouldExit.set(true)
        })
        
        // Use shorter timeout for eval mode, longer for file mode
        val checkInterval = 100L // 100ms
        val maxIdleCycles = if (isEvalMode) 10 else 50  // 1s for eval, 5s for file
        var idleCycles = 0
        
        // Initial small delay to let any immediate async operations start
        delay(50)
        
        while (!shouldExit.get()) {
            // Check if we have active timers or network requests (matching SwiftJS pattern)
            val hasActiveOps = engine.hasActiveOperations
            
            if (hasActiveOps) {
                // Reset idle counter when we have active operations
                idleCycles = 0
            } else {
                idleCycles++
            }
            
            delay(checkInterval)
            
            // Exit conditions based on mode and activity
            if (isEvalMode) {
                // For eval mode: exit after short idle period
                if (idleCycles >= maxIdleCycles) {
                    break
                }
            } else {
                // For file mode: more sophisticated detection
                if (idleCycles >= maxIdleCycles) {
                    break
                }
            }
        }
        
        } catch (e: Exception) {
            // Handle JavaScript exceptions
            System.err.println("JavaScript Error: ${e.message}")
            if (e.stackTrace.isNotEmpty()) {
                e.printStackTrace()
            }
            exitProcess(1)
        }
        // Resources automatically cleaned up by .use {} block
    }
}