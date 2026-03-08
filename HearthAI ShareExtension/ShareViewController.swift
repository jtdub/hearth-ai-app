import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let shareView = ShareView(
            extensionContext: extensionContext
        )
        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            hostingController.view.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            ),
            hostingController.view.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            hostingController.view.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
        ])
        hostingController.didMove(toParent: self)
    }
}
#elseif os(macOS)
import AppKit

class ShareViewController: NSViewController {
    override func loadView() {
        let shareView = ShareView(extensionContext: extensionContext)
        self.view = NSHostingView(rootView: shareView)
    }
}
#endif
