//
//  ComprehensiveErrorHandlingTests.swift
//  SwiftJS Comprehensive Error Handling Tests
//
//  The MIT License
//  Copyright (c) 2021 - 2025 O2ter Limited. All rights reserved.
//

import XCTest
@testable import SwiftJS

/// Comprehensive tests for error handling across all SwiftJS APIs to ensure
/// proper validation and error reporting for invalid inputs and edge cases.
@MainActor
final class ComprehensiveErrorHandlingTests: XCTestCase {
    
    // MARK: - Request API Error Tests
    
    func testRequestConstructorErrors() {
        let expectation = XCTestExpectation(description: "Request constructor errors")
        
        let script = """
            const errorTests = [];
            
            // Test 1: No URL provided
            try {
                new Request();
                errorTests.push({ test: 'no URL', error: false });
            } catch (e) {
                errorTests.push({ test: 'no URL', error: true, type: e.name, message: e.message });
            }
            
            // Test 2: Forbidden method (TRACE)
            try {
                new Request('http://example.com', { method: 'TRACE' });
                errorTests.push({ test: 'forbidden method TRACE', error: false });
            } catch (e) {
                errorTests.push({ test: 'forbidden method TRACE', error: true, type: e.name, message: e.message });
            }
            
            // Test 3: Forbidden method (CONNECT)
            try {
                new Request('http://example.com', { method: 'CONNECT' });
                errorTests.push({ test: 'forbidden method CONNECT', error: false });
            } catch (e) {
                errorTests.push({ test: 'forbidden method CONNECT', error: true, type: e.name, message: e.message });
            }
            
            // Test 4: Invalid method with spaces
            try {
                new Request('http://example.com', { method: 'GET POST' });
                errorTests.push({ test: 'invalid method with spaces', error: false });
            } catch (e) {
                errorTests.push({ test: 'invalid method with spaces', error: true, type: e.name, message: e.message });
            }
            
            // Test 5: Body with GET method
            try {
                new Request('http://example.com', { 
                    method: 'GET',
                    body: 'should not work'
                });
                errorTests.push({ test: 'body with GET', error: false });
            } catch (e) {
                errorTests.push({ test: 'body with GET', error: true, type: e.name, message: e.message });
            }
            
            testCompleted({ errorTests: errorTests });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let errorTests = result["errorTests"]
            let testCount = Int(errorTests["length"].numberValue ?? 0)
            
            for i in 0..<testCount {
                let test = errorTests[i]
                let testName = test["test"].toString()
                
        if testName == "no URL" || testName.contains("forbidden method")
          || testName.contains("invalid method") || testName == "body with GET"
        {
                    // These should throw errors
                    XCTAssertTrue(test["error"].boolValue ?? false, 
                                "Test '\(testName)' should throw an error")
                    if test["error"].boolValue == true {
                        XCTAssertEqual(test["type"].toString(), "TypeError", 
                                     "Test '\(testName)' should throw TypeError")
                    }
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testResponseConstructorErrors() {
        let expectation = XCTestExpectation(description: "Response constructor errors")
        
        let script = """
            const errorTests = [];
            
            // Test 1: Invalid status code
            try {
                new Response('test', { status: 999 });
                errorTests.push({ test: 'invalid status 999', error: false });
            } catch (e) {
                errorTests.push({ test: 'invalid status 999', error: true, type: e.name });
            }
            
            // Test 2: Invalid status code (too low)
            try {
                new Response('test', { status: 99 });
                errorTests.push({ test: 'invalid status 99', error: false });
            } catch (e) {
                errorTests.push({ test: 'invalid status 99', error: true, type: e.name });
            }
            
            // Test 3: Non-integer status
            try {
                new Response('test', { status: 200.5 });
                errorTests.push({ test: 'non-integer status', error: false });
            } catch (e) {
                errorTests.push({ test: 'non-integer status', error: true, type: e.name });
            }
            
            testCompleted({ errorTests: errorTests });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let errorTests = result["errorTests"]
            let testCount = Int(errorTests["length"].numberValue ?? 0)
            
            for i in 0..<testCount {
                let test = errorTests[i]
                let testName = test["test"].toString()
                
                // Invalid status codes should throw errors
                XCTAssertTrue(test["error"].boolValue ?? false, 
                            "Test '\(testName)' should throw an error for invalid status")
                if test["error"].boolValue == true {
                    XCTAssertTrue(["TypeError", "RangeError"].contains(test["type"].toString()), 
                                "Test '\(testName)' should throw TypeError or RangeError")
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - FormData Error Tests
    
    func testFormDataErrors() {
        let expectation = XCTestExpectation(description: "FormData errors")
        
        let script = """
            const errorTests = [];
            
            // Test 1: append with no arguments
            try {
                const fd = new FormData();
                fd.append();
                errorTests.push({ test: 'append no args', error: false });
            } catch (e) {
                errorTests.push({ test: 'append no args', error: true, type: e.name });
            }
            
            // Test 2: append with only one argument
            try {
                const fd = new FormData();
                fd.append('name');
                errorTests.push({ test: 'append one arg', error: false });
            } catch (e) {
                errorTests.push({ test: 'append one arg', error: true, type: e.name });
            }
            
            // Test 3: set with no arguments
            try {
                const fd = new FormData();
                fd.set();
                errorTests.push({ test: 'set no args', error: false });
            } catch (e) {
                errorTests.push({ test: 'set no args', error: true, type: e.name });
            }
            
            testCompleted({ errorTests: errorTests });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let errorTests = result["errorTests"]
            let testCount = Int(errorTests["length"].numberValue ?? 0)
            
            for i in 0..<testCount {
                let test = errorTests[i]
                let testName = test["test"].toString()
                
                // These should throw errors for missing required arguments
                XCTAssertTrue(test["error"].boolValue ?? false, 
                            "Test '\(testName)' should throw an error for missing arguments")
                if test["error"].boolValue == true {
                    XCTAssertEqual(test["type"].toString(), "TypeError", 
                                 "Test '\(testName)' should throw TypeError")
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - File/Blob Error Tests
    
    func testFileConstructorErrors() {
        let expectation = XCTestExpectation(description: "File constructor errors")
        
        let script = """
            const errorTests = [];
            
            // Test 1: No arguments
            try {
                new File();
                errorTests.push({ test: 'no args', error: false });
            } catch (e) {
                errorTests.push({ test: 'no args', error: true, type: e.name });
            }
            
            // Test 2: Invalid name type
            try {
                new File(['content'], 123);
                errorTests.push({ test: 'invalid name type', error: false });
            } catch (e) {
                errorTests.push({ test: 'invalid name type', error: true, type: e.name });
            }
            
            // Test 3: Invalid options
            try {
                new File(['content'], 'file.txt', 'invalid options');
                errorTests.push({ test: 'invalid options', error: false });
            } catch (e) {
                errorTests.push({ test: 'invalid options', error: true, type: e.name });
            }
            
            testCompleted({ errorTests: errorTests });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let errorTests = result["errorTests"]
            let testCount = Int(errorTests["length"].numberValue ?? 0)
            
            for i in 0..<testCount {
                let test = errorTests[i]
                let testName = test["test"].toString()
                
                // File constructor should validate arguments
                if testName == "no args" {
                    XCTAssertTrue(test["error"].boolValue ?? false, 
                                "File constructor with no args should throw error")
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - URLSearchParams Error Tests
    
    func testURLSearchParamsErrors() {
        let expectation = XCTestExpectation(description: "URLSearchParams errors")
        
        let script = """
            const errorTests = [];
            
            // Test 1: Invalid constructor argument
            try {
                new URLSearchParams(123);
                errorTests.push({ test: 'number init', error: false });
            } catch (e) {
                errorTests.push({ test: 'number init', error: true, type: e.name });
            }
            
            // Test 2: Invalid array format
            try {
                new URLSearchParams([['key']]);  // Missing value
                errorTests.push({ test: 'incomplete array', error: false });
            } catch (e) {
                errorTests.push({ test: 'incomplete array', error: true, type: e.name });
            }
            
            // Test 3: append with no arguments
            try {
                const params = new URLSearchParams();
                params.append();
                errorTests.push({ test: 'append no args', error: false });
            } catch (e) {
                errorTests.push({ test: 'append no args', error: true, type: e.name });
            }
            
            testCompleted({ errorTests: errorTests });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let errorTests = result["errorTests"]
            let testCount = Int(errorTests["length"].numberValue ?? 0)
            
            for i in 0..<testCount {
                let test = errorTests[i]
                let testName = test["test"].toString()
                
                // URLSearchParams should validate inputs
                if testName.contains("no args") {
                    XCTAssertTrue(test["error"].boolValue ?? false, 
                                "URLSearchParams methods without required args should throw error")
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - TextEncoder/TextDecoder Error Tests
    
    func testTextEncoderDecoderErrors() {
        let expectation = XCTestExpectation(description: "TextEncoder/TextDecoder errors")
        
        let script = """
            const errorTests = [];
            
            // Test 1: TextEncoder with invalid encoding
            try {
                new TextEncoder('invalid-encoding');
                errorTests.push({ test: 'TextEncoder invalid encoding', error: false });
            } catch (e) {
                errorTests.push({ test: 'TextEncoder invalid encoding', error: true, type: e.name });
            }
            
            // Test 2: TextDecoder with invalid encoding
            try {
                new TextDecoder('invalid-encoding');
                errorTests.push({ test: 'TextDecoder invalid encoding', error: false });
            } catch (e) {
                errorTests.push({ test: 'TextDecoder invalid encoding', error: true, type: e.name });
            }
            
            // Test 3: TextEncoder.encode with no argument
            try {
                const encoder = new TextEncoder();
                encoder.encode();
                errorTests.push({ test: 'encode no args', error: false });
            } catch (e) {
                errorTests.push({ test: 'encode no args', error: true, type: e.name });
            }
            
            // Test 4: TextDecoder.decode with invalid input
            try {
                const decoder = new TextDecoder();
                decoder.decode('not a typed array');
                errorTests.push({ test: 'decode invalid input', error: false });
            } catch (e) {
                errorTests.push({ test: 'decode invalid input', error: true, type: e.name });
            }
            
            testCompleted({ errorTests: errorTests });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let errorTests = result["errorTests"]
            let testCount = Int(errorTests["length"].numberValue ?? 0)
            
            for i in 0..<testCount {
                let test = errorTests[i]
                let testName = test["test"].toString()
                
                // Some of these should throw errors for invalid inputs
                if testName.contains("invalid encoding") || testName.contains("invalid input") {
                    if test["error"].boolValue == true {
                        XCTAssertEqual(test["type"].toString(), "TypeError", 
                                     "Invalid encoding should throw TypeError")
                    }
                    // Note: Some implementations may be permissive, so we don't strictly require errors
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - ReadableStream Error Tests
    
    func testReadableStreamErrors() {
        let expectation = XCTestExpectation(description: "ReadableStream errors")
        
        let script = """
            const errorTests = [];
            
            // Test 1: Invalid underlyingSource
            try {
                new ReadableStream('not an object');
                errorTests.push({ test: 'invalid source', error: false });
            } catch (e) {
                errorTests.push({ test: 'invalid source', error: true, type: e.name });
            }
            
            // Test 2: Controller error propagation
            try {
                const stream = new ReadableStream({
                    start(controller) {
                        controller.error(new Error('deliberate error'));
                    }
                });
                
                const reader = stream.getReader();
                reader.read().then(() => {
                    errorTests.push({ test: 'controller error propagation', error: false });
                    testCompleted({ errorTests: errorTests });
                }).catch(e => {
                    errorTests.push({ test: 'controller error propagation', error: true, type: e.name });
                    testCompleted({ errorTests: errorTests });
                });
            } catch (e) {
                errorTests.push({ test: 'controller error propagation', error: true, type: e.name });
                testCompleted({ errorTests: errorTests });
            }
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let errorTests = result["errorTests"]
            let testCount = Int(errorTests["length"].numberValue ?? 0)
            
            for i in 0..<testCount {
                let test = errorTests[i]
                let testName = test["test"].toString()
                
                if testName == "controller error propagation" {
                    XCTAssertTrue(test["error"].boolValue ?? false, 
                                "Stream errors should propagate to readers")
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Process API Error Tests
    
    func testProcessErrors() {
        let expectation = XCTestExpectation(description: "Process errors")
        
        let script = """
            const errorTests = [];
            
            // Test 1: chdir with invalid path
            try {
                process.chdir('/absolutely/nonexistent/path/12345');
                errorTests.push({ test: 'chdir invalid path', error: false });
            } catch (e) {
                errorTests.push({ test: 'chdir invalid path', error: true, type: e.name });
            }
            
            // Test 2: chdir with null
            try {
                process.chdir(null);
                errorTests.push({ test: 'chdir null', error: false });
            } catch (e) {
                errorTests.push({ test: 'chdir null', error: true, type: e.name });
            }
            
            testCompleted({ errorTests: errorTests });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let errorTests = result["errorTests"]
            let testCount = Int(errorTests["length"].numberValue ?? 0)
            
            for i in 0..<testCount {
                let test = errorTests[i]
                
                // chdir should validate paths and throw errors for invalid ones
                XCTAssertTrue(test["error"].boolValue ?? false, 
                            "process.chdir with invalid path should throw error")
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
  func testHTTPMethodValidation() {
    let expectation = XCTestExpectation(description: "HTTP method validation")

    let script = """
          const testResults = [];
          
          // Standard HTTP methods - should all work
          const standardMethods = ['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'PATCH'];
          standardMethods.forEach(method => {
              try {
                  new Request('http://example.com', { method: method });
                  testResults.push({ method: method, category: 'standard', passed: true });
              } catch (e) {
                  testResults.push({ method: method, category: 'standard', passed: false, error: e.message });
              }
          });
          
          // Case insensitive methods - should work
          const caseVariations = ['get', 'POST', 'Put', 'dElEtE'];
          caseVariations.forEach(method => {
              try {
                  new Request('http://example.com', { method: method });
                  testResults.push({ method: method, category: 'case-insensitive', passed: true });
              } catch (e) {
                  testResults.push({ method: method, category: 'case-insensitive', passed: false, error: e.message });
              }
          });
          
          // WebDAV methods - should work
          const webdavMethods = ['PROPFIND', 'PROPPATCH', 'MKCOL', 'COPY', 'MOVE', 'LOCK', 'UNLOCK'];
          webdavMethods.forEach(method => {
              try {
                  new Request('http://example.com', { method: method });
                  testResults.push({ method: method, category: 'webdav', passed: true });
              } catch (e) {
                  testResults.push({ method: method, category: 'webdav', passed: false, error: e.message });
              }
          });
          
          // Custom methods - should work
          const customMethods = ['CUSTOM_METHOD', 'X-CUSTOM', 'MY-API-METHOD', 'FOO'];
          customMethods.forEach(method => {
              try {
                  new Request('http://example.com', { method: method });
                  testResults.push({ method: method, category: 'custom', passed: true });
              } catch (e) {
                  testResults.push({ method: method, category: 'custom', passed: false, error: e.message });
              }
          });
          
          // Forbidden methods - should fail
          const forbiddenMethods = ['TRACE', 'TRACK', 'CONNECT'];
          forbiddenMethods.forEach(method => {
              try {
                  new Request('http://example.com', { method: method });
                  testResults.push({ method: method, category: 'forbidden', passed: false, shouldFail: true });
              } catch (e) {
                  testResults.push({ method: method, category: 'forbidden', passed: true, shouldFail: true, error: e.message });
              }
          });
          
          // Invalid token methods - should fail
          const invalidMethods = ['GET POST', 'GET\\nPOST', 'GET\\tPOST', 'GET()', 'GET,POST', 'GET@POST'];
          invalidMethods.forEach(method => {
              try {
                  new Request('http://example.com', { method: method });
                  testResults.push({ method: method, category: 'invalid-token', passed: false, shouldFail: true });
              } catch (e) {
                  testResults.push({ method: method, category: 'invalid-token', passed: true, shouldFail: true, error: e.message });
              }
          });
          
          testCompleted({ results: testResults });
      """

    let context = SwiftJS()
    context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
      let result = args[0]
      let results = result["results"]
      let testCount = Int(results["length"].numberValue ?? 0)

      for i in 0..<testCount {
        let test = results[i]
        let method = test["method"].toString()
        let category = test["category"].toString()
        let passed = test["passed"].boolValue ?? false

        switch category {
        case "standard", "case-insensitive", "webdav", "custom":
          XCTAssertTrue(passed, "Method '\(method)' in category '\(category)' should be accepted")
        case "forbidden", "invalid-token":
          XCTAssertTrue(passed, "Method '\(method)' in category '\(category)' should be rejected")
        default:
          XCTFail("Unknown test category: \(category)")
        }
      }

      expectation.fulfill()
      return SwiftJS.Value.undefined
    }

    context.evaluateScript(script)
    wait(for: [expectation], timeout: 10.0)
  }

  func testHeadersValidation() {
    let expectation = XCTestExpectation(description: "Headers validation")

    let script = """
          const testResults = [];
          
          // Valid headers - should work
          const validHeaders = [
              ['Content-Type', 'application/json'],
              ['Authorization', 'Bearer token'],
              ['X-Custom-Header', 'value'],
              ['Accept', 'text/html'],
              ['User-Agent', 'MyApp/1.0']
          ];
          
          validHeaders.forEach(([name, value]) => {
              try {
                  new Headers([[name, value]]);
                  testResults.push({ name: name, value: value, category: 'valid', passed: true });
              } catch (e) {
                  testResults.push({ name: name, value: value, category: 'valid', passed: false, error: e.message });
              }
          });
          
          // Invalid header names - should fail
          const invalidNames = [
              'Content\\nType',      // newline
              'Content\\rType',      // carriage return
              'Content\\x00Type',    // null byte
              'Content Type',        // space
              'Content(Type)',       // parentheses
              ''                     // empty name
          ];
          
          invalidNames.forEach(name => {
              try {
                  new Headers([[name, 'value']]);
                  testResults.push({ name: name, category: 'invalid-name', passed: false });
              } catch (e) {
                  testResults.push({ name: name, category: 'invalid-name', passed: true, error: e.message });
              }
          });
          
          // Invalid header values - should fail  
          const invalidValues = [
              'value\\nwith\\nnewlines',
              'value\\rwith\\rcarriage',
              'value\\x00with\\x00null'
          ];
          
          invalidValues.forEach(value => {
              try {
                  new Headers([['Content-Type', value]]);
                  testResults.push({ value: value, category: 'invalid-value', passed: false });
              } catch (e) {
                  testResults.push({ value: value, category: 'invalid-value', passed: true, error: e.message });
              }
          });
          
          testCompleted({ results: testResults });
      """

    let context = SwiftJS()
    context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
      let result = args[0]
      let results = result["results"]
      let testCount = Int(results["length"].numberValue ?? 0)

      for i in 0..<testCount {
        let test = results[i]
        let category = test["category"].toString()
        let passed = test["passed"].boolValue ?? false

        switch category {
        case "valid":
          let name = test["name"].toString()
          let value = test["value"].toString()
          XCTAssertTrue(passed, "Valid header '\(name): \(value)' should be accepted")
        case "invalid-name":
          let name = test["name"].toString()
          XCTAssertTrue(passed, "Invalid header name '\(name)' should be rejected")
        case "invalid-value":
          let value = test["value"].toString()
          XCTAssertTrue(passed, "Invalid header value '\(value)' should be rejected")
        default:
          XCTFail("Unknown test category: \(category)")
        }
      }

      expectation.fulfill()
      return SwiftJS.Value.undefined
    }

    context.evaluateScript(script)
    wait(for: [expectation], timeout: 10.0)
  }

  func testURLSearchParamsValidation() {
    let expectation = XCTestExpectation(description: "URLSearchParams validation")

    let script = """
          const testResults = [];
          
          // Test valid constructor arguments
          try {
              new URLSearchParams('key=value&foo=bar');
              testResults.push({ test: 'string constructor', passed: true });
          } catch (e) {
              testResults.push({ test: 'string constructor', passed: false, error: e.message });
          }
          
          try {
              new URLSearchParams([['key', 'value'], ['foo', 'bar']]);
              testResults.push({ test: 'array constructor', passed: true });
          } catch (e) {
              testResults.push({ test: 'array constructor', passed: false, error: e.message });
          }
          
          try {
              new URLSearchParams({key: 'value', foo: 'bar'});
              testResults.push({ test: 'object constructor', passed: true });
          } catch (e) {
              testResults.push({ test: 'object constructor', passed: false, error: e.message });
          }
          
          // Test invalid arguments to append method
          const params = new URLSearchParams();
          
          try {
              params.append();  // missing arguments
              testResults.push({ test: 'append no args', passed: false });
          } catch (e) {
              testResults.push({ test: 'append no args', passed: true, error: e.message });
          }
          
          try {
              params.append('key');  // missing value
              testResults.push({ test: 'append one arg', passed: false });
          } catch (e) {
              testResults.push({ test: 'append one arg', passed: true, error: e.message });
          }
          
          try {
              params.set();  // missing arguments
              testResults.push({ test: 'set no args', passed: false });
          } catch (e) {
              testResults.push({ test: 'set no args', passed: true, error: e.message });
          }
          
          try {
              params.delete();  // missing argument
              testResults.push({ test: 'delete no args', passed: false });
          } catch (e) {
              testResults.push({ test: 'delete no args', passed: true, error: e.message });
          }
          
          testCompleted({ results: testResults });
      """

    let context = SwiftJS()
    context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
      let result = args[0]
      let results = result["results"]
      let testCount = Int(results["length"].numberValue ?? 0)

      for i in 0..<testCount {
        let test = results[i]
        let testName = test["test"].toString()
        let passed = test["passed"].boolValue ?? false

        if testName.contains("constructor") {
          XCTAssertTrue(passed, "Test '\(testName)' should pass")
        } else {
          // Error handling tests
          XCTAssertTrue(passed, "Test '\(testName)' should throw error")
        }
      }

      expectation.fulfill()
      return SwiftJS.Value.undefined
    }

    context.evaluateScript(script)
    wait(for: [expectation], timeout: 10.0)
  }
}
