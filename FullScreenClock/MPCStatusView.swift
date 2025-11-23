import SwiftUI

struct MPCStatusView: View {
    @ObservedObject private var manager = NearbySyncManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if manager.connectedPeersCount > 0 {
                Text("• \(manager.connectedPeersCount) peer\(manager.connectedPeersCount == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Nearby sync status: \(statusText), \(manager.connectedPeersCount) connected"))
    }

    private var statusText: String {
        manager.lastStateDescription
    }

    private var statusColor: Color {
        if !manager.isRunning { return .gray }
        return manager.connectedPeersCount > 0 ? .green : .yellow
    }
}

#Preview {
    MPCStatusView()
        .padding()
}
