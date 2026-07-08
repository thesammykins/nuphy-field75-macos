import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var store: Field75MapperStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Log")
                        .font(.title2.weight(.semibold))
                    Text("Readback, planning, write, and action-runner messages.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            List(store.logs) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Text(entry.date, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Text(entry.level.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color(for: entry.level))
                        .frame(width: 58, alignment: .leading)
                    Text(entry.message)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 3)
            }
            .listStyle(.inset)
        }
        .padding(24)
    }

    private func color(for level: LogEntry.Level) -> Color {
        switch level {
        case .info: .secondary
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
