//
//  PlatformContext.kt
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

/**
 * Platform-independent context interface that provides access to platform-specific services
 */
interface PlatformContext {
    /**
     * Gets the platform logger
     */
    val logger: PlatformLogger
    
    /**
     * Gets the device/platform information provider
     */
    val deviceInfo: DeviceInfo
    
    /**
     * Gets the bundle/application information
     */
    val bundleInfo: BundleInfo
    
    /**
     * Gets the secure storage interface
     */
    val secureStorage: SecureStorage
    
    /**
     * Gets the path to ICU data file for i18n support
     * Returns null if ICU data is not available
     */
    fun getIcuDataPath(): String?
}

/**
 * Platform-independent logging interface
 */
interface PlatformLogger {
    fun verbose(tag: String, message: String)
    fun debug(tag: String, message: String)
    fun info(tag: String, message: String)
    fun warning(tag: String, message: String)
    fun error(tag: String, message: String)
}

/**
 * Device information interface
 */
interface DeviceInfo {
    val spec: String
    val isRealDevice: Boolean
    fun getIdentifierForVendor(): String
}

/**
 * Bundle/Application information interface
 */
interface BundleInfo {
    val appVersion: String
    val buildVersion: String
    val bundleIdentifier: String
}

/**
 * Secure storage interface for persistent data
 */
interface SecureStorage {
    fun getString(key: String, defaultValue: String = ""): String
    fun putString(key: String, value: String)
}