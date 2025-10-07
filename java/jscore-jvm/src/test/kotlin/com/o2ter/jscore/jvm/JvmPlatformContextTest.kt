//
//  JvmPlatformContextTest.kt
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
import kotlin.test.Test
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertNull

class JvmPlatformContextTest {
    
    @Test
    fun testJvmPlatformContextCreation() {
        val context = JvmPlatformContext("TestApp")
        
        assertNotNull(context.logger, "JVM context should provide logger")
        assertNotNull(context.deviceInfo, "JVM context should provide device info")
        assertNotNull(context.bundleInfo, "JVM context should provide bundle info")
        assertNotNull(context.secureStorage, "JVM context should provide secure storage")
    }
    
    @Test
    fun testJvmLogger() {
        val context = JvmPlatformContext("TestApp")
        val logger = context.logger
        
        // Should not throw exceptions
        logger.info("TEST", "Test message")
        logger.debug("TEST", "Debug message")
        logger.error("TEST", "Error message")
        logger.warning("TEST", "Warning message")
        logger.verbose("TEST", "Verbose message")
    }
    
    @Test
    fun testJvmDeviceInfo() {
        val context = JvmPlatformContext("TestApp")
        val deviceInfo = context.deviceInfo
        
        assertTrue(deviceInfo.isRealDevice, "JVM implementation considers itself a real device")
        assertNotNull(deviceInfo.getIdentifierForVendor(), "Should provide device identifier")
        
        // Should be consistent across calls
        val id1 = deviceInfo.getIdentifierForVendor()
        val id2 = deviceInfo.getIdentifierForVendor()
        assertEquals(id1, id2, "Device identifier should be consistent")
    }
    
    @Test
    fun testJvmBundleInfo() {
        val context = JvmPlatformContext("TestApp")
        val bundleInfo = context.bundleInfo
        
        assertNotNull(bundleInfo.appVersion, "Should provide app version")
        assertNotNull(bundleInfo.buildVersion, "Should provide build version")
        assertNotNull(bundleInfo.bundleIdentifier, "Should provide bundle identifier")
        
        assertTrue(bundleInfo.bundleIdentifier.contains("TestApp"), "Bundle ID should contain app name")
    }
    
    @Test
    fun testJvmSecureStorage() {
        val uniqueKey = "test_key_${System.currentTimeMillis()}"
        val context = JvmPlatformContext("TestApp")
        val storage = context.secureStorage
        
        // Test default value
        val defaultValue = storage.getString(uniqueKey, "default")
        assertEquals("default", defaultValue, "Should return default for non-existent key")
        
        // Test store and retrieve
        storage.putString(uniqueKey, "test_value")
        val retrievedValue = storage.getString(uniqueKey, "default")
        assertEquals("test_value", retrievedValue, "Should store and retrieve values")
    }
    
    @Test
    fun testAssetLoadingNotNeeded() {
        // Test that polyfill loading no longer requires asset access
        val polyfillCode = com.o2ter.jscore.PolyfillLoader.getPolyfillCode()
        assertNotNull(polyfillCode, "Embedded polyfill should be accessible without asset loading")
        assertTrue(polyfillCode.isNotEmpty(), "Polyfill should have content")
    }
}

class JavaScriptEngineTest {
    
    @Test
    fun testEngineCreation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        assertNotNull(engine, "Should create engine instance")
    }
    
    @Test
    fun testBasicJavaScriptExecution() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        // Test basic expression evaluation
        val result = engine.execute("1 + 1")
        assertEquals("2", result?.toString(), "Should evaluate basic arithmetic")
        
        // Test variable assignment and retrieval
        engine.execute("var testVar = 'hello world'")
        val varResult = engine.execute("testVar")
        assertEquals("hello world", varResult?.toString(), "Should handle variable assignment")
    }
    
    @Test
    fun testConsoleLogging() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        // Should not throw exceptions when console functions are called
        engine.execute("console.log('Test message')")
        engine.execute("console.error('Error message')")
        engine.execute("console.warn('Warning message')")
    }
    
    @Test
    fun testTimerFunctionality() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        // Test that timer functions exist and don't throw errors
        engine.execute("var timerId = setTimeout(function() { console.log('timeout'); }, 100)")
        engine.execute("clearTimeout(timerId)")
        
        engine.execute("var intervalId = setInterval(function() { console.log('interval'); }, 100)")
        engine.execute("clearInterval(intervalId)")
    }
    
    @Test
    fun testLoadAndExecuteTestScript() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        // Load and execute test script using embedded polyfill
        val polyfillCode = com.o2ter.jscore.PolyfillLoader.getPolyfillCode()
        engine.execute(polyfillCode) // Load polyfill first
        
        // Test basic execution works with polyfill loaded
        val result = engine.execute("typeof Event !== 'undefined'")
        assertTrue(result as? Boolean ?: false, "Event should be available after polyfill load")
    }
    
    @Test
    fun testEmbeddedPolyfillAccess() {
        // Test that we can access the embedded polyfill without file I/O
        val polyfillCode = com.o2ter.jscore.PolyfillLoader.getPolyfillCode()
        
        assertNotNull(polyfillCode, "Embedded polyfill should be available")
        assertTrue(polyfillCode.contains("Private symbols for internal APIs"), "Should contain expected content")
        assertTrue(polyfillCode.contains("Event"), "Should contain Event polyfill")
        assertTrue(polyfillCode.contains("AbortController"), "Should contain AbortController polyfill")
        
        // Test utility methods
        assertTrue(com.o2ter.jscore.PolyfillLoader.isPolyfillAvailable(), "Polyfill should always be available")
        assertTrue(com.o2ter.jscore.PolyfillLoader.getPolyfillSize() > 0, "Polyfill should have content")
    }
}