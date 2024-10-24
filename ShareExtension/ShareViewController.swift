import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let extensionContext else {
            return
        }

        setupView(with: extensionContext)
    }

    // https://kylehaptonstall.com/posts/building-a-share-extension-with-swiftui/

    private func setupView(with context: NSExtensionContext) {
        let actionView = ActionView(
            url: URL(string: "https://example.com/test")
//            dismiss: { [weak self] in
//                self?.close()
//            }
        )

//        view.backgroundColor = .blue
//        view.isHidden = false

        let contentView = UIHostingController(
            rootView: actionView
        )

        addChild(contentView)

//        contentView.view.backgroundColor = .red
//        contentView.view.isHidden = false
//        contentView.view.frame = self.view.bounds

        view.addSubview(contentView.view)

        contentView.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.view.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func close() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        // self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
}

struct WidgetView: View {
    var body: some View {
        Text("This is a swiftUI view 👋")
    }
}
