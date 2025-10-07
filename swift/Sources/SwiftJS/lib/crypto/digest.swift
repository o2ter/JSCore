//
//  digest.swift
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

import Crypto
import JavaScriptCore

protocol DigestProtocol {

  associatedtype Digest: ContiguousBytes

  mutating func update(bufferPointer: UnsafeRawBufferPointer)

  func finalize() -> Self.Digest
}

extension Insecure.MD5: DigestProtocol {

}

extension Insecure.SHA1: DigestProtocol {

}

extension SHA256: DigestProtocol {

}

extension SHA384: DigestProtocol {

}

extension SHA512: DigestProtocol {

}

extension HMAC: DigestProtocol {

  typealias Digest = Self.MAC

  mutating func update(bufferPointer: UnsafeRawBufferPointer) {
    self.update(data: bufferPointer)
  }
}

@objc protocol JSDigestExport: JSExport {

  func update(_ data: JSValue)

  func digest() -> JSValue

  func clone() -> Self
}

@objc final class JSDigest: NSObject, JSDigestExport {

  var base: any DigestProtocol

  init(_ hash: any DigestProtocol) {
    self.base = hash
  }

  func update(_ data: JSValue) {
    guard data.isTypedArray else { return }
    base.update(bufferPointer: data.typedArrayBytes)
  }

  func digest() -> JSValue {
    let digest = base.finalize()
    return digest.withUnsafeBytes { bytes in
      .uint8Array(count: bytes.count, in: JSContext.current()) { buffer in
        buffer.copyBytes(from: bytes)
      }
    }
  }

  func clone() -> JSDigest {
    return JSDigest(base)
  }
}

extension JSCrypto {

  func createHash(_ algorithm: String) -> JSDigest {
    switch algorithm {
    case "md5": return JSDigest(Insecure.MD5())
    case "sha1": return JSDigest(Insecure.SHA1())
    case "sha256": return JSDigest(SHA256())
    case "sha384": return JSDigest(SHA384())
    case "sha512": return JSDigest(SHA512())
    default:
      let context = JSContext.current()!
      context.exception = JSValue(
        newErrorFromMessage: "Unknown hash algorithm: \(algorithm)", in: context)
      return JSDigest(SHA256())  // Return a default hash to satisfy protocol, but exception is set
    }
  }
}

extension JSCrypto {

  func createHamc(_ algorithm: String, _ secret: JSValue) -> JSDigest? {
    guard secret.isTypedArray else { return nil }
    let key = SymmetricKey(data: secret.typedArrayBytes)
    switch algorithm {
    case "md5": return JSDigest(HMAC<Insecure.MD5>(key: key))
    case "sha1": return JSDigest(HMAC<Insecure.SHA1>(key: key))
    case "sha256": return JSDigest(HMAC<SHA256>(key: key))
    case "sha384": return JSDigest(HMAC<SHA384>(key: key))
    case "sha512": return JSDigest(HMAC<SHA512>(key: key))
    default: return nil
    }
  }
}
