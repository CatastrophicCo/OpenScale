import SwiftUI

struct WeightView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kilograms

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Connection Status
                ConnectionStatusView()

                Spacer()

                // Main Weight Display
                WeightDisplayView(
                    weight: bluetoothManager.currentWeight,
                    unit: weightUnit
                )

                // Peak Weight
                PeakWeightView(
                    peakWeight: bluetoothManager.peakWeight,
                    unit: weightUnit
                )

                Spacer()

                // Control Buttons
                ControlButtonsView()

                Spacer()
            }
            .padding()
            .navigationTitle("LineScale")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Button(action: { weightUnit = unit }) {
                                HStack {
                                    Text(unit.rawValue.uppercased())
                                    if weightUnit == unit {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(weightUnit.rawValue)
                            .font(.headline)
                    }
                }
            }
        }
    }
}

// MARK: - Connection Status View
struct ConnectionStatusView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var statusColor: Color {
        switch bluetoothManager.connectionState {
        case .disconnected: return .red
        case .scanning: return .orange
        case .connecting: return .yellow
        case .connected: return .green
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            Text(bluetoothManager.connectionState.rawValue)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if bluetoothManager.connectionState == .disconnected {
                Button("Connect") {
                    bluetoothManager.startScanning()
                }
                .buttonStyle(.bordered)
            } else if bluetoothManager.connectionState == .connected {
                Button("Disconnect") {
                    bluetoothManager.disconnect()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Weight Display View
struct WeightDisplayView: View {
    let weight: Float
    let unit: WeightUnit

    var displayValue: String {
        let converted = unit.convert(weight)
        switch unit {
        case .grams: return String(format: "%.0f", converted)
        case .kilograms: return String(format: "%.2f", converted)
        case .pounds: return String(format: "%.1f", converted)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(displayValue)
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)

            Text(unit.rawValue)
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Peak Weight View
struct PeakWeightView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    let peakWeight: Float
    let unit: WeightUnit

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Peak")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(unit.format(peakWeight))
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()

            Button(action: { bluetoothManager.resetPeak() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Control Buttons View
struct ControlButtonsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @StateObject private var sessionManager = SessionManager()

    var body: some View {
        VStack(spacing: 16) {
            // Tare Button
            Button(action: { bluetoothManager.tare() }) {
                Label("Tare / Zero", systemImage: "arrow.down.to.line")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(bluetoothManager.connectionState != .connected)

            // Record Button
            HStack(spacing: 16) {
                Button(action: {
                    if bluetoothManager.isRecording {
                        bluetoothManager.stopRecording()
                        sessionManager.saveSession(
                            dataPoints: bluetoothManager.weightHistory,
                            peakWeight: bluetoothManager.peakWeight
                        )
                    } else {
                        bluetoothManager.startRecording()
                    }
                }) {
                    Label(
                        bluetoothManager.isRecording ? "Stop" : "Record",
                        systemImage: bluetoothManager.isRecording ? "stop.fill" : "record.circle"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(bluetoothManager.isRecording ? .red : .blue)
                .disabled(bluetoothManager.connectionState != .connected)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WeightView()
        .environmentObject(BluetoothManager())
}
