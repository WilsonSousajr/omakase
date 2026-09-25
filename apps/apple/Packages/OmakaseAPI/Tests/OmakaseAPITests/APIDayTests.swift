import Foundation
import Testing

@testable import OmakaseAPI

struct APIDayTests {
    private let saoPaulo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    @Test func formatsTheUsersDayNotUTCs() {
        // 2026-03-08 01:30 UTC is still 2026-03-07 in Sao Paulo (UTC-3): the
        // server would say the 8th, the user means the 7th (#65).
        let instant = Date(timeIntervalSince1970: 1_772_933_400)
        #expect(APIDay(date: instant, calendar: saoPaulo).string == "2026-03-07")
    }

    @Test func parsesOnlyTheWireFormat() {
        #expect(APIDay(string: "2026-03-07")?.string == "2026-03-07")
        #expect(APIDay(string: "20260307") == nil)
        #expect(APIDay(string: "2026-02-30") == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        let day = try #require(APIDay(string: "2026-03-07"))
        let data = try JSONEncoder().encode([day])
        #expect(String(bytes: data, encoding: .utf8) == #"["2026-03-07"]"#)
        #expect(try JSONDecoder().decode([APIDay].self, from: data) == [day])
    }

    @Test func todayIsTheCalendarDayOfNow() {
        let instant = Date(timeIntervalSince1970: 1_772_933_400)
        #expect(APIDay.today(calendar: saoPaulo, now: instant).string == "2026-03-07")
    }

    @Test func daysOrderChronologically() throws {
        let earlier = try #require(APIDay(string: "2026-03-07"))
        let later = try #require(APIDay(string: "2026-12-01"))
        #expect(earlier < later && !(later < earlier))
    }

    @Test func decodingAMalformedDayNamesTheValue() {
        let json = Data(#"["2026-3-7"]"#.utf8)
        #expect {
            try JSONDecoder().decode([APIDay].self, from: json)
        } throws: { error in
            String(describing: error).contains("\"2026-3-7\" is not YYYY-MM-DD")
        }
    }
}
