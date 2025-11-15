//
// PerformanceAPITests.swift
// SwiftJS
//
// MIT License
//
// Copyright (c) 2025 o2ter
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
@testable import SwiftJS

@MainActor
final class PerformanceAPITests: XCTestCase {
    
    func testPerformanceNow() {
        let context = SwiftJS()
        
        let script = """
        var start = performance.now();
        var end = performance.now();
        ({
            start: start,
            end: end,
            elapsed: end - start
        })
        """
        
        let result = context.evaluateScript(script)
        let start = result["start"].numberValue ?? 0
        let end = result["end"].numberValue ?? 0
        let elapsed = result["elapsed"].numberValue ?? 0
        
        XCTAssertGreaterThan(start, 0, "Start time should be positive")
        XCTAssertGreaterThanOrEqual(end, start, "End time should be >= start time")
        XCTAssertGreaterThanOrEqual(elapsed, 0, "Elapsed time should be non-negative")
    }
    
    func testPerformanceMark() {
        let context = SwiftJS()
        
        let script = """
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
        
        let result = context.evaluateScript(script)
        let count = Int(result["count"].numberValue ?? 0)
        let hasStart = result["hasStart"].boolValue ?? false
        let hasEnd = result["hasEnd"].boolValue ?? false
        let firstType = result["firstType"].stringValue ?? ""
        
        XCTAssertEqual(count, 2, "Should have 2 marks")
        XCTAssertTrue(hasStart, "Should have test-start mark")
        XCTAssertTrue(hasEnd, "Should have test-end mark")
        XCTAssertEqual(firstType, "mark", "Entry type should be 'mark'")
    }
    
    func testPerformanceMeasure() {
        let context = SwiftJS()
        
        let script = """
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
        
        let result = context.evaluateScript(script)
        let count = Int(result["count"].numberValue ?? 0)
        let name = result["name"].stringValue ?? ""
        let entryType = result["entryType"].stringValue ?? ""
        let hasDuration = result["hasDuration"].boolValue ?? false
        
        XCTAssertEqual(count, 1, "Should have 1 measure")
        XCTAssertEqual(name, "duration", "Measure name should be 'duration'")
        XCTAssertEqual(entryType, "measure", "Entry type should be 'measure'")
        XCTAssertTrue(hasDuration, "Measure should have duration property")
    }
    
    func testPerformanceGetEntriesByName() {
        let context = SwiftJS()
        
        let script = """
        performance.mark('test');
        performance.mark('other');
        performance.mark('test');
        var testEntries = performance.getEntriesByName('test');
        ({
            count: testEntries.length,
            allNamed: testEntries.every(e => e.name === 'test')
        })
        """
        
        let result = context.evaluateScript(script)
        let count = Int(result["count"].numberValue ?? 0)
        let allNamed = result["allNamed"].boolValue ?? false
        
        XCTAssertEqual(count, 2, "Should have 2 'test' marks")
        XCTAssertTrue(allNamed, "All entries should be named 'test'")
    }
    
    func testPerformanceGetEntries() {
        let context = SwiftJS()
        
        let script = """
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
        
        let result = context.evaluateScript(script)
        let totalCount = Int(result["totalCount"].numberValue ?? 0)
        let hasMarks = result["hasMarks"].boolValue ?? false
        let hasMeasures = result["hasMeasures"].boolValue ?? false
        
        XCTAssertEqual(totalCount, 3, "Should have 3 total entries (2 marks + 1 measure)")
        XCTAssertTrue(hasMarks, "Should have mark entries")
        XCTAssertTrue(hasMeasures, "Should have measure entries")
    }
    
    func testPerformanceClearMarks() {
        let context = SwiftJS()
        
        let script = """
        performance.mark('test1');
        performance.mark('test2');
        performance.clearMarks();
        var marks = performance.getEntriesByType('mark');
        marks.length
        """
        
        let count = Int(context.evaluateScript(script).numberValue ?? -1)
        XCTAssertEqual(count, 0, "All marks should be cleared")
    }
    
    func testPerformanceClearMeasures() {
        let context = SwiftJS()
        
        let script = """
        performance.mark('start');
        performance.mark('end');
        performance.measure('test', 'start', 'end');
        performance.clearMeasures();
        var measures = performance.getEntriesByType('measure');
        measures.length
        """
        
        let count = Int(context.evaluateScript(script).numberValue ?? -1)
        XCTAssertEqual(count, 0, "All measures should be cleared")
    }
    
    func testPerformanceHighResolution() {
        let context = SwiftJS()
        
        let script = """
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
        
        let result = context.evaluateScript(script)
        let allIncreasing = result["allIncreasing"].boolValue ?? false
        let hasFractional = result["hasFractional"].boolValue ?? false
        
        XCTAssertTrue(allIncreasing, "Times should be monotonically increasing")
        XCTAssertTrue(hasFractional, "Should have sub-millisecond precision")
    }
}
