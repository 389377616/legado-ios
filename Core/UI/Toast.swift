import UIKit

enum Toast {
    private static var currentToast: UIView?
    
    static func show(_ message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            hide()
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            let toastView = UIView()
            toastView.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            toastView.layer.cornerRadius = 10
            toastView.clipsToBounds = true
            toastView.alpha = 0
            
            let label = UILabel()
            label.text = message
            label.textColor = .white
            label.font = .systemFont(ofSize: 14)
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            toastView.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 12),
                label.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -12),
                label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -16)
            ])
            
            toastView.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(toastView)
            
            NSLayoutConstraint.activate([
                toastView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                toastView.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -60),
                toastView.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 40),
                toastView.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -40)
            ])
            
            currentToast = toastView
            
            UIView.animate(withDuration: 0.3, animations: {
                toastView.alpha = 1
            }) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    hide()
                }
            }
        }
    }
    
    static func hide() {
        guard let toast = currentToast else { return }
        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 0
        }) { _ in
            toast.removeFromSuperview()
            currentToast = nil
        }
    }
}