import SwiftUI
import WidgetKit

struct HermesNeedsYou: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HermesNeedsYou", provider: SurfaceProvider()) { entry in
      NeedsYouView(entry: entry)
    }
    .configurationDisplayName("Needs you")
    .description("Approvals and questions waiting for you. Tap to open the oldest.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct NeedsYouView: View {
  @Environment(\.widgetFamily) private var widgetFamily
  let entry: SurfaceEntry

  var body: some View {
    let family = SurfaceFamily(widgetFamily)
    let model = NeedsYouModel(snapshot: entry.snapshot, family: family, now: entry.date)
    SurfaceFrame(title: "Needs you", symbol: "hand.raised", status: model.status, url: model.url) {
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
