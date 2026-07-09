
import Foundation

enum QueryItemBuilder {
    static func buildQueryItems(from parameters: QueryParameters, encoding: ArrayEncoding) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []

        for (key, value) in parameters {
            switch value {
            case .array(let values):
                switch encoding {
                case .brackets:
                    let bracketedKey = key.hasSuffix("[]") ? key : "\(key)[]"
                    for item in values {
                        queryItems.append(URLQueryItem(name: bracketedKey, value: item.stringValue))
                    }
                case .noBrackets:
                    let cleanKey = key.replacingOccurrences(of: "[]", with: "")
                    for item in values {
                        queryItems.append(URLQueryItem(name: cleanKey, value: item.stringValue))
                    }
                case .commaSeparated:
                    let cleanKey = key.replacingOccurrences(of: "[]", with: "")
                    let commaSeparatedValue = values.map(\.stringValue).joined(separator: ",")
                    queryItems.append(URLQueryItem(name: cleanKey, value: commaSeparatedValue))
                }
            default:
                queryItems.append(URLQueryItem(name: key, value: value.stringValue))
            }
        }

        return queryItems
    }
}
