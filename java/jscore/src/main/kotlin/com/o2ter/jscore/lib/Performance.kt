//
//  Performance.kt
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

package com.o2ter.jscore.lib

import com.caoccao.javet.interop.V8Runtime
import com.caoccao.javet.interop.callback.IJavetDirectCallable
import com.caoccao.javet.interop.callback.JavetCallbackContext
import com.caoccao.javet.interop.callback.JavetCallbackType
import com.caoccao.javet.values.V8Value
import com.caoccao.javet.values.reference.V8ValueObject
import com.o2ter.jscore.createJSObject
import java.util.concurrent.ConcurrentHashMap

/**
 * Performance API implementation for JavaScript
 * Provides high-resolution timing and performance measurement capabilities
 */
class Performance(private val v8Runtime: V8Runtime) {
    
    // Store performance entries with thread-safe access
    private val marks = ConcurrentHashMap<String, Double>()
    private val measures = ConcurrentHashMap<String, Map<String, Any>>()
    
    companion object {
        // Reference time (application start time) in nanoseconds
        private val referenceTime = System.nanoTime()
    }
    
    /**
     * Returns high-resolution timestamp in milliseconds since time origin
     * Uses System.nanoTime() for microsecond precision
     */
    fun now(): Double {
        val currentTime = System.nanoTime()
        // Convert nanoseconds to milliseconds with high precision
        return (currentTime - referenceTime) / 1_000_000.0
    }
    
    /**
     * Create a named timestamp marker
     */
    fun mark(name: String): V8Value {
        val timestamp = now()
        marks[name] = timestamp
        
        // Return PerformanceMark object
        return v8Runtime.createJSObject(
            properties = mapOf(
                "name" to name,
                "entryType" to "mark",
                "startTime" to timestamp,
                "duration" to 0.0
            )
        )
    }
    
    /**
     * Measure duration between two marks
     */
    fun measure(name: String, startMark: String?, endMark: String?): V8Value {
        val endTime: Double = if (endMark != null) {
            marks[endMark] ?: throw RuntimeException("The mark '$endMark' does not exist")
        } else {
            now()
        }
        
        val startTime: Double = if (startMark != null) {
            marks[startMark] ?: throw RuntimeException("The mark '$startMark' does not exist")
        } else {
            0.0 // Start from time origin
        }
        
        val duration = endTime - startTime
        
        // Store measure
        val entry = mapOf(
            "name" to name,
            "entryType" to "measure",
            "startTime" to startTime,
            "duration" to duration
        )
        
        measures[name] = entry
        
        return v8Runtime.createJSObject(properties = entry)
    }
    
    /**
     * Get all entries of a specific type
     */
    fun getEntriesByType(type: String): V8Value {
        val entries = mutableListOf<Map<String, Any>>()
        
        when (type) {
            "mark" -> {
                marks.forEach { (name, timestamp) ->
                    entries.add(
                        mapOf(
                            "name" to name,
                            "entryType" to "mark",
                            "startTime" to timestamp,
                            "duration" to 0.0
                        )
                    )
                }
            }
            "measure" -> {
                entries.addAll(measures.values)
            }
        }
        
        // Sort by startTime
        entries.sortBy { it["startTime"] as? Double ?: 0.0 }
        
        return v8Runtime.createV8ValueArray().use { array ->
            entries.forEach { entry ->
                v8Runtime.createJSObject(properties = entry).use { obj ->
                    array.push(obj)
                }
            }
            array
        }
    }
    
    /**
     * Get all entries with a specific name
     */
    fun getEntriesByName(name: String, type: String?): V8Value {
        val entries = mutableListOf<Map<String, Any>>()
        
        // Check marks
        if (type == null || type == "mark") {
            marks[name]?.let { timestamp ->
                entries.add(
                    mapOf(
                        "name" to name,
                        "entryType" to "mark",
                        "startTime" to timestamp,
                        "duration" to 0.0
                    )
                )
            }
        }
        
        // Check measures
        if (type == null || type == "measure") {
            measures[name]?.let { measure ->
                entries.add(measure)
            }
        }
        
        // Sort by startTime
        entries.sortBy { it["startTime"] as? Double ?: 0.0 }
        
        return v8Runtime.createV8ValueArray().use { array ->
            entries.forEach { entry ->
                v8Runtime.createJSObject(properties = entry).use { obj ->
                    array.push(obj)
                }
            }
            array
        }
    }
    
    /**
     * Get all performance entries
     */
    fun getEntries(): V8Value {
        val entries = mutableListOf<Map<String, Any>>()
        
        // Add all marks
        marks.forEach { (name, timestamp) ->
            entries.add(
                mapOf(
                    "name" to name,
                    "entryType" to "mark",
                    "startTime" to timestamp,
                    "duration" to 0.0
                )
            )
        }
        
        // Add all measures
        entries.addAll(measures.values)
        
        // Sort by startTime
        entries.sortBy { it["startTime"] as? Double ?: 0.0 }
        
        return v8Runtime.createV8ValueArray().use { array ->
            entries.forEach { entry ->
                v8Runtime.createJSObject(properties = entry).use { obj ->
                    array.push(obj)
                }
            }
            array
        }
    }
    
    /**
     * Clear marks
     */
    fun clearMarks(name: String?) {
        if (name != null) {
            marks.remove(name)
        } else {
            marks.clear()
        }
    }
    
    /**
     * Clear measures
     */
    fun clearMeasures(name: String?) {
        if (name != null) {
            measures.remove(name)
        } else {
            measures.clear()
        }
    }
    
    /**
     * Setup performance bridge in the native bridge object
     * @param nativeBridge The native bridge object to register performance APIs
     */
    fun setupBridge(nativeBridge: V8ValueObject) {
        val performanceBridge = v8Runtime.createV8ValueObject()
        try {
            performanceBridge.bindFunction(JavetCallbackContext("now",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    return@NoThisAndResult v8Runtime.createV8ValueDouble(now())
                }))
            
            performanceBridge.bindFunction(JavetCallbackContext("mark",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty()) {
                        throw RuntimeException("mark() requires 1 argument")
                    }
                    return@NoThisAndResult mark(v8Values[0].toString())
                }))
            
            performanceBridge.bindFunction(JavetCallbackContext("measure",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty()) {
                        throw RuntimeException("measure() requires at least 1 argument")
                    }
                    val name = v8Values[0].toString()
                    val startMark = if (v8Values.size > 1 && !v8Values[1].isNullOrUndefined) v8Values[1].toString() else null
                    val endMark = if (v8Values.size > 2 && !v8Values[2].isNullOrUndefined) v8Values[2].toString() else null
                    return@NoThisAndResult measure(name, startMark, endMark)
                }))
            
            performanceBridge.bindFunction(JavetCallbackContext("getEntriesByType",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty()) {
                        throw RuntimeException("getEntriesByType() requires 1 argument")
                    }
                    return@NoThisAndResult getEntriesByType(v8Values[0].toString())
                }))
            
            performanceBridge.bindFunction(JavetCallbackContext("getEntriesByName",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty()) {
                        throw RuntimeException("getEntriesByName() requires at least 1 argument")
                    }
                    val name = v8Values[0].toString()
                    val type = if (v8Values.size > 1 && !v8Values[1].isNullOrUndefined) v8Values[1].toString() else null
                    return@NoThisAndResult getEntriesByName(name, type)
                }))
            
            performanceBridge.bindFunction(JavetCallbackContext("getEntries",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    return@NoThisAndResult getEntries()
                }))
            
            performanceBridge.bindFunction(JavetCallbackContext("clearMarks",
                JavetCallbackType.DirectCallNoThisAndNoResult,
                IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                    val name = if (v8Values.isNotEmpty() && !v8Values[0].isNullOrUndefined) v8Values[0].toString() else null
                    clearMarks(name)
                }))
            
            performanceBridge.bindFunction(JavetCallbackContext("clearMeasures",
                JavetCallbackType.DirectCallNoThisAndNoResult,
                IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                    val name = if (v8Values.isNotEmpty() && !v8Values[0].isNullOrUndefined) v8Values[0].toString() else null
                    clearMeasures(name)
                }))
            
            nativeBridge.set("performance", performanceBridge)
        } finally {
            performanceBridge.close()
        }
    }
}
