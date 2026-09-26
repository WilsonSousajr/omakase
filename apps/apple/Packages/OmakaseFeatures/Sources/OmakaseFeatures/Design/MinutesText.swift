/// A length of time as the app writes it: "45m", "2h", "1h 30m".
///
///     MinutesText.format(90)   // "1h 30m"
enum MinutesText {
    static func format(_ minutes: Int) -> String {
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        guard hours > 0 else { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}
