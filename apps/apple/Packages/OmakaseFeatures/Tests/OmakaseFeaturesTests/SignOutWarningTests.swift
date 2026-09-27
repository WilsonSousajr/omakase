import Testing

@testable import OmakaseFeatures

/// Signing out erases the Mac's copy, so the confirmation says what is lost (#224).
struct SignOutWarningTests {
    @Test func nothingUnsentSaysTheCopyGoes() {
        #expect(SignOutWarning.message(unsent: 0) == "This Mac's copy of your data is removed. It stays on the server.")
    }

    @Test func unsentWritesAreCountedAsLost() {
        #expect(SignOutWarning.message(unsent: 1).hasPrefix("1 change hasn't reached the server and will be lost."))
        #expect(SignOutWarning.message(unsent: 3).hasPrefix("3 changes haven't reached the server and will be lost."))
    }
}
