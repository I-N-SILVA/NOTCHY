import Foundation

/// A `URLProtocol` stub for intercepting requests in tests. Install it on an
/// ephemeral `URLSessionConfiguration` and set `requestHandler` to return a
/// canned `(HTTPURLResponse, Data)` (or throw) per request.
final class MockURLProtocol: URLProtocol {

    /// Inspect the outgoing request and return the response + body to deliver,
    /// or throw to simulate a transport failure.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() { requestHandler = nil }

    /// Build a session whose traffic is fully handled by this protocol.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Convenience for building an `HTTPURLResponse` for a URL + status code.
    static func response(_ url: URL, _ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
