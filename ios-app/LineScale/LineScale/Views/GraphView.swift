import SwiftUI
import Charts

struct GraphView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kilograms
    @State private var showFullHistory = false

    var displayData: [WeightDataPoint] {
        if showFullHistory {
            return bluetoothManager.weightHistory
        } else {
            // Show last 10 seconds of data
            let cutoff = (bluetoothManager.weightHistory.last?.timestamp ?? 0) - 10
            return bluetoothManager.weightHistory.filter { $0.timestamp >= cutoff }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Live weight indicator
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(weightUnit.format(bluetoothManager.currentWeight))
                            .font(.title)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Peak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(weightUnit.format(bluetoothManager.peakWeight))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // Recording indicator
                if bluetoothManager.isRecording {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("Recording - \(bluetoothManager.weightHistory.count) samples")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Chart
                if bluetoothManager.weightHistory.isEmpty {
                    emptyChartView
                } else {
                    chartView
                }

                // Toggle for full history
                if !bluetoothManager.weightHistory.isEmpty {
                    Toggle("Show Full History", isOn: $showFullHistory)
                        .padding(.horizontal)
                }

                Spacer()

                // Clear button
                Button(action: {
                    bluetoothManager.clearHistory()
                }) {
                    Label("Clear Graph", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(bluetoothManager.weightHistory.isEmpty)
            }
            .padding()
            .navigationTitle("Force Graph")
        }
    }

    var emptyChartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Data")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Start recording to see the force graph")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    var chartView: some View {
        Chart(displayData) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Weight", weightUnit.convert(point.weight))
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))

            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Weight", weightUnit.convert(point.weight))
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
                        Text(String(format: "%.1fs", seconds))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text("\(Int(weight))")
                    }
                }
            }
        }
        .chartYAxisLabel(weightUnit.rawValue)
        .frame(maxHeight: 300)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    GraphView()
        .environmentObject(BluetoothManager())
}
