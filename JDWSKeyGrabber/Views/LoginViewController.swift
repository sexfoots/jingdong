import UIKit
import WebKit

protocol LoginViewControllerDelegate: AnyObject {
    func didExtractWSKey(_ result: String)
}

class LoginViewController: UIViewController, WKNavigationDelegate, WKHTTPCookieStoreObserver {

    weak var delegate: LoginViewControllerDelegate?
    var targetPhone: String?
    
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var topControlBar: UIView!
    private var btnFillPhone: UIButton!
    private var btnDone: UIButton!
    
    private let LOGIN_URL = "https://plogin.m.jd.com/login/login?appid=300&returnurl=https://m.jd.com/&source=wq_passport"
    
    private var extractedPin: String?
    private var extractedWSKey: String?
    private var extractedPtKey: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupTopBar()
        setupProgressView()
        setupWebView()
        
        loadLoginPage()
    }
    
    private func setupTopBar() {
        topControlBar = UIView()
        topControlBar.backgroundColor = UIColor.systemGroupedBackground
        topControlBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topControlBar)
        
        btnFillPhone = UIButton(type: .system)
        btnFillPhone.setTitle("📱 复制手机号", for: .normal)
        btnFillPhone.setTitleColor(.white, for: .normal)
        btnFillPhone.backgroundColor = .systemOrange
        btnFillPhone.layer.cornerRadius = 8
        btnFillPhone.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        btnFillPhone.addTarget(self, action: #selector(manualFillPhone), for: .touchUpInside)
        btnFillPhone.translatesAutoresizingMaskIntoConstraints = false
        topControlBar.addSubview(btnFillPhone)
        
        btnDone = UIButton(type: .system)
        btnDone.setTitle("✓ 提取凭证并返回", for: .normal)
        btnDone.setTitleColor(.white, for: .normal)
        btnDone.backgroundColor = .systemRed
        btnDone.layer.cornerRadius = 8
        btnDone.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        btnDone.addTarget(self, action: #selector(forceExtractAndFinish), for: .touchUpInside)
        btnDone.translatesAutoresizingMaskIntoConstraints = false
        topControlBar.addSubview(btnDone)
        
        NSLayoutConstraint.activate([
            topControlBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topControlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topControlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topControlBar.heightAnchor.constraint(equalToConstant: 54),
            
            btnFillPhone.leadingAnchor.constraint(equalTo: topControlBar.leadingAnchor, constant: 12),
            btnFillPhone.centerYAnchor.constraint(equalTo: topControlBar.centerYAnchor),
            btnFillPhone.heightAnchor.constraint(equalToConstant: 40),
            btnFillPhone.widthAnchor.constraint(equalTo: topControlBar.widthAnchor, multiplier: 0.45),
            
            btnDone.trailingAnchor.constraint(equalTo: topControlBar.trailingAnchor, constant: -12),
            btnDone.centerYAnchor.constraint(equalTo: topControlBar.centerYAnchor),
            btnDone.heightAnchor.constraint(equalToConstant: 40),
            btnDone.widthAnchor.constraint(equalTo: topControlBar.widthAnchor, multiplier: 0.45)
        ])
    }
    
    private func setupProgressView() {
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.tintColor = .systemRed
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: topControlBar.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let pref = WKPreferences()
        pref.javaScriptEnabled = true
        pref.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = pref
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1"
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        WKWebsiteDataStore.default().httpCookieStore.add(self)
    }
    
    private func loadLoginPage() {
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, let url = URL(string: self.LOGIN_URL) else { return }
                var req = URLRequest(url: url)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                self.webView.load(req)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1.0
        }
    }
    
    // MARK: - WKNavigationDelegate 拦截 HTTP 响应头中的 Set-Cookie (兼容 HTTPOnly)
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let httpResponse = navigationResponse.response as? HTTPURLResponse,
           let url = httpResponse.url, url.host?.contains("jd.com") == true {
            
            let headers = httpResponse.allHeaderFields
            for (key, value) in headers {
                let keyStr = String(describing: key).lowercased()
                if keyStr == "set-cookie" {
                    let cookieStr = String(describing: value)
                    parseCookieString(cookieStr)
                }
            }
        }
        checkCookies()
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkCookies()
        
        // 尝试通过 document.cookie 获取
        webView.evaluateJavaScript("document.cookie") { [weak self] result, _ in
            if let cookieStr = result as? String {
                self?.parseCookieString(cookieStr)
                self?.checkCookies()
            }
        }
    }
    
    // MARK: - WKHTTPCookieStoreObserver
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        checkCookies()
    }
    
    @objc private func manualFillPhone() {
        guard let phone = targetPhone, !phone.isEmpty else {
            showToast(message: "未接收到待填入的手机号")
            return
        }
        UIPasteboard.general.string = phone
        showToast(message: "手机号已复制！在输入框点击【粘贴】即可填入")
    }
    
    private func parseCookieString(_ str: String) {
        let pairs = str.components(separatedBy: ";")
        for pair in pairs {
            let kv = pair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
            if kv.count >= 2 {
                let k = kv[0].trimmingCharacters(in: .whitespaces)
                let v = kv[1].trimmingCharacters(in: .whitespaces)
                if k == "wskey" { extractedWSKey = v }
                if k == "pt_key" { extractedPtKey = v }
                if k == "pin" || k == "pt_pin" { extractedPin = v }
            }
        }
    }
    
    @objc private func forceExtractAndFinish() {
        checkCookies(force: true)
    }
    
    private func checkCookies(force: Bool = false) {
        // 先检查内部存储解析到的凭证
        if tryEmitResult() { return }
        
        // 尝试全量 Cookie 检索
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            
            for cookie in cookies {
                if cookie.name == "wskey" { self.extractedWSKey = cookie.value }
                if cookie.name == "pt_key" { self.extractedPtKey = cookie.value }
                if cookie.name == "pin" || cookie.name == "pt_pin" { self.extractedPin = cookie.value }
            }
            
            if self.tryEmitResult() { return }
            
            if force {
                self.showToast(message: "未检测到已登录 Cookie，请先在页面中完成登录！")
            }
        }
    }
    
    @discardableResult
    private func tryEmitResult() -> Bool {
        if let w = extractedWSKey, let p = extractedPin, !w.isEmpty, !p.isEmpty {
            let res = "pin=\(p);wskey=\(w);"
            delegate?.didExtractWSKey(res)
            dismiss(animated: true, completion: nil)
            return true
        }
        
        if let k = extractedPtKey, let p = extractedPin, !k.isEmpty, !p.isEmpty {
            let res = "pt_key=\(k);pt_pin=\(p);"
            delegate?.didExtractWSKey(res)
            dismiss(animated: true, completion: nil)
            return true
        }
        
        return false
    }
    
    private func showToast(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true, completion: nil)
        }
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        WKWebsiteDataStore.default().httpCookieStore.remove(self)
    }
}
