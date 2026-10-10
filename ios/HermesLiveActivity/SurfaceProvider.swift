import SwiftUI
import WidgetKit

/// One moment of a widget: the snapshot as the app last wrote it, or `nil`
/// when there is none.
struct SurfaceEntry: TimelineEntry {
  let date: Date
  let snapshot: SurfaceSnapshot?

  static func sample(at date: Date = .now) -> SurfaceEntry {
    SurfaceEntry(date: date, snapshot: .sample(now: date))
  }
}

/// Reads the surface snapshot from the App Group. The app reloads the
/// timelines after each write, so the timeline never expires by itself; its
/// extra entries only let a widget notice, with no app running, that the
/// snapshot turned stale or that the next scheduled run came due.
struct SurfaceProvider: TimelineProvider {
  var followsNextRun = false

  func placeholder(in context: Context) -> SurfaceEntry {
    .sample()
  }

  // The gallery gets made-up content so the user's own chats never show there.
  func getSnapshot(in context: Context, completion: @escaping (SurfaceEntry) -> Void) {
    completion(context.isPreview ? .sample() : entries(now: .now)[0])
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SurfaceEntry>) -> Void) {
    completion(Timeline(entries: entries(now: .now), policy: .never))
  }

  private func entries(now: Date) -> [SurfaceEntry] {
    let snapshot = SurfaceSnapshot.load(appGroup: appGroup)
    return SurfaceTimeline.dates(snapshot: snapshot, now: now, followsNextRun: followsNextRun)
      .map { SurfaceEntry(date: $0, snapshot: snapshot) }
  }
}

extension SurfaceFamily {
  init(_ family: WidgetFamily) {
    switch family {
    case .systemSmall: self = .small
    case .systemLarge, .systemExtraLarge: self = .large
    default: self = .medium
    }
  }
}
