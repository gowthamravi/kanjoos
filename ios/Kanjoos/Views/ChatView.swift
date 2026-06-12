import SwiftUI

struct ChatView: View {
    @StateObject private var model = ChatViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BudgetGaugeView(status: model.status)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if model.messages.isEmpty {
                                emptyState
                            }
                            ForEach(model.messages) { message in
                                MessageBubble(message: message)
                            }
                            if model.isStreaming {
                                HStack {
                                    ProgressView()
                                    Text("Kanjoos is thinking…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.leading, 8)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: model.messages) {
                        if let last = model.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                inputBar
            }
            .navigationTitle("Kanjoos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(model: model)
            }
            .task { await model.refreshStatus() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🪙")
                .font(.system(size: 56))
            Text("Order food. I'll keep the math honest.")
                .foregroundStyle(.secondary)
            Text("Try: \u{201C}order me a biryani\u{201D}")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 80)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("What are you craving?", text: $model.input, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                .onSubmit { Task { await model.send() } }
            Button {
                Task { await model.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
            }
            .disabled(model.isStreaming || model.input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
