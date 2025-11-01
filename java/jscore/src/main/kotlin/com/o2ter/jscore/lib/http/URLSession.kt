//
//  URLSession.kt
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

package com.o2ter.jscore.lib.http

import com.caoccao.javet.interop.V8Runtime
import com.caoccao.javet.interop.callback.IJavetDirectCallable
import com.caoccao.javet.interop.callback.JavetCallbackContext
import com.caoccao.javet.interop.callback.JavetCallbackType
import com.caoccao.javet.values.V8Value
import com.caoccao.javet.values.reference.V8ValueFunction
import com.caoccao.javet.values.reference.V8ValueObject
import com.caoccao.javet.values.reference.V8ValuePromise
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.invokeFunction
import com.o2ter.jscore.PlatformContext
import com.o2ter.jscore.createJSObject
import com.o2ter.jscore.JSProperty
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Native HTTP session implementation bridged to JavaScript
 * 
 * Exposes HTTP networking capabilities to JavaScript via __NATIVE_BRIDGE__.URLSession
 */
class URLSession(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext,
    private val engine: JavaScriptEngine
) {
    private var nextRequestId = 0
    
    // Store progress handler functions by request ID (prevents GC and avoids global pollution)
    private val progressHandlers = mutableMapOf<String, V8ValueFunction>()
    
    companion object {
        fun register(engine: JavaScriptEngine, v8Runtime: V8Runtime, platformContext: PlatformContext, nativeBridge: V8ValueObject) {
            val session = URLSession(v8Runtime, platformContext, engine)
            
        // Create URLSession bridge object with methods using helper
        val urlSessionBridge = v8Runtime.createJSObject(
            methods = mapOf(
                "shared" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    // Return self reference
                    nativeBridge.get("URLSession")
                },
                "httpRequestWithRequest" to IJavetDirectCallable.NoThisAndResult<Exception> { args ->
                    session.httpRequestWithRequest(args)
                }
            )
        )
        
        try {
            nativeBridge.set("URLSession", urlSessionBridge)
        } finally {
            urlSessionBridge.close() // Close to release callback contexts
        }
        }
    }
    
    private fun httpRequestWithRequest(v8Values: Array<out com.caoccao.javet.values.V8Value>): V8ValuePromise {
        if (v8Values.isEmpty()) {
            throw IllegalArgumentException("httpRequestWithRequest requires at least 1 argument")
        }
        
        val requestConfig = v8Values[0] as? V8ValueObject
            ?: throw IllegalArgumentException("First argument must be a request config object")
        
        // Extract request properties from plain JavaScript object
        val url = requestConfig.getString("url")
        val httpMethod = requestConfig.getString("httpMethod") ?: "GET"
        val timeoutInterval = requestConfig.getDouble("timeoutInterval")
        
        // Extract headers
        val headersObj = requestConfig.get("headers") as? V8ValueObject
        val headers = mutableMapOf<String, String>()
        if (headersObj != null) {
            try {
                val headerKeys = headersObj.ownKeys
                for (key in headerKeys) {
                    val value = headersObj.getString(key)
                    if (value != null) {
                        headers[key] = value
                    }
                }
            } finally {
                headersObj.close()
            }
        }
        
        // Extract http body (may be string or typed array)
        val httpBodyValue = requestConfig.get("httpBody")
        val httpBody: Any? = when {
            httpBodyValue == null || httpBodyValue.isNullOrUndefined -> null
            httpBodyValue.isString -> httpBodyValue.toString()
            httpBodyValue is V8ValueTypedArray -> {
                try {
                    httpBodyValue.toBytes()
                } finally {
                    httpBodyValue.close()
                }
            }
            else -> {
                httpBodyValue.close()
                null
            }
        }
        
        // Generate unique request ID for progress handler tracking
        val requestId = "req_${nextRequestId++}"
        
        // Get optional body stream and progress handler
        val hasProgressHandler = v8Values.size > 2 && v8Values[2] is V8ValueFunction
        
        // Store progress handler with weak reference (lifecycle managed by V8 GC)
        // This prevents auto-close when callback returns
        if (hasProgressHandler) {
            val handler = v8Values[2] as V8ValueFunction
            handler.setWeak()  // Lifecycle managed by V8 GC, not try-with-resource
            progressHandlers[requestId] = handler
        }
        
        // Create promise
        val resolver = v8Runtime.createV8ValuePromise()
        
        // Register this request for lifecycle tracking
        engine.registerHttpRequest(requestId)
        
        // Execute request in a background thread
        val httpThread = Thread {
            try {
                // Execute the request and get response headers immediately
                val urlObj = URL(url)
                val connection = urlObj.openConnection() as HttpURLConnection
                
                try {
                    // Configure request
                    connection.requestMethod = httpMethod
                    connection.connectTimeout = (timeoutInterval * 1000).toInt()
                    connection.readTimeout = (timeoutInterval * 1000).toInt()
                    connection.instanceFollowRedirects = true
                    
                    // Set doOutput for POST/PUT/PATCH methods before setting headers
                    if (httpMethod in listOf("POST", "PUT", "PATCH")) {
                        connection.doOutput = true
                    }
                    
                    // Set headers
                    headers.forEach { (key, value) ->
                        connection.setRequestProperty(key, value)
                    }
                    
                    // Handle request body
                    if (httpBody != null) {
                        val outputStream = connection.outputStream
                        
                        when (httpBody) {
                            is String -> {
                                outputStream.write(httpBody.toByteArray(Charsets.UTF_8))
                            }
                            is ByteArray -> {
                                outputStream.write(httpBody)
                            }
                        }
                        
                        outputStream.close()
                    }
                    
                    // Get response headers and status
                    val responseCode = connection.responseCode
                    
                    val inputStream: InputStream = try {
                        connection.inputStream
                    } catch (e: Exception) {
                        // For HTTP error status codes (4xx, 5xx), use error stream
                        // This is normal behavior for fetch() - HTTP errors should return Response objects, not throw
                        connection.errorStream ?: run {
                            // Create empty input stream for HTTP errors without error stream
                            java.io.ByteArrayInputStream(ByteArray(0))
                        }
                    }
                    
                    // Read response headers
                    val headers = connection.headerFields
                        .filterKeys { it != null }
                        .mapKeys { it.key.lowercase() }
                        .mapValues { it.value.joinToString(", ") }
                    
                    // Create response object
                    val response = URLResponse(
                        url = connection.url.toString(),
                        statusCode = responseCode,
                        allHeaderFields = headers
                    )
                    
                    // Resolve promise immediately with response metadata (standard web behavior)
                    engine.executeOnJSThreadAsync {
                        val responseBridge = createResponseBridge(response)
                        resolver.resolve(responseBridge)
                        responseBridge.close()
                    }
                    
                    // Stream response body if progress handler is provided
                    if (hasProgressHandler) {
                        try {
                            val buffer = ByteArray(8192)
                            var bytesRead: Int
                            
                            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                                if (bytesRead > 0) {
                                    // Create a copy of the chunk to send to JS
                                    val chunk = buffer.copyOf(bytesRead)
                                    
                                    // Call progress handler on JS thread with chunk
                                    engine.executeOnJSThreadAsync {
                                        val handler = progressHandlers[requestId]
                                        if (handler != null && !handler.isClosed) {
                                            // Create typed array for the chunk
                                            val typedArray = v8Runtime.createV8ValueTypedArray(
                                                com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                                                chunk.size
                                            )
                                            typedArray.use {
                                                typedArray.fromBytes(chunk)
                                                val nullValue = v8Runtime.createV8ValueNull()
                                                nullValue.use {
                                                    // Call handler
                                                    handler.callVoid(null, typedArray, nullValue)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Signal completion with empty chunk
                            engine.executeOnJSThreadAsync {
                                val handler = progressHandlers[requestId]
                                if (handler != null && !handler.isClosed) {
                                    val emptyArray = v8Runtime.createV8ValueTypedArray(
                                        com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                                        0
                                    )
                                    emptyArray.use {
                                        val nullValue = v8Runtime.createV8ValueNull()
                                        nullValue.use {
                                            // Signal completion
                                            handler.callVoid(null, emptyArray, nullValue)
                                        }
                                    }
                                }
                                
                                // Clean up: remove handler from map (weak ref, V8 GC handles close)
                                progressHandlers.remove(requestId)
                                
                                // Unregister HTTP request AFTER all callbacks complete
                                engine.unregisterHttpRequest(requestId)
                            }
                        } catch (e: Exception) {
                            // Call progress handler with error on JS thread
                            engine.executeOnJSThreadAsync {
                                val handler = progressHandlers[requestId]
                                if (handler != null && !handler.isClosed) {
                                    val emptyArray = v8Runtime.createV8ValueTypedArray(
                                        com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                                        0
                                    )
                                    emptyArray.use {
                                        val errorValue = v8Runtime.getExecutor("new Error('${e.message?.replace("'", "\\'") ?: "Stream read error"}')").execute<V8Value>()
                                        errorValue.use {
                                            // Call handler with error
                                            handler.callVoid(null, emptyArray, errorValue)
                                        }
                                    }
                                }
                                
                                // Clean up: remove handler from map (weak ref, V8 GC handles close)
                                progressHandlers.remove(requestId)
                                
                                // Unregister HTTP request after stream error
                                engine.unregisterHttpRequest(requestId)
                            }
                        }
                    }
                    
                    // Close the stream
                    inputStream.close()
                    
                } finally {
                    connection.disconnect()
                }
            } catch (e: Exception) {
                engine.executeOnJSThreadAsync {
                    val errorMsg = v8Runtime.createV8ValueString(e.message ?: "Unknown error")
                    resolver.reject(errorMsg)
                    errorMsg.close()
                    
                    // Unregister HTTP request after error handling
                    engine.unregisterHttpRequest(requestId)
                }
            }
            
            // If no progress handler, unregister here (promise already resolved)
            if (!hasProgressHandler) {
                engine.unregisterHttpRequest(requestId)
            }
        }
        httpThread.start()
        
        return resolver.promise
    }
    
    private fun createResponseBridge(response: URLResponse): V8ValueObject {
        return v8Runtime.createJSObject(
            properties = mapOf(
                "url" to response.url,
                "statusCode" to response.statusCode,
                "allHeaderFields" to response.allHeaderFields
            ),
            methods = mapOf(
                "valueForHTTPHeaderField" to IJavetDirectCallable.NoThisAndResult<Exception> { args ->
                    if (args.isNotEmpty()) {
                        val field = args[0].toString()
                        val value = response.valueForHTTPHeaderField(field)
                        if (value != null) {
                            v8Runtime.createV8ValueString(value)
                        } else {
                            v8Runtime.createV8ValueNull()
                        }
                    } else {
                        v8Runtime.createV8ValueNull()
                    }
                }
            )
        )
    }
}
