//
//  JvmPlatformContext.kt
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

package com.o2ter.jscore.jvm

import com.o2ter.jscore.*
import org.slf4j.LoggerFactory
import java.io.File
import java.util.*

class JvmPlatformContext(private val appName: String = "JSCore") : PlatformContext {
    
    override val logger: PlatformLogger = Slf4jLogger()
    override val deviceInfo: DeviceInfo = JvmDeviceInfo()
    override val bundleInfo: BundleInfo = JvmBundleInfo(appName)
    override val secureStorage: SecureStorage = PropertiesSecureStorage(appName)
    override val processInfo: ProcessInfoProvider = JvmProcessInfo()
    
    /**
     * Get ICU data file path for i18n support
     * Extracts ICU data from resources (embedded in JAR) to a temporary file
     * ICU data is always present in source tree
     */
    override fun getIcuDataPath(): String? {
        try {
            // Load ICU data from resources (packaged in JAR)
            val resourceStream = this::class.java.classLoader?.getResourceAsStream(IcuConfig.ICU_DATA_RESOURCE_PATH)
                ?: throw RuntimeException("ICU data resource not found: ${IcuConfig.ICU_DATA_RESOURCE_PATH}")
            
            // Extract to temporary file for V8 to access
            val tempFile = File.createTempFile("icudtl", ".dat")
            tempFile.deleteOnExit()
            
            resourceStream.use { input ->
                tempFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            
            return tempFile.absolutePath
        } catch (e: Exception) {
            logger.error("JvmPlatformContext", "Failed to load ICU data: ${e.message}")
            throw RuntimeException("Failed to load ICU data for i18n support", e)
        }
    }
}

class Slf4jLogger : PlatformLogger {
    private val logger = LoggerFactory.getLogger("JSCore")
    
    override fun verbose(tag: String, message: String) = logger.trace("[$tag] $message")
    override fun debug(tag: String, message: String) = logger.debug("[$tag] $message")
    override fun info(tag: String, message: String) = logger.info("[$tag] $message")
    override fun warning(tag: String, message: String) = logger.warn("[$tag] $message")
    override fun error(tag: String, message: String) = logger.error("[$tag] $message")
}

class JvmDeviceInfo : DeviceInfo {
    override val spec: String = "jvm"

    override val isRealDevice: Boolean = true
    
    private val cachedIdentifier: String by lazy {
        // Use MAC address or system properties to generate a stable identifier
        try {
            val networkInterface = java.net.NetworkInterface.getNetworkInterfaces()
                .asSequence()
                .firstOrNull { it.hardwareAddress != null }
            
            if (networkInterface != null) {
                val mac = networkInterface.hardwareAddress
                val sb = StringBuilder()
                for (i in mac.indices) {
                    sb.append(String.format("%02X%s", mac[i], if (i < mac.size - 1) "-" else ""))
                }
                sb.toString()
            } else {
                // Fallback to system properties
                val props = System.getProperties()
                val composite = "${props["os.name"]}-${props["user.name"]}-${props["java.version"]}"
                composite.hashCode().toString()
            }
        } catch (e: Exception) {
            // Final fallback - random UUID but try to persist it
            UUID.randomUUID().toString()
        }
    }
    
    override fun getIdentifierForVendor(): String = cachedIdentifier
}

class JvmBundleInfo(private val appName: String) : BundleInfo {
    override val appVersion: String
        get() = this::class.java.`package`?.implementationVersion ?: "1.0.0"
    
    override val buildVersion: String
        get() = System.getProperty("java.version", "unknown")
    
    override val bundleIdentifier: String
        get() = "com.o2ter.jscore.$appName"
}

class PropertiesSecureStorage(appName: String) : SecureStorage {
    private val configDir = File(System.getProperty("user.home"), ".jscore")
    private val propertiesFile = File(configDir, "$appName.properties")
    private val properties = Properties()
    
    init {
        if (!configDir.exists()) {
            configDir.mkdirs()
        }
        
        if (propertiesFile.exists()) {
            try {
                propertiesFile.inputStream().use { 
                    properties.load(it)
                }
            } catch (e: Exception) {
                // Ignore errors loading properties
            }
        }
    }
    
    override fun getString(key: String, defaultValue: String): String {
        return properties.getProperty(key, defaultValue)
    }
    
    override fun putString(key: String, value: String) {
        properties.setProperty(key, value)
        try {
            propertiesFile.outputStream().use {
                properties.store(it, "JSCore Storage")
            }
        } catch (e: Exception) {
            // Ignore errors saving properties
        }
    }
}

class JvmProcessInfo : ProcessInfoProvider {
    /**
     * POSIX user/group IDs are not available in pure JVM
     * Return -1 to indicate unsupported (matching POSIX error convention)
     */
    override fun getuid(): Int = -1
    override fun geteuid(): Int = -1
    override fun getgid(): Int = -1
    override fun getegid(): Int = -1
    override fun getgroups(): IntArray = intArrayOf()
}