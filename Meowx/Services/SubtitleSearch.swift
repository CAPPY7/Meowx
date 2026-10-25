import Foundation

struct SubtitleHit: Identifiable, Equatable {
    let fileID: Int
    let language: String
    let title: String
    var id: Int { fileID }
}

enum SubtitleSearchError: LocalizedError {
    case missingKey
    case badResponse(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add your OpenSubtitles API key in Settings."
        case .badResponse(let status, let body):
            let detail = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty { return "OpenSubtitles returned \(status)." }
            return "OpenSubtitles returned \(status). \(detail.prefix(180))"
        }
    }
}

enum SubtitleSearch {
    static func search(apiKey: String, query: String, language: String) async throws -> [SubtitleHit] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw SubtitleSearchError.missingKey }
        var components = URLComponents(string: "https://api.opensubtitles.com/api/v1/subtitles")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "languages", value: language.isEmpty ? "en" : language)
        ]
        let (data, response) = try await URLSession.shared.data(for: request(url: components.url!, apiKey: key))
        try validate(data: data, response: response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rows = json?["data"] as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let attributes = row["attributes"] as? [String: Any],
                  let files = attributes["files"] as? [[String: Any]],
                  let fileID = files.first?["file_id"] as? Int else { return nil }
            let feature = attributes["feature_details"] as? [String: Any]
            let name = (feature?["movie_name"] as? String)
                ?? (attributes["release"] as? String)
                ?? "Subtitle"
            let language = (attributes["language"] as? String) ?? ""
            return SubtitleHit(fileID: fileID, language: language, title: name)
        }
    }

    static func download(apiKey: String, fileID: Int) async throws -> URL {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw SubtitleSearchError.missingKey }
        let url = URL(string: "https://api.opensubtitles.com/api/v1/download")!
        var downloadRequest = request(url: url, apiKey: key)
        downloadRequest.httpMethod = "POST"
        downloadRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        downloadRequest.httpBody = try JSONSerialization.data(withJSONObject: ["file_id": fileID])
        let (data, response) = try await URLSession.shared.data(for: downloadRequest)
        try validate(data: data, response: response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let link = json?["link"] as? String, let fileURL = URL(string: link) else {
            throw SubtitleSearchError.badResponse(200, "Download link was missing.")
        }
        let (fileData, fileResponse) = try await URLSession.shared.data(from: fileURL)
        try validate(data: fileData, response: fileResponse)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("meowx-\(fileID).srt")
        try fileData.write(to: destination, options: .atomic)
        return destination
    }

    private static func request(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("Meowx v1.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SubtitleSearchError.badResponse(http.statusCode, body)
        }
    }
}
