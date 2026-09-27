import OmakaseStore
import SwiftData
import SwiftUI

/// A sidebar row: its title and symbol, and for the Inbox the count of what
/// waits there (#225). A zero badge is hidden.
public struct SidebarRowView: View {
    private let item: SidebarItem
    @Query(filter: #Predicate<TaskRecord> { $0.scheduledDay == nil && !$0.isCompleted })
    private var inbox: [TaskRecord]

    public init(item: SidebarItem) { self.item = item }

    public var body: some View {
        Label(item.title, systemImage: item.symbol)
            .badge(item == .inbox ? InboxModel.badge(count: inbox.count) : 0)
    }
}
