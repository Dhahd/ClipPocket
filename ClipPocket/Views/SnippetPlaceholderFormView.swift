import SwiftUI

struct SnippetPlaceholderFormView: View {
    let snippet: Snippet
    @Binding var values: [String: String]
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Fill in Placeholders")
                    .font(.headline)
                Text(snippet.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Scrollable fields
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(snippet.placeholders, id: \.self) { placeholder in
                        HStack {
                            Text(placeholder)
                                .frame(width: 110, alignment: .trailing)
                                .font(.system(size: 13, weight: .medium))
                            TextField("Enter \(placeholder)...", text: binding(for: placeholder))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Divider()

            // Preview
            GroupBox("Preview") {
                ScrollView {
                    Text(snippet.resolve(with: values))
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Divider()

            // Buttons
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Copy") {
                    onSubmit(snippet.resolve(with: values))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(values.values.contains(where: { $0.isEmpty }))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 400)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }
}
