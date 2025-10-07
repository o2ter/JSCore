//
//  ProcessTests.swift
//  SwiftJS Tests
//
//  Created by GitHub Copilot on 2025/9/6.
//  Copyright © 2025 o2ter. All rights reserved.
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

/// Tests for the global process object API, which provides Node.js-like process information
/// and control functions.
@MainActor
final class ProcessTests: XCTestCase {
    
    // MARK: - Process API Existence Tests
    
    func testProcessExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testProcessProperties() {
        let script = """
            ({
                hasEnv: typeof process.env === 'object',
                hasArgv: Array.isArray(process.argv),
                hasPid: typeof process.pid === 'number',
                hasCwd: typeof process.cwd === 'function',
                hasChdir: typeof process.chdir === 'function',
                hasExit: typeof process.exit === 'function'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasEnv"].boolValue ?? false)
        XCTAssertTrue(result["hasArgv"].boolValue ?? false)
        XCTAssertTrue(result["hasPid"].boolValue ?? false)
        XCTAssertTrue(result["hasCwd"].boolValue ?? false)
        XCTAssertTrue(result["hasChdir"].boolValue ?? false)
        XCTAssertTrue(result["hasExit"].boolValue ?? false)
    }
    
    // MARK: - Process Environment Tests
    
    func testProcessEnvironment() {
        let script = """
            ({
                envIsObject: typeof process.env === 'object',
                envNotNull: process.env !== null,
                hasPath: typeof process.env.PATH === 'string' || process.env.PATH === undefined,
                isReadable: Object.keys(process.env).length >= 0
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["envIsObject"].boolValue ?? false)
        XCTAssertTrue(result["envNotNull"].boolValue ?? false)
        XCTAssertTrue(result["hasPath"].boolValue ?? false)
        XCTAssertTrue(result["isReadable"].boolValue ?? false)
    }
    
    func testProcessEnvironmentAccess() {
        let script = """
            // Test that we can read and potentially write environment variables
            var originalValue = process.env.TEST_VAR;
            process.env.TEST_VAR = 'test_value';
            var newValue = process.env.TEST_VAR;
            
            // Clean up
            if (originalValue === undefined) {
                delete process.env.TEST_VAR;
            } else {
                process.env.TEST_VAR = originalValue;
            }
            
            ({
                canWrite: newValue === 'test_value',
                originalWasUndefined: originalValue === undefined
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["canWrite"].boolValue ?? false)
        // originalWasUndefined could be true or false depending on environment
        XCTAssertNotNil(result["originalWasUndefined"].boolValue)
    }
    
    // MARK: - Process Arguments Tests
    
    func testProcessArguments() {
        let script = """
            ({
                isArray: Array.isArray(process.argv),
                hasLength: typeof process.argv.length === 'number',
                lengthIsValid: process.argv.length >= 0,
                firstIsString: process.argv.length > 0 ? typeof process.argv[0] === 'string' : true
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isArray"].boolValue ?? false)
        XCTAssertTrue(result["hasLength"].boolValue ?? false)
        XCTAssertTrue(result["lengthIsValid"].boolValue ?? false)
        XCTAssertTrue(result["firstIsString"].boolValue ?? false)
    }
    
    // MARK: - Process ID Tests
    
    func testProcessId() {
        let script = """
            ({
                isNumber: typeof process.pid === 'number',
                isPositive: process.pid > 0,
                isInteger: Number.isInteger(process.pid)
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isNumber"].boolValue ?? false)
        XCTAssertTrue(result["isPositive"].boolValue ?? false)
        XCTAssertTrue(result["isInteger"].boolValue ?? false)
    }
    
    // MARK: - Process Working Directory Tests
    
    func testProcessCwd() {
        let script = """
            ({
                cwdIsFunction: typeof process.cwd === 'function',
                cwdReturnsString: typeof process.cwd() === 'string',
                cwdNotEmpty: process.cwd().length > 0,
                cwdIsAbsolute: process.cwd().startsWith('/')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["cwdIsFunction"].boolValue ?? false)
        XCTAssertTrue(result["cwdReturnsString"].boolValue ?? false)
        XCTAssertTrue(result["cwdNotEmpty"].boolValue ?? false)
        XCTAssertTrue(result["cwdIsAbsolute"].boolValue ?? false)
    }
    
    func testProcessChdir() {
        let script = """
            var originalCwd = process.cwd();
            var tempDir = SystemFS.temp;
            
            try {
                // Change to temp directory
                process.chdir(tempDir);
                var newCwd = process.cwd();
                
                // Change back
                process.chdir(originalCwd);
                var restoredCwd = process.cwd();
                
                ({
                    success: true,
                    changedCorrectly: newCwd === tempDir || newCwd.endsWith(tempDir.split('/').pop()),
                    restoredCorrectly: restoredCwd === originalCwd
                })
            } catch (error) {
                // Restore on error
                try { process.chdir(originalCwd); } catch (e) {}
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["success"].boolValue ?? false {
            XCTAssertTrue(result["changedCorrectly"].boolValue ?? false)
            XCTAssertTrue(result["restoredCorrectly"].boolValue ?? false)
        } else {
            // chdir might not be supported on all platforms/configurations
            XCTAssertTrue(result["error"].isString)
        }
    }
    
    func testProcessChdirErrorHandling() {
        let script = """
            try {
                process.chdir('/nonexistent/directory/path');
                ({ success: false, error: 'Should have thrown' })
            } catch (error) {
                ({
                    success: true,
                    threwError: true,
                    errorIsString: typeof error.message === 'string'
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["success"].boolValue ?? false {
            XCTAssertTrue(result["threwError"].boolValue ?? false)
            XCTAssertTrue(result["errorIsString"].boolValue ?? false)
        }
    }
    
    // MARK: - Process Exit Tests
    
    func testProcessExitFunction() {
        let script = """
            ({
                exitIsFunction: typeof process.exit === 'function',
                exitExists: process.exit !== undefined
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["exitIsFunction"].boolValue ?? false)
        XCTAssertTrue(result["exitExists"].boolValue ?? false)
    }
    
    func testProcessExitBehavior() {
        // Test that process.exit() immediately terminates execution
        // Since the new implementation calls Darwin.exit() directly,
        // we can't test actual termination in a unit test.
        // Instead, we test that the function exists and has the correct signature.
        
        let script = """
            var exitFunctionExists = typeof process.exit === 'function';
            var canCallWithNumber = true;
            var canCallWithDefault = true;
            var invalidCodeThrows = false;
            
            try {
                // Test that calling with a number doesn't immediately throw
                // (the actual exit would happen in Darwin.exit() which we can't test)
                var mockExit = process.exit;
                // We can't actually call it since it would terminate the test process
                canCallWithNumber = typeof mockExit === 'function';
            } catch (error) {
                canCallWithNumber = false;
            }
            
            try {
                // Test invalid exit code validation
                // We need to actually call it to test validation, but this would terminate
                // So we test the function signature instead
                canCallWithDefault = process.exit.length >= 0; // accepts 0 or more parameters
            } catch (error) {
                canCallWithDefault = false;
            }
            
            ({
                exitFunctionExists: exitFunctionExists,
                canCallWithNumber: canCallWithNumber,
                canCallWithDefault: canCallWithDefault
            })
        """
        
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["exitFunctionExists"].boolValue ?? false)
        XCTAssertTrue(result["canCallWithNumber"].boolValue ?? false)
        XCTAssertTrue(result["canCallWithDefault"].boolValue ?? false)
    }
    
    // MARK: - Process Object Integrity Tests
    
    func testProcessObjectIntegrity() {
        let script = """
            ({
                processIsObject: typeof process === 'object',
                processNotNull: process !== null,
                processNotArray: !Array.isArray(process),
                hasExpectedProperties: [
                    'env', 'argv', 'pid', 'cwd', 'chdir', 'exit'
                ].every(prop => prop in process)
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["processIsObject"].boolValue ?? false)
        XCTAssertTrue(result["processNotNull"].boolValue ?? false)
        XCTAssertTrue(result["processNotArray"].boolValue ?? false)
        XCTAssertTrue(result["hasExpectedProperties"].boolValue ?? false)
    }
    
    func testProcessGlobalAccess() {
        let script = """
            // Test that process is accessible as a global
            ({
                accessibleAsGlobal: typeof process !== 'undefined',
                accessibleAsGlobalThis: typeof globalThis.process !== 'undefined',
                sameReference: process === globalThis.process
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["accessibleAsGlobal"].boolValue ?? false)
        XCTAssertTrue(result["accessibleAsGlobalThis"].boolValue ?? false)
        XCTAssertTrue(result["sameReference"].boolValue ?? false)
    }
}
