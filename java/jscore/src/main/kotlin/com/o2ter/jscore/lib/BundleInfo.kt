//
//  BundleInfo.kt
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
import com.caoccao.javet.values.reference.V8ValueObject
import com.o2ter.jscore.PlatformContext

/**
 * Native bridge for bundle/application information
 * Exposes app metadata to JavaScript
 */
class BundleInfo(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext
) {
    
    /**
     * Sets up the bundle info bridge on the native bridge object
     */
    fun setupBridge(nativeBridge: V8ValueObject) {
        // Create bundleInfo namespace
        v8Runtime.createV8ValueObject().use { bundleInfoBridge ->
            
            // Set bundle info properties as V8 properties
            bundleInfoBridge.set("appVersion", platformContext.bundleInfo.appVersion)
            bundleInfoBridge.set("buildVersion", platformContext.bundleInfo.buildVersion)
            bundleInfoBridge.set("bundleIdentifier", platformContext.bundleInfo.bundleIdentifier)
            
            // Set the bundleInfo namespace on native bridge
            nativeBridge.set("bundleInfo", bundleInfoBridge)
        }
    }
}