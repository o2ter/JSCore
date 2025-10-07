//
//  processInfo.swift
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

import JavaScriptCore
import Foundation

@objc protocol JSProcessInfoExport: JSExport {
    var environment: [String: String] { get }
    var arguments: [String] { get }
    var processName: String { get }
    var processIdentifier: Int32 { get }
    var globallyUniqueString: String { get }
    var hostName: String { get }
    var platform: String { get }
    var arch: String { get }
    var isLowPowerModeEnabled: Bool { get }
    var deviceSpec: String { get }
    var isRealDevice: Bool { get }
    var isMacCatalystApp: Bool { get }
    var isiOSAppOnMac: Bool { get }
    var operatingSystemVersionString: String { get }
    var operatingSystemVersion: [String: Int] { get }
    var physicalMemory: UInt64 { get }
    var processorCount: Int { get }
    var activeProcessorCount: Int { get }
    var systemUptime: TimeInterval { get }
    var thermalState: ProcessInfo.ThermalState { get }
}

@objc final class JSProcessInfo: NSObject, JSProcessInfoExport {
}

extension JSProcessInfo {
    
    var environment: [String: String] {
        return ProcessInfo.processInfo.environment
    }

    var arguments: [String] {
        return ProcessInfo.processInfo.arguments
    }

    var processName: String {
        return ProcessInfo.processInfo.processName
    }

    var processIdentifier: Int32 {
        return ProcessInfo.processInfo.processIdentifier
    }

    var globallyUniqueString: String {
        return ProcessInfo.processInfo.globallyUniqueString
    }

    var hostName: String {
        return ProcessInfo.processInfo.hostName
    }

    var platform: String {
        // Use Foundation's ProcessInfo to get OS name in a POSIX-compliant way
        let osName = ProcessInfo.processInfo.operatingSystemVersionString.lowercased()
        
        #if os(macOS)
            return "darwin"
        #elseif os(iOS)
            return "ios"
        #elseif os(tvOS)
            return "tvos"
        #elseif os(watchOS)
            return "watchos"
        #elseif os(Linux)
            return "linux"
        #elseif os(Windows)
            return "win32"
        #else
            // Fallback: try to detect from OS name string
            if osName.contains("darwin") || osName.contains("mac") {
                return "darwin"
            } else if osName.contains("linux") {
                return "linux"
            } else if osName.contains("windows") {
                return "win32"
            } else {
                return "unknown"
            }
        #endif
    }

    var arch: String {
        #if arch(arm64)
            return "arm64"
        #elseif arch(x86_64)
            return "x64"
        #elseif arch(i386)
            return "ia32"
        #elseif arch(arm)
            return "arm"
        #else
            return "unknown"
        #endif
    }

    var isLowPowerModeEnabled: Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var deviceSpec: String {
        return "apple"
    }

    var isRealDevice: Bool {
        #if targetEnvironment(simulator)
            return false
        #else
            return true
        #endif
    }

    var isMacCatalystApp: Bool {
        return ProcessInfo.processInfo.isMacCatalystApp
    }

    var isiOSAppOnMac: Bool {
        return ProcessInfo.processInfo.isiOSAppOnMac
    }

    var operatingSystemVersionString: String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    var operatingSystemVersion: [String: Int] {
        let operatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        return [
            "majorVersion": operatingSystemVersion.majorVersion,
            "minorVersion": operatingSystemVersion.minorVersion,
            "patchVersion": operatingSystemVersion.patchVersion,
        ]
    }

    var physicalMemory: UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }

    var processorCount: Int {
        return ProcessInfo.processInfo.processorCount
    }

    var activeProcessorCount: Int {
        return ProcessInfo.processInfo.activeProcessorCount
    }

    var systemUptime: TimeInterval {
        return ProcessInfo.processInfo.systemUptime
    }

    var thermalState: ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }
}
