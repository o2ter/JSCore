/*
 * PerformanceTests.kt
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

class PerformanceTests {

    @Test
    fun testPerformanceNow() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var start = performance.now();
            var end = performance.now();
            ({
                start: start,
                end: end,
                elapsed: end - start
            })
        """

        val result = engine.execute(script) as Map<*, *>
        val start = (result["start"] as Number).toDouble()
        val end = (result["end"] as Number).toDouble()
        val elapsed = (result["elapsed"] as Number).toDouble()

        assertTrue("Start time should be positive", start > 0)
        assertTrue("End time should be >= start time", end >= start)
        assertTrue("Elapsed time should be non-negative", elapsed >= 0)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testPerformanceMark() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            performance.mark('test-start');
            performance.mark('test-end');
            var entries = performance.getEntriesByType('mark');
            ({
                count: entries.length,
                hasStart: entries.some(e => e.name === 'test-start'),
                hasEnd: entries.some(e => e.name === 'test-end'),
                firstType: entries[0].entryType
            })
        """

        val result = engine.execute(script) as Map<*, *>
        val count = (result["count"] as Number).toInt()
        val hasStart = result["hasStart"] as Boolean
        val hasEnd = result["hasEnd"] as Boolean
        val firstType = result["firstType"] as String

        assertEquals("Should have 2 marks", 2, count)
        assertTrue("Should have test-start mark", hasStart)
        assertTrue("Should have test-end mark", hasEnd)
        assertEquals("Entry type should be 'mark'", "mark", firstType)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testPerformanceMeasure() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            performance.mark('start');
            performance.mark('end');
            performance.measure('duration', 'start', 'end');
            var measures = performance.getEntriesByType('measure');
            ({
                count: measures.length,
                name: measures[0].name,
                entryType: measures[0].entryType,
                hasDuration: measures[0].duration !== undefined
            })
        """

        val result = engine.execute(script) as Map<*, *>
        val count = (result["count"] as Number).toInt()
        val name = result["name"] as String
        val entryType = result["entryType"] as String
        val hasDuration = result["hasDuration"] as Boolean

        assertEquals("Should have 1 measure", 1, count)
        assertEquals("Measure name should be 'duration'", "duration", name)
        assertEquals("Entry type should be 'measure'", "measure", entryType)
        assertTrue("Measure should have duration property", hasDuration)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testPerformanceGetEntriesByName() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            performance.mark('test');
            performance.mark('other');
            performance.mark('test');
            var testEntries = performance.getEntriesByName('test');
            ({
                count: testEntries.length,
                allNamed: testEntries.every(e => e.name === 'test')
            })
        """

        val result = engine.execute(script) as Map<*, *>
        val count = (result["count"] as Number).toInt()
        val allNamed = result["allNamed"] as Boolean

        assertEquals("Should have 2 'test' marks", 2, count)
        assertTrue("All entries should be named 'test'", allNamed)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testPerformanceGetEntries() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            performance.mark('mark1');
            performance.mark('mark2');
            performance.measure('measure1', 'mark1', 'mark2');
            var allEntries = performance.getEntries();
            ({
                totalCount: allEntries.length,
                hasMarks: allEntries.some(e => e.entryType === 'mark'),
                hasMeasures: allEntries.some(e => e.entryType === 'measure')
            })
        """

        val result = engine.execute(script) as Map<*, *>
        val totalCount = (result["totalCount"] as Number).toInt()
        val hasMarks = result["hasMarks"] as Boolean
        val hasMeasures = result["hasMeasures"] as Boolean

        assertEquals("Should have 3 total entries (2 marks + 1 measure)", 3, totalCount)
        assertTrue("Should have mark entries", hasMarks)
        assertTrue("Should have measure entries", hasMeasures)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testPerformanceClearMarks() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            performance.mark('test1');
            performance.mark('test2');
            performance.clearMarks();
            var marks = performance.getEntriesByType('mark');
            marks.length
        """

        val count = (engine.execute(script) as Number).toInt()
        assertEquals("All marks should be cleared", 0, count)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testPerformanceClearMeasures() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            performance.mark('start');
            performance.mark('end');
            performance.measure('test', 'start', 'end');
            performance.clearMeasures();
            var measures = performance.getEntriesByType('measure');
            measures.length
        """

        val count = (engine.execute(script) as Number).toInt()
        assertEquals("All measures should be cleared", 0, count)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testPerformanceHighResolution() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val script = """
            var times = [];
            for (var i = 0; i < 10; i++) {
                times.push(performance.now());
            }
            var differences = [];
            for (var i = 1; i < times.length; i++) {
                differences.push(times[i] - times[i-1]);
            }
            ({
                allIncreasing: differences.every(d => d >= 0),
                hasFractional: times.some(t => t !== Math.floor(t))
            })
        """

        val result = engine.execute(script) as Map<*, *>
        val allIncreasing = result["allIncreasing"] as Boolean
        val hasFractional = result["hasFractional"] as Boolean

        assertTrue("Times should be monotonically increasing", allIncreasing)
        assertTrue("Should have sub-millisecond precision", hasFractional)
        } finally {
            engine.close()
        }
    }
}
