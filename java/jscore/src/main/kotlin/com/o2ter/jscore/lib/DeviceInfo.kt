//
//  DeviceInfo.kt
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
import com.caoccao.javet.values.reference.V8ValueObject
import com.o2ter.jscore.PlatformContext

/**
 * Native bridge for device information APIs
 * Exposes device identification capabilities to JavaScript
 */
class DeviceInfo(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext
) {
    
    /**
     * Sets up the device info bridge on the native bridge object
     */
    fun setupBridge(nativeBridge: V8ValueObject) {
        // Create deviceInfo namespace
        v8Runtime.createV8ValueObject().use { deviceInfoBridge ->
            
            // identifierForVendor() -> String
            deviceInfoBridge.bindFunction(JavetCallbackContext(
                "identifierForVendor",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    return@NoThisAndResult v8Runtime.createV8ValueString(platformContext.deviceInfo.getIdentifierForVendor())
                }
            ))
            
            // Set the deviceInfo namespace on native bridge
            nativeBridge.set("deviceInfo", deviceInfoBridge)
        }
    }
}