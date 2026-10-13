import SwiftUI

extension HermesClientError {
  var message: String {
    switch self {
    case .contextChanged: "Your Hermes session changed. Open the chat list again."
    case .updateRequired: "Update Hermes on your iPhone and Apple Watch, then open the phone app."
    case .signedOut: "Sign in to Hermes on your iPhone first."
    case .unavailable: "Open Hermes on your iPhone, then try again."
    case .phoneUnreachable: "Can't reach your iPhone."
    case .failed: "Something went wrong."
    case .replyFailed(let reason): reason
    case .noSpeech: "Didn't catch that."
    }
  }
}

struct ErrorView: View {
  let error: HermesClientError
  let retry: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        Text(error.message)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        Button("Try again", action: retry)
      }
    }
  }
}

#Preview("Phone update required") {
  ErrorView(error: .updateRequired, retry: {})
}

#Preview("Changed session") {
  ErrorView(error: .contextChanged, retry: {})
}
