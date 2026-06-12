import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var budgetText = ""
    @State private var simDateEnabled = false
    @State private var simDate = Date()
    @State private var spendAmount = ""
    @State private var spendDescription = ""
    @AppStorage("serverURL") private var serverURL = "http://127.0.0.1:8000"

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly budget") {
                    HStack {
                        Text("₹")
                        TextField("8000", text: $budgetText)
                            .keyboardType(.numberPad)
                    }
                    Button("Save budget") {
                        Task {
                            if let amount = Double(budgetText) {
                                model.status = try? await model.api.setBudget(amount)
                            }
                        }
                    }
                }

                Section("Log an outside spend") {
                    HStack {
                        Text("₹")
                        TextField("Amount", text: $spendAmount)
                            .keyboardType(.numberPad)
                    }
                    TextField("What was it?", text: $spendDescription)
                    Button("Log spend") {
                        Task {
                            if let amount = Double(spendAmount), !spendDescription.isEmpty {
                                model.status = try? await model.api.addSpend(amount: amount, description: spendDescription)
                                spendAmount = ""
                                spendDescription = ""
                            }
                        }
                    }
                }

                Section {
                    Toggle("Simulate a date", isOn: $simDateEnabled)
                    if simDateEnabled {
                        DatePicker("Pretend today is", selection: $simDate, displayedComponents: .date)
                    }
                    Button("Apply") {
                        Task {
                            let iso = simDateEnabled ? Self.isoFormatter.string(from: simDate) : nil
                            model.status = try? await model.api.setSimDate(iso)
                        }
                    }
                } header: {
                    Text("Time travel (demo)")
                } footer: {
                    Text("Jump to day 26 to see month-end mode without waiting three weeks.")
                }

                Section("Server") {
                    TextField("http://127.0.0.1:8000", text: $serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onAppear {
                if let s = model.status {
                    budgetText = String(Int(s.monthlyBudget))
                    simDateEnabled = s.simDateActive
                }
            }
        }
    }
}
