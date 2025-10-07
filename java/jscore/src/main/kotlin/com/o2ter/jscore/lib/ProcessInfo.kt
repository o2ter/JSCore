//
//  ProcessInfo.kt
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
 * ProcessInfo native bridge
 * Exposes process information to JavaScript via __NATIVE_BRIDGE__.processInfo
 */
class ProcessInfo(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext
) {
    
    fun setupBridge(nativeBridge: V8ValueObject) {
        val processInfoObject = v8Runtime.createV8ValueObject()
        
        try {
            // Get environment variables
            val env = v8Runtime.createV8ValueObject()
            try {
                System.getenv().forEach { (key, value) ->
                    env.set(key, value)
                }
                processInfoObject.set("environment", env)
            } finally {
                env.close()
            }
            
            // Get command-line arguments
            val args = v8Runtime.createV8ValueArray()
            try {
                val jvmArgs = java.lang.management.ManagementFactory.getRuntimeMXBean().inputArguments
                jvmArgs.forEachIndexed { index, arg ->
                    args.set(index, arg)
                }
                processInfoObject.set("arguments", args)
            } finally {
                args.close()
            }
            
            // Process identifier (PID)
            val pid = ProcessHandle.current().pid()
            processInfoObject.set("processIdentifier", pid.toInt())
            
            // Process name
            val processName = java.lang.management.ManagementFactory.getRuntimeMXBean().name
            processInfoObject.set("processName", processName)
            
            // Globally unique string (UUID)
            processInfoObject.set("globallyUniqueString", java.util.UUID.randomUUID().toString())
            
            // Host name
            val hostName = try {
                java.net.InetAddress.getLocalHost().hostName
            } catch (e: Exception) {
                "localhost"
            }
            processInfoObject.set("hostName", hostName)
            
            // OS information
            processInfoObject.set("operatingSystemVersionString", System.getProperty("os.version"))
            
            val osVersion = v8Runtime.createV8ValueObject()
            try {
                val versionParts = System.getProperty("os.version").split(".")
                osVersion.set("majorVersion", versionParts.getOrNull(0)?.toIntOrNull() ?: 0)
                osVersion.set("minorVersion", versionParts.getOrNull(1)?.toIntOrNull() ?: 0)
                osVersion.set("patchVersion", versionParts.getOrNull(2)?.toIntOrNull() ?: 0)
                processInfoObject.set("operatingSystemVersion", osVersion)
            } finally {
                osVersion.close()
            }
            
            // System resources
            val runtime = Runtime.getRuntime()
            processInfoObject.set("physicalMemory", runtime.maxMemory())
            processInfoObject.set("processorCount", runtime.availableProcessors())
            processInfoObject.set("activeProcessorCount", runtime.availableProcessors())
            
            // System uptime
            val uptime = java.lang.management.ManagementFactory.getRuntimeMXBean().uptime / 1000.0
            processInfoObject.set("systemUptime", uptime)
            
            // Platform-specific properties
            processInfoObject.set("deviceSpec", platformContext.deviceInfo.spec)
            processInfoObject.set("isRealDevice", platformContext.deviceInfo.isRealDevice)
            processInfoObject.set("isLowPowerModeEnabled", false) // JVM doesn't have this concept
            processInfoObject.set("isMacCatalystApp", false) // Not applicable
            processInfoObject.set("isiOSAppOnMac", false) // Not applicable
            processInfoObject.set("thermalState", 0) // Not applicable for JVM
            
            // Register with __NATIVE_BRIDGE__
            nativeBridge.set("processInfo", processInfoObject)
            
        } finally {
            processInfoObject.close()
        }
    }
}
