import Foundation

public protocol UserActivityServiceProtocol {
    func loadActivity() -> UserActivity
    func saveActivity(_ activity: UserActivity)
}

public class UserActivityService: UserActivityServiceProtocol {
    private let fileManager = FileManager.default
    private let saveQueue = DispatchQueue(label: "com.swiftforge.useractivity.save", qos: .utility)
    
    // Primary path: Application documents directory
    private var localStoreUrl: URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("user_activity.json")
    }
    
    public init() {}
    
    public func loadActivity() -> UserActivity {
        // Try local Documents storage first
        if fileManager.fileExists(atPath: localStoreUrl.path) {
            do {
                let data = try Data(contentsOf: localStoreUrl)
                let decoder = JSONDecoder()
                return try decoder.decode(UserActivity.self, from: data)
            } catch {
                print("UserActivityService: Error reading local activity file: \(error.localizedDescription)")
            }
        }
        
        return UserActivity()
    }
    
    public func saveActivity(_ activity: UserActivity) {
        saveQueue.async { [localStoreUrl] in
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(activity)
                
                // Save to local Documents storage
                try data.write(to: localStoreUrl, options: .atomic)
            } catch {
                print("UserActivityService: Error saving activity file: \(error.localizedDescription)")
            }
        }
    }
}
