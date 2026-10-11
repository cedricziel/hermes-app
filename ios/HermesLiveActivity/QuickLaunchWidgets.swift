import SwiftUI
import WidgetKit

// New Chat, Dictate and the Quick launch pair. Without App Intents a widget
// cannot be configured, so each launch is its own widget. They show no chat
// content; the snapshot only tells them whether anyone is signed in.

struct HermesNewChat: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HermesNewChat", provider: SurfaceProvider()) { entry in
      QuickLaunchView(entry: entry, actions: [.newChat])
    }
    .configurationDisplayName("New Chat")
    .description("Start a new chat in Hermes.")
    .supportedFamilies([.accessoryCircular, .systemSmall])
  }
}

struct HermesDictate: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HermesDictate", provider: SurfaceProvider()) { entry in
      QuickLaunchView(entry: entry, actions: [.dictate])
    }
    .configurationDisplayName("Dictate")
    .description("Start a new chat and speak your message.")
    .supportedFamilies([.accessoryCircular, .systemSmall])
  }
}

struct HermesQuickLaunch: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HermesQuickLaunch", provider: SurfaceProvider()) { entry in
      QuickLaunchView(entry: entry, actions: [.newChat, .dictate])
    }
    .configurationDisplayName("Quick launch")
    .description("New Chat and Dictate side by side.")
    .supportedFamilies([.systemMedium])
  }
}

struct QuickLaunchView: View {
  @Environment(\.widgetFamily) private var widgetFamily
  let entry: SurfaceEntry
  let actions: [QuickLaunchAction]

  var body: some View {
    let model = QuickLaunchModel(snapshot: entry.snapshot, actions: actions, now: entry.date)
    switch widgetFamily {
    case .accessoryCircular:
      CircularButton(button: model.buttons[0], isSignedOut: model.status.isSignedOut)
        .widgetURL(model.url)
        .containerBackground(.clear, for: .widget)
    case .systemMedium:
      HStack(spacing: 12) {
        ForEach(model.buttons) { button in
          Link(destination: button.url) { LaunchButton(button: button) }
        }
      }
      .containerBackground(.background, for: .widget)
    default:
      LaunchButton(button: model.buttons[0])
        .widgetURL(model.url)
        .containerBackground(.background, for: .widget)
    }
  }
}

private struct CircularButton: View {
  let button: QuickLaunchModel.Button
  let isSignedOut: Bool

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      if isSignedOut {
        VStack(spacing: 0) {
          Image(systemName: button.symbol).font(.caption)
          Text(button.label).font(.system(size: 9, weight: .semibold))
        }
      } else {
        Image(systemName: button.symbol)
          .font(.title2.weight(.semibold))
      }
    }
    .widgetAccentable()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(button.label)
  }
}

private struct LaunchButton: View {
  let button: QuickLaunchModel.Button

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: button.symbol)
        .font(.system(size: 30, weight: .semibold))
        .foregroundStyle(.orange)
      Text(button.label)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
    }
    .widgetAccentable()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .accessibilityElement(children: .combine)
  }
}
