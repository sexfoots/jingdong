import Foundation
import UIKit

class QRCodeWSKeyManager: ObservableObject {
    @Published var qrImage: UIImage? = nil
    @Published var statusMessage: String = "正在生成登录二维码..."
    @Published var isSuccess: Bool = false
    @Published var extractedWSKey: String? = nil
    
    private var token: String = ""
    private var oklToken: String = ""
    private var cookiesStr: String = ""
    private var timer: Timer?
    
    func startQRCodeLogin() {
        stopPolling()
        statusMessage = "正在向京东服务器获取二维码..."
        isSuccess = false
        extractedWSKey = nil
        
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
            
            // 提取 Response Cookie 中的 s_token / okl_token
            if let fields = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                var cookieArray: [String] = []
                for c in cookies {
                    cookieArray.append("\(c.name)=\(c.value)")
                    if c.name == "okl_token" {
                        self.oklToken = c.value
                    }
                }
                self.cookiesStr = cookieArray.joined(separator: "; ")
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
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkQRCodeStatus()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkQRCodeStatus() {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let checkUrlStr = "https://qr.m.jd.com/check?appid=133&callback=jQuery\(Int.random(in: 1000000...9999999))&token=\(token)&ou_state=0&okl_token=\(oklToken)&_=\(timestamp)"
        
        guard let url = URL(string: checkUrlStr) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://plogin.m.jd.com/", forHTTPHeaderField: "Referer")
        request.setValue(cookiesStr, forHTTPHeaderField: "Cookie")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, let httpResponse = response as? HTTPURLResponse else { return }
            
            let resStr = String(data: data, encoding: .utf8) ?? ""
            
            // 抓取 Response Cookie 中的 wskey & pin
            var currentWSKey: String?
            var currentPin: String?
            
            if let fields = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                for c in cookies {
                    if c.name == "wskey" { currentWSKey = c.value }
                    if c.name == "pin" || c.name == "pt_pin" { currentPin = c.value }
                }
            }
            
            DispatchQueue.main.async {
                if resStr.contains("\"code\":200") || resStr.contains("200") {
                    self.stopPolling()
                    
                    if let w = currentWSKey, let p = currentPin {
                        let finalResult = "pin=\(p);wskey=\(w);"
                        self.extractedWSKey = finalResult
                        self.statusMessage = "🎉 成功提取 60 天超长 WSKey！"
                        self.isSuccess = true
                        UIPasteboard.general.string = finalResult
                    } else {
                        self.statusMessage = "登录成功！正在二次抓取 WSKey..."
                        self.fetchWSKeyFromToken(cookiesResponse: httpResponse)
                    }
                } else if resStr.contains("\"code\":201") {
                    self.statusMessage = "已扫码，请在【京东 APP】点击确认登录"
                } else if resStr.contains("\"code\":203") || resStr.contains("\"code\":202") {
                    self.statusMessage = "二维码已过期，正在刷新..."
                    self.startQRCodeLogin()
                }
            }
        }.resume()
    }
    
    private func fetchWSKeyFromToken(cookiesResponse: HTTPURLResponse) {
        if let fields = cookiesResponse.allHeaderFields as? [String: String] {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: URL(string: "https://jd.com")!)
            var w: String?
            var p: String?
            for c in cookies {
                if c.name == "wskey" { w = c.value }
                if c.name == "pin" || c.name == "pt_pin" { p = c.value }
            }
            if let ws = w, let pin = p {
                let result = "pin=\(pin);wskey=\(ws);"
                self.extractedWSKey = result
                self.statusMessage = "🎉 成功提取 60 天超长 WSKey！"
                self.isSuccess = true
                UIPasteboard.general.string = result
            }
        }
    }
    
    deinit {
        stopPolling()
    }
}
