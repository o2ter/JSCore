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
import com.caoccao.javet.values.reference.V8ValueObject
import com.o2ter.jscore.PlatformContext
import com.o2ter.jscore.createJSObject

/**
 * ProcessInfo native bridge
 * Exposes process information to JavaScript via __NATIVE_BRIDGE__.processInfo
 */
class ProcessInfo(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext
) {
    
    fun setupBridge(nativeBridge: V8ValueObject) {
        // Get environment variables
        val env = v8Runtime.createV8ValueObject()
        try {
            System.getenv().forEach { (key, value) ->
                env.set(key, value)
            }
        } catch (e: Exception) {
            env.close()
            throw e
        }
        
        // Get command-line arguments
        val args = v8Runtime.createV8ValueArray()
        try {
            val jvmArgs = java.lang.management.ManagementFactory.getRuntimeMXBean().inputArguments
            jvmArgs.forEachIndexed { index, arg ->
                args.set(index, arg)
            }
        } catch (e: Exception) {
            args.close()
            env.close()
            throw e
        }
        
        // Process identifier (PID)
        val pid = ProcessHandle.current().pid()
        
        // Process name
        val processName = java.lang.management.ManagementFactory.getRuntimeMXBean().name
        
        // Host name
        val hostName = try {
            java.net.InetAddress.getLocalHost().hostName
        } catch (e: Exception) {
            "localhost"
        }
        
        // Platform
        val platform = when {
            System.getProperty("os.name").lowercase().contains("android") -> "android"
            System.getProperty("os.name").lowercase().contains("linux") -> "linux"
            System.getProperty("os.name").lowercase().contains("mac") || 
            System.getProperty("os.name").lowercase().contains("darwin") -> "darwin"
            System.getProperty("os.name").lowercase().contains("windows") -> "win32"
            else -> "unknown"
        }
        
        // Architecture
        val arch = when (System.getProperty("os.arch").lowercase()) {
            "amd64", "x86_64" -> "x64"
            "x86", "i386", "i686" -> "ia32"
            "aarch64", "arm64" -> "arm64"
            "arm" -> "arm"
            else -> System.getProperty("os.arch") // Return actual value as fallback
        }
        
        // OS information
        val osVersion = v8Runtime.createV8ValueObject()
        try {
            val versionParts = System.getProperty("os.version").split(".")
            osVersion.set("majorVersion", versionParts.getOrNull(0)?.toIntOrNull() ?: 0)
            osVersion.set("minorVersion", versionParts.getOrNull(1)?.toIntOrNull() ?: 0)
            osVersion.set("patchVersion", versionParts.getOrNull(2)?.toIntOrNull() ?: 0)
        } catch (e: Exception) {
            osVersion.close()
            args.close()
            env.close()
            throw e
        }
        
        // System resources
        val runtime = Runtime.getRuntime()
        
        // Build the process info object with properties and methods
        val processInfoObject = v8Runtime.createJSObject(
            properties = mapOf(
                "environment" to env,
                "arguments" to args,
                "processIdentifier" to pid.toInt(),
                "processName" to processName,
                "globallyUniqueString" to java.util.UUID.randomUUID().toString(),
                "hostName" to hostName,
                "platform" to platform,
                "arch" to arch,
                "operatingSystemVersionString" to System.getProperty("os.version"),
                "operatingSystemVersion" to osVersion,
                "deviceSpec" to platformContext.deviceInfo.spec,
                "isRealDevice" to platformContext.deviceInfo.isRealDevice,
                "isLowPowerModeEnabled" to false,
                "isMacCatalystApp" to false,
                "isiOSAppOnMac" to false,
                "thermalState" to 0
            ),
            methods = mapOf(
                "physicalMemory" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueLong(runtime.maxMemory())
                },
                "processorCount" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueInteger(runtime.availableProcessors())
                },
                "activeProcessorCount" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueInteger(runtime.availableProcessors())
                },
                "systemUptime" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueDouble(
                        java.lang.management.ManagementFactory.getRuntimeMXBean().uptime / 1000.0
                    )
                },
                "getuid" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueInteger(platformContext.processInfo.getuid())
                },
                "geteuid" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueInteger(platformContext.processInfo.geteuid())
                },
                "getgid" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueInteger(platformContext.processInfo.getgid())
                },
                "getegid" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueInteger(platformContext.processInfo.getegid())
                },
                "getgroups" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.toV8Value(platformContext.processInfo.getgroups())
                }
            )
        )
        
        // Register with __NATIVE_BRIDGE__
        // Note: Don't close processInfoObject - it needs to remain alive for the duration of the engine
        nativeBridge.set("processInfo", processInfoObject)
    }
}
