import Foundation
import UserNotifications

//  Main Manager Class
class BackgroundProcessingManager {
    // Singleton instance
    static let shared = BackgroundProcessingManager()
    private let defaults = UserDefaults.standard
    private let processingQueueKey = "processing_queue"
    
    //  Processing Item Structure
    struct ProcessingItem: Codable {
        let sessionId: String
        let youtubeUrl: String
        let timestamp: Date
        var status: Status
        var title: String?
        
        enum Status: String, Codable {
            case processing
            case ready
            case failed
        }
    }
    
    //  Initialize and Setup
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications()
    {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted
            {
            } else if let error = error
            {
            }
        }
    }
    
    //  Queue Management Methods
    func addToProcessingQueue(youtubeUrl: String, sessionId: String) {
        var queue = getProcessingQueue()
        let newItem = ProcessingItem(
            sessionId: sessionId,
            youtubeUrl: youtubeUrl,
            timestamp: Date(),
            status: .processing
        )
        queue.append(newItem)
        saveProcessingQueue(queue)
    }
    
    func updateItemStatus(sessionId: String, status: ProcessingItem.Status, title: String? = nil) {
        var queue = getProcessingQueue()
        if let index = queue.firstIndex(where: { $0.sessionId == sessionId }) {
            queue[index].status = status
            queue[index].title = title
            saveProcessingQueue(queue)
            
            if status == .ready {
                sendNotification(title: "Song Ready", body: "'\(title ?? "Your song")' is ready to play!")
            }
        }
    }
    
    //  Storage Methods
    func getProcessingQueue() -> [ProcessingItem] {
        guard let data = defaults.data(forKey: processingQueueKey),
              let queue = try? JSONDecoder().decode([ProcessingItem].self, from: data) else {
            return []
        }
        return queue
    }
    
    private func saveProcessingQueue(_ queue: [ProcessingItem]) {
        if let encoded = try? JSONEncoder().encode(queue) {
            defaults.set(encoded, forKey: processingQueueKey)
        }
    }
    
    // Notification Method
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
            }
        }
    }
    
    func removeFromQueue(sessionId: String) {
        var queue = getProcessingQueue()
        queue.removeAll { $0.sessionId == sessionId }
        saveProcessingQueue(queue)
    }
    
   
}
