import Foundation

/// The site's video search, called the way its own search page calls it: 25 videos a page,
/// as she scrolls, with her cookies so the results match her account.
struct Catalog {
    static let pageSize = 25

    struct Page: Sendable {
        var videos: [VideoInfo]
    }

    func search(_ text: String, offset: Int, cookies: [HTTPCookie]) async throws -> Page {
        let query = Query(freeText: text, count: Self.pageSize, offset: offset)
        let json = String(decoding: try JSONEncoder().encode(query), as: UTF8.self)
        var components = URLComponents(url: RawUmber.searchEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "json", value: json)]

        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpShouldHandleCookies = false
        for (field, value) in HTTPCookie.requestHeaderFields(with: cookies) {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return Page(videos: decoded.videos.map(\.info))
    }

    private struct Query: Encodable {
        var freeText: String
        var count: Int
        var offset: Int

        enum CodingKeys: String, CodingKey {
            case freeText = "FreeText"
            case count = "Count"
            case offset = "Offset"
        }
    }

    private struct Response: Decodable {
        var videos: [RemoteVideo]
    }

    /// The fields Easel uses from the search results; the rest are ignored.
    private struct RemoteVideo: Decodable {
        struct Tutor: Decodable {
            var name: String?
        }

        var id: Int
        var slug: String
        var title: String?
        var thumbnail: String?
        var description: String?
        var tutor: Tutor?
        var dateLive: String?
        var duration: Int?
        var isSeries: Bool?
        var inTheFuture: Bool?

        var info: VideoInfo {
            VideoInfo(
                id: id,
                slug: slug,
                title: title ?? slug,
                tutor: tutor?.name ?? "",
                thumbnail: thumbnail ?? "",
                summary: description ?? "",
                dateLive: dateLive.flatMap(VideoInfo.parseDate),
                durationMinutes: duration ?? 0,
                isSeries: isSeries ?? false,
                isUpcoming: inTheFuture ?? false
            )
        }
    }
}
