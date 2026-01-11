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
                this.get<V8Value>(i).use { element ->
                    list.add(element.toNative())
                }
            }
            list
        }
        this is V8ValueFunction -> {
            // Convert JavaScript function to Kotlin lambda
            // Return a callback that can be invoked from Kotlin
            val jsFunction = this
            // Set weak reference - V8 GC will handle lifecycle automatically
            jsFunction.setWeak()
            return { args: List<Any?> ->
                val v8Runtime = jsFunction.v8Runtime
                if (v8Runtime != null && !jsFunction.isClosed) {
                    val v8Args = args.map { arg -> v8Runtime.createJSObject(arg) }.toTypedArray()
                    try {
                        val result = jsFunction.call<V8Value>(null, *v8Args)
                        result.use { it.toNative() }
                    } finally {
                        v8Args.forEach { it.close() }
                    }
                } else {
                    null
                }
            }
        }
        this is V8ValueObject -> {
            // Convert JavaScript object to Kotlin Map
            val map = mutableMapOf<String, Any?>()
            this.ownPropertyNames.use { propertyNames ->
                for (i in 0 until propertyNames.length) {
                    val key = propertyNames.getString(i)
                    this.get<V8Value>(key).use { value ->
                        if (value is V8ValueFunction) {
                            // Convert function to lambda
                            val jsFunction = value
                            // Set weak reference - V8 GC will handle lifecycle automatically
                            jsFunction.setWeak()
                            val self = this
                            self.setWeak()
                            map[key] = { args: List<Any?> ->
                                val v8Runtime = jsFunction.v8Runtime
                                if (v8Runtime != null && !self.isClosed && !jsFunction.isClosed) {
                                    val v8Args = args.map { arg -> v8Runtime.createJSObject(arg) }.toTypedArray()
                                    try {
                                        val result = jsFunction.call<V8Value>(self, *v8Args)
                                        result.use { it.toNative() }
                                    } finally {
                                        v8Args.forEach { it.close() }
                                    }
                                } else {
                                    null
                                }
                            }
                        } else {
                            map[key] = value.toNative()
                        }
                    }
                }
            }
            map
        }
        else -> this.toString()
    }
}

/**
 * Convert a V8ValueObject to a Map<String, String> by extracting all own properties.
 * This is useful for extracting headers, configuration objects, etc. from JavaScript.
 * 
 * @return Map of string keys to string values, or empty map if extraction fails
 */
fun V8ValueObject.toStringMap(): Map<String, String> {
    val result = mutableMapOf<String, String>()
    try {
        // Don't use .use {} on 'this' - caller owns the lifecycle
        val propertyNames = this.getOwnPropertyNames()
        propertyNames.use { names ->
            for (i in 0 until names.length) {
                val key = names.getString(i)
                val value = this.getString(key)
                if (key != null && value != null) {
                    result[key] = value
                }
            }
        }
    } catch (e: Exception) {
        // Return empty map on any error
    }
    return result
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
        is List<*> -> createJSArray(value)
        is Map<*, *> -> createJSObjectFromMap(value)
        is Function<*> -> createJSFunction(value)
        else -> createProxy(value)
    }
}

/**
 * Convert a Kotlin List to a JavaScript array
 * Creates a real V8ValueArray with proper array prototype, supporting all array methods
 */
private fun V8Runtime.createJSArray(value: List<*>): V8Value {
    val array = this.createV8ValueArray()
    value.forEachIndexed { index, element ->
        createJSObject(element).use { jsElement ->
            array.set(index, jsElement)
        }
    }
    return array
}

/**
 * Convert a Kotlin Map to a JavaScript object
 * Creates a real V8ValueObject with enumerable properties
 */
private fun V8Runtime.createJSObjectFromMap(value: Map<*, *>): V8Value {
    val obj = this.createV8ValueObject()
    value.forEach { (key, mapValue) ->
        createJSObject(mapValue).use { jsValue ->
            obj.set(key.toString(), jsValue)
        }
    }
    return obj
}

private fun V8Runtime.createProxy(value: Any): V8Value {
    val handler = this.createV8ValueObject()
    
    // ownKeys trap - returns all property and method names
    handler.bindFunction(JavetCallbackContext(
        "ownKeys",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val array = this.createV8ValueArray()
            var index = 0
            value::class.memberProperties.forEach { property ->
                array.set(index++, property.name)
            }
            value::class.memberFunctions.forEach { function ->
                array.set(index++, function.name)
            }
            return@NoThisAndResult array
        }
    ))
    
    // has trap - checks if property/method exists (for 'in' operator)
    handler.bindFunction(JavetCallbackContext(
        "has",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val prop = v8Values[1].toString()
            
            // Check if property or method exists
            val hasProperty = value::class.memberProperties.any { it.name == prop }
            val hasMethod = value::class.memberFunctions.any { it.name == prop }
            
            return@NoThisAndResult this.createV8ValueBoolean(hasProperty || hasMethod)
        }
    ))
    
    // getOwnPropertyDescriptor trap - returns property descriptor for enumeration
    handler.bindFunction(JavetCallbackContext(
        "getOwnPropertyDescriptor",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val prop = v8Values[1].toString()
            
            // Check if property or method exists
            val property = value::class.memberProperties.find { it.name == prop }
            val hasMethod = value::class.memberFunctions.any { it.name == prop }
            
            return@NoThisAndResult if (property != null || hasMethod) {
                // Return descriptor that makes the property enumerable and configurable
                // Properties are writable if they're mutable (var), methods are not writable
                this.createV8ValueObject().apply {
                    set("enumerable", true)
                    set("configurable", true)
                    set("writable", property != null && property is kotlin.reflect.KMutableProperty1)
                }
            } else {
                this.createV8ValueUndefined()
            }
        }
    ))
    
    // get trap - retrieves property values or method functions
    handler.bindFunction(JavetCallbackContext(
        "get",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val prop = v8Values[1].toString()
            
            // Try to find property first
            val property = value::class.memberProperties.find { it.name == prop }
            return@NoThisAndResult if (property != null) {
                val propValue = (property as KProperty1<Any, *>).get(value)
                // Ensure we always return a V8Value, never null
                createJSObject(propValue)
            } else {
                // Try to find member function
                val method = value::class.memberFunctions.find { it.name == prop }
                if (method != null) {
                    // Create a callback that binds the method to the object instance
                    this.createV8ValueFunction(JavetCallbackContext(
                        method.name,
                        JavetCallbackType.DirectCallNoThisAndResult,
                        IJavetDirectCallable.NoThisAndResult<Exception> { args ->
                            try {
                                // Handle null args array (when JavaScript calls function with no arguments)
                                val safeArgs = args ?: emptyArray()
                                
                                // Convert V8 arguments to native types using toNative()
                                val nativeArgs = safeArgs.map { arg -> arg.toNative() }
                                
                                // Use call() - first argument is the receiver (instance), followed by method arguments
                                val allArgs = arrayOf(value, *nativeArgs.toTypedArray())
                                val result = method.call(*allArgs)
                                // Ensure we always return a V8Value, never null
                                return@NoThisAndResult createJSObject(result)
                            } catch (e: Exception) {
                                // Return error message on failure
                                return@NoThisAndResult this.createV8ValueString("Error calling ${method.name}: ${e::class.simpleName}: ${e.message ?: "no message"}")
                            }
                        }
                    ))
                } else {
                    this.createV8ValueUndefined()
                }
            }
        }
    ))
    
    // set trap - allows setting mutable property values
    handler.bindFunction(JavetCallbackContext(
        "set",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val prop = v8Values[1].toString()
            val newValue = v8Values[2]
            
            // Try to find mutable property
            val property = value::class.memberProperties.find { it.name == prop }
            return@NoThisAndResult if (property is kotlin.reflect.KMutableProperty1) {
                try {
                    // Convert JavaScript value to native type
                    val nativeValue = newValue.toNative()
                    
                    // Set the property value
                    @Suppress("UNCHECKED_CAST")
                    (property as kotlin.reflect.KMutableProperty1<Any, Any?>).set(value, nativeValue)
                    
                    this.createV8ValueBoolean(true)
                } catch (e: Exception) {
                    // Setting failed - return false
                    this.createV8ValueBoolean(false)
                }
            } else {
                // Property not found or not mutable - return false
                this.createV8ValueBoolean(false)
            }
        }
    ))
    
    // deleteProperty trap - prevents deletion of Kotlin object properties
    handler.bindFunction(JavetCallbackContext(
        "deleteProperty",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            // Kotlin object properties cannot be deleted
            // Return false to indicate deletion is not allowed
            return@NoThisAndResult this.createV8ValueBoolean(false)
        }
    ))
    return try {
        this.invokeFunction("(function(handler) { return new Proxy({}, handler); })".trimIndent(), handler)
    } finally {
        handler.close()
    }
}

@OptIn(ExperimentalReflectionOnLambdas::class)
private fun V8Runtime.createJSFunction(value: Function<*>): V8Value {
    // Try reflection first for named functions
    val func = value.reflect()
    
    // Handle different Function arities
    return this.createV8ValueFunction(JavetCallbackContext(
        func?.name ?: "lambda",
        JavetCallbackType.DirectCallNoThisAndResult,
        IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val result = when (value) {
                is Function0<*> -> value.invoke()
                is Function1<*, *> -> {
                    val arg0 = if (v8Values.isNotEmpty()) convertToAny(v8Values[0]) else null
                    @Suppress("UNCHECKED_CAST")
                    (value as Function1<Any?, *>).invoke(arg0)
                }
                is Function2<*, *, *> -> {
                    val arg0 = if (v8Values.size > 0) convertToAny(v8Values[0]) else null
                    val arg1 = if (v8Values.size > 1) convertToAny(v8Values[1]) else null
                    @Suppress("UNCHECKED_CAST")
                    (value as Function2<Any?, Any?, *>).invoke(arg0, arg1)
                }
                is Function3<*, *, *, *> -> {
                    val arg0 = if (v8Values.size > 0) convertToAny(v8Values[0]) else null
                    val arg1 = if (v8Values.size > 1) convertToAny(v8Values[1]) else null
                    val arg2 = if (v8Values.size > 2) convertToAny(v8Values[2]) else null
                    @Suppress("UNCHECKED_CAST")
                    (value as Function3<Any?, Any?, Any?, *>).invoke(arg0, arg1, arg2)
                }
                else -> {
                    // Fall back to reflection if available
                    if (func != null) {
                        val args = arrayOfNulls<Any>(func.parameters.size)
                        v8Values.forEachIndexed { index, entry ->
                            if (index < func.parameters.size) {
                                val param = func.parameters[index]
                                if (param.isOptional && entry.isNullOrUndefined) {
                                    args[index] = null
                                } else {
                                    args[index] = convertToNativeValue(param.type, entry)
                                }
                            }
                        }
                        func.call(*args)
                    } else {
                        null
                    }
                }
            }
            return@NoThisAndResult createJSObject(result)
        }
    ))
}

private fun V8Runtime.convertToAny(value: V8Value): Any? {
    return when {
        value.isNullOrUndefined -> null
        value is V8ValueBoolean -> value.asBoolean()
        value is V8ValueInteger -> value.asInt()
        value is V8ValueLong -> value.asLong()
        value is V8ValueDouble -> value.asDouble()
        value is V8ValueString -> value.toString()
        else -> value.toNative()
    }
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
        val jsValue = createJSObject(value)
        try {
            obj.set(key, jsValue)
        } finally {
            // Close primitive values, but keep references for non-primitives
            if (jsValue !is V8ValueObject && jsValue !is com.caoccao.javet.values.reference.V8ValueArray) {
                jsValue.close()
            }
        }
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
                    return@NoThisAndResult createJSObject(property.getter())
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
