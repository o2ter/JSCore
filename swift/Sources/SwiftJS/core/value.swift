//
//  value.swift
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

extension SwiftJS {
    
    enum ValueBase {
        case null
        case undefined
        case bool(Bool)
        case number(Double)
        case string(String)
        case date(Date)
        case array([ValueBase])
        case object([String: ValueBase])
        case value(JSValue)
    }
    
    public struct Value {
        
        let base: ValueBase
        
        public init(_ value: JSValue) {
            self.base = .value(value)
        }
        
        init(_ base: ValueBase) {
            self.base = base
        }
    }
}

extension SwiftJS.ValueBase: @unchecked Sendable {}
extension SwiftJS.Value: Sendable {}

extension JSContext: @unchecked @retroactive Sendable {}
extension JSValue: @unchecked @retroactive Sendable {}
extension JSValue: @retroactive Error {}

extension SwiftJS.Value: Error {
    
    public init(newErrorFromMessage message: String, in context: SwiftJS) {
        self.init(JSValue(newErrorFromMessage: message, in: context.base))
    }
}

extension SwiftJS.Value {
    
    public static var null: SwiftJS.Value {
        return SwiftJS.Value(.null)
    }
    
    public static var undefined: SwiftJS.Value {
        return SwiftJS.Value(.undefined)
    }
    
    public init(_ value: Bool) {
        self.init(.bool(value))
    }
    
    public init(_ value: Double) {
        self.init(.number(value))
    }
    
    public init(_ value: String) {
        self.init(.string(value))
    }
    
    public init(_ value: [SwiftJS.Value]) {
        self.init(.array(value.map { $0.base }))
    }
    
    public init(_ value: [String: SwiftJS.Value]) {
        self.init(.object(value.mapValues { $0.base }))
    }
}

extension JSValue {
    
    public convenience init(
        newFunctionIn context: JSContext,
        _ callback: @escaping (_ arguments: [JSValue], _ this: JSValue) throws -> JSValue
    ) {
        let closure: @convention(block) () -> JSValue = {
            do {
                let result = try callback(
                    JSContext.currentArguments()!.map { $0 as! JSValue },
                    JSContext.currentThis() ?? JSValue(undefinedIn: context))
                return result
            } catch let error {
                if let error = error as? JSValue {
                    context.exception = error
                } else {
                    context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
                }
                return JSValue(undefinedIn: context)
            }
        }
        self.init(object: closure, in: context)
    }
    
    public convenience init(
        newFunctionIn context: JSContext,
        _ callback: @escaping (_ arguments: [JSValue], _ this: JSValue) throws -> Void
    ) {
        self.init(newFunctionIn: context) { arguments, this in
            try callback(arguments, this)
            return JSValue(undefinedIn: context)
        }
    }
}

extension JSValue {
    
    public convenience init(
        newPromiseIn context: JSContext,
        _ callback: @Sendable @escaping () async throws -> JSValue
    ) {
        self.init(newPromiseIn: context) { resolve, reject in
            Task {
                do {
                    let result = try await callback()
                    resolve?.call(withArguments: [result])
                } catch let error {
                    if let error = error as? JSValue {
                        reject?.call(withArguments: [error])
                    } else {
                        reject?.call(withArguments: [JSValue(newErrorFromMessage: "\(error)", in: context)!])
                    }
                }
            }
        }
    }
}

extension JSValue {
    
    public convenience init(
        newFunctionIn context: JSContext,
        _ callback: @Sendable @escaping (_ arguments: [JSValue], _ this: JSValue) async throws -> JSValue
    ) {
        self.init(newFunctionIn: context) { arguments, this in
            return JSValue(newPromiseIn: context) { resolve, reject in
                Task {
                    do {
                        let result = try await callback(arguments, this)
                        resolve?.call(withArguments: [result])
                    } catch let error {
                        if let error = error as? JSValue {
                            reject?.call(withArguments: [error])
                        } else {
                            reject?.call(withArguments: [JSValue(newErrorFromMessage: "\(error)", in: context)!])
                        }
                    }
                }
            }
        }
    }
    
    public convenience init(
        newFunctionIn context: JSContext,
        _ callback: @Sendable @escaping (_ arguments: [JSValue], _ this: JSValue) async throws -> Void
    ) {
        self.init(newFunctionIn: context) { arguments, this in
            try await callback(arguments, this)
            return JSValue(undefinedIn: context)
        }
    }
}

extension SwiftJS.Value {
    
    public init(
        in context: SwiftJS,
        _ callback: @escaping (_ arguments: [SwiftJS.Value], _ this: SwiftJS.Value) throws -> SwiftJS.Value
    ) {
        self.init(
            JSValue(newFunctionIn: context.base) { arguments, this in
                let result = try callback(arguments.map { .init($0) }, SwiftJS.Value(this))
                return result.toJSValue(inContext: context.base)
            })
    }
    
    public init(
        in context: SwiftJS,
        _ callback: @escaping (_ arguments: [SwiftJS.Value], _ this: SwiftJS.Value) throws -> Void
    ) {
        self.init(in: context) { arguments, this in
            try callback(arguments, this)
            return .undefined
        }
    }
}

extension SwiftJS.Value {
    
    public init(
        newPromiseIn context: SwiftJS,
        _ callback: @Sendable @escaping () async throws -> SwiftJS.Value
    ) {
        self.init(
            JSValue(newPromiseIn: context.base) {
                let result = try await callback()
                return result.toJSValue(inContext: context.base)
            })
    }
}

extension SwiftJS.Value {
    
    public init(
        newFunctionIn context: SwiftJS,
        _ callback: @Sendable @escaping (_ arguments: [SwiftJS.Value], _ this: SwiftJS.Value) async throws -> SwiftJS.Value
    ) {
        self.init(
            JSValue(newFunctionIn: context.base) { arguments, this in
                let result = try await callback(arguments.map { .init($0) }, SwiftJS.Value(this))
                return result.toJSValue(inContext: context.base)
            })
    }
    
    public init(
        newFunctionIn context: SwiftJS,
        _ callback: @Sendable @escaping (_ arguments: [SwiftJS.Value], _ this: SwiftJS.Value) async throws -> Void
    ) {
        self.init(newFunctionIn: context) { arguments, this in
            try await callback(arguments, this)
            return .undefined
        }
    }
}

extension JSValue {
    
    public static func arrayBuffer(
        bytesLength count: Int,
        in context: JSContext,
        _ callback: (_ bytes: UnsafeMutableRawBufferPointer) -> Void = { _ in }
    ) -> JSValue {
        let buffer = context.evaluateScript("new ArrayBuffer(\(count))")!
        let address = JSObjectGetArrayBufferBytesPtr(
            context.jsGlobalContextRef, buffer.jsValueRef, nil)
        callback(.init(start: address, count: count))
        return buffer
    }
    
    public static func int8Array(
        count: Int,
        in context: JSContext,
        _ callback: (_ bytes: UnsafeMutableRawBufferPointer) -> Void = { _ in }
    ) -> JSValue {
        let buffer = context.evaluateScript("new Int8Array(\(count))")!
        let address = JSObjectGetTypedArrayBytesPtr(
            context.jsGlobalContextRef, buffer.jsValueRef, nil)
        callback(.init(start: address, count: count))
        return buffer
    }
    
    public static func uint8Array(
        count: Int,
        in context: JSContext,
        _ callback: (_ bytes: UnsafeMutableRawBufferPointer) -> Void = { _ in }
    ) -> JSValue {
        let buffer = context.evaluateScript("new Uint8Array(\(count))")!
        let address = JSObjectGetTypedArrayBytesPtr(
            context.jsGlobalContextRef, buffer.jsValueRef, nil)
        callback(.init(start: address, count: count))
        return buffer
    }
}

extension SwiftJS.Value {
    
    public static func arrayBuffer(
        bytesLength count: Int,
        in context: SwiftJS,
        _ callback: (_ bytes: UnsafeMutableRawBufferPointer) -> Void = { _ in }
    ) -> SwiftJS.Value {
        return SwiftJS.Value(JSValue.arrayBuffer(bytesLength: count, in: context.base, callback))
    }
    
    public static func int8Array(
        count: Int,
        in context: SwiftJS,
        _ callback: (_ bytes: UnsafeMutableRawBufferPointer) -> Void = { _ in }
    ) -> SwiftJS.Value {
        return SwiftJS.Value(JSValue.int8Array(count: count, in: context.base, callback))
    }
    
    public static func uint8Array(
        count: Int,
        in context: SwiftJS,
        _ callback: (_ bytes: UnsafeMutableRawBufferPointer) -> Void = { _ in }
    ) -> SwiftJS.Value {
        return SwiftJS.Value(JSValue.uint8Array(count: count, in: context.base, callback))
    }
}

extension SwiftJS.Value: CustomStringConvertible {
    
    public var description: String {
        return self.toString()
    }
}

extension SwiftJS.ValueBase {
    
    func toJSValue(inContext context: JSContext) -> JSValue {
        switch self {
        case .null: return JSValue(nullIn: context)
        case .undefined: return JSValue(undefinedIn: context)
        case let .bool(value): return JSValue(bool: value, in: context)
        case let .number(value): return JSValue(double: value, in: context)
        case let .string(value): return JSValue(object: value, in: context)
        case let .date(value): return JSValue(object: value, in: context)
        case let .array(elements):
            if elements.isEmpty { return JSValue(newArrayIn: context) }
            let array = elements.map { $0.toJSValue(inContext: context) }
            return JSValue(object: array, in: context)
        case let .object(dictionary):
            if dictionary.isEmpty { return JSValue(newObjectIn: context) }
            let object = dictionary.mapValues { $0.toJSValue(inContext: context) }
            return JSValue(object: object, in: context)
        case let .value(value):
            assert(value.context === context, "JSValue context mismatch")
            return value
        }
    }
}

extension SwiftJS.Value {
    
    func toJSValue(inContext context: JSContext) -> JSValue {
        return self.base.toJSValue(inContext: context)
    }
}

extension SwiftJS.Value: ExpressibleByBooleanLiteral {
    
    public init(booleanLiteral value: BooleanLiteralType) {
        self.init(value)
    }
}

extension SwiftJS.Value: ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: IntegerLiteralType) {
        self.init(Double(value))
    }
}

extension SwiftJS.Value: ExpressibleByFloatLiteral {
    
    public init(floatLiteral value: FloatLiteralType) {
        self.init(value)
    }
}

extension SwiftJS.Value: ExpressibleByStringInterpolation {
    
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
    
    public init(stringInterpolation: String.StringInterpolation) {
        self.init(String(stringInterpolation: stringInterpolation))
    }
}

extension SwiftJS.Value: ExpressibleByArrayLiteral {
    
    public init(arrayLiteral elements: SwiftJS.Value...) {
        self.init(elements)
    }
}

extension SwiftJS.Value: ExpressibleByDictionaryLiteral {
    
    public init(dictionaryLiteral elements: (String, SwiftJS.Value)...) {
        let dictionary = elements.reduce(into: [String: SwiftJS.Value]()) { $0[$1.0] = $1.1 }
        self.init(dictionary)
    }
}

extension SwiftJS.Value {
    
    public subscript(_ property: String) -> SwiftJS.Value {
        get {
            switch self.base {
            case let .value(base): return .init(base.forProperty(property))
            case let .object(dictionary): return dictionary[property].map(SwiftJS.Value.init) ?? .undefined
            default: return .undefined
            }
        }
        nonmutating set {
            guard case let .value(base) = self.base, let context = base.context else { return }
            base.setValue(newValue.toJSValue(inContext: context), forProperty: property)
        }
    }
    
    public subscript(_ index: Int) -> SwiftJS.Value {
        get {
            switch self.base {
            case let .value(base): return .init(base.atIndex(index))
            case let .array(elements):
                guard index >= 0 && index < elements.count else { return .undefined }
                return .init(elements[index])
            default: return .undefined
            }
        }
        nonmutating set {
            guard case let .value(base) = self.base, let context = base.context else { return }
            base.setValue(newValue.toJSValue(inContext: context), at: index)
        }
    }
}

extension SwiftJS.Value {
    
    public func hasProperty(_ property: String) -> Bool {
        guard case let .value(base) = self.base else {
            return false
        }
        return base.hasProperty(property)
    }
}

extension SwiftJS.Value {
    
    @discardableResult
    public func call(withArguments arguments: [SwiftJS.Value] = []) -> SwiftJS.Value {
        guard case let .value(base) = self.base, let context = base.context else {
            return .undefined
        }
        let result = base.call(withArguments: arguments.map { $0.toJSValue(inContext: context) })
        return result.map(SwiftJS.Value.init) ?? .undefined
    }
    
    public func construct(withArguments arguments: [SwiftJS.Value] = []) -> SwiftJS.Value {
        guard case let .value(base) = self.base, let context = base.context else {
            return .undefined
        }
        let result = base.construct(
            withArguments: arguments.map { $0.toJSValue(inContext: context) })
        return result.map(SwiftJS.Value.init) ?? .undefined
    }
    
    @discardableResult
    public func invokeMethod(_ method: String, withArguments arguments: [SwiftJS.Value] = [])
    -> SwiftJS.Value
    {
        guard case let .value(base) = self.base, let context = base.context else {
            return .undefined
        }
        let result = base.invokeMethod(
            method, withArguments: arguments.map { $0.toJSValue(inContext: context) })
        return result.map(SwiftJS.Value.init) ?? .undefined
    }
}

extension SwiftJS.Value {
    
    public var isNull: Bool {
        switch self.base {
        case .null: return true
        case let .value(value): return value.isNull
        default: return false
        }
    }
    
    public var isUndefined: Bool {
        switch self.base {
        case .undefined: return true
        case let .value(value): return value.isUndefined
        default: return false
        }
    }
    
    public var isBool: Bool {
        switch self.base {
        case .bool: return true
        case let .value(value): return value.isBoolean
        default: return false
        }
    }
    
    public var isNumber: Bool {
        switch self.base {
        case .number: return true
        case let .value(value): return value.isNumber
        default: return false
        }
    }
    
    public var isString: Bool {
        switch self.base {
        case .string: return true
        case let .value(value): return value.isString
        default: return false
        }
    }
}

extension SwiftJS.Value {
    
    public var isObject: Bool {
        switch self.base {
        case .value(let value): return value.isObject
        default: return false
        }
    }
    
    public var isArray: Bool {
        switch self.base {
        case .value(let value): return value.isArray
        default: return false
        }
    }
    
    public var isDate: Bool {
        switch self.base {
        case .value(let value): return value.isDate
        default: return false
        }
    }
    
    public var isSymbol: Bool {
        switch self.base {
        case .value(let value): return value.isSymbol
        default: return false
        }
    }
    
    @available(macOS 15.0, macCatalyst 18, iOS 18, tvOS 18, *)
    public var isBigInt: Bool {
        switch self.base {
        case .value(let value): return value.isBigInt
        default: return false
        }
    }
}

extension SwiftJS.Value {
    
    public var isFunction: Bool {
        switch self.base {
        case .value(let value):
            return JSObjectIsFunction(value.context.jsGlobalContextRef, value.jsValueRef)
        default: return false
        }
    }
    
    public var isConstructor: Bool {
        switch self.base {
        case .value(let value):
            return JSObjectIsConstructor(value.context.jsGlobalContextRef, value.jsValueRef)
        default: return false
        }
    }
}

extension SwiftJS {
    
    public struct TypedArrayType: RawRepresentable, Hashable, Sendable {
        
        public let rawValue: UInt32
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        public static var int8: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeInt8Array.rawValue)
        }
        public static var uint8: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeUint8Array.rawValue)
        }
        public static var uint8Clamped: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeUint8ClampedArray.rawValue)
        }
        public static var int16: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeInt16Array.rawValue)
        }
        public static var uint16: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeUint16Array.rawValue)
        }
        public static var int32: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeInt32Array.rawValue)
        }
        public static var uint32: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeUint32Array.rawValue)
        }
        public static var float32: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeFloat32Array.rawValue)
        }
        public static var float64: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeFloat64Array.rawValue)
        }
        public static var bigInt64: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeBigInt64Array.rawValue)
        }
        public static var bigUint64: TypedArrayType {
            return .init(rawValue: kJSTypedArrayTypeBigUint64Array.rawValue)
        }
    }
}

extension JSValue {
    
    public var typedArrayType: JSTypedArrayType {
        return JSValueGetTypedArrayType(self.context.jsGlobalContextRef, self.jsValueRef, nil)
    }
    
    public var isTypedArray: Bool {
        return self.typedArrayType != kJSTypedArrayTypeNone
    }
    
    public var typedArrayBytes: UnsafeRawBufferPointer {
        let byteLength = JSObjectGetTypedArrayByteLength(
            self.context.jsGlobalContextRef, self.jsValueRef, nil)
        let address = JSObjectGetTypedArrayBytesPtr(
            self.context.jsGlobalContextRef, self.jsValueRef, nil)
        return .init(start: address, count: byteLength)
    }
    
    public var typedArrayMutableBytes: UnsafeMutableRawBufferPointer {
        let byteLength = JSObjectGetTypedArrayByteLength(
            self.context.jsGlobalContextRef, self.jsValueRef, nil)
        let address = JSObjectGetTypedArrayBytesPtr(
            self.context.jsGlobalContextRef, self.jsValueRef, nil)
        return .init(start: address, count: byteLength)
    }
}

extension SwiftJS.Value {
    
    public var typedArrayType: SwiftJS.TypedArrayType? {
        switch self.base {
        case .value(let value):
            let type = value.typedArrayType
            return type == kJSTypedArrayTypeNone ? nil : SwiftJS.TypedArrayType(rawValue: type.rawValue)
        default: return nil
        }
    }
    
    public var isTypedArray: Bool {
        return self.typedArrayType != nil
    }
}

extension SwiftJS.ValueBase {
    
    public func toString() -> String {
        switch self {
        case .null: return "null"
        case .undefined: return "undefined"
        case let .bool(value): return "\(value)"
        case let .number(value): return "\(value)"
        case let .string(value): return value
        case let .date(value):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            return formatter.string(from: value)
        case let .array(elements):
            return "[\(elements.map { $0.toString() }.joined(separator: ", "))]"
        case let .object(dictionary):
            return "{\(dictionary.map { "\($0.key): \($0.value.toString())" }.joined(separator: ", "))}"
        case let .value(value): return value.toString()
        }
    }
}

extension SwiftJS.Value {
    
    public func toString() -> String {
        return self.base.toString()
    }
}

extension SwiftJS.Value {
    
    public var boolValue: Bool? {
        switch self.base {
        case .bool(let value): return value
        case let .value(value): return value.toBool()
        default: return nil
        }
    }
    
    public var numberValue: Double? {
        switch self.base {
        case .number(let value): return value
        case let .value(value): return value.toDouble()
        default: return nil
        }
    }
    
    public var stringValue: String? {
        switch self.base {
        case .string(let value): return value
        case let .value(value): return value.toString()
        default: return nil
        }
    }
    
    public var dateValue: Date? {
        switch self.base {
        case .date(let value): return value
        case .value(let value): return value.toDate()
        default: return nil
        }
    }
}

// MARK: - Promise Awaiting Support

extension SwiftJS.Value {

    /// Converts a JavaScript Promise to a Swift async throws result.
    /// This method simplifies the common pattern of converting JavaScript promises
    /// to Swift async/await by handling the promise resolution/rejection automatically.
    ///
    /// Usage:
    /// ```swift
    /// let promise = context.evaluateScript("fetch('https://example.com')")
    /// let result = try await promise.awaited(inContext: context)
    /// ```
    ///
    /// - Returns: The resolved value of the promise
    /// - Throws: An error if the promise is rejected or if this value is not a promise
    public func awaited(inContext context: SwiftJS) async throws -> SwiftJS.Value {
        guard case let .value(jsValue) = self.base else {
            throw SwiftJS.Value(
                newErrorFromMessage: "Value is not a JavaScript object", in: context)
        }

        return try await withCheckedThrowingContinuation { continuation in

            context.runloop.perform {
            
                // Check if this is actually a promise (has then and catch methods)
                let thenMethod = jsValue.forProperty("then")
                guard let thenMethod = thenMethod, thenMethod.isObject else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "SwiftJSError",
                            code: 1,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Value is not a Promise (missing 'then' method)"
                            ]
                        ))
                    return
                }

                // Handle promise resolution
                let resolveCallback = JSValue(newFunctionIn: context.base) { args, _ in
                    if let result = args.first {
                        continuation.resume(returning: SwiftJS.Value(result))
                    } else {
                        continuation.resume(returning: .undefined)
                    }
                    return JSValue(undefinedIn: context.base)
                }

                // Handle promise rejection
                let rejectCallback = JSValue(newFunctionIn: context.base) { args, _ in
                    let errorMessage = args.first?.toString() ?? "Unknown promise rejection"
                    let errorName = args.first?.forProperty("name").toString() ?? "Error"
                    let errorStack =
                        args.first?.forProperty("stack").toString() ?? "No stack trace available"

                    let error = NSError(
                        domain: "SwiftJSPromiseError",
                        code: 2,
                        userInfo: [
                            NSLocalizedDescriptionKey: errorMessage,
                            "errorName": errorName,
                            "errorStack": errorStack,
                        ]
                    )
                    continuation.resume(throwing: error)
                    return JSValue(undefinedIn: context.base)
                }

                // Use invokeMethod with both resolve and reject callbacks
                // The then() method accepts both onFulfilled and onRejected as arguments
                jsValue.invokeMethod("then", withArguments: [resolveCallback, rejectCallback])
            }
        }
    }
}
