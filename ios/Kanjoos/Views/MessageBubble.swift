import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .padding(12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.white)
            }
        case .assistant:
            HStack {
                Text(.init(message.text)) // render markdown
                    .padding(12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 18))
                Spacer(minLength: 48)
            }
        case .tool:
            HStack {
                Text(message.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 8)
        case .error:
            Text(message.text)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
