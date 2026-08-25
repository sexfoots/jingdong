import Foundation
import UIKit

class QRCodeWSKeyManager: ObservableObject {
    @Published var qrImage: UIImage? = nil
    @Published var statusMessage: String = "正在生成登录二维码..."
    @Published var isSuccess: Bool = false
    @Published var extractedWSKey: String? = nil
    
    private var token: String = ""
    private var oklToken: String = ""
    private var cookiesDict: [String: String] = [:]
    private var timer: Timer?
    
    func startQRCodeLogin() {
        stopPolling()
        statusMessage = "正在向京东服务器获取二维码..."
        isSuccess = false
        extractedWSKey = nil
        cookiesDict.removeAll()
        
        let urlStr = "https://qr.m.jd.com/show?appid=133&size=147&t=\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://plogin.m.jd.com/", forHTTPHeaderField: "Referer")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self?.statusMessage = "获取二维码失败，请检查网络"
                }
                return
            }
            
            if let fields = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                for c in cookies {
                    self.cookiesDict[c.name] = c.value
                    if c.name == "wtoken" || c.name == "qr_token" || c.name == "s_token" || c.name == "token" {
                        self.token = c.value
                    }
                    if c.name == "okl_token" {
                        self.oklToken = c.value
                    }
                }
            }
            
            DispatchQueue.main.async {
                if let img = UIImage(data: data) {
                    self.qrImage = img
                    self.statusMessage = "请使用【京东 APP】扫描上方二维码确认登录"
                    self.startPolling()
                } else {
                    self.statusMessage = "解析二维码失败"
                }
            }
        }.resume()
    }
    
    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkQRCodeStatus()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func getCookieString() -> String {
        return cookiesDict.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }
    
    private func checkQRCodeStatus() {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let tokenToUse = token.isEmpty ? (cookiesDict["wtoken"] ?? cookiesDict["qr_token"] ?? "") : token
        let checkUrlStr = "https://qr.m.jd.com/check?appid=133&callback=jQuery\(Int.random(in: 1000000...9999999))&token=\(tokenToUse)&ou_state=0&okl_token=\(oklToken)&_=\(timestamp)"
        
        guard let url = URL(string: checkUrlStr) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://plogin.m.jd.com/", forHTTPHeaderField: "Referer")
        request.setValue(getCookieString(), forHTTPHeaderField: "Cookie")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, let httpResponse = response as? HTTPURLResponse else { return }
            
            // 抓取 Response Cookie 中的凭证
            if let fields = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                for c in cookies {
                    self.cookiesDict[c.name] = c.value
                }
            }
            
            let resStr = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async {
                if resStr.contains("\"code\":200") || resStr.contains("200") {
                    self.stopPolling()
                    self.statusMessage = "京东 APP 确认成功！正在换取 WSKey..."
                    
                    // 解析 Ticket 换取 WSKey
                    if let ticket = self.extractTicket(from: resStr) {
                        self.validateTicket(ticket)
                    } else {
                        self.parseAndEmitCookies()
                    }
                } else if resStr.contains("\"code\":201") {
                    self.statusMessage = "已扫码，请在【京东 APP】点击确认登录"
                } else if resStr.contains("\"code\":203") || resStr.contains("\"code\":202") {
                    self.statusMessage = "二维码已过期，正在自动刷新..."
                    self.startQRCodeLogin()
                }
            }
        }.resume()
    }
    
    private func extractTicket(from str: String) -> String? {
        // 使用正则提取 ticket
        let pattern = "\"ticket\"\\s*:\\s*\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = str as NSString
            if let match = regex.firstMatch(in: str, options: [], range: NSRange(location: 0, length: nsString.length)) {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        return nil
    }
    
    private func validateTicket(_ ticket: String) {
        let validateUrlStr = "https://passport.m.jd.com/uc/qrCodeTicketValidation?ticket=\(ticket)"
        guard let url = URL(string: validateUrlStr) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://plogin.m.jd.com/", forHTTPHeaderField: "Referer")
        request.setValue(getCookieString(), forHTTPHeaderField: "Cookie")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let httpResponse = response as? HTTPURLResponse else { return }
            
            if let fields = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                for c in cookies {
                    self.cookiesDict[c.name] = c.value
                }
            }
            
            DispatchQueue.main.async {
                self.parseAndEmitCookies()
            }
        }.resume()
    }
    
    private func parseAndEmitCookies() {
        var wskey: String? = cookiesDict["wskey"]
        var ptKey: String? = cookiesDict["pt_key"]
        var pin: String? = cookiesDict["pin"] ?? cookiesDict["pt_pin"]
        
        if let w = wskey, let p = pin, !w.isEmpty, !p.isEmpty {
            let res = "pin=\(p);wskey=\(w);"
            self.extractedWSKey = res
            self.statusMessage = "🎉 成功提取 60 天超长 WSKey！"
            self.isSuccess = true
            UIPasteboard.general.string = res
            return
        }
        
        if let k = ptKey, let p = pin, !k.isEmpty, !p.isEmpty {
            let res = "pt_key=\(k);pt_pin=\(p);"
            self.extractedWSKey = res
            self.statusMessage = "🎉 成功提取京东 Cookie 凭证！"
            self.isSuccess = true
            UIPasteboard.general.string = res
            return
        }
        
        self.statusMessage = "登录成功，但未识别到 WSKey，请重试"
    }
    
    deinit {
        stopPolling()
    }
}
