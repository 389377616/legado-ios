import SwiftUI
import UIKit

struct ReadViewWrapper: UIViewRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let onTap: () -> Void
    
    func makeUIView(context: Context) -> ReadView {
        let readView = ReadView()
        readView.callBack = context.coordinator
        readView.pageFactory = TextPageFactory(readView: readView)
        updatePageDelegate(for: readView)
        return readView
    }
    
    func updateUIView(_ uiView: ReadView, context: Context) {
        updatePageDelegate(for: uiView)
        uiView.upContent()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updatePageDelegate(for readView: ReadView) {
        let animationType = PageAnimationType(rawValue: viewModel.pageAnimation) ?? .cover
        readView.pageDelegate?.onDestroy()
        
        switch animationType {
        case .cover:
            readView.pageDelegate = CoverPageDelegate(readView: readView)
        case .slide:
            readView.pageDelegate = SlidePageDelegate(readView: readView)
        case .simulation:
            readView.pageDelegate = SimulationPageDelegate(readView: readView)
        case .scroll:
            readView.pageDelegate = ScrollPageDelegate(readView: readView)
        case .none:
            readView.pageDelegate = NoAnimPageDelegate(readView: readView)
        }
    }
    
    class Coordinator: NSObject, ReadViewCallBack {
        let parent: ReadViewWrapper
        
        init(_ parent: ReadViewWrapper) {
            self.parent = parent
        }
        
        func showActionMenu() {
            parent.onTap()
        }
        
        func hideActionMenu() {
            parent.onTap()
        }
        
        func addBookmark() {}
        func showTextActionMenu() {}
        func screenOffTimerStart() {}
        func upSystemUiVisibility() {}
        func autoPageStop() {}
        
        func upContent() {}
        func upMenuView() {}
        func upPageAnim() {}
        
        func upContent(relativePosition: CGFloat, resetPageOffset: Bool) {}
        func upMenu() {}
        func upMenuAnim() {}
        func upHidingToolbar(tools: [String]) {}
        
        func pageChanged() {
            if let page = parent.viewModel.currentPage {
                parent.viewModel.currentPageIndex = page.index
            }
        }
    }
}

extension ReadView: ReadViewProtocol {
    var isScroll: Bool {
        get { return pageDelegate is ScrollPageDelegate }
        set { }
    }
    
    func setContent() {
        upContent()
    }
    
    func clearSearchResult() {}
    func submitRenderTask() { setContent() }
    func submitPreRenderTask() {}
}
