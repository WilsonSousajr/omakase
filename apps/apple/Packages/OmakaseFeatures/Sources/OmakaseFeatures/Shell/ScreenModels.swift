/// Every model `MainWindowView`'s detail and toolbar read, bundled so the
/// window takes one parameter instead of one per screen. Optional exactly as
/// the app produces them today: nil until `start()` finishes wiring the
/// screens, non-nil for the rest of the window's life.
///
///     MainWindowView(day: FocusDay().today, models: screenModels)
public struct ScreenModels {
    public let focus: FocusModel?
    public let review: ReviewModel?
    public let plan: PlanModel?
    public let inbox: InboxModel?
    public let projects: ProjectsModel?
    public let study: StudyModel?
    public let calendarOverlay: CalendarOverlayModel?
    public let timer: TimerModel?
    public let failedWrites: FailedWritesModel?

    public init(
        focus: FocusModel? = nil, review: ReviewModel? = nil, plan: PlanModel? = nil, inbox: InboxModel? = nil,
        projects: ProjectsModel? = nil, study: StudyModel? = nil, calendarOverlay: CalendarOverlayModel? = nil,
        timer: TimerModel? = nil, failedWrites: FailedWritesModel? = nil
    ) {
        (self.focus, self.review, self.plan, self.inbox) = (focus, review, plan, inbox)
        (self.projects, self.study, self.calendarOverlay) = (projects, study, calendarOverlay)
        (self.timer, self.failedWrites) = (timer, failedWrites)
    }
}
