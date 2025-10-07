//
//  PolyfillLoader.kt
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

/**
 * Utility for loading the embedded polyfill JavaScript code
 */
object PolyfillLoader {
    
    /**
     * Get the polyfill JavaScript code as a string.
     * Loads from resources at runtime.
     */
    fun getPolyfillCode(): String {
        return try {
            val classLoader = this::class.java.classLoader
            val resourceStream = classLoader.getResourceAsStream("polyfill.js")
            resourceStream?.bufferedReader()?.use { it.readText() } ?: ""
        } catch (e: Exception) {
            println("Warning: Could not load polyfill.js from resources: ${e.message}")
            ""
        }
    }
    
    /**
     * Check if polyfill is available
     */
    fun isPolyfillAvailable(): Boolean {
        return try {
            val classLoader = this::class.java.classLoader
            classLoader.getResourceAsStream("polyfill.js") != null
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Get polyfill size for debugging/monitoring
     */
    fun getPolyfillSize(): Int {
        return getPolyfillCode().length
    }
}