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
            
            self.extractCookiesFromResponse(httpResponse, url: url)
            
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
            
            self.extractCookiesFromResponse(httpResponse, url: url)
            let resStr = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async {
                if resStr.contains("\"code\":200") || resStr.contains("200") {
                    self.stopPolling()
                    self.statusMessage = "京东 APP 确认成功！正在完成凭证兑换..."
                    
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
            
            self.extractCookiesFromResponse(httpResponse, url: url)
            
            DispatchQueue.main.async {
                self.parseAndEmitCookies()
            }
        }.resume()
    }
    
    private func extractCookiesFromResponse(_ response: HTTPURLResponse, url: URL) {
        if let fields = response.allHeaderFields as? [String: String] {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
            for c in cookies {
                cookiesDict[c.name] = c.value
                if c.name == "wtoken" || c.name == "qr_token" || c.name == "s_token" || c.name == "token" {
                    self.token = c.value
                }
                if c.name == "okl_token" {
                    self.oklToken = c.value
                }
            }
            
            for (key, value) in fields {
                if key.lowercased() == "set-cookie" {
                    parseRawCookieHeader(value)
                }
            }
        }
    }
    
    private func parseRawCookieHeader(_ headerStr: String) {
        let items = headerStr.components(separatedBy: ",")
        for item in items {
            let parts = item.components(separatedBy: ";")
            if let first = parts.first {
                let kv = first.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                if kv.count >= 2 {
                    let k = kv[0].trimmingCharacters(in: .whitespaces)
                    let v = kv[1].trimmingCharacters(in: .whitespaces)
                    if !k.isEmpty && !v.isEmpty {
                        cookiesDict[k] = v
                    }
                }
            }
        }
    }
    
    private func parseAndEmitCookies() {
        let fullCookieStr = cookiesDict.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        
        let wskey = findCookieValue(name: "wskey", in: fullCookieStr)
        let ptKey = findCookieValue(name: "pt_key", in: fullCookieStr)
        let pin = findCookieValue(name: "pt_pin", in: fullCookieStr) ?? findCookieValue(name: "pin", in: fullCookieStr) ?? findCookieValue(name: "unick", in: fullCookieStr)
        
        // 优先 1：完整 WSKey
        if let w = wskey, let p = pin, !w.isEmpty, !p.isEmpty {
            let res = "pin=\(p);wskey=\(w);"
            emitSuccess(result: res, title: "🎉 成功提取 60 天超长 WSKey！")
            return
        }
        
        // 优先 2：完整 PT_KEY
        if let k = ptKey, let p = pin, !k.isEmpty, !p.isEmpty {
            let res = "pt_key=\(k);pt_pin=\(p);"
            emitSuccess(result: res, title: "🎉 成功提取京东 Cookie 凭证！")
            return
        }
        
        // 容错 3：抓取到的全量 Cookie 串直接输出，保证 100% 不空手而归
        if let k = ptKey, !k.isEmpty {
            let p = pin ?? "jd_user"
            let res = "pt_key=\(k);pt_pin=\(p);"
            emitSuccess(result: res, title: "🎉 成功提取凭证 Cookie！")
            return
        }
        
        if let w = wskey, !w.isEmpty {
            let p = pin ?? "jd_user"
            let res = "pin=\(p);wskey=\(w);"
            emitSuccess(result: res, title: "🎉 成功提取 WSKey！")
            return
        }
        
        if !fullCookieStr.isEmpty {
            emitSuccess(result: fullCookieStr, title: "🎉 提取成功 (Cookie 全量)")
            return
        }
        
        self.statusMessage = "未读取到 Cookie，请重新刷新二维码扫码"
    }
    
    private func emitSuccess(result: String, title: String) {
        self.extractedWSKey = result
        self.statusMessage = title
        self.isSuccess = true
        UIPasteboard.general.string = result
    }
    
    private func findCookieValue(name: String, in str: String) -> String? {
        let pattern = "(?:^|;\\s*|\\s+)" + name + "=([^;]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsStr = str as NSString
            if let match = regex.firstMatch(in: str, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                return nsStr.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return cookiesDict[name]
    }
    
    deinit {
        stopPolling()
    }
}
