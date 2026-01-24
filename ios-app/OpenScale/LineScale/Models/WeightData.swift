import Foundation

// MARK: - Weight Data Point
struct WeightDataPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let weight: Float

    init(timestamp: TimeInterval, weight: Float) {
        self.id = UUID()
        self.timestamp = timestamp
        self.weight = weight
    }
}

// MARK: - Training Session
struct TrainingSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let peakWeight: Float
    let averageWeight: Float
    let dataPoints: [WeightDataPoint]

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Session Manager
class SessionManager: ObservableObject {
    @Published var sessions: [TrainingSession] = []

    private let sessionsKey = "training_sessions"

    init() {
        loadSessions()
    }

    func saveSession(dataPoints: [WeightDataPoint], peakWeight: Float) {
        guard !dataPoints.isEmpty else { return }

        let duration = dataPoints.last?.timestamp ?? 0
        let avgWeight = dataPoints.map { $0.weight }.reduce(0, +) / Float(dataPoints.count)

        let session = TrainingSession(
            id: UUID(),
            date: Date(),
            duration: duration,
            peakWeight: peakWeight,
            averageWeight: avgWeight,
            dataPoints: dataPoints
        )

        sessions.insert(session, at: 0)
        persistSessions()
    }

    func deleteSession(_ session: TrainingSession) {
        sessions.removeAll { $0.id == session.id }
        persistSessions()
    }

    func clearAllSessions() {
        sessions.removeAll()
        persistSessions()
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else { return }
        do {
            sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
        } catch {
            print("Error loading sessions: \(error)")
        }
    }

    private func persistSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
        } catch {
            print("Error saving sessions: \(error)")
        }
    }
}

// MARK: - Unit Conversion
enum WeightUnit: String, CaseIterable {
    case grams = "g"
    case kilograms = "kg"
    case pounds = "lbs"

    func convert(_ grams: Float) -> Float {
        switch self {
        case .grams: return grams
        case .kilograms: return grams / 1000.0
        case .pounds: return grams / 453.592
        }
    }

    func format(_ grams: Float) -> String {
        let value = convert(grams)
        switch self {
        case .grams: return String(format: "%.0f %@", value, rawValue)
        case .kilograms: return String(format: "%.2f %@", value, rawValue)
        case .pounds: return String(format: "%.1f %@", value, rawValue)
        }
    }
}
