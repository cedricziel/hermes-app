import SwiftUI

extension HermesClientError {
  var message: String {
    switch self {
    case .contextChanged: "Your Hermes session changed. Open the chat list again."
    case .updateRequired: "Update Hermes on your iPhone and Apple Watch, then open the phone app."
    case .signedOut: "Sign in to Hermes on your iPhone first."
    case .unavailable: "Open Hermes on your iPhone, then try again."
    case .phoneUnreachable: "Can't reach your iPhone."
    case .notDelivered: "Your message did not reach your iPhone."
    case .recoveryCapacity: "Recovery is full. Forget an old pending request to free a slot, then try again."
    case .recoveryStorage: "Could not save recovery securely. Free storage before another request."
    case .sendExpired: "This request has expired or the device clocks disagree. Check the watch and iPhone time, then check its result before a new request."
    case .clockSkew: "Check the date and time on your watch and iPhone. Check the original result before sending again."
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
        if error != .updateRequired && error != .recoveryCapacity { Button("Try again", action: retry) }
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

#Preview("Recovery capacity") { ErrorView(error: .recoveryCapacity, retry: {}) }
