import Foundation
import WidgetKit

/// Takes what the phone pushed for the complications: keeps it where the
/// widget reads it and asks WidgetKit for a new timeline.
enum ComplicationUpdates {
  static func receive(_ payload: [String: Any], store: ComplicationStore = .shared) {
    guard let update = ComplicationUpdate(payload: payload) else { return }
    store.apply(update) { id in
      FileChatCache.standard.threads()?.first { $0.id == id }?.title
    }
    WidgetCenter.shared.reloadAllTimelines()
  }
}
