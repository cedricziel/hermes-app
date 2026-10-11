import SwiftUI
import WidgetKit

struct HermesNeedsYou: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HermesNeedsYou", provider: SurfaceProvider()) { entry in
      NeedsYouView(entry: entry)
    }
    .configurationDisplayName("Needs you")
    .description("Approvals and questions waiting for you. Tap to open the oldest.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
  }
}

struct NeedsYouView: View {
  @Environment(\.widgetFamily) private var widgetFamily
  let entry: SurfaceEntry

  var body: some View {
    switch widgetFamily {
    case .accessoryCircular, .accessoryRectangular, .accessoryInline:
      NeedsYouAccessoryView(entry: entry)
    default:
      homeScreen
    }
  }

  private var homeScreen: some View {
    let family = SurfaceFamily(widgetFamily)
    let model = NeedsYouModel(snapshot: entry.snapshot, family: family, now: entry.date)
    return SurfaceFrame(title: "Needs you", symbol: "hand.raised", status: model.status, url: model.url) {
      if family == .small || model.isEmpty {
        Count(model: model)
      } else {
        HStack(alignment: .top, spacing: 16) {
          Count(model: model)
          VStack(alignment: .leading, spacing: 8) {
            ForEach(model.rows) { row in
              Link(destination: row.url) { RequestRow(row: row) }
            }
          }
        }
      }
    }
  }
}

/// The Lock Screen and StandBy forms. Only the chat title is private; the
/// count and the words stay readable on a locked device. VoiceOver is not
/// redacted, so the title is hidden from it and the spoken label holds none.
private struct NeedsYouAccessoryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SurfaceEntry

  var body: some View {
    let model = NeedsYouAccessoryModel(snapshot: entry.snapshot, now: entry.date)
    Group {
      switch family {
      case .accessoryCircular: circular(model)
      case .accessoryRectangular: rectangular(model)
      default: inline(model)
      }
    }
    .widgetURL(model.url)
    .containerBackground(.clear, for: .widget)
  }

  private func circular(_ model: NeedsYouAccessoryModel) -> some View {
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: 0) {
        Image(systemName: "hand.raised.fill")
          .font(.caption)
          .widgetAccentable()
        if model.status.isSignedOut {
          Text("Sign in")
            .font(.caption2.weight(.semibold))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        } else {
          Text("\(model.count)")
            .font(.system(.title2, design: .rounded, weight: .bold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(model.accessibilityLabel)
  }

  private func rectangular(_ model: NeedsYouAccessoryModel) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      VStack(alignment: .leading, spacing: 1) {
        Label(headline(model), systemImage: "hand.raised.fill")
          .font(.headline)
          .widgetAccentable()
          .lineLimit(1)
        Text(model.kindLabel ?? (model.status.isSignedOut ? "Open Hermes" : "Hermes"))
          .font(.caption)
          .lineLimit(1)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(model.accessibilityLabel)
      if !model.isEmpty && !model.status.isSignedOut {
        TitleText(title: model.title, font: .caption2)
          .accessibilityHidden(true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    // The card holds three lines in 76 pt, so it cannot grow with the largest
    // text sizes; the circular and inline forms scale on their own.
    .dynamicTypeSize(...DynamicTypeSize.xLarge)
  }

  private func inline(_ model: NeedsYouAccessoryModel) -> some View {
    Label(model.inlineText, systemImage: "hand.raised.fill")
      .accessibilityLabel(model.accessibilityLabel)
  }

  private func headline(_ model: NeedsYouAccessoryModel) -> String {
    if model.status.isSignedOut { return "Sign in" }
    return model.isEmpty ? "Nothing waiting" : "\(model.count) waiting"
  }
}

/// The number of open requests, or a word when there are none. Neither is
/// privacy sensitive: a count is not content.
private struct Count: View {
  let model: NeedsYouModel

  var body: some View {
    if model.isEmpty {
      Text("Nothing waiting").font(.subheadline.weight(.medium))
    } else {
      VStack(alignment: .leading, spacing: 0) {
        Text("\(model.count)")
          .font(.system(size: 44, weight: .bold, design: .rounded))
          .foregroundStyle(.orange)
          .contentTransition(.numericText())
        Text("waiting for you")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
    }
  }
}

private struct RequestRow: View {
  let row: NeedsYouModel.Row

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      TitleText(title: row.title)
      HStack(spacing: 6) {
        Text(NeedsYouModel.label(for: row.kind))
          .font(.caption)
          .foregroundStyle(.orange)
        Age(date: row.createdAt)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
