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
    
    // Store performance entries - marks can have duplicate names
    private var markEntries: [[String: Any]] = []
    private var measureEntries: [[String: Any]] = []
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
        
        // Store mark entry (can have duplicates)
        let entry: [String: Any] = [
            "name": name,
            "entryType": "mark",
            "startTime": timestamp,
            "duration": 0
        ]
        
        markEntries.append(entry)
        
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
            // Find the most recent mark with this name
            guard let endMarkEntry = markEntries.last(where: { ($0["name"] as? String) == endMarkName }),
                  let endMarkTime = endMarkEntry["startTime"] as? Double else {
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
            // Find the most recent mark with this name
            guard let startMarkEntry = markEntries.last(where: { ($0["name"] as? String) == startMarkName }),
                  let startMarkTime = startMarkEntry["startTime"] as? Double else {
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
        
        measureEntries.append(entry)
        
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
            entries = markEntries
        } else if type == "measure" {
            entries = measureEntries
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
        
        // Handle JavaScript null which gets converted to "null" string by JavaScriptCore
        let entryType = (type == nil || type == "null") ? nil : type
        
        // Check marks
        if entryType == nil || entryType == "mark" {
            let matchingMarks = markEntries.filter { ($0["name"] as? String) == name }
            entries.append(contentsOf: matchingMarks)
        }
        
        // Check measures
        if entryType == nil || entryType == "measure" {
            let matchingMeasures = measureEntries.filter { ($0["name"] as? String) == name }
            entries.append(contentsOf: matchingMeasures)
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
        entries.append(contentsOf: markEntries)
        
        // Add all measures
        entries.append(contentsOf: measureEntries)
        
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
        
        // Handle JavaScript null which gets converted to "null" string by JavaScriptCore
        if let markName = name, markName != "null" {
            markEntries.removeAll { ($0["name"] as? String) == markName }
        } else {
            markEntries.removeAll()
        }
    }
    
    /// Clear measures
    func clearMeasures(_ name: String?) {
        lock.lock()
        defer { lock.unlock() }
        
        // Handle JavaScript null which gets converted to "null" string by JavaScriptCore
        if let measureName = name, measureName != "null" {
            measureEntries.removeAll { ($0["name"] as? String) == measureName }
        } else {
            measureEntries.removeAll()
        }
    }
}
