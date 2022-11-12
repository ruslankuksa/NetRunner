
import Foundation

enum ParametersEncodingType {
    case httpBody
    case queryString
}

protocol ParametersEncoder {
    func encode(parameters: Parameters?, request: URLRequest) throws -> URLRequest
    func encode<Parameters: Encodable>(_ parameters: Parameters, request: URLRequest) throws -> URLRequest
}

open class JSONParametersEncoder {
    
    let encoder: JSONEncoder
    
    public static var `default`: JSONParametersEncoder { JSONParametersEncoder() }
    
    public static var prettyPrinted: JSONParametersEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        return JSONParametersEncoder(encoder: encoder)
    }
    
    public static var sortedKeys: JSONParametersEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        return JSONParametersEncoder(encoder: encoder)
    }
    
    init(encoder: JSONEncoder = JSONEncoder(), parametersEncodingType: ParametersEncodingType = .httpBody) {
        self.encoder = encoder
    }
}
