//
//  bridge.kt
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

import com.caoccao.javet.interop.V8Runtime
import com.caoccao.javet.interop.callback.IJavetDirectCallable
import com.caoccao.javet.interop.callback.JavetCallbackContext
import com.caoccao.javet.interop.callback.JavetCallbackType
import com.caoccao.javet.values.V8Value
import kotlin.reflect.KProperty1
import kotlin.reflect.KType
import kotlin.reflect.full.memberFunctions
import kotlin.reflect.full.memberProperties
import kotlin.reflect.jvm.ExperimentalReflectionOnLambdas
import kotlin.reflect.jvm.reflect
import com.caoccao.javet.values.primitive.*
import com.caoccao.javet.values.reference.*

fun V8Value.toNative(): Any? {
    return when {
        this.isUndefined || this.isNullOrUndefined -> null
        this is V8ValueInteger -> this.value
        this is V8ValueBoolean -> this.value
        this is V8ValueString -> this.value
        this is V8ValueDouble -> this.value
        this is V8ValueLong -> this.value
        this is V8ValueArray -> {
            // Convert JavaScript array to Kotlin List
            val list = mutableListOf<Any?>()
            for (i in 0 until this.length) {
                list.add(this.get<V8Value>(i).toNative())
            }
            list
        }
        this is V8ValueObject -> {
            // Check if it's an Error object - get message and stack
            val hasMessage = this.has("message")
            val hasStack = this.has("stack")
            if (hasMessage || hasStack) {
                // It's likely an Error object, return string representation with message and stack
                val message = if (hasMessage) this.getString("message") else "Unknown error"
                val stack = if (hasStack) this.getString("stack") else ""
                return if (stack.isNotEmpty()) {
                    "$message\n$stack"
                } else {
                    message
                }
            }
            // Convert JavaScript object to Kotlin Map
            val map = mutableMapOf<String, Any?>()
            val propertyNames = this.ownPropertyNames
            for (i in 0 until propertyNames.length) {
                val key = propertyNames.getString(i)
                map[key] = this.get<V8Value>(key).toNative()
            }
            map
        }
        else -> this.toString()
    }
}

/**
 * Helper class for easy conversion between Kotlin and JavaScript values/functions
 * Provides a simple API for creating native bridges and exposing Kotlin functionality to JavaScript
 */
fun V8Runtime.createJSObject(value: Any?): V8Value {
    return when (value) {
        null -> this.createV8ValueUndefined()
        is Boolean -> this.createV8ValueBoolean(value)
        is Int -> this.createV8ValueInteger(value)
        is Long -> this.createV8ValueLong(value)
        is Float -> this.createV8ValueDouble(value.toDouble())
        is Double -> this.createV8ValueDouble(value)
        is String -> this.createV8ValueString(value)
        is V8Value -> value // Already a JS value
        is JavetCallbackContext -> this.createV8ValueFunction(value)
        is List<*> -> createListProxy(value)
        is Map<*, *> -> createMapProxy(value)
        is Function<*> -> createJSFunction(value)
        else -> createProxy(value)
    }
}

private fun V8Runtime.createListProxy(value: List<*>): V8Value {
    val handler = this.createV8ValueObject()
    
    // get trap - access array elements
    handler.bindFunction(JavetCallbackContext(
        "get",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val prop = v8Values[1].toString()
            when (prop) {
                "length" -> this.createV8ValueInteger(value.size)
                else -> {
                    // Try to parse as array index
                    val index = prop.toIntOrNull()
                    if (index != null && index >= 0 && index < value.size) {
                        createJSObject(value[index])
                    } else {
                        this.createV8ValueUndefined()
                    }
                }
            }
        }
    ))
    
    // ownKeys trap - enumerate array indices and length
    handler.bindFunction(JavetCallbackContext(
        "ownKeys",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
            val array = this.createV8ValueArray()
            for (i in value.indices) {
                array.set(i, i.toString())
            }
            array.set(value.size, "length")
            array
        }
    ))
    
    return this.invokeFunction("(function(handler) { return new Proxy([], handler); })".trimIndent(), handler)
}

private fun V8Runtime.createMapProxy(value: Map<*, *>): V8Value {
    val handler = this.createV8ValueObject()
    handler.bindFunction(JavetCallbackContext(
        "ownKeys",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val array = this.createV8ValueArray()
            value.keys.forEachIndexed { index, entry ->
                array.set(index, entry.toString())
            }
            array
        }
    ))
    handler.bindFunction(JavetCallbackContext(
        "get",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val prop = v8Values[1].toString()
            createJSObject(value[prop])
        }
    ))
    return this.invokeFunction("(function(handler) { return new Proxy({}, handler); })".trimIndent(), handler)
}

private fun V8Runtime.createProxy(value: Any): V8Value {
    val handler = this.createV8ValueObject()
    handler.bindFunction(JavetCallbackContext(
        "ownKeys",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val array = this.createV8ValueArray()
            value::class.memberProperties.forEachIndexed { index, entry ->
                array.set(index, entry.name)
            }
            value::class.memberFunctions.forEachIndexed { index, entry ->
                array.set(index, entry.name)
            }
            array
        }
    ))
    handler.bindFunction(JavetCallbackContext(
        "get",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val prop = v8Values[1].toString()
            val property = value::class.memberProperties.find { it.name == prop }
            if (property != null) {
                val propValue = (property as KProperty1<Any, *>).get(value)
                return@NoThisAndResult createJSObject(propValue)
            }
            val method = value::class.memberFunctions.find { it.name == prop }
            if (method != null) {
                return@NoThisAndResult createJSFunction(method)
            }
            this.createV8ValueUndefined()
        }
    ))
    return this.invokeFunction("(function(handler) { return new Proxy({}, handler); })".trimIndent(), handler)
}

@OptIn(ExperimentalReflectionOnLambdas::class)
private fun V8Runtime.createJSFunction(value: Function<*>): V8Value {
    val func = value.reflect()
    if (func == null) {
        return this.createV8ValueUndefined()
    }
    return this.createV8ValueFunction(JavetCallbackContext(
        func.name,
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val args = arrayOfNulls<Any>(func.parameters.size)
            v8Values.forEachIndexed { index, entry ->
                if (index > 0 && index <= func.parameters.size) { // Skip the first argument which is 'this'
                    val param = func.parameters[index - 1]
                    if (param.isOptional && entry.isNullOrUndefined) {
                        args[index - 1] = null
                    } else {
                        args[index - 1] = convertToNativeValue(param.type, entry)
                    }
                }
            }
            val result = func.call(*args)
            return@NoThisAndResult createJSObject(result)
        }
    ))
}

private fun V8Runtime.convertToNativeValue(type: KType, value: V8Value): Any? {
    return when (type.classifier) {
        Boolean::class -> value.asBoolean()
        Int::class -> value.asInt()
        Long::class -> value.asLong()
        Float::class -> value.asDouble().toFloat()
        Double::class -> value.asDouble()
        String::class -> value.toString()
        else -> null // TODO: Handle more complex types
    }
}

/**
 * Represents a JavaScript property with custom getter and optional setter
 * 
 * @property getter Returns the property value (can return any type convertible to V8Value)
 * @property setter Optional setter that receives the new value as String
 */
data class JSProperty(
    val getter: () -> Any?,
    val setter: ((String) -> Unit)? = null
)

/**
 * Creates a JavaScript object with properties, methods, and custom getter/setter properties
 * This combines all functionality and automatically handles property descriptors
 * 
 * Example:
 * ```kotlin
 * val obj = v8Runtime.createJSObject(
 *     properties = mapOf(
 *         "url" to "https://example.com",
 *         "timeout" to 30
 *     ),
 *     dynamicProperties = mapOf(
 *         "httpMethod" to JSProperty(
 *             getter = { request.httpMethod },
 *             setter = { value -> request.httpMethod = value }
 *         )
 *     ),
 *     methods = mapOf(
 *         "setHeader" to IJavetDirectCallable.NoThisAndResult<Exception> { args ->
 *             // implementation
 *             v8Runtime.createV8ValueUndefined()
 *         }
 *     )
 * )
 * ```
 */
fun V8Runtime.createJSObject(
    properties: Map<String, Any?> = emptyMap(),
    dynamicProperties: Map<String, JSProperty> = emptyMap(),
    methods: Map<String, IJavetDirectCallable.NoThisAndResult<Exception>> = emptyMap()
): V8ValueObject {
    val obj = this.createV8ValueObject()
    
    // Set static properties
    properties.forEach { (key, value) ->
        obj.set(key, createJSObject(value))
    }
    
    // Bind methods
    methods.forEach { (name, handler) ->
        obj.bindFunction(JavetCallbackContext(
            name,
            JavetCallbackType.DirectCallNoThisAndResult,
            handler
        ))
    }
    
    // Setup dynamic properties with getters/setters
    if (dynamicProperties.isNotEmpty()) {
        // For each dynamic property, create a native getter/setter callback
        dynamicProperties.forEach { (propName, property) ->
            // Bind getter
            val getterName = "__get_$propName"
            obj.bindFunction(JavetCallbackContext(
                getterName,
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    createJSObject(property.getter())
                }
            ))
            
            // Bind setter if provided
            if (property.setter != null) {
                val setterName = "__set_$propName"
                obj.bindFunction(JavetCallbackContext(
                    setterName,
                    JavetCallbackType.DirectCallNoThisAndNoResult,
                    IJavetDirectCallable.NoThisAndNoResult<Exception> { args ->
                        if (args.isNotEmpty()) {
                            property.setter.invoke(args[0].toString())
                        }
                    }
                ))
            }
        }
        
        // Build JavaScript code to define all properties with Object.defineProperty
        val propertyDefinitions = dynamicProperties.map { (propName, property) ->
            val setterCode = if (property.setter != null) {
                """
                set: function(value) {
                    this.__set_$propName(value);
                },
                """.trimIndent()
            } else {
                ""
            }
            
            """
            Object.defineProperty(target, '$propName', {
                get: function() {
                    return this.__get_$propName();
                },
                $setterCode
                enumerable: true,
                configurable: true
            });
            """.trimIndent()
        }.joinToString("\n")
        
        // Execute the property setup code
        val setupFunc = this.getExecutor("""
            (function(target) {
                $propertyDefinitions
            })
        """.trimIndent()).execute<V8ValueFunction>()
        
        setupFunc.use {
            setupFunc.callVoid(null, obj)
        }
    }
    
    return obj
}
