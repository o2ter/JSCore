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
        // Get environment variables from platform context
        val env = v8Runtime.createV8ValueObject()
        val args = v8Runtime.createV8ValueArray()
        val osVersion = v8Runtime.createV8ValueObject()
        
        try {
            platformContext.processInfo.environment.forEach { (key, value) ->
                env.set(key, value)
            }
            
            // Get command-line arguments from platform context
            platformContext.processInfo.inputArguments.forEachIndexed { index, arg ->
                args.set(index, arg)
            }
            
            // OS version information from platform context
            val osVer = platformContext.processInfo.osVersion
            osVersion.set("majorVersion", osVer.major)
            osVersion.set("minorVersion", osVer.minor)
            osVersion.set("patchVersion", osVer.patch)
            
            // Build the process info object with properties and methods
            val processInfoObject = v8Runtime.createJSObject(
                properties = mapOf(
                    "environment" to env,
                    "arguments" to args,
                    "processIdentifier" to platformContext.processInfo.processIdentifier.toInt(),
                    "processName" to platformContext.processInfo.processName,
                    "globallyUniqueString" to java.util.UUID.randomUUID().toString(),
                    "hostName" to platformContext.processInfo.hostName,
                    "platform" to platformContext.processInfo.platform,
                    "arch" to platformContext.processInfo.architecture,
                    "operatingSystemVersionString" to platformContext.processInfo.osVersionString,
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
                        return@NoThisAndResult v8Runtime.createV8ValueLong(platformContext.processInfo.getPhysicalMemory())
                    },
                    "processorCount" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(platformContext.processInfo.getProcessorCount())
                    },
                    "activeProcessorCount" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(platformContext.processInfo.getActiveProcessorCount())
                    },
                    "systemUptime" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                        return@NoThisAndResult v8Runtime.createV8ValueDouble(
                            platformContext.processInfo.getSystemUptime()
                        )
                    },
                    "getuid" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(platformContext.processInfo.getuid())
                    },
                    "geteuid" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(platformContext.processInfo.geteuid())
                    },
                    "getgid" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(platformContext.processInfo.getgid())
                    },
                    "getegid" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(platformContext.processInfo.getegid())
                    },
                    "getgroups" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                        return@NoThisAndResult v8Runtime.toV8Value(platformContext.processInfo.getgroups())
                    }
                )
            )
            
            try {
                // Register with __NATIVE_BRIDGE__
                nativeBridge.set("processInfo", processInfoObject)
            } finally {
                processInfoObject.close()
            }
        } finally {
            // Clean up child objects - these are now owned by processInfoObject, but we release our references
            osVersion.close()
            args.close()
            env.close()
        }
    }
}
