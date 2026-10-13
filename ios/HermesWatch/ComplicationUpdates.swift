import Foundation
import WidgetKit

/// Takes what the phone pushed for the complications: keeps it where the
/// widget reads it and asks WidgetKit for a new timeline.
enum ComplicationUpdates {
  static func clear(store: ComplicationStore = .shared) {
    store.apply(.clear)
    WidgetCenter.shared.reloadAllTimelines()
  }

  static func receive(_ payload: [String: Any], store: ComplicationStore = .shared) {
    guard let context = UserDefaults.standard.string(forKey: "watch.session.context"),
      payload["contextId"] as? String == context,
      payload["revision"] as? Int == UserDefaults.standard.integer(forKey: "watch.session.revision") else { return }
    if let id = payload["threadId"] as? String,
      WatchThreadId.decode(id)?.contextId != UserDefaults.standard.string(forKey: "watch.session.context") { return }
    guard let update = ComplicationUpdate(payload: payload) else { return }
    guard store.apply(update, seq: ComplicationUpdate.seq(of: payload)) else { return }
    WidgetCenter.shared.reloadAllTimelines()
  }
}
