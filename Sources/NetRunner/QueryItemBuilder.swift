
import Foundation

enum QueryItemBuilder {
    static func buildQueryItems(from parameters: QueryParameters, encoding: ArrayEncoding) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []

        for (key, value) in parameters {
            if let array = value as? [Any] {
                switch encoding {
                case .brackets:
                    for item in array {
                        queryItems.append(URLQueryItem(name: key, value: "\(item)"))
                    }
                case .noBrackets:
                    let cleanKey = key.replacingOccurrences(of: "[]", with: "")
                    for item in array {
                        queryItems.append(URLQueryItem(name: cleanKey, value: "\(item)"))
                    }
                case .commaSeparated:
                    let cleanKey = key.replacingOccurrences(of: "[]", with: "")
                    let commaSeparatedValue = array.map { "\($0)" }.joined(separator: ",")
                    queryItems.append(URLQueryItem(name: cleanKey, value: commaSeparatedValue))
                }
            } else {
                queryItems.append(URLQueryItem(name: key, value: "\(value)"))
            }
        }

        return queryItems
    }
}
