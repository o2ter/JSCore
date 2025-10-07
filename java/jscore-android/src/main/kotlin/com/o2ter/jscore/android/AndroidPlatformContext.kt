//
//  AndroidPlatformContext.kt
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

package com.o2ter.jscore.android

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.core.content.edit
import com.o2ter.jscore.*
import java.lang.reflect.InvocationTargetException
import java.util.UUID

class AndroidPlatformContext(private val context: Context) : PlatformContext {
    
    override val logger: PlatformLogger = AndroidLogger()
    override val deviceInfo: DeviceInfo = AndroidDeviceInfo(context)
    override val bundleInfo: BundleInfo = AndroidBundleInfo(context)
    override val secureStorage: SecureStorage = AndroidSecureStorage(context)
    override val processInfo: ProcessInfoProvider = AndroidProcessInfo()
    
    /**
     * Get ICU data path for Android
     * Loads ICU data from resources (embedded in APK) and copies to internal storage
     * ICU data is always present in source tree
     */
    override fun getIcuDataPath(): String? {
        try {
            val icuFile = java.io.File(context.filesDir, "icudtl.dat")
            
            // Copy from resources if not already present
            if (!icuFile.exists()) {
                val resourceStream = this::class.java.classLoader?.getResourceAsStream(
                    "com/o2ter/jscore/android/resource/icudtl.dat"
                ) ?: throw RuntimeException("ICU data resource not found in APK")
                
                resourceStream.use { input ->
                    icuFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            }
            
            return icuFile.absolutePath
        } catch (e: Exception) {
            Log.e("AndroidPlatformContext", "Failed to load ICU data: ${e.message}")
            throw RuntimeException("Failed to load ICU data for i18n support", e)
        }
    }
}

class AndroidLogger : PlatformLogger {
    override fun verbose(tag: String, message: String) {
        Log.v(tag, message)
    }
    override fun debug(tag: String, message: String) {
        Log.d(tag, message)
    }
    override fun info(tag: String, message: String) {
        Log.i(tag, message)
    }
    override fun warning(tag: String, message: String) {
        Log.w(tag, message)
    }
    override fun error(tag: String, message: String) {
        Log.e(tag, message)
    }
}

class AndroidDeviceInfo(private val context: Context) : DeviceInfo {
    override val spec: String = "android"

    override val isRealDevice: Boolean
        get() = !isEmulator()
    
    override fun getIdentifierForVendor(): String {
        return context.identifierForVendor()
    }
    
    @Suppress("DEPRECATION")
    private fun isEmulator(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.FROYO && Build.HARDWARE.contains("goldfish"))
                || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.FROYO && Build.HARDWARE.contains("ranchu"))
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.DONUT && Build.MANUFACTURER.contains("Genymotion"))
                || Build.PRODUCT.contains("sdk_google")
                || Build.PRODUCT.contains("google_sdk")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("sdk_x86")
                || Build.PRODUCT.contains("sdk_gphone64_arm64")
                || Build.PRODUCT.contains("vbox86p")
                || Build.PRODUCT.contains("emulator")
                || Build.PRODUCT.contains("simulator")
    }
}

class AndroidBundleInfo(private val context: Context) : BundleInfo {
    override val appVersion: String
        get() = try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            info.versionName ?: "unknown"
        } catch (_: Exception) {
            "unknown"
        }
    
    @Suppress("DEPRECATION")
    override val buildVersion: String
        get() = try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode.toString()
            } else {
                info.versionCode.toString()
            }
        } catch (_: Exception) {
            "unknown"
        }
    
    override val bundleIdentifier: String
        get() = context.packageName
}

class AndroidSecureStorage(private val context: Context) : SecureStorage {
    private val prefs: SharedPreferences = context.getSharedPreferences("__JSCORE_NATIVE__", Context.MODE_PRIVATE)
    
    override fun getString(key: String, defaultValue: String): String {
        return prefs.getString(key, defaultValue) ?: defaultValue
    }
    
    override fun putString(key: String, value: String) {
        prefs.edit(commit = true) {
            putString(key, value)
        }
    }
}

// Extension functions for Android compatibility
private fun Context.defaultSharedPreferences(): SharedPreferences {
    return this.getSharedPreferences("__JSCORE_NATIVE__", Context.MODE_PRIVATE)
}

fun Context.identifierForVendor(): String {
    val prefs = this.defaultSharedPreferences()
    var instanceId = prefs.getString("instanceId", "")!!

    if (instanceId.isNotEmpty()) {
        return instanceId
    }

    try {
        instanceId = getFirebaseInstanceId()
        prefs.edit(commit = true) {
            putString("instanceId", instanceId)
        }
        return instanceId
    } catch (_: ClassNotFoundException) {
    } catch (_: NoSuchMethodException) {
        System.err.println("N/A: Unsupported version of com.google.firebase:firebase-iid in your project.")
    } catch (_: SecurityException) {
        System.err.println("N/A: Unsupported version of com.google.firebase:firebase-iid in your project.")
    } catch (_: IllegalAccessException) {
        System.err.println("N/A: Unsupported version of com.google.firebase:firebase-iid in your project.")
    } catch (_: InvocationTargetException) {
        System.err.println("N/A: Unsupported version of com.google.firebase:firebase-iid in your project.")
    }

    try {
        instanceId = getGmsInstanceId()
        prefs.edit(commit = true) {
            putString("instanceId", instanceId)
        }
        return instanceId
    } catch (_: ClassNotFoundException) {
    } catch (_: NoSuchMethodException) {
        System.err.println("N/A: Unsupported version of com.google.android.gms.iid in your project.")
    } catch (_: SecurityException) {
        System.err.println("N/A: Unsupported version of com.google.android.gms.iid in your project.")
    } catch (_: IllegalAccessException) {
        System.err.println("N/A: Unsupported version of com.google.android.gms.iid in your project.")
    } catch (_: InvocationTargetException) {
        System.err.println("N/A: Unsupported version of com.google.android.gms.iid in your project.")
    }

    instanceId = getUUIDInstanceId()
    prefs.edit(commit = true) {
        putString("instanceId", instanceId)
    }
    return instanceId
}

fun getUUIDInstanceId(): String {
    return UUID.randomUUID().toString()
}

@Throws(
    ClassNotFoundException::class,
    NoSuchMethodException::class,
    IllegalAccessException::class,
    InvocationTargetException::class
)
fun Context.getGmsInstanceId(): String {
    val clazz = Class.forName("com.google.android.gms.iid.InstanceID")
    val method = clazz.getDeclaredMethod("getInstance", Context::class.java)
    val obj = method.invoke(null, this.applicationContext)
    val method1 = obj.javaClass.getMethod("getId")
    return method1.invoke(obj) as String
}

@Throws(
    ClassNotFoundException::class,
    NoSuchMethodException::class,
    IllegalAccessException::class,
    InvocationTargetException::class
)
fun getFirebaseInstanceId(): String {
    val clazz = Class.forName("com.google.firebase.iid.FirebaseInstanceId")
    val method = clazz.getDeclaredMethod("getInstance")
    val obj = method.invoke(null)
    val method1 = obj.javaClass.getMethod("getId")
    return method1.invoke(obj) as String
}

class AndroidProcessInfo : ProcessInfoProvider {
    /**
     * Android uses Linux kernel, so POSIX user/group IDs are available via Os class
     * Returns actual UID/GID values from the Android system
     */
    override fun getuid(): Int {
        return try {
            android.system.Os.getuid()
        } catch (e: Exception) {
            -1
        }
    }
    
    override fun geteuid(): Int {
        return try {
            android.system.Os.geteuid()
        } catch (e: Exception) {
            -1
        }
    }
    
    override fun getgid(): Int {
        return try {
            android.system.Os.getgid()
        } catch (e: Exception) {
            -1
        }
    }
    
    override fun getegid(): Int {
        return try {
            android.system.Os.getegid()
        } catch (e: Exception) {
            -1
        }
    }
    
    override fun getgroups(): IntArray {
        return try {
            android.system.Os.getgroups()
        } catch (e: Exception) {
            intArrayOf()
        }
    }
}