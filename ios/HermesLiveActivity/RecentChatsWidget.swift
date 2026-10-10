import SwiftUI
import WidgetKit

struct HermesRecentChats: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HermesRecentChats", provider: SurfaceProvider()) { entry in
      RecentChatsView(entry: entry)
    }
    .configurationDisplayName("Recent chats")
    .description("Your newest chats. Tap one to open it.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct RecentChatsView: View {
  @Environment(\.widgetFamily) private var widgetFamily
  let entry: SurfaceEntry

  var body: some View {
    let family = SurfaceFamily(widgetFamily)
    let model = RecentChatsModel(snapshot: entry.snapshot, family: family, now: entry.date)
    SurfaceFrame(
      title: "Recent chats", symbol: "bubble.left.and.text.bubble.right", status: model.status,
      url: model.url
    ) {
      if model.isEmpty {
        Text("No chats yet").font(.subheadline.weight(.medium))
      } else if family == .small {
        SmallChat(row: model.rows[0])
      } else {
        VStack(alignment: .leading, spacing: family == .large ? 10 : 8) {
          ForEach(model.rows) { row in
            Link(destination: row.url) { ChatRow(row: row, family: family) }
          }
          if model.showsOpenRow {
            Link(destination: SurfaceFallbackURL.newChat) {
              Label("New chat", systemImage: "plus")
                .font(.caption.weight(.medium))
            }
          }
        }
      }
    }
  }
}

private struct SmallChat: View {
  let row: RecentChatsModel.Row

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      TitleText(title: row.title, font: .headline, lineLimit: 3)
      if let profile = row.profile {
        Text(profile).font(.caption).foregroundStyle(.secondary).privacySensitive()
      }
      Age(date: row.updatedAt)
    }
  }
}

private struct ChatRow: View {
  let row: RecentChatsModel.Row
  let family: SurfaceFamily

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 6) {
        TitleText(title: row.title)
        Spacer(minLength: 4)
        if let profile = row.profile {
          Text(profile).font(.caption2).foregroundStyle(.secondary).lineLimit(1).privacySensitive()
        }
        Age(date: row.updatedAt)
      }
      if row.isRedacted {
        RedactedLine(width: 30).font(.caption).foregroundStyle(.secondary)
      } else if let snippet = row.snippet {
        Text(snippet)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(family == .large ? 2 : 1)
          .privacySensitive()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
