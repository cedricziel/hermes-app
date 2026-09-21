import SwiftUI

extension HermesClientError {
  var message: String {
    switch self {
    case .signedOut: "Sign in to Hermes on your iPhone first."
    case .unavailable: "Open Hermes on your iPhone, then try again."
    case .phoneUnreachable: "Can't reach your iPhone."
    case .failed: "Something went wrong."
    case .replyFailed(let reason): reason
    }
  }
}

struct ErrorView: View {
  let error: HermesClientError
  let retry: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Text(error.message)
        .multilineTextAlignment(.center)
      Button("Try again", action: retry)
    }
  }
}
