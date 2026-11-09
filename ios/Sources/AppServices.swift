import Foundation
import MessengerShared

enum AppServices {
    static let repository: MessengerRepository = {
        let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? ""
        return SupabaseMessenger.shared.repository(projectUrl: url, publishableKey: key)
    }()
}
