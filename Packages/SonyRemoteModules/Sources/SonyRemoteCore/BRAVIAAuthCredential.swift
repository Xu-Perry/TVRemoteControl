public enum BRAVIAAuthCredential: Sendable, Equatable {
    case psk(String)
    case cookie(String)

    public var headerName: String {
        switch self {
        case .psk: "X-Auth-PSK"
        case .cookie: "Cookie"
        }
    }

    public var headerValue: String {
        switch self {
        case .psk(let value): value
        case .cookie(let value): value
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .psk(let value): value.isEmpty
        case .cookie(let value): value.isEmpty
        }
    }
}
