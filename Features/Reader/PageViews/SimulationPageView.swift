import SwiftUI
import UIKit

struct SimulationPageView: UIViewRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let pages: [String]
    @Binding var currentPage: Int
    let onTap: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> SimulationPageUIView {
        let view = SimulationPageUIView(
            pages: pages,
            viewModel: viewModel,
            onTap: onTap,
            coordinator: context.coordinator
        )
        return view
    }
    
    func updateUIView(_ uiView: SimulationPageUIView, context: Context) {
        uiView.updatePages(pages)
        uiView.updateCurrentPage(currentPage)
        uiView.updateTheme(
            backgroundColor: viewModel.backgroundColor,
            textColor: viewModel.textColor,
            fontSize: viewModel.fontSize
        )
    }
}

class SimulationPageUIView: UIView {
    private var pages: [String] = []
    private var currentPageIndex: Int = 0
    private var viewModel: ReaderViewModel
    private var onTap: () -> Void
    private var coordinator: SimulationPageView.Coordinator?
    
    private var currentPageView: UITextView?
    private var nextPageView: UITextView?
    
    private var curlPoint: CGPoint = .zero
    private var isAnimating: Bool = false
    private var animationProgress: CGFloat = 0
    private var animationDirection: Bool = true
    
    private var pageBackgroundColor: UIColor = .white
    private var pageTextColor: UIColor = .black
    private var fontSize: CGFloat = 18
    
    private var shadowLayer: CALayer?
    private var curlMaskLayer: CAShapeLayer?
    
    init(pages: [String], viewModel: ReaderViewModel, onTap: @escaping () -> Void, coordinator: SimulationPageView.Coordinator) {
        self.pages = pages
        self.viewModel = viewModel
        self.onTap = onTap
        self.coordinator = coordinator
        super.init(frame: .zero)
        
        setupViews()
        setupGestureRecognizers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        currentPageView = createTextView()
        nextPageView = createTextView()
        
        addSubview(currentPageView!)
        
        updateContent()
    }
    
    private func createTextView() -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.backgroundColor = pageBackgroundColor
        textView.textColor = pageTextColor
        textView.font = UIFont.systemFont(ofSize: fontSize)
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        return textView
    }
    
    private func setupGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }
    
    private func updateContent() {
        guard pages.indices.contains(currentPageIndex) else { return }
        currentPageView?.text = pages[currentPageIndex]
        
        if currentPageIndex + 1 < pages.count {
            nextPageView?.text = pages[currentPageIndex + 1]
        }
    }
    
    func updatePages(_ newPages: [String]) {
        pages = newPages
        updateContent()
    }
    
    func updateCurrentPage(_ index: Int) {
        if index != currentPageIndex && !isAnimating {
            currentPageIndex = index
            updateContent()
        }
    }
    
    func updateTheme(backgroundColor: Color, textColor: Color, fontSize: CGFloat) {
        self.pageBackgroundColor = UIColor(backgroundColor)
        self.pageTextColor = UIColor(textColor)
        self.fontSize = fontSize
        
        currentPageView?.backgroundColor = self.pageBackgroundColor
        currentPageView?.textColor = self.pageTextColor
        currentPageView?.font = UIFont.systemFont(ofSize: fontSize)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let location = gesture.location(in: self)
        
        switch gesture.state {
        case .began:
            isAnimating = true
            curlPoint = location
            animationDirection = translation.x < 0
            
        case .changed:
            curlPoint = location
            animationProgress = min(1, max(0, abs(translation.x) / (bounds.width * 0.5)))
            updateCurlAnimation()
            
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: self)
            
            if abs(velocity.x) > 500 || animationProgress > 0.5 {
                completeCurlAnimation()
            } else {
                cancelCurlAnimation()
            }
            
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let width = bounds.width
        
        if location.x < width * 0.3 {
            animateToPreviousPage()
        } else if location.x > width * 0.7 {
            animateToNextPage()
        } else {
            onTap()
        }
    }
    
    private func updateCurlAnimation() {
        let width = bounds.width
        let height = bounds.height
        
        let curlWidth = width * animationProgress
        
        let path = UIBezierPath()
        
        if animationDirection {
            path.move(to: CGPoint(x: width, y: 0))
            path.addCurve(
                to: CGPoint(x: width - curlWidth, y: height * 0.5),
                controlPoint1: CGPoint(x: width - curlWidth * 0.3, y: 0),
                controlPoint2: CGPoint(x: width - curlWidth * 0.7, y: height * 0.3)
            )
            path.addCurve(
                to: CGPoint(x: width, y: height),
                controlPoint1: CGPoint(x: width - curlWidth * 0.7, y: height * 0.7),
                controlPoint2: CGPoint(x: width - curlWidth * 0.3, y: height)
            )
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addCurve(
                to: CGPoint(x: curlWidth, y: height * 0.5),
                controlPoint1: CGPoint(x: curlWidth * 0.3, y: 0),
                controlPoint2: CGPoint(x: curlWidth * 0.7, y: height * 0.3)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: height),
                controlPoint1: CGPoint(x: curlWidth * 0.7, y: height * 0.7),
                controlPoint2: CGPoint(x: curlWidth * 0.3, y: height)
            )
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        currentPageView?.layer.mask = maskLayer
        
        let shadowPath = UIBezierPath(rect: CGRect(x: width - curlWidth - 10, y: 0, width: 10, height: height))
        let shadowLayer = CALayer()
        shadowLayer.frame = bounds
        shadowLayer.shadowPath = shadowPath.cgPath
        shadowLayer.shadowColor = UIColor.black.cgColor
        shadowLayer.shadowOpacity = Float(0.3 * animationProgress)
        shadowLayer.shadowRadius = 5
        shadowLayer.shadowOffset = CGSize(width: -3, height: 0)
        
        layer.addSublayer(shadowLayer)
        
        CATransaction.commit()
    }
    
    private func completeCurlAnimation() {
        UIView.animate(withDuration: 0.3, animations: {
            self.animationProgress = 1
            self.updateCurlAnimation()
        }) { _ in
            if self.animationDirection {
                self.moveToNextPage()
            } else {
                self.moveToPreviousPage()
            }
            self.resetCurlState()
        }
    }
    
    private func cancelCurlAnimation() {
        UIView.animate(withDuration: 0.2, animations: {
            self.animationProgress = 0
            self.updateCurlAnimation()
        }) { _ in
            self.resetCurlState()
        }
    }
    
    private func resetCurlState() {
        isAnimating = false
        animationProgress = 0
        currentPageView?.layer.mask = nil
        layer.sublayers?.filter { $0 != currentPageView?.layer }.forEach { $0.removeFromSuperlayer() }
    }
    
    private func moveToNextPage() {
        guard currentPageIndex + 1 < pages.count else { return }
        currentPageIndex += 1
        updateContent()
        coordinator?.updatePageIndex(currentPageIndex)
    }
    
    private func moveToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
        updateContent()
        coordinator?.updatePageIndex(currentPageIndex)
    }
    
    private func animateToNextPage() {
        isAnimating = true
        animationDirection = true
        
        UIView.animate(withDuration: 0.5, animations: {
            self.animationProgress = 1
            self.updateCurlAnimation()
        }) { _ in
            self.moveToNextPage()
            self.resetCurlState()
        }
    }
    
    private func animateToPreviousPage() {
        isAnimating = true
        animationDirection = false
        
        UIView.animate(withDuration: 0.5, animations: {
            self.animationProgress = 1
            self.updateCurlAnimation()
        }) { _ in
            self.moveToPreviousPage()
            self.resetCurlState()
        }
    }
}

extension SimulationPageUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension SimulationPageView {
    class Coordinator {
        var parent: SimulationPageView
        
        init(_ parent: SimulationPageView) {
            self.parent = parent
        }
        
        func updatePageIndex(_ index: Int) {
            Task { @MainActor in
                parent.currentPage = index
                parent.viewModel.currentPageIndex = index
            }
        }
    }
}
