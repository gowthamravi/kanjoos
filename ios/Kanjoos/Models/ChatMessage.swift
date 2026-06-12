import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role {
        case user, assistant, tool, error
    }

    let id = UUID()
    let role: Role
    let text: String
}
