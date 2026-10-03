import SwiftUI

/// Text input at the bottom of the screen. In the mock voice agent it also stands in for
/// speech: while "listening", whatever is typed becomes the transcript, and a one-tap
/// suggestion shows what the user might say next.
struct InputBar: View {
    @Environment(AppModel.self) private var app
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            if let s = app.input.suggestion {
                Button { app.useSuggestion() } label: {
                    Text("Try: “\(s)”").font(LoferFont.ui(13)).foregroundStyle(Color(hex: 0xE6DBD2)).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x24201F).opacity(0.95)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.loferPeach.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain).padding(.horizontal, 16)
            }
            HStack(spacing: 8) {
                TextField(app.input.voiceMode ? "Listening… type what you’d say" : "e.g. the back of my left wrist aches", text: $text)
                    .font(LoferFont.ui(15)).foregroundStyle(Color.loferCream).focused($focused).submitLabel(.send)
                    .onSubmit(send).padding(.leading, 10)
                Button("Send", action: send).font(LoferFont.ui(15, .medium)).foregroundStyle(Color(hex: 0x1A1210))
                    .padding(.horizontal, 18).frame(height: 42).background(Capsule().fill(Color(hex: 0xE4C0A6)))
                CircleIconButton(systemName: "xmark", label: "Close") { app.closeInput() }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 28).fill(Color(hex: 0x181514).opacity(0.97)))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(app.input.voiceMode ? Color.loferPeach.opacity(0.55) : Color.loferLine2))
            .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .onAppear { focused = true }
    }
    private func send() { let t = text; text = ""; if !t.trimmingCharacters(in: .whitespaces).isEmpty { app.submitTyped(t) } }
}
