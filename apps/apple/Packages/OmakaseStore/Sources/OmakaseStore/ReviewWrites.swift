import Foundation
import OmakaseAPI
import SwiftData

/// The day's review: saved locally at once, then PUT by date, which replays
/// safely (#144).
///
///     try ReviewWrites(context: ctx).save(day: "2026-03-07", rating: 4, win: "", energy: 2, shutdown: true)
@MainActor
public final class ReviewWrites {
    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    public func save(day: String, rating: Int?, win: String, energy: Int?, shutdown: Bool) throws {
        let record = try review(on: day)
        (record.rating, record.win, record.energy, record.isShutdown) = (rating, win, energy, shutdown)
        let body = ReviewBody(productivityRating: rating, winOfTheDay: win, energy: energy, isShutdown: shutdown)
        try queue.enqueue(
            kind: "review.put", method: "PUT", path: "/api/v1/stats/reviews/by-date/\(day)/",
            body: try OmakaseJSON.encoder.encode(body), subjectID: DailyReviewRecord.subjectID(for: day))
        try context.save()
    }

    private func review(on day: String) throws -> DailyReviewRecord {
        let found = try context.fetch(FetchDescriptor<DailyReviewRecord>(predicate: #Predicate { $0.day == day }))
        if let existing = found.first { return existing }
        let record = DailyReviewRecord(day: day)
        context.insert(record)
        return record
    }

    /// The PUT is partial: an omitted key keeps the server's value. So every
    /// key is written, and a cleared rating or energy goes as an explicit null;
    /// a synthesized Encodable would omit nil and clear nothing.
    private struct ReviewBody: Encodable {
        let productivityRating: Int?
        let winOfTheDay: String
        let energy: Int?
        let isShutdown: Bool

        enum CodingKeys: String, CodingKey { case productivityRating, winOfTheDay, energy, isShutdown }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(productivityRating, forKey: .productivityRating)
            try container.encode(winOfTheDay, forKey: .winOfTheDay)
            try container.encode(energy, forKey: .energy)
            try container.encode(isShutdown, forKey: .isShutdown)
        }
    }
}

/// The server's copy of the review replaces the local one, unless a later write is queued.
@MainActor
public final class ReviewHandler: OutboxHandler {
    public let kinds = ["review.put"]
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(DailyReviewDTO.self, from: body) else { return }
        let day = dto.date.string
        let subject = DailyReviewRecord.subjectID(for: day)
        guard !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [subject]),
            let record = try? context.fetch(FetchDescriptor<DailyReviewRecord>(predicate: #Predicate { $0.day == day }))
                .first
        else { return }
        record.apply(dto)
    }
}
