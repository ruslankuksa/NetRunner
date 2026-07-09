import Foundation

/// Per-request configuration that applies to URL construction and response decoding.
public struct RequestOptions: Sendable {
    /// How array query parameters are encoded.
    public var arrayEncoding: ArrayEncoding
    /// The cache policy applied to the generated `URLRequest`.
    public var cachePolicy: URLRequest.CachePolicy
    /// A response decoder override for this request.
    public var responseDecoder: JSONDecoder?

    /// Creates request options.
    public init(
        arrayEncoding: ArrayEncoding = .brackets,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        responseDecoder: JSONDecoder? = nil
    ) {
        self.arrayEncoding = arrayEncoding
        self.cachePolicy = cachePolicy
        self.responseDecoder = responseDecoder
    }

    /// The default request options.
    public static let `default` = RequestOptions()
}
