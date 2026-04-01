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

    func showSwiftUIView<V: View>(_ swiftUIView: V) {
        view.subviews.forEach { $0.removeFromSuperview() }

        let hosting = NSHostingView(rootView: swiftUIView)
        hosting.frame = view.bounds
        hosting.autoresizingMask = [.width, .height]
        view.addSubview(hosting)
    }

    func showUnsupportedURL() {
        showSwiftUIView(UnsupportedURLView(close: close))
    }

    func showInstancePicker(_ instances: [Instance], onSelect: @escaping (Instance) -> Void) {
        showSwiftUIView(InstancePickerView(
            instances: instances,
            onSelect: onSelect,
            onCancel: close
        ))
    }

    func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
#else
class ShareViewController: UIViewController {

    private var hostingController: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
        processInput()
    }

    func showSwiftUIView<V: View>(_ swiftUIView: V) {
        view.isHidden = false

        if let existing = hostingController {
            existing.rootView = AnyView(swiftUIView)
            return
        }

        let hosting = UIHostingController(rootView: AnyView(swiftUIView))
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    func showUnsupportedURL() {
        showSwiftUIView(UnsupportedURLView(close: close))
    }

    func showInstancePicker(_ instances: [Instance], onSelect: @escaping (Instance) -> Void) {
        showSwiftUIView(InstancePickerView(
            instances: instances,
            onSelect: onSelect,
            onCancel: close
        ))
    }

    func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
#endif
