import SwiftUI
import Testing

@testable import OmakaseFeatures

/// Pins the named motion tokens and their Reduce Motion mapping (spec §2, §10).
struct MotionTests {
    @Test func resolvedKeepsTheAnimationWhenMotionIsAllowed() {
        #expect(Motion.resolved(Motion.select, reduceMotion: false) == Motion.select)
    }

    @Test func resolvedIsNilUnderReduceMotion() {
        #expect(Motion.resolved(Motion.select, reduceMotion: true) == nil)
    }

    @Test func digitsAreNumericTextByDefault() {
        #expect(Motion.digits(reduceMotion: false) == .numericText())
    }

    @Test func digitsAreIdentityUnderReduceMotion() {
        #expect(Motion.digits(reduceMotion: true) == .identity)
    }

    @Test func performRunsItsBody() {
        var ran = false
        Motion.perform(Motion.layout, reduceMotion: true) { ran = true }
        #expect(ran)
    }
}
