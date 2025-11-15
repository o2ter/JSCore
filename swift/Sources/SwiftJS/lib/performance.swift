//
//  performance.swift
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

import Foundation
import JavaScriptCore
import QuartzCore

@objc protocol JSPerformanceExport: JSExport {
    func now() -> Double
    func mark(_ name: String) -> JSValue
    func measure(_ name: String, _ startMark: String?, _ endMark: String?) -> JSValue
    func getEntriesByType(_ type: String) -> JSValue
    func getEntriesByName(_ name: String, _ type: String?) -> JSValue
    func clearMarks(_ name: String?) -> Void
    func clearMeasures(_ name: String?) -> Void
    func getEntries() -> JSValue
}

@objc final class JSPerformance: NSObject, JSPerformanceExport {
    
    // Store performance entries
    private var marks: [String: Double] = [:]
    private var measures: [String: [String: Any]] = [:]
    private let lock = NSLock()
    
    // Reference time (application start time)
    private static let referenceTime = CACurrentMediaTime()
    
    /// Returns high-resolution timestamp in milliseconds since time origin
    func now() -> Double {
        // Use CACurrentMediaTime for high-resolution timing (microsecond precision)
        // Returns time in seconds, convert to milliseconds
        let currentTime = CACurrentMediaTime()
        return (currentTime - JSPerformance.referenceTime) * 1000.0
    }
    
    /// Create a named timestamp marker
    func mark(_ name: String) -> JSValue {
        guard let context = JSContext.current() else {
            return JSValue(undefinedIn: JSContext())
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        let timestamp = now()
        marks[name] = timestamp
        
        // Return PerformanceMark object
        let entry: [String: Any] = [
            "name": name,
            "entryType": "mark",
            "startTime": timestamp,
            "duration": 0
        ]
        
        return JSValue(object: entry, in: context)
    }
    
    /// Measure duration between two marks
    func measure(_ name: String, _ startMark: String?, _ endMark: String?) -> JSValue {
        guard let context = JSContext.current() else {
            return JSValue(undefinedIn: JSContext())
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        let endTime: Double
        let startTime: Double
        
        // Determine end time
        if let endMarkName = endMark {
            guard let endMarkTime = marks[endMarkName] else {
                return JSValue(
                    newErrorFromMessage: "The mark '\(endMarkName)' does not exist",
                    in: context
                )
            }
            endTime = endMarkTime
        } else {
            endTime = now()
        }
        
        // Determine start time
        if let startMarkName = startMark {
            guard let startMarkTime = marks[startMarkName] else {
                return JSValue(
                    newErrorFromMessage: "The mark '\(startMarkName)' does not exist",
                    in: context
                )
            }
            startTime = startMarkTime
        } else {
            startTime = 0 // Start from time origin
        }
        
        let duration = endTime - startTime
        
        // Store measure
        let entry: [String: Any] = [
            "name": name,
            "entryType": "measure",
            "startTime": startTime,
            "duration": duration
        ]
        
        measures[name] = entry
        
        return JSValue(object: entry, in: context)
    }
    
    /// Get all entries of a specific type
    func getEntriesByType(_ type: String) -> JSValue {
        guard let context = JSContext.current() else {
            return JSValue(undefinedIn: JSContext())
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        var entries: [[String: Any]] = []
        
        if type == "mark" {
            for (name, timestamp) in marks {
                entries.append([
                    "name": name,
                    "entryType": "mark",
                    "startTime": timestamp,
                    "duration": 0
                ])
            }
        } else if type == "measure" {
            entries = Array(measures.values)
        }
        
        // Sort by startTime
        entries.sort { (a, b) in
            let aTime = a["startTime"] as? Double ?? 0
            let bTime = b["startTime"] as? Double ?? 0
            return aTime < bTime
        }
        
        return JSValue(object: entries, in: context)
    }
    
    /// Get all entries with a specific name
    func getEntriesByName(_ name: String, _ type: String?) -> JSValue {
        guard let context = JSContext.current() else {
            return JSValue(undefinedIn: JSContext())
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        var entries: [[String: Any]] = []
        
        // Check marks
        if type == nil || type == "mark" {
            if let timestamp = marks[name] {
                entries.append([
                    "name": name,
                    "entryType": "mark",
                    "startTime": timestamp,
                    "duration": 0
                ])
            }
        }
        
        // Check measures
        if type == nil || type == "measure" {
            if let measure = measures[name] {
                entries.append(measure)
            }
        }
        
        // Sort by startTime
        entries.sort { (a, b) in
            let aTime = a["startTime"] as? Double ?? 0
            let bTime = b["startTime"] as? Double ?? 0
            return aTime < bTime
        }
        
        return JSValue(object: entries, in: context)
    }
    
    /// Get all performance entries
    func getEntries() -> JSValue {
        guard let context = JSContext.current() else {
            return JSValue(undefinedIn: JSContext())
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        var entries: [[String: Any]] = []
        
        // Add all marks
        for (name, timestamp) in marks {
            entries.append([
                "name": name,
                "entryType": "mark",
                "startTime": timestamp,
                "duration": 0
            ])
        }
        
        // Add all measures
        entries.append(contentsOf: Array(measures.values))
        
        // Sort by startTime
        entries.sort { (a, b) in
            let aTime = a["startTime"] as? Double ?? 0
            let bTime = b["startTime"] as? Double ?? 0
            return aTime < bTime
        }
        
        return JSValue(object: entries, in: context)
    }
    
    /// Clear marks
    func clearMarks(_ name: String?) {
        lock.lock()
        defer { lock.unlock() }
        
        if let markName = name {
            marks.removeValue(forKey: markName)
        } else {
            marks.removeAll()
        }
    }
    
    /// Clear measures
    func clearMeasures(_ name: String?) {
        lock.lock()
        defer { lock.unlock() }
        
        if let measureName = name {
            measures.removeValue(forKey: measureName)
        } else {
            measures.removeAll()
        }
    }
}
