import SwiftUI
import WidgetKit

@main
struct HermesComplicationBundle: WidgetBundle {
  var body: some Widget {
    HermesVoiceChat()
    HermesChatStatus()
  }
}

// MARK: - Voice Chat

/// Starts a voice message in a new chat: a tap on the circular or corner
/// complication opens the watch app on it.
struct HermesVoiceChat: Widget {
  static let kind = "HermesVoiceChat"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: VoiceProvider()) { _ in
      VoiceChatView()
    }
    .configurationDisplayName("Voice Chat")
    .description("Starts a voice message to Hermes.")
    .supportedFamilies([.accessoryCircular, .accessoryCorner])
  }
}

private struct VoiceEntry: TimelineEntry {
  let date: Date
}

private struct VoiceProvider: TimelineProvider {
  func placeholder(in context: Context) -> VoiceEntry { VoiceEntry(date: .now) }

  func getSnapshot(in context: Context, completion: @escaping (VoiceEntry) -> Void) {
    completion(VoiceEntry(date: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<VoiceEntry>) -> Void) {
    completion(Timeline(entries: [VoiceEntry(date: .now)], policy: .never))
  }
}

private struct VoiceChatView: View {
  @Environment(\.widgetFamily) private var family

  var body: some View {
    Group {
      switch family {
      case .accessoryCorner:
        Image(systemName: "mic.fill")
          .font(.title2)
          .widgetLabel("Voice Chat")
      default:
        ZStack {
          AccessoryWidgetBackground()
          Image(systemName: "mic.fill").font(.title3)
        }
      }
    }
    .widgetAccentable()
    .widgetURL(ComplicationLink.voice.url)
    .containerBackground(.clear, for: .widget)
  }
}

// MARK: - Chat status

/// The latest chat and what Hermes is doing with it. The rectangular
/// complication and the Smart Stack show it, and the Smart Stack raises it
/// while the user is needed.
struct HermesChatStatus: Widget {
  static let kind = "HermesChatStatus"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: StatusProvider()) { entry in
      ChatStatusView(entry: entry)
    }
    .configurationDisplayName("Chat status")
    .description("The latest chat, and whether Hermes needs you.")
    .supportedFamilies([.accessoryRectangular])
  }
}

struct StatusEntry: TimelineEntry {
  let date: Date
  let status: ComplicationStatus?
  let relevance: TimelineEntryRelevance?

  init(_ entry: ComplicationEntry) {
    date = entry.date
    status = entry.status
    relevance = entry.relevance > 0
      ? TimelineEntryRelevance(score: Float(entry.relevance), duration: entry.duration ?? 0) : nil
  }

  init(date: Date, status: ComplicationStatus?) {
    self.date = date
    self.status = status
    relevance = nil
  }
}

struct StatusProvider: TimelineProvider {
  private static let sample = ComplicationStatus(
    state: .working, updatedAt: .now, title: "Why is the nightly backup slow?", threadId: nil)

  func placeholder(in context: Context) -> StatusEntry {
    StatusEntry(date: .now, status: Self.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
    completion(StatusEntry(date: .now, status: context.isPreview ? Self.sample : ComplicationStore.shared.status()))
  }

  // Nothing renews the timeline on its own: the watch app reloads it when the
  // phone sends a status, and the plan ends with a quiet entry for the time a
  // status stops being believed.
  func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
    let plan = ComplicationTimeline.plan(for: ComplicationStore.shared.status(), now: .now)
    completion(Timeline(entries: plan.map(StatusEntry.init), policy: .never))
  }
}

extension ComplicationStatus.State {
  var symbol: String {
    switch self {
    case .working: "sparkles"
    case .waiting: "hand.raised.fill"
    case .ready: "checkmark.circle.fill"
    case .failed: "xmark.octagon.fill"
    }
  }
}

struct ChatStatusView: View {
  let entry: StatusEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let status = entry.status {
        Label(status.state.label, systemImage: status.state.symbol)
          .font(.headline)
          .widgetAccentable()
          .lineLimit(1)
        Text(status.title ?? "Hermes")
          .font(.footnote)
          .lineLimit(2)
      } else {
        Label("Hermes", systemImage: "bubble.left.and.bubble.right")
          .font(.headline)
          .widgetAccentable()
        Text("No recent chat")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(link.url)
    .containerBackground(.fill.tertiary, for: .widget)
  }

  private var link: ComplicationLink {
    guard let status = entry.status, let id = status.threadId else { return .open }
    return .chat(id: id, title: status.title)
  }
}
