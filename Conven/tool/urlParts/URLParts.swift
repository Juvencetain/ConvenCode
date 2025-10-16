import Foundation

struct URLParts {
    let scheme: String
    let host: String
    let path: String
    let queryItems: [URLQueryItem]
}

enum URLParserError: Error, LocalizedError {
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL 格式"
        }
    }
}

class URLParser {
    func parse(urlString: String) -> Result<URLParts, URLParserError> {
        guard let url = URL(string: urlString), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.invalidURL)
        }
        
        let scheme = components.scheme ?? "N/A"
        let host = components.host ?? "N/A"
        let path = components.path
        let queryItems = components.queryItems ?? []
        
        let parts = URLParts(scheme: scheme, host: host, path: path, queryItems: queryItems)
        return .success(parts)
    }
}