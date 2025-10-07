// swift-tools-version: 6.0
//
//  Package.swift
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

import PackageDescription

let package = Package(
    name: "SwiftJS",
    platforms: [
        .macOS(.v14),
        .macCatalyst(.v17),
        .iOS(.v17),
    ],
    products: [
        .executable(name: "SwiftJSRunner", targets: ["SwiftJSRunner"]),
        .library(name: "SwiftJS", targets: ["SwiftJS"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.15.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.86.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.27.0")
    ],
    targets: [
        .target(
            name: "SwiftJS",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ],
            path: "swift/Sources/SwiftJS",
            resources: [
                .embedInCode("../../../resources/polyfill.js")
            ]
        ),
        .testTarget(
            name: "SwiftJSTests",
            dependencies: ["SwiftJS"],
            path: "swift/Tests/SwiftJSTests"
        ),
        .executableTarget(
            name: "SwiftJSRunner",
            dependencies: ["SwiftJS"],
            path: "swift/Sources/SwiftJSRunner"
        )
    ]
)
