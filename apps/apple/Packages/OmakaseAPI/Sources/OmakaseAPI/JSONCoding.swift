import Foundation

/// JSON as the API speaks it: snake_case keys, ISO-8601 datetimes in UTC
/// with 0-6 fractional digits (DRF emits microseconds).
public enum OmakaseJSON {
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseDatetime(raw) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "\(raw.debugDescription) is not an ISO-8601 datetime"))
            }
            return date
        }
        return decoder
    }()

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    /// Truncates the fraction to milliseconds, then parses: ISO8601DateFormatter
    /// does not accept six fractional digits on every OS version.
    static func parseDatetime(_ raw: String) -> Date? {
        let millis = raw.replacing(/\.(\d{1,3})\d*/) { ".\($0.1)" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =
            millis.contains(".") ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.date(from: millis)
    }
}
