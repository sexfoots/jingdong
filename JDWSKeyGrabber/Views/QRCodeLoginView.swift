import SwiftUI

struct QRCodeLoginView: View {
    @StateObject private var qrManager = QRCodeWSKeyManager()
    @Environment(\.presentationMode) var presentationMode
    
    var onWSKeyExtracted: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("京东 APP 扫码直取 60 天 WSKey")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                if let img = qrManager.qrImage {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                } else {
                    ProgressView()
                        .frame(width: 220, height: 220)
                }
                
                VStack(spacing: 8) {
                    Text(qrManager.statusMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(qrManager.isSuccess ? .green : .secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("提示：使用手机【京东 APP】扫一扫，确认登录后自动完成提取并复制到剪贴板。")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                if qrManager.isSuccess, let wskey = qrManager.extractedWSKey {
                    VStack(spacing: 12) {
                        Text("WSKey 凭证：")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(wskey)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(10)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(8)
                        
                        Button(action: {
                            onWSKeyExtracted(wskey)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("完成并返回")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("扫码提取 WSKey")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("关闭") {
                qrManager.stopPolling()
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                qrManager.startQRCodeLogin()
            }
            .onDisappear {
                qrManager.stopPolling()
            }
        }
    }
}
