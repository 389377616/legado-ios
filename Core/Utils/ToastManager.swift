import SwiftUI
import UIKit

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastItem?
    private var toastQueue: [ToastItem] = []
    private var displayTimer: Timer?
    
    struct ToastItem: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: ToastType
        let duration: TimeInterval
        
        static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum ToastType: Equatable {
        case info
        case success
        case warning
        case error
        case debug
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .debug: return "ladybug.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .debug: return .purple
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .info: return Color.blue.opacity(0.15)
            case .success: return Color.green.opacity(0.15)
            case .warning: return Color.orange.opacity(0.15)
            case .error: return Color.red.opacity(0.15)
            case .debug: return Color.purple.opacity(0.15)
            }
        }
    }
    
    func show(_ message: String, type: ToastType = .info, duration: TimeInterval = 3.0) {
        let toast = ToastItem(message: message, type: type, duration: duration)
        
        if currentToast == nil {
            displayToast(toast)
        } else {
            toastQueue.append(toast)
        }
    }
    
    func info(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .info, duration: duration)
    }
    
    func success(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .success, duration: duration)
    }
    
    func warning(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .warning, duration: duration)
    }
    
    func error(_ message: String, duration: TimeInterval = 4.0) {
        show(message, type: .error, duration: duration)
    }
    
    func debug(_ message: String, duration: TimeInterval = 5.0) {
        show(message, type: .debug, duration: duration)
    }
    
    private func displayToast(_ toast: ToastItem) {
        DispatchQueue.main.async {
            self.currentToast = toast
        }
        
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: toast.duration, repeats: false) { [weak self] _ in
            self?.dismissCurrent()
        }
    }
    
    private func dismissCurrent() {
        DispatchQueue.main.async {
            self.currentToast = nil
            
            if !self.toastQueue.isEmpty {
                let nextToast = self.toastQueue.removeFirst()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.displayToast(nextToast)
                }
            }
        }
    }
    
    func dismiss() {
        displayTimer?.invalidate()
        dismissCurrent()
    }
}

struct ToastView: View {
    let toast: ToastManager.ToastItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 20))
                .foregroundColor(toast.type.color)
            
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(toast.type.backgroundColor)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ToastModifier: ViewModifier {
    @StateObject private var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast)
                        .padding(.horizontal, 16)
                        .padding(.top, 50)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toastManager.currentToast != nil)
                        .onTapGesture {
                            toastManager.dismiss()
                        }
                }
            }
    }
}

extension View {
    func toast() -> some View {
        self.modifier(ToastModifier())
    }
}

func ToastInfo(_ message: String) {
    print("ℹ️ \(message)")
    DispatchQueue.main.async {
        ToastManager.shared.info(message)
    }
}

func ToastSuccess(_ message: String) {
    print("✅ \(message)")
    DispatchQueue.main.async {
        ToastManager.shared.success(message)
    }
}

func ToastWarning(_ message: String) {
    print("⚠️ \(message)")
    DispatchQueue.main.async {
        ToastManager.shared.warning(message)
    }
}

func ToastError(_ message: String) {
    print("❌ \(message)")
    DispatchQueue.main.async {
        ToastManager.shared.error(message)
    }
}

func ToastDebug(_ message: String) {
    print("🐛 \(message)")
    DispatchQueue.main.async {
        ToastManager.shared.debug(message)
    }
}