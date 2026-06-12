import Foundation

struct ChatStreamEvent: Decodable {
    let type: String
    let text: String?
    let name: String?
    let status: BudgetStatus?
}

struct APIClient {
    // Simulator reaches the Mac via localhost; on a device, set this to the Mac's LAN IP.
    var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: "serverURL") ?? "http://127.0.0.1:8000"
        return URL(string: stored)!
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func request(_ path: String, method: String = "GET", body: [String: Any?]? = nil) throws -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body.mapValues { $0 ?? NSNull() })
        }
        return req
    }

    func chatStream(sessionId: String, message: String) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let req = try request("chat", method: "POST", body: ["session_id": sessionId, "message": message])
                    let (bytes, _) = try await URLSession.shared.bytes(for: req)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "), let data = line.dropFirst(6).data(using: .utf8) else { continue }
                        let event = try decoder.decode(ChatStreamEvent.self, from: data)
                        continuation.yield(event)
                        if event.type == "done" { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func fetchBudget() async throws -> BudgetStatus {
        let (data, _) = try await URLSession.shared.data(for: try request("budget"))
        return try decoder.decode(BudgetStatus.self, from: data)
    }

    func setBudget(_ amount: Double) async throws -> BudgetStatus {
        let (data, _) = try await URLSession.shared.data(
            for: try request("budget", method: "POST", body: ["monthly_budget": amount]))
        return try decoder.decode(BudgetStatus.self, from: data)
    }

    func addSpend(amount: Double, description: String) async throws -> BudgetStatus {
        let (data, _) = try await URLSession.shared.data(
            for: try request("spend", method: "POST", body: ["amount": amount, "description": description]))
        return try decoder.decode(BudgetStatus.self, from: data)
    }

    func setSimDate(_ isoDate: String?) async throws -> BudgetStatus {
        let (data, _) = try await URLSession.shared.data(
            for: try request("debug/date", method: "POST", body: ["date": isoDate]))
        return try decoder.decode(BudgetStatus.self, from: data)
    }
}
