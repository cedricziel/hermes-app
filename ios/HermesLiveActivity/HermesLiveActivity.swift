import ActivityKit
import SwiftUI
import WidgetKit

// The live_activities plugin creates activities of a type with exactly this
// name and keeps their values in the App Group's UserDefaults, under keys
// prefixed with the activity's id.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {}

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

private let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
  ?? "group.com.cedricziel.hermesApp"

/// What the app last wrote for one activity. Only a title and a fixed label:
/// nothing a reply, command or question said reaches the Lock Screen.
struct ReplyActivity {
  let title: String
  let state: String
  let label: String
  let startedAt: Date
  let url: URL?

  init(_ attributes: LiveActivitiesAppAttributes) {
    let defaults = UserDefaults(suiteName: appGroup)
    func string(_ key: String) -> String {
      defaults?.string(forKey: attributes.prefixedKey(key)) ?? ""
    }
    title = string("title").isEmpty ? "Hermes" : string("title")
    state = string("state")
    label = string("label").isEmpty ? "Working" : string("label")
    let millis = defaults?.double(forKey: attributes.prefixedKey("startedAt")) ?? 0
    startedAt = millis > 0 ? Date(timeIntervalSince1970: millis / 1000) : .now
    var components = URLComponents()
    components.scheme = "hermes-activity"
    components.host = "open"
    components.queryItems = [
      URLQueryItem(name: "thread", value: string("threadId")),
      URLQueryItem(name: "profile", value: string("profile")),
    ]
    url = components.url
  }

  var working: Bool { state == "working" }
  var finished: Bool { state == "ready" || state == "failed" }

  var symbol: String {
    switch state {
    case "approval": "hand.raised.fill"
    case "question": "questionmark.bubble.fill"
    case "needsYou": "exclamationmark.bubble.fill"
    case "ready": "checkmark.circle.fill"
    case "failed": "xmark.octagon.fill"
    default: "sparkles"
    }
  }

  var tint: Color {
    switch state {
    case "ready": .green
    case "failed": .red
    case "approval", "question", "needsYou": .orange
    default: .accentColor
    }
  }
}

@main
struct HermesLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    HermesReplyActivity()
  }
}

struct HermesReplyActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      let reply = ReplyActivity(context.attributes)
      LockScreenView(reply: reply, stale: context.isStale)
        .widgetURL(reply.url)
        .activityBackgroundTint(nil)
    } dynamicIsland: { context in
      let reply = ReplyActivity(context.attributes)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: reply.symbol)
            .foregroundStyle(reply.tint)
            .font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if reply.working {
            Text(timerInterval: reply.startedAt...Date.distantFuture, countsDown: false)
              .monospacedDigit()
              .frame(maxWidth: 64)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 2) {
            Text(reply.title).font(.headline).lineLimit(1)
            Text(reply.label).font(.subheadline).foregroundStyle(.secondary)
            if context.isStale && !reply.finished {
              Text("Open Hermes for the latest").font(.caption).foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        Image(systemName: reply.symbol).foregroundStyle(reply.tint)
      } compactTrailing: {
        if reply.working {
          Text(timerInterval: reply.startedAt...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .frame(maxWidth: 44)
        } else {
          Text(reply.finished ? "Done" : "Waiting").font(.caption2)
        }
      } minimal: {
        Image(systemName: reply.symbol).foregroundStyle(reply.tint)
      }
      .widgetURL(reply.url)
    }
  }
}

struct LockScreenView: View {
  let reply: ReplyActivity
  let stale: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: reply.symbol)
        .font(.title2)
        .foregroundStyle(reply.tint)
      VStack(alignment: .leading, spacing: 2) {
        Text(reply.title).font(.headline).lineLimit(1)
        Text(reply.label).font(.subheadline).foregroundStyle(.secondary)
        if stale && !reply.finished {
          Text("Open Hermes for the latest").font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 0)
      if reply.working {
        Text(timerInterval: reply.startedAt...Date.distantFuture, countsDown: false)
          .monospacedDigit()
          .font(.subheadline)
          .frame(maxWidth: 64, alignment: .trailing)
      }
    }
    .padding(16)
  }
}
