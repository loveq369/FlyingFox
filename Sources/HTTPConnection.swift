//
//  HTTPConnection.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/02/2022.
//  Copyright © 2022 Simon Whitty. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/FlyingFox
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

final class HTTPConnection: Hashable {

    let hostname: String
    private let socket: AsyncSocket

    init(socket: AsyncSocket) {
        self.socket = socket
        self.hostname = (try? socket.socket.remoteHostname()) ?? "<unknown>"
    }

    // some AsyncSequence<HTTPRequest>
    var requests: HTTPRequestSequence<ClosureSequence<UInt8>> {
        HTTPRequestSequence(bytes: socket.bytes)
    }

    func sendResponse(_ response: HTTPResponse, for request: HTTPRequest) throws {
        try socket.write(HTTPResponseEncoder.encodeResponse(response, for: request))
    }

    func close() throws {
        try socket.close()
    }

    func hash(into hasher: inout Hasher) {
      ObjectIdentifier(self).hash(into: &hasher)
    }

    static func == (lhs: HTTPConnection, rhs: HTTPConnection) -> Bool {
      lhs === rhs
    }
}

struct HTTPRequestSequence<S: AsyncSequence>: AsyncSequence, AsyncIteratorProtocol where S.Element == UInt8 {
    typealias Element = HTTPRequest
    private let bytes: S
    private var isComplete: Bool = false

    init(bytes: S) {
        self.bytes = bytes
    }

    func makeAsyncIterator() -> HTTPRequestSequence { self }

    mutating func next() async throws -> HTTPRequest? {
        guard !isComplete else { return nil }
        let request = try await HTTPRequestDecoder.decodeRequest(from: bytes)
        isComplete = !request.shouldKeepAlive
        return request
    }
}