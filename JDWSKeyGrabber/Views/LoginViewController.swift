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
    
    private let userAgents = [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Mobile/15E148 Safari/604.1"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupTopBar()
        setupProgressView()
        setupWebView()
        
        clearDataAndLoad()
    }
    
    private func setupTopBar() {
        topControlBar = UIView()
        topControlBar.backgroundColor = UIColor.systemGroupedBackground
        topControlBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topControlBar)
        
        btnFillPhone = UIButton(type: .system)
        btnFillPhone.setTitle("📱 填入手机号", for: .normal)
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
        let store = WKWebsiteDataStore.nonPersistent()
        config.websiteDataStore = store
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = userAgents.randomElement()
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 观察 KVO 进度与 Cookie
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        store.httpCookieStore.add(self)
    }
    
    private func clearDataAndLoad() {
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            guard let self = self, let url = URL(string: self.LOGIN_URL) else { return }
            self.webView.load(URLRequest(url: url))
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1.0
            
            if webView.estimatedProgress > 0.6 {
                injectPhoneNumber()
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        injectPhoneNumber()
        checkCookies()
    }
    
    // MARK: - WKHTTPCookieStoreObserver
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        checkCookies()
    }
    
    @objc private func manualFillPhone() {
        guard let phone = targetPhone else { return }
        UIPasteboard.general.string = phone
        
        injectPhoneNumber()
        showToast(message: "已触发自动填号 (已复制手机号到剪贴板)")
    }
    
    /**
     * 完全移植 Android 版经过充分测试证明完美的 JS 算法：
     * 直读 placeholder，凡是提示文字里带有“码”或“code”的输入框，直接强行清空置为空白！
     * 对手机号框保留填入。
     */
    private func injectPhoneNumber() {
        guard let phone = targetPhone else { return }
        let js = """
            (function(val) {
                if (!val) return;
                var inputs = document.querySelectorAll('input');
                for (var i = 0; i < inputs.length; i++) {
                    var inp = inputs[i];
                    var type = (inp.getAttribute('type') || '').toLowerCase();
                    var placeholder = (inp.getAttribute('placeholder') || '');
                    
                    if (placeholder.indexOf('码') !== -1 || placeholder.toLowerCase().indexOf('code') !== -1) {
                        inp.value = '';
                        inp.dispatchEvent(new Event('input', { bubbles: true }));
                        inp.dispatchEvent(new Event('change', { bubbles: true }));
                        continue;
                    }
                    
                    if (type === 'tel' || type === 'number' || placeholder.indexOf('手机号') !== -1) {
                        inp.focus();
                        inp.value = val;
                        inp.dispatchEvent(new Event('input', { bubbles: true }));
                        inp.dispatchEvent(new Event('change', { bubbles: true }));
                        inp.dispatchEvent(new Event('blur', { bubbles: true }));
                    }
                }
            })('\(phone)');
        """
        
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    @objc private func forceExtractAndFinish() {
        checkCookies(force: true)
    }
    
    private func checkCookies(force: Bool = false) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            var wskey: String?
            var ptKey: String?
            var pin: String?
            
            for cookie in cookies {
                if cookie.name == "wskey" { wskey = cookie.value }
                if cookie.name == "pt_key" { ptKey = cookie.value }
                if cookie.name == "pin" || cookie.name == "pt_pin" { pin = cookie.value }
            }
            
            if let w = wskey, let p = pin {
                let res = "pin=\(p);wskey=\(w);"
                self.delegate?.didExtractWSKey(res)
                self.dismiss(animated: true, completion: nil)
                return
            }
            
            if let k = ptKey, let p = pin {
                let res = "pt_key=\(k);pt_pin=\(p);"
                self.delegate?.didExtractWSKey(res)
                self.dismiss(animated: true, completion: nil)
                return
            }
            
            if force {
                self.showToast(message: "未检测到已登录 Cookie，请先在页面中完成登录！")
            }
        }
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
        webView.configuration.websiteDataStore.httpCookieStore.remove(self)
    }
}
