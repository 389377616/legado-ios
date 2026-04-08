import SwiftUI
import WebKit

struct VerificationCodeView: View {
    let source: BookSource
    let onComplete: ((String) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VerificationCodeViewModel
    @State private var inputCode = ""
    
    init(source: BookSource, onComplete: ((String) -> Void)? = nil) {
        self.source = source
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: VerificationCodeViewModel(source: source))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            viewModel.loadVerificationPage()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VerificationCodeWebView(viewModel: viewModel)
                        .frame(maxHeight: .infinity)
                    
                    VStack(spacing: 12) {
                        TextField("输入验证码", text: $inputCode)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        HStack {
                            Button("刷新") {
                                viewModel.refresh()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("确认") {
                                submitCode()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(inputCode.isEmpty)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                }
            }
            .navigationTitle("验证码登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    private func submitCode() {
        guard !inputCode.isEmpty else { return }
        
        viewModel.submitVerificationCode(inputCode) { success, cookies in
            if success, let cookies = cookies {
                onComplete?(cookies)
                dismiss()
            }
        }
    }
}

class VerificationCodeViewModel: ObservableObject {
    let source: BookSource
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    var webView: WKWebView?
    var currentURL: String = ""
    
    init(source: BookSource) {
        self.source = source
        loadVerificationPage()
    }
    
    func loadVerificationPage() {
        isLoading = true
        errorMessage = nil
    }
    
    func refresh() {
        webView?.reload()
    }
    
    func submitVerificationCode(_ code: String, completion: @escaping (Bool, String?) -> Void) {
        guard let webView = webView else {
            completion(false, nil)
            return
        }
        
        webView.evaluateJavaScript("document.querySelector('input[type=\"text\"], input[type=\"text\"]').value = '\(code)'") { _, _ in }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.extractCookies { cookies in
                completion(true, cookies)
            }
        }
    }
    
    private func extractCookies(completion: @escaping (String?) -> Void) {
        guard let webView = webView else {
            completion(nil)
            return
        }
        
        let dataStore = webView.configuration.websiteDataStore
        dataStore.httpCookieStore.getAllCookies { cookies in
            let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            completion(cookieString.isEmpty ? nil : cookieString)
        }
    }
}

struct VerificationCodeWebView: UIViewRepresentable {
    @ObservedObject var viewModel: VerificationCodeViewModel
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        viewModel.webView = webView
        
        let loginURL = viewModel.source.loginUrl.isEmpty ? viewModel.source.bookSourceUrl : viewModel.source.loginUrl
        if let url = URL(string: loginURL) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: VerificationCodeViewModel
        
        init(viewModel: VerificationCodeViewModel) {
            self.viewModel = viewModel
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.viewModel.isLoading = false
                self.viewModel.currentURL = webView.url?.absoluteString ?? ""
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.viewModel.isLoading = false
                self.viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}