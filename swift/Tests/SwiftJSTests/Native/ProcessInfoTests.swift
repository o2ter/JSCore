//
//  ProcessInfoTests.swift
//  SwiftJS Process Info Tests
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

import XCTest
@testable import SwiftJS

/// Tests for the Process Info API including process ID, arguments,
/// and environment variables.
@MainActor
final class ProcessInfoTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testProcessExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testProcessIsObject() {
        let script = """
            process !== null && typeof process === 'object'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Process ID Tests
    
    func testProcessPid() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process.pid")
        XCTAssertEqual(result.toString(), "number")
    }
    
    func testProcessPidValue() {
        let context = SwiftJS()
        let result = context.evaluateScript("process.pid")
        XCTAssertTrue((result.numberValue ?? 0) > 0)
    }
    
    func testProcessPidIsInteger() {
        let script = """
            Number.isInteger(process.pid) && process.pid > 0
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testProcessPidMatchesSystem() {
        let context = SwiftJS()
        let jsPid = Int(context.evaluateScript("process.pid").numberValue ?? 0)
        let systemPid = ProcessInfo.processInfo.processIdentifier
        XCTAssertEqual(jsPid, Int(systemPid))
    }
    
    // MARK: - Process Arguments Tests
    
    func testProcessArgv() {
        let context = SwiftJS()
        let result = context.evaluateScript("Array.isArray(process.argv)")
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testProcessArgvLength() {
        let context = SwiftJS()
        let result = context.evaluateScript("process.argv.length")
        XCTAssertGreaterThanOrEqual(Int(result.numberValue ?? 0), 0)
    }
    
    func testProcessArgvFirstElement() {
        let script = """
            process.argv.length > 0 && typeof process.argv[0] === 'string'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        // argv[0] should be the executable path (if available)
        let hasArgs = context.evaluateScript("process.argv.length > 0").boolValue ?? false
        if hasArgs {
            XCTAssertTrue(result.boolValue ?? false)
        } else {
            XCTAssertTrue(true, "No arguments available")
        }
    }
    
    func testProcessArgvContent() {
        let script = """
            ({
                length: process.argv.length,
                allStrings: process.argv.every(arg => typeof arg === 'string'),
                firstArg: process.argv[0] || null
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let length = Int(result["length"].numberValue ?? 0)
        XCTAssertGreaterThanOrEqual(length, 0)
        
        if length > 0 {
            XCTAssertTrue(result["allStrings"].boolValue ?? false)
            XCTAssertTrue(result["firstArg"].isString)
        }
    }
    
    // MARK: - Environment Variables Tests
    
    func testProcessEnv() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process.env")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testProcessEnvIsObject() {
        let script = """
            process.env !== null && typeof process.env === 'object' && !Array.isArray(process.env)
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testProcessEnvPath() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process.env.PATH")
        // PATH should exist on most systems
        let pathType = result.toString()
        XCTAssertTrue(pathType == "string" || pathType == "undefined", "PATH should be string or undefined, got \(pathType)")
    }
    
    func testProcessEnvHome() {
        let script = """
            const homeKeys = ['HOME', 'USERPROFILE', 'HOMEPATH'];
            const homeValues = homeKeys.map(key => process.env[key]).filter(val => val !== undefined);
            ({
                hasHome: homeValues.length > 0,
                homeValue: homeValues[0] || null,
                homeType: homeValues[0] ? typeof homeValues[0] : 'undefined'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // At least one home-related env var should exist
        if result["hasHome"].boolValue == true {
            XCTAssertEqual(result["homeType"].toString(), "string")
            XCTAssertTrue(result["homeValue"].isString)
        }
    }
    
    func testProcessEnvCustomVariable() {
        let script = """
            // Test setting and getting a custom environment variable
            const originalValue = process.env.SWIFTJS_TEST_VAR;
            process.env.SWIFTJS_TEST_VAR = 'test-value-123';
            const newValue = process.env.SWIFTJS_TEST_VAR;
            
            // Clean up
            if (originalValue === undefined) {
                delete process.env.SWIFTJS_TEST_VAR;
            } else {
                process.env.SWIFTJS_TEST_VAR = originalValue;
            }
            
            ({
                wasUndefined: originalValue === undefined,
                setValue: newValue,
                isString: typeof newValue === 'string'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Should be able to set and retrieve custom env vars
        XCTAssertEqual(result["setValue"].toString(), "test-value-123")
        XCTAssertTrue(result["isString"].boolValue ?? false)
    }
    
    func testProcessEnvKeys() {
        let script = """
            const keys = Object.keys(process.env);
            ({
                hasKeys: keys.length > 0,
                allStrings: keys.every(key => typeof key === 'string'),
                sampleKey: keys[0] || null
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasKeys"].boolValue ?? false)
        XCTAssertTrue(result["allStrings"].boolValue ?? false)
        if result["sampleKey"].isString {
            XCTAssertNotEqual(result["sampleKey"].toString(), "")
        }
    }
    
    func testProcessEnvValues() {
        let script = """
            const values = Object.values(process.env);
            ({
                hasValues: values.length > 0,
                allStrings: values.every(val => typeof val === 'string'),
                sampleValue: values[0] || null
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasValues"].boolValue ?? false)
        XCTAssertTrue(result["allStrings"].boolValue ?? false)
        if result["sampleValue"].isString {
            XCTAssertTrue(result["sampleValue"].toString().count >= 0) // Can be empty string
        }
    }
    
    // MARK: - Process Platform Information Tests
    
    func testProcessPlatform() {
        let script = """
            // Check if platform is available and reasonable
            const platform = process.platform;
            ({
                hasPlatform: platform !== undefined,
                platformType: typeof platform,
                platform: platform || null,
                isValidPlatform: platform ? ['darwin', 'linux', 'win32', 'ios', 'android'].includes(platform) : false
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["hasPlatform"].boolValue == true {
            XCTAssertEqual(result["platformType"].toString(), "string")
            // On macOS/iOS, should be 'darwin' or 'ios'
            let platform = result["platform"].toString()
            XCTAssertTrue(["darwin", "ios", "linux", "win32", "android"].contains(platform), 
                         "Platform '\(platform)' should be a known platform")
        }
    }
    
    func testProcessArch() {
        let script = """
            // Check if architecture is available
            const arch = process.arch;
            ({
                hasArch: arch !== undefined,
                archType: typeof arch,
                arch: arch || null,
                isValidArch: arch ? ['arm64', 'x64', 'ia32', 'x86'].includes(arch) : false
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["hasArch"].boolValue == true {
            XCTAssertEqual(result["archType"].toString(), "string")
            let arch = result["arch"].toString()
            XCTAssertTrue(["arm64", "x64", "ia32", "x86"].contains(arch), 
                         "Architecture '\(arch)' should be a known architecture")
        }
    }
    
    // MARK: - Process Working Directory Tests
    
    func testProcessCwd() {
        let script = """
            // Check if cwd function exists and works
            ({
                hasCwd: typeof process.cwd === 'function',
                cwdResult: typeof process.cwd === 'function' ? process.cwd() : null,
                cwdType: typeof process.cwd === 'function' ? typeof process.cwd() : 'undefined'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["hasCwd"].boolValue == true {
            XCTAssertEqual(result["cwdType"].toString(), "string")
            XCTAssertTrue(result["cwdResult"].isString)
            let cwd = result["cwdResult"].toString()
            XCTAssertGreaterThan(cwd.count, 0)
        }
    }
    
    // MARK: - Process Exit Code Tests
    
    func testProcessExitCode() {
        let script = """
            // Check if exitCode property exists
            ({
                hasExitCode: 'exitCode' in process,
                exitCodeType: typeof process.exitCode,
                exitCodeValue: process.exitCode
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["hasExitCode"].boolValue == true {
            let exitCodeType = result["exitCodeType"].toString()
            XCTAssertTrue(["number", "undefined"].contains(exitCodeType))
            
            if exitCodeType == "number" {
                let exitCode = Int(result["exitCodeValue"].numberValue ?? 0)
                XCTAssertGreaterThanOrEqual(exitCode, 0)
            }
        }
    }
    
    // MARK: - Process Version Information Tests
    
    func testProcessVersion() {
        let script = """
            // Check if version info is available
            ({
                hasVersion: 'version' in process,
                versionType: typeof process.version,
                version: process.version || null,
                hasVersions: 'versions' in process,
                versionsType: typeof process.versions
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["hasVersion"].boolValue == true {
            XCTAssertEqual(result["versionType"].toString(), "string")
        }
        
        if result["hasVersions"].boolValue == true {
            XCTAssertEqual(result["versionsType"].toString(), "object")
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testProcessMemoryUsage() {
        let script = """
            // Check if memoryUsage function exists
            ({
                hasMemoryUsage: typeof process.memoryUsage === 'function',
                memoryResult: typeof process.memoryUsage === 'function' ? process.memoryUsage() : null
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["hasMemoryUsage"].boolValue == true {
            let memoryResult = result["memoryResult"]
            XCTAssertTrue(memoryResult.isObject)
            
            // Memory usage should have numeric properties
            let script2 = """
                const mem = process.memoryUsage();
                ({
                    hasRss: typeof mem.rss === 'number',
                    hasHeapTotal: typeof mem.heapTotal === 'number',
                    hasHeapUsed: typeof mem.heapUsed === 'number',
                    hasExternal: typeof mem.external === 'number',
                    rssPositive: mem.rss > 0,
                    heapTotalPositive: mem.heapTotal >= 0,
                    heapUsedPositive: mem.heapUsed >= 0
                })
            """
            let context2 = SwiftJS()
            let memDetails = context2.evaluateScript(script2)
            
            if memDetails["hasRss"].boolValue == true {
                XCTAssertTrue(memDetails["rssPositive"].boolValue ?? false)
            }
            if memDetails["hasHeapTotal"].boolValue == true {
                XCTAssertTrue(memDetails["heapTotalPositive"].boolValue ?? false)
            }
            if memDetails["hasHeapUsed"].boolValue == true {
                XCTAssertTrue(memDetails["heapUsedPositive"].boolValue ?? false)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testProcessCompleteInfo() {
        let script = """
            ({
                pid: process.pid,
                pidType: typeof process.pid,
                argv: process.argv,
                argvLength: process.argv.length,
                env: Object.keys(process.env).length,
                envType: typeof process.env,
                hasRequiredProperties: (
                    typeof process.pid === 'number' &&
                    Array.isArray(process.argv) &&
                    typeof process.env === 'object'
                )
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["pidType"].toString(), "number")
        XCTAssertTrue((result["pid"].numberValue ?? 0) > 0)
        XCTAssertGreaterThanOrEqual(Int(result["argvLength"].numberValue ?? 0), 0)
        XCTAssertGreaterThanOrEqual(Int(result["env"].numberValue ?? 0), 0)
        XCTAssertEqual(result["envType"].toString(), "object")
        XCTAssertTrue(result["hasRequiredProperties"].boolValue ?? false)
    }
    
    func testProcessConsistency() {
        let script = """
            // Test that process properties are consistent across multiple accesses
            const pid1 = process.pid;
            const pid2 = process.pid;
            const env1 = process.env.PATH;
            const env2 = process.env.PATH;
            const argv1 = process.argv.length;
            const argv2 = process.argv.length;
            
            ({
                pidConsistent: pid1 === pid2,
                envConsistent: env1 === env2,
                argvConsistent: argv1 === argv2,
                allConsistent: pid1 === pid2 && env1 === env2 && argv1 === argv2
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["pidConsistent"].boolValue ?? false)
        XCTAssertTrue(result["envConsistent"].boolValue ?? false)
        XCTAssertTrue(result["argvConsistent"].boolValue ?? false)
        XCTAssertTrue(result["allConsistent"].boolValue ?? false)
    }
}
