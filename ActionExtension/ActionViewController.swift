import UIKit
import SwiftUI
import MobileCoreServices
import UniformTypeIdentifiers

// TODO: needs icon

class ActionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else { return }
        guard let attachments = item.attachments else { return }
        let providers = attachments.filter { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.url.identifier) { (urlItem, _) in
            guard let url = urlItem as? URL else { return }

            DispatchQueue.main.async {
                self.renderView(url)
            }
        }
    }

    func renderView(_ url: URL?) {
        view.backgroundColor = .clear
        view.isHidden = true

        let actionView = ActionView(
            url: url,
            dismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingController = UIHostingController(rootView: actionView)

        addChild(hostingController)

        hostingController.view.backgroundColor = .clear
        hostingController.view.isHidden = true
        hostingController.view.frame = self.view.bounds

        self.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    func dismiss() {
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
