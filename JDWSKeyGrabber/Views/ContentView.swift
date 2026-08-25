import SwiftUI

struct AccountSheetItem: Identifiable {
    let id: String
    let phone: String
}

struct LoginViewWrapper: UIViewControllerRepresentable {
    var phone: String
    var onExtracted: (String) -> Void
    
    func makeUIViewController(context: Context) -> LoginViewController {
        let vc = LoginViewController()
        vc.targetPhone = phone
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: LoginViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, LoginViewControllerDelegate {
        var parent: LoginViewWrapper
        
        init(_ parent: LoginViewWrapper) {
            self.parent = parent
        }
        
        func didExtractWSKey(_ result: String) {
            parent.onExtracted(result)
        }
    }
}

struct ContentView: View {
    @StateObject private var accountMgr = AccountManager.shared
    @State private var inputPhone: String = ""
    @State private var activeSheetItem: AccountSheetItem? = nil
    @State private var showQRCodeSheet: Bool = false
    
    @State private var extractedWSKey: String? = nil
    @State private var showResultAlert: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                
                // 顶部最强功能推荐：扫码直取 WSKey
                Button(action: {
                    showQRCodeSheet = true
                }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🔥 京东 APP 扫码直取 WSKey")
                                .font(.system(size: 16, weight: .bold))
                            Text("无需手机号验证码，扫码直接提取 60 天超长凭证")
                                .font(.system(size: 11))
                                .opacity(0.9)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 输入保存区域
                VStack(alignment: .leading, spacing: 10) {
                    Text("保存常用京东账号 (H5模式)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("输入手机号 (如: 15042647397)", text: $inputPhone)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            accountMgr.saveAccount(phone: inputPhone)
                            inputPhone = ""
                        }) {
                            Text("保存")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 账号列表区域
                if accountMgr.accounts.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无保存的账号")
                            .foregroundColor(.gray)
                        Text("在上方输入手机号保存，或直接点击顶部扫码直取 WSKey")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        Section(header: Text("已保存账号列表 (H5登录模式)")) {
                            ForEach(accountMgr.accounts) { acc in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(acc.phone)
                                            .font(.system(size: 18, weight: .bold))
                                        Text("快捷填充并提取 Cookie")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        activeSheetItem = AccountSheetItem(id: acc.phone, phone: acc.phone)
                                    }) {
                                        HStack {
                                            Image(systemName: "bolt.fill")
                                            Text("快捷登录")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: accountMgr.deleteAccount)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("JD WSKey 提取器")
            .sheet(item: $activeSheetItem) { item in
                LoginViewWrapper(phone: item.phone) { result in
                    extractedWSKey = result
                    UIPasteboard.general.string = result
                    showResultAlert = true
                }
            }
            .sheet(isPresented: $showQRCodeSheet) {
                QRCodeLoginView { result in
                    extractedWSKey = result
                    UIPasteboard.general.string = result
                    showResultAlert = true
                }
            }
            .alert(isPresented: $showResultAlert) {
                Alert(
                    title: Text("🎉 WSKey 提取成功！"),
                    message: Text("已自动复制 60 天超长凭证到剪贴板：\n\n\(extractedWSKey ?? "")"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
