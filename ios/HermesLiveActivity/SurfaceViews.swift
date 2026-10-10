import SwiftUI
import WidgetKit

// Pieces the Home Screen widgets share. Chat titles, snippets, profile names
// and job names are privacy sensitive, so iOS redacts them on a locked
// device; counts, symbols and fixed labels are not.

/// A widget's frame: its header line, content, and the notes that apply to
/// every widget (signed out, out of date).
struct SurfaceFrame<Content: View>: View {
  let title: String
  let symbol: String
  let status: WidgetStatus
  let url: URL?
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      if status.isSignedOut {
        Text("Open Hermes to sign in")
          .font(.subheadline.weight(.medium))
        Spacer(minLength: 0)
      } else {
        content
        Spacer(minLength: 0)
        if status.isStale {
          Text("Open Hermes to refresh")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(url)
    .containerBackground(.background, for: .widget)
  }
}

/// How long ago something happened, ticking without a timeline reload.
struct Age: View {
  let date: Date

  var body: some View {
    Text(date, style: .relative)
      .font(.caption2)
      .foregroundStyle(.secondary)
      .lineLimit(1)
  }
}

/// Grey bars where a title would be while App Lock hides it. A fixed string,
/// never an invented title.
struct RedactedLine: View {
  var width = 14

  var body: some View {
    Text(String(repeating: "x", count: width))
      .redacted(reason: .placeholder)
      .lineLimit(1)
      .accessibilityLabel("Hidden")
  }
}

/// A title the snapshot holds, or the placeholder when App Lock left it out.
struct TitleText: View {
  let title: String?
  var font: Font = .subheadline.weight(.semibold)
  var lineLimit = 1

  var body: some View {
    if let title {
      Text(title)
        .font(font)
        .lineLimit(lineLimit)
        .privacySensitive()
    } else {
      RedactedLine().font(font)
    }
  }
}
