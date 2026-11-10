import Foundation
import Testing

@testable import Easel

struct VideoInfoTests {
    @Test func readsTheSitesCompactForm() throws {
        let video = try #require(
            VideoInfo(site: [
                "id": 42, "slug": "portrait-of-anna",
                "title": "Anna: An online portrait drawing session",
                "tutor": "Luca", "duration": 120, "dateLive": "2026-11-08T19:00:00Z",
            ]))
        #expect(video.id == 42)
        #expect(video.displayTitle == "Anna")
        #expect(video.sessionKind == "Portrait")
        #expect(video.durationMinutes == 120)
        #expect(video.dateLive == Date(timeIntervalSince1970: 1_794_164_400))
    }

    @Test func needsASlug() {
        #expect(VideoInfo(site: ["id": 1, "title": "No slug"]) == nil)
        #expect(VideoInfo(site: ["slug": ""]) == nil)
    }

    @Test func parsesDatesWithAndWithoutFractionalSeconds() {
        #expect(VideoInfo.parseDate("2026-11-08T19:00:00Z") != nil)
        #expect(VideoInfo.parseDate("2026-11-08T19:00:00.123Z") != nil)
        #expect(VideoInfo.parseDate("8 November") == nil)
    }

    @Test func keepsTitlesThatAreNotWeeklySessions() {
        let video = VideoInfo(id: 1, slug: "s", title: "Painting skin tones")
        #expect(video.displayTitle == "Painting skin tones")
        #expect(video.sessionKind == nil)
    }
}

@MainActor
struct SearchQueryTests {
    private func body(_ query: SearchQuery, offset: Int = 0) throws -> [String: Any] {
        let json = query.json(offset: offset, count: SiteAPI.pageSize)
        return try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    @Test func asksForOnePageOf25() throws {
        let sent = try body(SearchQuery(text: "  hands  "), offset: 50)
        #expect(sent["Count"] as? Int == 25)
        #expect(sent["Offset"] as? Int == 50)
        #expect(sent["FreeText"] as? String == "hands")
        #expect(sent["Materials"] == nil)
    }

    @Test func sendsTheChosenFilters() throws {
        let query = SearchQuery(materials: [.pencil, .charcoal], type: .short)
        let sent = try body(query)
        #expect(sent["Materials"] as? [String] == ["Charcoal", "Pencil"])
        #expect(sent["VideoTypes"] as? [String] == ["Short"])
        #expect(!query.isEmpty)
        #expect(SearchQuery(text: "   ").isEmpty)
    }
}

struct TimecodeTests {
    @Test func formatsPlaybackTimes() {
        #expect(Timecode.string(0) == "0:00")
        #expect(Timecode.string(.nan) == "0:00")
        #expect(Timecode.string(754.9) == "12:34")
        #expect(Timecode.string(3723) == "1:02:03")
    }

    @Test func roundsTheTimeLeftUp() {
        #expect(Timecode.remaining(10) == "1 min left")
        #expect(Timecode.remaining(61) == "2 min left")
        #expect(Timecode.remaining(1380) == "23 min left")
    }
}
