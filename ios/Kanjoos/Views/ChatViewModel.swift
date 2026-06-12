import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var status: BudgetStatus?
    @Published var input = ""
    @Published var isStreaming = false

    let api = APIClient()
    private let sessionId = UUID().uuidString

    func refreshStatus() async {
        status = try? await api.fetchBudget()
    }

    func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        input = ""
        messages.append(ChatMessage(role: .user, text: text))
        isStreaming = true
        defer { isStreaming = false }

        do {
            for try await event in api.chatStream(sessionId: sessionId, message: text) {
                switch event.type {
                case "text":
                    if let t = event.text { messages.append(ChatMessage(role: .assistant, text: t)) }
                case "tool":
                    messages.append(ChatMessage(role: .tool, text: Self.toolLabel(event.name)))
                case "error":
                    messages.append(ChatMessage(role: .error, text: event.text ?? "Something went wrong"))
                case "done":
                    if let s = event.status { status = s }
                default:
                    break
                }
            }
        } catch {
            messages.append(ChatMessage(role: .error, text: error.localizedDescription))
        }
    }

    static func toolLabel(_ name: String?) -> String {
        guard let name else { return "working…" }
        if name.contains("swiggy_food") { return "🍽️ Checking Swiggy…" }
        if name.contains("swiggy_instamart") { return "🛒 Building Instamart cart…" }
        if name.contains("budget") { return "📒 Checking the ledger…" }
        return "⚙️ \(name)"
    }
}
