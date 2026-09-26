import Testing

@testable import OmakaseFeatures

/// One way to write a length of time, shared by the Review summary and the
/// Focus header's workload line (#192).
struct MinutesTextTests {
    @Test(arguments: [(0, "0m"), (45, "45m"), (60, "1h"), (120, "2h"), (90, "1h 30m"), (725, "12h 5m")])
    func formatsMinutesAsHoursAndMinutes(minutes: Int, expected: String) {
        #expect(MinutesText.format(minutes) == expected)
    }
}
