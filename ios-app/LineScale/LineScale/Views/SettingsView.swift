import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kilograms
    @State private var sampleRateSlider: Double = 10
    @State private var showDeviceList = false

    var body: some View {
        NavigationStack {
            Form {
                // Connection Section
                Section("Device") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack {
                            Circle()
                                .fill(connectionColor)
                                .frame(width: 10, height: 10)
                            Text(bluetoothManager.connectionState.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }

                    if bluetoothManager.connectionState == .disconnected {
                        Button("Scan for Devices") {
                            showDeviceList = true
                            bluetoothManager.startScanning()
                        }
                    } else if bluetoothManager.connectionState == .connected {
                        Button("Disconnect", role: .destructive) {
                            bluetoothManager.disconnect()
                        }
                    }
                }

                // Units Section
                Section("Display") {
                    Picker("Weight Unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unitDisplayName(unit)).tag(unit)
                        }
                    }
                }

                // Sample Rate Section
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Sample Rate")
                            Spacer()
                            Text("\(Int(sampleRateSlider)) Hz")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $sampleRateSlider, in: 1...80, step: 1) { editing in
                            if !editing {
                                bluetoothManager.setSampleRate(UInt8(sampleRateSlider))
                            }
                        }

                        Text("Higher rates give smoother graphs but use more battery")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Sampling")
                } footer: {
                    Text("HX711 supports up to 80 Hz. Recommended: 10-20 Hz for training.")
                }

                // Calibration Section
                Section("Calibration") {
                    Button("Tare / Zero Scale") {
                        bluetoothManager.tare()
                    }
                    .disabled(bluetoothManager.connectionState != .connected)
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("GitHub Repository", destination: URL(string: "https://github.com/")!)

                    Link("Report Issue", destination: URL(string: "https://github.com/")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                sampleRateSlider = Double(bluetoothManager.sampleRate)
            }
            .onChange(of: bluetoothManager.sampleRate) { _, newValue in
                sampleRateSlider = Double(newValue)
            }
            .sheet(isPresented: $showDeviceList) {
                DeviceListView()
            }
        }
    }

    var connectionColor: Color {
        switch bluetoothManager.connectionState {
        case .disconnected: return .red
        case .scanning: return .orange
        case .connecting: return .yellow
        case .connected: return .green
        }
    }

    func unitDisplayName(_ unit: WeightUnit) -> String {
        switch unit {
        case .grams: return "Grams (g)"
        case .kilograms: return "Kilograms (kg)"
        case .pounds: return "Pounds (lbs)"
        }
    }
}

// MARK: - Device List View
struct DeviceListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if bluetoothManager.connectionState == .scanning {
                    ProgressView("Scanning...")
                        .padding()
                }

                if bluetoothManager.discoveredDevices.isEmpty && bluetoothManager.connectionState != .scanning {
                    VStack(spacing: 16) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No Devices Found")
                            .font(.headline)

                        Text("Make sure your LineScale is powered on and nearby")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Scan Again") {
                            bluetoothManager.startScanning()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                        Button(action: {
                            bluetoothManager.connect(to: device)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "scalemass.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name ?? "Unknown Device")
                                        .font(.headline)
                                    Text("ID: \(String(device.identifier.uuidString.prefix(8)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .foregroundColor(.primary)
                    }

                    Text("Each LineScale has a unique name (e.g., LineScale-A1B2). Select your device from the list above.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        bluetoothManager.stopScanning()
                        dismiss()
                    }
                }

                if bluetoothManager.connectionState != .scanning {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            bluetoothManager.startScanning()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BluetoothManager())
}
