import SwiftUI
import Charts

struct SessionView: View {
    @StateObject private var sessionManager = SessionManager()
    @State private var selectedSession: TrainingSession?
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kilograms

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                if !sessionManager.sessions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            sessionManager.clearAllSessions()
                        }) {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session, unit: weightUnit)
            }
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Sessions")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Recorded training sessions will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    var sessionListView: some View {
        List {
            ForEach(sessionManager.sessions) { session in
                SessionRowView(session: session, unit: weightUnit)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSession = session
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    sessionManager.deleteSession(sessionManager.sessions[index])
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: TrainingSession
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.formattedDate)
                    .font(.headline)
                Spacer()
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Peak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(unit.format(session.peakWeight))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading) {
                    Text("Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(unit.format(session.averageWeight))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading) {
                    Text("Samples")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(session.dataPoints.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Detail View
struct SessionDetailView: View {
    let session: TrainingSession
    let unit: WeightUnit
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats
                    statsView

                    // Chart
                    chartView

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    var statsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text(session.formattedDate)
                    .font(.headline)
                Spacer()
                Text("Duration: \(session.formattedDuration)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                StatBox(title: "Peak", value: unit.format(session.peakWeight), color: .orange)
                StatBox(title: "Average", value: unit.format(session.averageWeight), color: .blue)
                StatBox(title: "Samples", value: "\(session.dataPoints.count)", color: .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    var chartView: some View {
        VStack(alignment: .leading) {
            Text("Force Over Time")
                .font(.headline)
                .padding(.horizontal)

            Chart(session.dataPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Weight", unit.convert(point.weight))
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Weight", unit.convert(point.weight))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(String(format: "%.0fs", seconds))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel(unit.rawValue)
            .frame(height: 250)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    SessionView()
}
