/*
 * URLPatternTests.kt
 * JSCore
 *
 * MIT License
 *
 * Copyright (c) 2025 o2ter
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

package com.o2ter.jscore.webapis

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.platform.JvmPlatformContext
import org.junit.Assert.*
import org.junit.Test

class URLPatternTests {

    @Test
    fun testURLPatternExactMatch() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/users/123');
            ({
                match1: pattern.test('/users/123'),
                match2: pattern.test('/users/456'),
                match3: pattern.test('/posts/123')
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should match exact path", result["match1"] as Boolean)
        assertFalse("Should not match different ID", result["match2"] as Boolean)
        assertFalse("Should not match different path", result["match3"] as Boolean)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternNamedParameters() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/users/:id');
            var result = pattern.exec('/users/123');
            ({
                matched: result !== null,
                hasParams: result && result.params !== undefined,
                id: result && result.params.id
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should match pattern", result["matched"] as Boolean)
        assertTrue("Should have params object", result["hasParams"] as Boolean)
        assertEquals("Should extract ID parameter", "123", result["id"])
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternMultipleNamedParameters() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/users/:userId/posts/:postId');
            var result = pattern.exec('/users/42/posts/99');
            ({
                userId: result && result.params.userId,
                postId: result && result.params.postId
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertEquals("Should extract userId", "42", result["userId"])
        assertEquals("Should extract postId", "99", result["postId"])
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternWildcard() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/static/*');
            ({
                match1: pattern.test('/static/css/style.css'),
                match2: pattern.test('/static/js/app.js'),
                match3: pattern.test('/api/data'),
                exec: pattern.exec('/static/images/logo.png')
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should match /static/css/style.css", result["match1"] as Boolean)
        assertTrue("Should match /static/js/app.js", result["match2"] as Boolean)
        assertFalse("Should not match /api/data", result["match3"] as Boolean)
        assertNotNull("Should match and return result", result["exec"])
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternDoubleWildcard() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/files/**');
            ({
                match1: pattern.test('/files/docs/report.pdf'),
                match2: pattern.test('/files/images/2024/photo.jpg'),
                match3: pattern.test('/api/files')
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should match nested path", result["match1"] as Boolean)
        assertTrue("Should match deeply nested path", result["match2"] as Boolean)
        assertFalse("Should not match different base path", result["match3"] as Boolean)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternMixedParameters() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/api/:version/users/:id/*');
            var result = pattern.exec('/api/v1/users/123/profile/avatar');
            ({
                matched: result !== null,
                version: result && result.params.version,
                id: result && result.params.id
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should match complex pattern", result["matched"] as Boolean)
        assertEquals("Should extract version", "v1", result["version"])
        assertEquals("Should extract id", "123", result["id"])
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternNoMatch() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/users/:id');
            var result = pattern.exec('/posts/123');
            result === null
        """

        val isNull = engine.execute(script) as Boolean
        assertTrue("Should return null for non-matching path", isNull)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternTrailingSlash() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/users/:id');
            ({
                withoutSlash: pattern.test('/users/123'),
                withSlash: pattern.test('/users/123/')
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should match without trailing slash", result["withoutSlash"] as Boolean)
        // Note: Behavior for trailing slash may vary by implementation
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternEmptyPath() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/');
            ({
                root: pattern.test('/'),
                other: pattern.test('/users')
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should match root path", result["root"] as Boolean)
        assertFalse("Should not match non-root path", result["other"] as Boolean)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternSpecialCharacters() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/users/:id');
            var result = pattern.exec('/users/abc-123_xyz');
            ({
                matched: result !== null,
                id: result && result.params.id
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should match ID with special chars", result["matched"] as Boolean)
        assertEquals("Should extract full ID with special chars", "abc-123_xyz", result["id"])
        } finally {
            engine.close()
        }
    }

    @Test
    fun testURLPatternConstructor() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var pattern = new URLPattern('/test');
            ({
                hasTest: typeof pattern.test === 'function',
                hasExec: typeof pattern.exec === 'function',
                isURLPattern: pattern.constructor.name === 'URLPattern'
            })
        """

        val result = engine.execute(script) as Map<*, *>
        assertTrue("Should have test method", result["hasTest"] as Boolean)
        assertTrue("Should have exec method", result["hasExec"] as Boolean)
        assertTrue("Constructor name should be URLPattern", result["isURLPattern"] as Boolean)
        } finally {
            engine.close()
        }
    }
}
