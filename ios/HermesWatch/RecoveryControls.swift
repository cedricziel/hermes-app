import SwiftUI

struct RecoveryControls: View {
  let state: SendRecoveryState
  let hasThread: Bool
  let checked: Bool
  let disabled: Bool
  let check: () -> Void
  let open: () -> Void
  let resend: () -> Void
  let forget: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(state == .pending ? "Hermes is still working. Check for the result." :
        state == .notSent ? "This message was not sent. Retry sends a new request." :
        "Delivery or completion could not be confirmed. Another send may run the request twice.")
        .fixedSize(horizontal: false, vertical: true)
      Button("Check result", action: check)
      if hasThread { Button("Open chat", action: open) }
      if state != .pending {
        Button(state == .notSent ? "Retry as new request" : "Send again", action: resend)
          .disabled(disabled || !checked)
      }
      Button("Forget recovery", action: forget)
    }
    .disabled(disabled)
  }
}

#Preview("Pending result") { RecoveryControls(state: .pending, hasThread: true, checked: false, disabled: false, check: {}, open: {}, resend: {}, forget: {}) }
#Preview("Uncertain with chat") { RecoveryControls(state: .uncertain, hasThread: true, checked: true, disabled: false, check: {}, open: {}, resend: {}, forget: {}) }
#Preview("Uncertain without chat") { RecoveryControls(state: .uncertain, hasThread: false, checked: false, disabled: false, check: {}, open: {}, resend: {}, forget: {}) }
#Preview("Not sent") { RecoveryControls(state: .notSent, hasThread: false, checked: true, disabled: false, check: {}, open: {}, resend: {}, forget: {}) }

#Preview("Resend confirmation") {
  VStack {
    Text("Send this request again?")
    Text("The original message may already have reached Hermes. Sending again can run the request twice.")
    Button("Cancel") {}
    Button("Send again") {}
  }
}
