import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Platform View Controller

#if os(macOS)
class ShareViewController: NSViewController {

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        processInput()
    }

    func showUnsupportedURL() {
        let hosting = NSHostingView(rootView: UnsupportedURLView(close: close))
        hosting.frame = view.bounds
        hosting.autoresizingMask = [.width, .height]
        view.addSubview(hosting)
    }

    func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
#else
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
        processInput()
    }

    func showUnsupportedURL() {
        view.isHidden = false

        let hosting = UIHostingController(rootView: UnsupportedURLView(close: close))
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
#endif
