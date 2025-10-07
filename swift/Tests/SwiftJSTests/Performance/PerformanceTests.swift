//
//  PerformanceTests.swift
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

final class PerformanceTests: XCTestCase {
    
    
    // MARK: - Object Creation Performance
    
    func testXMLHttpRequestCreationPerformance() {
        let context = SwiftJS()
        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("new XMLHttpRequest()")
            }
        }
    }
    
    func testHeadersCreationPerformance() {
        let context = SwiftJS()
        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("new Headers({ 'Content-Type': 'application/json' })")
            }
        }
    }
    
    func testRequestCreationPerformance() {
        let context = SwiftJS()
        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("""
                    new Request('https://postman-echo.com', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' }
                    })
                """)
            }
        }
    }
    
    func testResponseCreationPerformance() {
        let context = SwiftJS()
        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("""
                    new Response('{"data": "test"}', {
                        status: 200,
                        headers: { 'Content-Type': 'application/json' }
                    })
                """)
            }
        }
    }
    
    // MARK: - Text Encoding Performance
    
    func testTextEncoderPerformance() {
        let script = """
            const encoder = new TextEncoder();
            const text = 'Hello, World! This is a test string with some UTF-8 characters: 你好世界 🌍';
        """
        let context = SwiftJS()
        context.evaluateScript(script)
        
        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("encoder.encode(text)")
            }
        }
    }
    
    func testTextDecoderPerformance() {
        let script = """
            const encoder = new TextEncoder();
            const decoder = new TextDecoder();
            const text = 'Hello, World! This is a test string with some UTF-8 characters: 你好世界 🌍';
            const encoded = encoder.encode(text);
        """
        let context = SwiftJS()
        context.evaluateScript(script)
        
        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("decoder.decode(encoded)")
            }
        }
    }
    
    // MARK: - Header Manipulation Performance
    
    func testHeaderManipulationPerformance() {
        let script = """
            function testHeaders() {
                const headers = new Headers();
                headers.set('Content-Type', 'application/json');
                headers.set('Authorization', 'Bearer token123');
                headers.set('X-Custom-Header', 'custom-value');
                headers.append('Accept', 'application/json');
                headers.append('Accept', 'text/plain');
                
                return headers.get('content-type') + headers.get('authorization');
            }
        """
        let context = SwiftJS()
        context.evaluateScript(script)

        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("testHeaders()")
            }
        }
    }
    
    // MARK: - Promise Performance
    
    func testPromiseCreationPerformance() {
        let script = """
            function createPromise() {
                return new Promise((resolve, reject) => {
                    resolve('test data');
                });
            }
        """
        let context = SwiftJS()
        context.evaluateScript(script)

        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("createPromise()")
            }
        }
    }
    
    // MARK: - Event System Performance
    
    func testEventSystemPerformance() {
        let script = """
            function testEvents() {
                const target = new EventTarget();
                const listener = () => {};
                target.addEventListener('test', listener);
                target.dispatchEvent(new Event('test'));
                target.removeEventListener('test', listener);
            }
        """
        let context = SwiftJS()
        context.evaluateScript(script)

        measure {
            for _ in 0..<1000 {
                _ = context.evaluateScript("testEvents()")
            }
        }
    }
    
    // MARK: - Large Data Performance
    
    func testLargeJSONProcessing() {
        let script = """
            const largeData = {
                items: Array(1000).fill(0).map((_, i) => ({
                    id: i,
                    name: `Item ${i}`,
                    data: `Data for item ${i}`,
                    timestamp: Date.now() + i
                }))
            };
            const jsonString = JSON.stringify(largeData);
        """
        let context = SwiftJS()
        context.evaluateScript(script)

        measure {
            _ = context.evaluateScript("JSON.parse(jsonString)")
        }
    }
    
    func testLargeTextEncoding() {
        let script = """
            const encoder = new TextEncoder();
            const decoder = new TextDecoder();
            const largeText = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '.repeat(1000);
        """
        let context = SwiftJS()
        context.evaluateScript(script)

        measure {
            _ = context.evaluateScript("""
                (function() {
                    const encoded = encoder.encode(largeText);
                    const decoded = decoder.decode(encoded);
                    return decoded.length;
                })()
            """)
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageWithManyRequests() {
        let script = """
            function createManyRequests() {
                const requests = [];
                for (let i = 0; i < 100; i++) {
                    requests.push(new Request(`https://postman-echo.com/api/${i}`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ id: i, data: `test data ${i}` })
                    }));
                }
                return requests.length;
            }
        """
        let context = SwiftJS()
        context.evaluateScript(script)

        measure {
            for _ in 0..<10 {
                _ = context.evaluateScript("createManyRequests()")
            }
        }
    }
    
    func testMemoryUsageWithManyResponses() {
        let script = """
            function createManyResponses() {
                const responses = [];
                for (let i = 0; i < 100; i++) {
                    responses.push(new Response(JSON.stringify({ id: i, data: `response data ${i}` }), {
                        status: 200,
                        headers: { 'Content-Type': 'application/json' }
                    }));
                }
                return responses.length;
            }
        """
        let context = SwiftJS()
        context.evaluateScript(script)

        measure {
            for _ in 0..<10 {
                _ = context.evaluateScript("createManyResponses()")
            }
        }
    }
    
    // MARK: - Real-world Scenario Performance
    
    func testCompleteHTTPWorkflowPerformance() {
        let script = """
            function completeWorkflow() {
                // Create request
                const request = new Request('https://postman-echo.com/data', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer token123'
                    },
                    body: JSON.stringify({
                        name: 'Test User',
                        email: 'test@example.com',
                        data: Array(10).fill(0).map((_, i) => `item ${i}`)
                    })
                });
                
                // Create response
                const response = new Response(JSON.stringify({
                    success: true,
                    id: 12345,
                    message: 'Data saved successfully'
                }), {
                    status: 201,
                    headers: { 'Content-Type': 'application/json' }
                });
                
                // Process response
                return response.json().then(data => ({
                    requestUrl: request.url,
                    responseStatus: response.status,
                    responseData: data
                }));
            }
        """
        let context = SwiftJS()
        context.evaluateScript(script)
        
        measure {
            for _ in 0..<100 {
                _ = context.evaluateScript("completeWorkflow()")
            }
        }
    }
}
