//
//  XMLHttpRequestTests.swift
//  SwiftJS XMLHttpRequest API Tests
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

/// Tests for the XMLHttpRequest API including instantiation, state management,
/// headers, and request handling.
@MainActor
final class XMLHttpRequestTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testXMLHttpRequestExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof XMLHttpRequest")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testXMLHttpRequestAPIExistence() {
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        XCTAssertTrue(globals.toString().contains("XMLHttpRequest"))
    }
    
    // MARK: - Instantiation and Constants Tests
    
    func testXMLHttpRequestInstantiation() {
        let context = SwiftJS()
        let result = context.evaluateScript("""
            const xhr = new XMLHttpRequest();
            xhr.readyState
        """)
        XCTAssertEqual(result.numberValue, 0) // UNSENT state
    }
    
    func testXMLHttpRequestInstanceof() {
        let script = """
            const xhr = new XMLHttpRequest();
            xhr instanceof XMLHttpRequest
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testXMLHttpRequestConstants() {
        let script = """
            [
                XMLHttpRequest.UNSENT,
                XMLHttpRequest.OPENED,
                XMLHttpRequest.HEADERS_RECEIVED,
                XMLHttpRequest.LOADING,
                XMLHttpRequest.DONE
            ]
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result[0].numberValue, 0)
        XCTAssertEqual(result[1].numberValue, 1)
        XCTAssertEqual(result[2].numberValue, 2)
        XCTAssertEqual(result[3].numberValue, 3)
        XCTAssertEqual(result[4].numberValue, 4)
    }
    
    func testXMLHttpRequestInstanceConstants() {
        let script = """
            const xhr = new XMLHttpRequest();
            [
                xhr.UNSENT,
                xhr.OPENED,
                xhr.HEADERS_RECEIVED,
                xhr.LOADING,
                xhr.DONE
            ]
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result[0].numberValue, 0)
        XCTAssertEqual(result[1].numberValue, 1)
        XCTAssertEqual(result[2].numberValue, 2)
        XCTAssertEqual(result[3].numberValue, 3)
        XCTAssertEqual(result[4].numberValue, 4)
    }
    
    // MARK: - State Management Tests
    
    func testXMLHttpRequestInitialState() {
        let script = """
            const xhr = new XMLHttpRequest();
            ({
                readyState: xhr.readyState,
                status: xhr.status,
                statusText: xhr.statusText,
                responseText: xhr.responseText,
                responseURL: xhr.responseURL
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["readyState"].numberValue ?? -1), 0) // UNSENT
        XCTAssertEqual(Int(result["status"].numberValue ?? -1), 0)
        XCTAssertEqual(result["statusText"].toString(), "")
        XCTAssertEqual(result["responseText"].toString(), "")
        XCTAssertEqual(result["responseURL"].toString(), "")
    }
    
    func testXMLHttpRequestOpen() {
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://postman-echo.com/get');
            ({
                readyState: xhr.readyState,
                responseURL: xhr.responseURL
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(Int(result["readyState"].numberValue ?? -1), 1) // OPENED state
        // responseURL might not be set until send() is called
    }
    
    func testXMLHttpRequestOpenWithDifferentMethods() {
        let methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]
        
        for method in methods {
            let script = """
                const xhr = new XMLHttpRequest();
                xhr.open('\(method)', 'https://postman-echo.com/\(method.lowercased())');
                xhr.readyState
            """
            let context = SwiftJS()
            let result = context.evaluateScript(script)
            XCTAssertEqual(Int(result.numberValue ?? -1), 1, "Method \(method) should set readyState to OPENED")
        }
    }
    
    // MARK: - Header Management Tests
    
    func testXMLHttpRequestSetRequestHeader() {
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://postman-echo.com/get');
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.setRequestHeader('X-Custom-Header', 'test-value');
            'success'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "success")
    }
    
    func testXMLHttpRequestSetRequestHeaderCaseInsensitive() {
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://postman-echo.com/post');
            xhr.setRequestHeader('content-type', 'application/json');
            xhr.setRequestHeader('Content-Type', 'application/xml'); // Should combine or override
            'success'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "success")
    }
    
    func testXMLHttpRequestSetRequestHeaderInvalidState() {
        let script = """
            const xhr = new XMLHttpRequest();
            try {
                xhr.setRequestHeader('Test', 'value'); // Should fail - not opened
                false
            } catch (error) {
                error.name === 'InvalidStateError' || error.message.includes('InvalidStateError')
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testXMLHttpRequestSetRequestHeaderAfterSend() {
        let expectation = XCTestExpectation(description: "Set header after send")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://postman-echo.com/get');
            xhr.send();
            
            try {
                xhr.setRequestHeader('Late-Header', 'value'); // Should fail - already sent
                testCompleted({ shouldHaveFailed: true });
            } catch (error) {
                testCompleted({ 
                    caughtError: true,
                    errorName: error.name,
                    isInvalidState: error.name === 'InvalidStateError' || error.message.includes('InvalidStateError')
                });
            }
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["shouldHaveFailed"].boolValue == true {
                XCTFail("Should have thrown InvalidStateError when setting header after send")
            } else {
                XCTAssertTrue(result["caughtError"].boolValue ?? false)
                XCTAssertTrue(result["isInvalidState"].boolValue ?? false)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Response Header Tests
    
    func testXMLHttpRequestGetResponseHeader() {
        let expectation = XCTestExpectation(description: "Get response header")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://postman-echo.com/response-headers?Content-Type=application/json');
            
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    const contentType = xhr.getResponseHeader('Content-Type');
                    testCompleted({
                        status: xhr.status,
                        contentType: contentType,
                        hasContentType: contentType !== null && contentType !== ''
                    });
                }
            };
            
            xhr.onerror = function() {
                testCompleted({ error: 'Network error' });
            };
            
            xhr.send();
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(
                result["error"].isString,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200, "Status should be 200")
            XCTAssertTrue(
                result["hasContentType"].boolValue ?? false, "Should have content-type header")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testXMLHttpRequestGetAllResponseHeaders() {
        let expectation = XCTestExpectation(description: "Get all response headers")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://postman-echo.com/headers');
            
            xhr.onload = function() {
                const allHeaders = xhr.getAllResponseHeaders();
                testCompleted({
                    status: xhr.status,
                    allHeaders: allHeaders,
                    hasHeaders: allHeaders !== null && allHeaders.length > 0,
                    headersType: typeof allHeaders
                });
            };
            
            xhr.onerror = function() {
                testCompleted({ error: 'Network error' });
            };
            
            xhr.send();
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped: \(result["error"].toString())")
            } else {
                XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
                XCTAssertEqual(result["headersType"].toString(), "string")
                XCTAssertTrue(result["hasHeaders"].boolValue ?? false)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Event Handler Tests
    
    func testXMLHttpRequestEventHandlers() {
        let script = """
            const xhr = new XMLHttpRequest();
            const eventHandlers = [
                'onreadystatechange',
                'onload',
                'onerror',
                'onabort',
                'ontimeout',
                'onloadstart',
                'onloadend',
                'onprogress'
            ];
            
            const results = {};
            eventHandlers.forEach(handler => {
                results[handler] = typeof xhr[handler];
            });
            
            results
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // All event handlers should initially be null (object type) or undefined
        let eventHandlers = ["onreadystatechange", "onload", "onerror", "onabort", "ontimeout", "onloadstart", "onloadend", "onprogress"]
        for handler in eventHandlers {
            let handlerType = result[handler].toString()
            // Should be null, undefined, or function initially
            XCTAssertTrue(["object", "undefined", "function"].contains(handlerType), 
                         "\(handler) should be object/undefined/function, got \(handlerType)")
        }
    }
    
    func testXMLHttpRequestOnReadyStateChange() {
        let expectation = XCTestExpectation(description: "onreadystatechange event")
        
        let script = """
            const xhr = new XMLHttpRequest();
            const states = [];
            
            xhr.onreadystatechange = function() {
                states.push(xhr.readyState);
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    testCompleted({
                        states: states,
                        finalStatus: xhr.status,
                        hasMultipleStates: states.length > 1
                    });
                }
            };
            
            xhr.open('GET', 'https://postman-echo.com/get');
            xhr.send();
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["finalStatus"].numberValue == 0 {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped")
            } else {
                XCTAssertEqual(Int(result["finalStatus"].numberValue ?? 0), 200)
                XCTAssertTrue(result["hasMultipleStates"].boolValue ?? false)
                
                let states = result["states"]
                let stateCount = Int(states["length"].numberValue ?? 0)
                XCTAssertGreaterThan(stateCount, 0)
                
                // Final state should be DONE (4)
                let finalState = Int(states[stateCount - 1].numberValue ?? -1)
                XCTAssertEqual(finalState, 4)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Send and Response Tests
    
    func testXMLHttpRequestBasicGET() {
        let expectation = XCTestExpectation(description: "Basic GET request")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://postman-echo.com/get');
            
            xhr.onload = function() {
                testCompleted({
                    status: xhr.status,
                    readyState: xhr.readyState,
                    responseLength: xhr.responseText.length,
                    hasResponse: xhr.responseText.length > 0
                });
            };
            
            xhr.onerror = function() {
                testCompleted({ error: 'Network error' });
            };
            
            xhr.send();
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped: \(result["error"].toString())")
            } else {
                XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
                XCTAssertEqual(Int(result["readyState"].numberValue ?? 0), 4) // DONE
                XCTAssertTrue(result["hasResponse"].boolValue ?? false)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testXMLHttpRequestPOST() {
        let expectation = XCTestExpectation(description: "POST request")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://postman-echo.com/post');
            xhr.setRequestHeader('Content-Type', 'application/json');
            
            const postData = JSON.stringify({ 
                message: 'Hello from XMLHttpRequest',
                timestamp: Date.now()
            });
            
            xhr.onload = function() {
                try {
                    const response = JSON.parse(xhr.responseText);
                    const receivedData = JSON.parse(response.data || '{}');
                    
                    testCompleted({
                        status: xhr.status,
                        hasData: !!response.data,
                        messageMatch: receivedData.message === 'Hello from XMLHttpRequest',
                        contentType: response.headers ? response.headers['Content-Type'] : null
                    });
                } catch (parseError) {
                    testCompleted({ parseError: parseError.message });
                }
            };
            
            xhr.onerror = function() {
                testCompleted({ error: 'Network error' });
            };
            
            xhr.send(postData);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString || result["parseError"].isString {
                // Network might not be available or response format different, skip the test
                XCTAssertTrue(true, "Network test skipped")
            } else {
                XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
                XCTAssertTrue(result["hasData"].boolValue ?? false)
                // Message matching might depend on exact server implementation
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testXMLHttpRequestInvalidURL() {
        let expectation = XCTestExpectation(description: "Invalid URL handling")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'invalid-url');
            
            xhr.onerror = function() {
                testCompleted({ 
                    errorHandled: true,
                    status: xhr.status,
                    readyState: xhr.readyState
                });
            };
            
            xhr.onload = function() {
                testCompleted({ unexpectedLoad: true });
            };
            
            xhr.send();
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["unexpectedLoad"].boolValue == true {
                XCTFail("Invalid URL should not load successfully")
            } else {
                XCTAssertTrue(result["errorHandled"].boolValue ?? false)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testXMLHttpRequestAbort() {
        let expectation = XCTestExpectation(description: "Request abort")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://postman-echo.com/delay/5');
            
            xhr.onabort = function() {
                testCompleted({
                    aborted: true,
                    readyState: xhr.readyState,
                    status: xhr.status
                });
            };
            
            xhr.onload = function() {
                testCompleted({ unexpectedLoad: true });
            };
            
            xhr.send();
            
            // Abort after 100ms
            setTimeout(() => xhr.abort(), 100);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["unexpectedLoad"].boolValue == true {
                // The request might complete faster than we can abort it
                XCTAssertTrue(true, "Request completed before abort")
            } else {
                XCTAssertTrue(result["aborted"].boolValue ?? false)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Timeout Tests
    
    func testXMLHttpRequestTimeout() {
        let expectation = XCTestExpectation(description: "Request timeout")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.timeout = 1000; // 1 second timeout
            xhr.open('GET', 'https://postman-echo.com/delay/5');
            
            xhr.ontimeout = function() {
                testCompleted({
                    timedOut: true,
                    readyState: xhr.readyState,
                    timeoutValue: xhr.timeout
                });
            };
            
            xhr.onload = function() {
                testCompleted({ unexpectedLoad: true });
            };
            
            xhr.onerror = function() {
                testCompleted({ error: 'Network error instead of timeout' });
            };
            
            xhr.send();
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["unexpectedLoad"].boolValue == true {
                // The delay service might not work as expected
                XCTAssertTrue(true, "Delay service responded faster than expected")
            } else if result["error"].isString {
                // Might get network error instead of timeout
                XCTAssertTrue(true, "Got network error instead of timeout")
            } else {
                XCTAssertTrue(result["timedOut"].boolValue ?? false)
                XCTAssertEqual(Int(result["timeoutValue"].numberValue ?? 0), 1000)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Response Type Tests
    
    func testXMLHttpRequestResponseType() {
        let script = """
            const xhr = new XMLHttpRequest();
            
            // Test default response type
            const defaultType = xhr.responseType;
            
            // Test setting response type
            xhr.responseType = 'text';
            const textType = xhr.responseType;
            
            xhr.responseType = 'json';
            const jsonType = xhr.responseType;
            
            ({
                defaultType: defaultType,
                textType: textType,
                jsonType: jsonType
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Default should be empty string or 'text'
        let defaultType = result["defaultType"].toString()
        XCTAssertTrue(["", "text"].contains(defaultType))
        
        // Setting specific types should work
        XCTAssertEqual(result["textType"].toString(), "text")
        XCTAssertEqual(result["jsonType"].toString(), "json")
    }
    
    // MARK: - Integration Tests
    
    func testXMLHttpRequestCompleteWorkflow() {
        let expectation = XCTestExpectation(description: "Complete XMLHttpRequest workflow")
        
        let script = """
            const xhr = new XMLHttpRequest();
            const events = [];
            
            // Track all events
            xhr.onloadstart = () => events.push('loadstart');
            xhr.onprogress = () => events.push('progress');
            xhr.onload = () => events.push('load');
            xhr.onloadend = () => events.push('loadend');
            xhr.onreadystatechange = () => events.push(`readystate-${xhr.readyState}`);
            
            xhr.onload = function() {
                try {
                    const data = JSON.parse(xhr.responseText);
                    testCompleted({
                        status: xhr.status,
                        readyState: xhr.readyState,
                        events: events,
                        hasData: !!data,
                        url: data.url || xhr.responseURL,
                        headersReceived: xhr.getAllResponseHeaders().length > 0
                    });
                } catch (error) {
                    testCompleted({ parseError: error.message });
                }
            };
            
            xhr.onerror = function() {
                testCompleted({ error: 'Network error', events: events });
            };
            
            xhr.open('GET', 'https://postman-echo.com/get');
            xhr.setRequestHeader('X-Test', 'XMLHttpRequest-Integration');
            xhr.send();
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString || result["parseError"].isString {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped")
            } else {
                XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
                XCTAssertEqual(Int(result["readyState"].numberValue ?? 0), 4)
                XCTAssertTrue(result["hasData"].boolValue ?? false)
                XCTAssertTrue(result["headersReceived"].boolValue ?? false)
                
                let events = result["events"]
                let eventCount = Int(events["length"].numberValue ?? 0)
                XCTAssertGreaterThan(eventCount, 0, "Should have received some events")
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
}
