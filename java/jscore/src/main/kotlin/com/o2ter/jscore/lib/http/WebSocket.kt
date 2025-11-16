//
//  WebSocket.kt
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
import com.caoccao.javet.values.primitive.V8ValueString
import com.caoccao.javet.values.reference.V8ValueArray
import com.caoccao.javet.values.reference.V8ValueFunction
import com.caoccao.javet.values.reference.V8ValueObject
import com.caoccao.javet.values.reference.V8ValueTypedArray
import com.caoccao.javet.values.reference.IV8ValueArray
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.PlatformContext
import java.net.URI
import java.nio.ByteBuffer
import java.util.Collections
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString

/**
 * Native WebSocket implementation bridged to JavaScript
 * 
 * Exposes WebSocket capabilities to JavaScript via __NATIVE_BRIDGE__.WebSocket
 */
class JSWebSocket(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext,
    private val engine: JavaScriptEngine
) {
    private val sockets = ConcurrentHashMap<String, WebSocketConnection>()
    
    // Track active WebSocket connections by socket ID
    private val activeWebSockets = Collections.synchronizedSet(mutableSetOf<String>())
    
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()
    
    /**
     * Check if there are active WebSocket connections
     */
    val hasActiveWebSockets: Boolean
        get() = activeWebSockets.isNotEmpty()
    
    /**
     * Get the count of active WebSocket connections
     */
    val activeWebSocketCount: Int
        get() = activeWebSockets.size
    
    /**
     * Register a WebSocket connection for lifecycle tracking
     */
    internal fun registerWebSocket(socketId: String) {
        activeWebSockets.add(socketId)
    }
    
    /**
     * Unregister a WebSocket connection after closure
     */
    internal fun unregisterWebSocket(socketId: String) {
        activeWebSockets.remove(socketId)
    }
    
    fun createWebSocket(
        url: String,
        protocols: V8ValueArray?,
        onOpen: V8ValueFunction,
        onMessage: V8ValueFunction,
        onError: V8ValueFunction,
        onClose: V8ValueFunction
    ): String {
        try {
            // Parse protocols
            val protocolList = mutableListOf<String>()
            protocols?.use { arr ->
                for (i in 0 until arr.length) {
                    arr.get<V8Value>(i).use { protocol ->
                        protocolList.add(protocol.toString())
                    }
                }
            }
            
            // Generate unique socket ID
            val socketId = UUID.randomUUID().toString()
            
            // Build request
            val requestBuilder = Request.Builder().url(url)
            if (protocolList.isNotEmpty()) {
                requestBuilder.header("Sec-WebSocket-Protocol", protocolList.joinToString(", "))
            }
            
            // Create WebSocket connection
            val connection = WebSocketConnection(
                socketId = socketId,
                onOpen = onOpen,
                onMessage = onMessage,
                onError = onError,
                onClose = onClose,
                engine = engine,
                v8Runtime = v8Runtime,
                manager = this
            )
            
            val webSocket = client.newWebSocket(requestBuilder.build(), connection)
            connection.webSocket = webSocket
            
            sockets[socketId] = connection
            registerWebSocket(socketId)
            
            return socketId
        } catch (e: Exception) {
            // Call error callback
            engine.executeOnJSThreadAsync {
                if (!onError.isClosed) {
                    v8Runtime.createV8ValueString("Invalid WebSocket URL: $url").use { errorMsg ->
                        onError.callVoid(null, errorMsg as V8Value)
                    }
                }
            }
            return ""
        }
    }
    
    fun send(socketId: String, data: V8Value): Boolean {
        val connection = sockets[socketId] ?: return false
        return connection.send(data)
    }
    
    fun close(socketId: String, code: Int, reason: String): Boolean {
        val connection = sockets[socketId] ?: return false
        connection.close(code, reason)
        
        // Clean up after delay
        Thread {
            Thread.sleep(1000)
            cleanupSocket(socketId)
        }.start()
        
        return true
    }
    
    fun getReadyState(socketId: String): Int {
        return sockets[socketId]?.readyState ?: 3 // CLOSED
    }
    
    fun getBufferedAmount(socketId: String): Int {
        return sockets[socketId]?.bufferedAmount ?: 0
    }
    
    internal fun cleanupSocket(socketId: String) {
        sockets.remove(socketId)
        unregisterWebSocket(socketId)
    }
}

private class WebSocketConnection(
    val socketId: String,
    val onOpen: V8ValueFunction,
    val onMessage: V8ValueFunction,
    val onError: V8ValueFunction,
    val onClose: V8ValueFunction,
    val engine: JavaScriptEngine,
    val v8Runtime: V8Runtime,
    val manager: JSWebSocket
) : WebSocketListener() {
    
    var webSocket: WebSocket? = null
    @Volatile var readyState: Int = 0 // 0=CONNECTING, 1=OPEN, 2=CLOSING, 3=CLOSED
    @Volatile var bufferedAmount: Int = 0
    
    override fun onOpen(webSocket: WebSocket, response: Response) {
        readyState = 1 // OPEN
        
        engine.executeOnJSThreadAsync {
            if (!onOpen.isClosed) {
                onOpen.callVoid(null, *emptyArray<V8Value>())
            }
        }
    }
    
    override fun onMessage(webSocket: WebSocket, text: String) {
        engine.executeOnJSThreadAsync {
            if (!onMessage.isClosed) {
                v8Runtime.createV8ValueObject().use { event ->
                    v8Runtime.createV8ValueString(text).use { data ->
                        event.set("data", data)
                    }
                    v8Runtime.createV8ValueString("message").use { type ->
                        event.set("type", type)
                    }
                    onMessage.callVoid(null, event)
                }
            }
        }
    }
    
    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
        engine.executeOnJSThreadAsync {
            if (!onMessage.isClosed) {
                v8Runtime.createV8ValueObject().use { event ->
                    val byteArray = bytes.toByteArray()
                    v8Runtime.createV8ValueTypedArray(
                        com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                        byteArray.size
                    ).use { typedArray ->
                        val buffer = typedArray.toBytes()
                        byteArray.copyInto(buffer)
                        event.set("data", typedArray)
                    }
                    v8Runtime.createV8ValueString("message").use { type ->
                        event.set("type", type)
                    }
                    onMessage.callVoid(null, event)
                }
            }
        }
    }
    
    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
        readyState = 2 // CLOSING
    }
    
    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        readyState = 3 // CLOSED
        
        engine.executeOnJSThreadAsync {
            if (!onClose.isClosed) {
                v8Runtime.createV8ValueObject().use { closeEvent ->
                    v8Runtime.createV8ValueInteger(code).use { codeVal ->
                        closeEvent.set("code", codeVal)
                    }
                    v8Runtime.createV8ValueString(reason).use { reasonVal ->
                        closeEvent.set("reason", reasonVal)
                    }
                    v8Runtime.createV8ValueBoolean(true).use { wasClean ->
                        closeEvent.set("wasClean", wasClean)
                    }
                    onClose.callVoid(null, closeEvent)
                }
            }
        }
        
        // Clean up tracking - safe to do immediately as we're already on background thread
        cleanupSocket()
    }
    
    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        readyState = 3 // CLOSED
        
        engine.executeOnJSThreadAsync {
            if (!onError.isClosed) {
                v8Runtime.createV8ValueString(t.message ?: "WebSocket error").use { errorMsg ->
                    onError.callVoid(null, errorMsg)
                }
            }
            
            if (!onClose.isClosed) {
                v8Runtime.createV8ValueObject().use { closeEvent ->
                    v8Runtime.createV8ValueInteger(1006).use { code ->
                        closeEvent.set("code", code)
                    }
                    v8Runtime.createV8ValueString(t.message ?: "").use { reason ->
                        closeEvent.set("reason", reason)
                    }
                    v8Runtime.createV8ValueBoolean(false).use { wasClean ->
                        closeEvent.set("wasClean", wasClean)
                    }
                    onClose.callVoid(null, closeEvent)
                }
            }
        }
        
        // Clean up tracking - safe to do immediately as we're already on background thread
        cleanupSocket()
    }
    
    fun send(data: V8Value): Boolean {
        if (readyState != 1) return false
        
        val ws = webSocket ?: return false
        
        return when {
            data is V8ValueString -> {
                ws.send(data.value)
                true
            }
            data is V8ValueTypedArray -> {
                val bytes = data.toBytes()
                ws.send(ByteString.of(*bytes))
                true
            }
            else -> false
        }
    }
    
    fun close(code: Int, reason: String) {
        if (readyState == 3) return
        readyState = 2 // CLOSING
        
        webSocket?.close(code, reason)
        readyState = 3 // CLOSED
        
        engine.executeOnJSThreadAsync {
            if (!onClose.isClosed) {
                v8Runtime.createV8ValueObject().use { closeEvent ->
                    v8Runtime.createV8ValueInteger(code).use { codeVal ->
                        closeEvent.set("code", codeVal)
                    }
                    v8Runtime.createV8ValueString(reason).use { reasonVal ->
                        closeEvent.set("reason", reasonVal)
                    }
                    v8Runtime.createV8ValueBoolean(true).use { wasClean ->
                        closeEvent.set("wasClean", wasClean)
                    }
                    onClose.callVoid(null, closeEvent)
                }
            }
        }
    }
    
    private fun cleanupSocket() {
        manager.cleanupSocket(socketId)
    }
}

/**
 * Setup WebSocket bridge in the native bridge object
 * @param nativeBridge The native bridge object to register WebSocket APIs
 * @param jsWebSocket The JSWebSocket instance to use
 */
fun setupWebSocketBridge(nativeBridge: V8ValueObject, jsWebSocket: JSWebSocket, v8Runtime: V8Runtime) {
    val webSocketBridge = v8Runtime.createV8ValueObject()
    try {
        webSocketBridge.bindFunction(JavetCallbackContext("createWebSocket",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                if (v8Values.size < 6) {
                    throw RuntimeException("createWebSocket() requires 6 arguments")
                }
                val url = v8Values[0].toString()
                val protocols = v8Values[1] as? V8ValueArray
                val onOpen = v8Values[2] as V8ValueFunction
                val onMessage = v8Values[3] as V8ValueFunction
                val onError = v8Values[4] as V8ValueFunction
                val onClose = v8Values[5] as V8ValueFunction
                
                onOpen.setWeak()
                onMessage.setWeak()
                onError.setWeak()
                onClose.setWeak()
                
                val socketId = jsWebSocket.createWebSocket(url, protocols, onOpen, onMessage, onError, onClose)
                v8Runtime.createV8ValueString(socketId)
            }))
        
        webSocketBridge.bindFunction(JavetCallbackContext("send",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                if (v8Values.size < 2) {
                    throw RuntimeException("send() requires 2 arguments")
                }
                val socketId = v8Values[0].toString()
                val data = v8Values[1]
                jsWebSocket.send(socketId, data)
                v8Runtime.createV8ValueBoolean(true)
            }))
        
        webSocketBridge.bindFunction(JavetCallbackContext("close",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                if (v8Values.isEmpty()) {
                    throw RuntimeException("close() requires at least 1 argument")
                }
                val socketId = v8Values[0].toString()
                val code = if (v8Values.size > 1) v8Values[1].asInt() else 1000
                val reason = if (v8Values.size > 2) v8Values[2].toString() else ""
                val success = jsWebSocket.close(socketId, code, reason)
                v8Runtime.createV8ValueBoolean(success)
            }))
        
        webSocketBridge.bindFunction(JavetCallbackContext("getReadyState",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                if (v8Values.isEmpty()) {
                    throw RuntimeException("getReadyState() requires 1 argument")
                }
                val socketId = v8Values[0].toString()
                val state = jsWebSocket.getReadyState(socketId)
                v8Runtime.createV8ValueInteger(state)
            }))
        
        webSocketBridge.bindFunction(JavetCallbackContext("getBufferedAmount",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                if (v8Values.isEmpty()) {
                    throw RuntimeException("getBufferedAmount() requires 1 argument")
                }
                val socketId = v8Values[0].toString()
                val amount = jsWebSocket.getBufferedAmount(socketId)
                v8Runtime.createV8ValueInteger(amount)
            }))
        
        nativeBridge.set("WebSocket", webSocketBridge)
    } finally {
        webSocketBridge.close()
    }
}
