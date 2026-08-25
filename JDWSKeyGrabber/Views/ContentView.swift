import SwiftUI

struct LoginViewWrapper: UIViewControllerRepresentable {
    var phone: String?
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
    @State private var selectedPhone: String? = nil
    @State private var showLoginView: Bool = false
    
    @State private var extractedWSKey: String? = nil
    @State private var showResultAlert: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                
                // 输入保存区域
                VStack(alignment: .leading, spacing: 10) {
                    Text("保存常用京东账号")
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
                                .bold()
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
                        Text("在上方输入手机号保存后，即可一键自动填写登录")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        Section(header: Text("已保存账号列表 (点击一键登录)")) {
                            ForEach(accountMgr.accounts) { acc in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(acc.phone)
                                            .font(.title3)
                                            .bold()
                                        Text("快捷填充并提取 Cookie")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        selectedPhone = acc.phone
                                        showLoginView = true
                                    }) {
                                        HStack {
                                            Image(systemName: "bolt.fill")
                                            Text("快捷登录")
                                        }
                                        .font(.subheadline)
                                        .bold()
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
            .sheet(isPresented: $showLoginView) {
                LoginViewWrapper(phone: selectedPhone) { result in
                    extractedWSKey = result
                    UIPasteboard.general.string = result
                    showResultAlert = true
                }
            }
            .alert(isPresented: $showResultAlert) {
                Alert(
                    title: Text("🎉 凭证提取成功！"),
                    message: Text("已自动复制到剪贴板：\n\n\(extractedWSKey ?? "")"),
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
