import SwiftUI
import Combine

struct ChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let content: String
}

@MainActor
final class ChatViewModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    private let systemPrompt = "You are a helpful assistant."

    func send() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        messages.append(.init(role: .user, content: userText))
        errorMessage = nil
        isSending = true

        Task {
            do {
                let response = try await OpenRouterChatAPI.shared.sendMessage(userText, systemPrompt: systemPrompt)
                messages.append(.init(role: .assistant, content: response))
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            isSending = false
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                messageRow(message)
                            }
                        }
                        .padding()
                        .onChange(of: viewModel.messages.count) { _ in
                            if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                Divider()
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding([.leading, .trailing, .bottom], 12)
                }
                HStack {
                    TextField("Type a message…", text: $viewModel.inputText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isSending)

                    Button(action: viewModel.send) {
                        if viewModel.isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                                .bold()
                        }
                    }
                    .disabled(viewModel.isSending || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("ChatBot")
        }
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption)
                    .foregroundColor(message.role == .user ? .blue : .green)

                Text(message.content)
                    .padding(10)
                    .background(message.role == .user ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                    .cornerRadius(10)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .id(message.id)
    }
}
