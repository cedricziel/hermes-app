import SwiftUI
import WidgetKit

struct HermesBoard: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HermesBoard", provider: SurfaceProvider(followsNextRun: true)) {
      entry in
      BoardView(entry: entry)
    }
    .configurationDisplayName("Board")
    .description("Kanban tasks waiting for you, the next scheduled run and the last failed job.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct BoardView: View {
  @Environment(\.widgetFamily) private var widgetFamily
  let entry: SurfaceEntry

  var body: some View {
    let model = BoardModel(
      snapshot: entry.snapshot, family: SurfaceFamily(widgetFamily), now: entry.date)
    SurfaceFrame(
      title: "Board", symbol: "rectangle.3.group", status: model.status, url: model.url
    ) {
      if let emptyText = model.emptyText {
        Text(emptyText).font(.subheadline.weight(.medium))
      } else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(model.parts.enumerated()), id: \.offset) { _, part in
            // A small widget has one tap target (widgetURL); Links work from medium up.
            if widgetFamily == .systemSmall {
              PartRow(part: part, now: entry.date)
            } else {
              Link(destination: part.url) { PartRow(part: part, now: entry.date) }
            }
          }
        }
      }
    }
  }
}

private struct PartRow: View {
  let part: BoardModel.Part
  let now: Date

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .font(.caption)
        .foregroundStyle(tint)
        .frame(width: 16)
      VStack(alignment: .leading, spacing: 1) {
        switch part {
        case .kanban(let blocked, let review, _):
          Text("\(blocked) blocked").font(.subheadline.weight(.semibold))
          Text("\(review) in review").font(.caption).foregroundStyle(.secondary)
        case .failedJob(let name, let at, _):
          TitleText(title: name)
          HStack(spacing: 4) {
            Text("Failed").font(.caption).foregroundStyle(.red)
            Age(date: at)
          }
        case .nextRun(let name, let at, let isDue, _):
          TitleText(title: name)
          if isDue {
            Text("Due").font(.caption).foregroundStyle(.secondary)
          } else {
            Text("Next \(at, format: runFormat(at))").font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var symbol: String {
    switch part {
    case .kanban: "rectangle.split.3x1"
    case .failedJob: "exclamationmark.triangle.fill"
    case .nextRun: "clock"
    }
  }

  private var tint: Color {
    switch part {
    case .kanban: .accentColor
    case .failedJob: .red
    case .nextRun: .secondary
    }
  }

  /// The time alone for a run today, with the weekday otherwise.
  private func runFormat(_ at: Date) -> Date.FormatStyle {
    Calendar.current.isDate(at, inSameDayAs: now)
      ? .dateTime.hour().minute() : .dateTime.weekday(.abbreviated).hour().minute()
  }
}
