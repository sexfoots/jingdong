import Foundation

struct Account: Codable, Identifiable {
    var id: String { phone }
    let phone: String
    var note: String?
}

class AccountManager: ObservableObject {
    static let shared = AccountManager()
    
    private let STORAGE_KEY = "saved_jd_phones"
    
    @Published var accounts: [Account] = []
    
    init() {
        loadAccounts()
    }
    
    func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: STORAGE_KEY),
           let list = try? JSONDecoder().decode([Account].self, from: data) {
            self.accounts = list
        } else {
            self.accounts = []
        }
    }
    
    func saveAccount(phone: String, note: String? = nil) {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if !accounts.contains(where: { $0.phone == trimmed }) {
            accounts.append(Account(phone: trimmed, note: note))
            saveToDisk()
        }
    }
    
    func deleteAccount(at offsets: IndexSet) {
        accounts.remove(atOffsets: offsets)
        saveToDisk()
    }
    
    func deleteAccount(phone: String) {
        accounts.removeAll(where: { $0.phone == phone })
        saveToDisk()
    }
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: STORAGE_KEY)
        }
    }
}
