/// The confirmation before signing out (#224): the store and the outbox are
/// erased, so any change the server hasn't taken is lost.
///
///     SignOutWarning.message(unsent: 2)   // "2 changes haven't reached …"
public enum SignOutWarning {
    public static let title = "Sign out of Omakase?"
    public static let confirm = "Sign Out"

    public static func message(unsent: Int) -> String {
        let copy = "This Mac's copy of your data is removed. It stays on the server."
        guard unsent > 0 else { return copy }
        let lost =
            unsent == 1
            ? "1 change hasn't reached the server and will be lost."
            : "\(unsent) changes haven't reached the server and will be lost."
        return "\(lost) \(copy)"
    }
}
