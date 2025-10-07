//
//  AutoCleanable.kt
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

import java.lang.ref.Cleaner
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Base class for resources that need automatic cleanup when garbage collected.
 * Uses Java's Cleaner API as a modern replacement for finalize().
 * 
 * This provides a safety net for cases where users forget to call close(),
 * while still encouraging explicit close() calls for predictable cleanup.
 * 
 * ## How it works:
 * 
 * 1. Child class overrides close() with actual resource cleanup logic
 * 2. When object is created, AutoCleanable registers it with the Cleaner
 * 3. CleanupAction captures a WeakReference to the object
 * 4. When garbage collected, close() is called automatically
 * 5. Explicit close() runs cleanup immediately and prevents future GC cleanup
 * 
 * ## Usage Pattern:
 * 
 * ```kotlin
 * class MyResource : AutoCleanable() {
 *     private val handle = allocateNativeHandle()
 *     
 *     override fun close() {
 *         super.close() // IMPORTANT: Call this first for once-only guarantee
 *         // Then your cleanup code:
 *         releaseNativeHandle(handle)
 *     }
 * }
 * 
 * // Works with .use {} pattern
 * MyResource().use { resource ->
 *     resource.doWork()
 * } // close() called automatically
 * ```
 * 
 * ## Thread Safety:
 * 
 * - The Cleaner runs cleanup on its own thread, not the finalizer thread
 * - close() should be thread-safe
 * - close() can be called from any thread
 * - Multiple close() calls are safe (cleanup runs only once via super.close())
 * 
 * ## Best Practices:
 * 
 * - Always call super.close() FIRST in your override
 * - Always call close() explicitly when done (don't rely on GC)
 * - Keep close() simple and fast
 * - Don't throw exceptions from close()
 * - This is a safety net, not a replacement for proper resource management
 * 
 * @see java.lang.ref.Cleaner
 */
abstract class AutoCleanable : AutoCloseable {
    
    companion object {
        /**
         * Shared Cleaner instance for all AutoCleanable objects
         * Creates a daemon thread for cleanup operations
         */
        private val cleaner: Cleaner = Cleaner.create()
    }
    
    /**
     * The registered Cleanable object that can trigger cleanup
     * Null after cleanup has been performed
     */
    @Volatile
    private var cleanable: Cleaner.Cleanable? = null
    
    /**
     * Flag to ensure cleanup runs only once
     */
    private val hasCleanedUp = AtomicBoolean(false)
    
    /**
     * Check if this resource has been closed
     */
    val isClosed: Boolean
        get() = hasCleanedUp.get()
    
    init {
        // Register cleanup action that will run on GC
        // CRITICAL: CleanupAction must use WeakReference
        val cleanupAction = CleanupAction(this, hasCleanedUp)
        cleanable = cleaner.register(this, cleanupAction)
    }
    
    /**
     * Close and clean up resources.
     * 
     * Child classes should override this method to perform actual cleanup.
     * **CRITICAL:** Always call super.close() FIRST to ensure once-only cleanup.
     * 
     * This method is called:
     * - When close() is explicitly called
     * - Automatically when this object is garbage collected
     * - Automatically by .use {} block
     * 
     * **Thread Safety:** May be called on any thread, should be thread-safe.
     * 
     * **Error Handling:** Do not throw exceptions from this method. Log errors instead.
     * 
     * Example:
     * ```kotlin
     * override fun close() {
     *     super.close() // FIRST: ensures once-only cleanup
     *     // Then your cleanup:
     *     myResource.release()
     * }
     * ```
     */
    override fun close() {
        // Ensure cleanup runs only once
        if (hasCleanedUp.compareAndSet(false, true)) {
            // Deregister from Cleaner to prevent redundant GC cleanup
            cleanable?.clean()
            cleanable = null
        }
    }
    
    /**
     * Internal cleanup action that runs on the Cleaner thread for GC cleanup.
     * 
     * This class uses WeakReference internally to avoid preventing GC.
     * It calls close() on the target object if it still exists.
     */
    private class CleanupAction(
        target: AutoCleanable,
        private val hasCleanedUp: AtomicBoolean
    ) : Runnable {
        
        // Use WeakReference so we don't prevent garbage collection
        private val targetRef = java.lang.ref.WeakReference(target)
        
        override fun run() {
            // Ensure cleanup runs only once
            if (hasCleanedUp.compareAndSet(false, true)) {
                try {
                    // Get the object if it still exists and call its close()
                    targetRef.get()?.close()
                } catch (e: Exception) {
                    // Log but don't throw - we're on the Cleaner thread
                    System.err.println("AutoCleanable cleanup failed: ${e.message}")
                    e.printStackTrace()
                }
            }
        }
    }
}
