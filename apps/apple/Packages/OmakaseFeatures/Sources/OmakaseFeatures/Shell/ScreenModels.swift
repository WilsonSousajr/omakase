/// Every model `MainWindowView`'s detail, sidebar and toolbar read, bundled
/// so the window takes one parameter instead of one per screen. Optional exactly as
/// the app produces them today: nil until `start()` finishes wiring the
/// screens, non-nil for the rest of the window's life.
///
///     MainWindowView(day: FocusDay().today, models: screenModels, openCapture: { capture?.show(context: $0) })
public struct ScreenModels {
    public let focus: FocusModel?
    public let review: ReviewModel?
    public let plan: PlanModel?
    public let inbox: TriageModel?
    public let projects: ProjectsModel?
    public let study: StudyModel?
    public let calendarOverlay: CalendarOverlayModel?
    public let timer: TimerModel?
    public let failedWrites: FailedWritesModel?
    /// A place's task list (spec §5, #259): nil until `start()` wires it, as the rest are.
    public let places: PlaceListModel?
    /// The sidebar footer's account (spec §6, #260): its address, read as Settings reads it.
    public let settings: SettingsModel?

    public init(
        focus: FocusModel? = nil, review: ReviewModel? = nil, plan: PlanModel? = nil, inbox: TriageModel? = nil,
        projects: ProjectsModel? = nil, study: StudyModel? = nil, calendarOverlay: CalendarOverlayModel? = nil,
        timer: TimerModel? = nil, failedWrites: FailedWritesModel? = nil, places: PlaceListModel? = nil,
        settings: SettingsModel? = nil
    ) {
        (self.focus, self.review, self.plan, self.inbox) = (focus, review, plan, inbox)
        (self.projects, self.study, self.calendarOverlay) = (projects, study, calendarOverlay)
        (self.timer, self.failedWrites, self.places, self.settings) = (timer, failedWrites, places, settings)
    }
}
