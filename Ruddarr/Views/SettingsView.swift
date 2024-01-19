import SwiftUI
import Nuke

struct SettingsView: View {
    @AppStorage("instances") private var instances: [Instance] = []

    var body: some View {
        NavigationStack {
            List {
                instanceSection
                aboutSection
                systemSection
            }
            .navigationTitle("Settings")
        }
    }

    var instanceSection: some View {
        Section(header: Text("Instances")) {
            ForEach(instances) { instance in
                NavigationLink {
                    InstanceForm(state: .update, instance: instance)
                } label: {
                    VStack(alignment: .leading) {
                        Text(instance.label)
                        Text(instance.type.rawValue).font(.footnote).foregroundStyle(.gray)
                    }
                }
            }
            NavigationLink("Add instance") {
                InstanceForm(state: .create, instance: Instance())
            }
        }
    }

    let shareUrl = URL(string: "https://ruddarr.com")!
    let githubUrl = URL(string: "https://github.com/tillkruss/ruddarr/")!
    let reviewUrl = URL(string: "itms-apps://itunes.apple.com/app/id663592361")!

    var aboutSection: some View {
        Section(header: Text("About")) {
            ShareLink(item: shareUrl) {
                Label("Share App", systemImage: "square.and.arrow.up")
            }

            Link(destination: reviewUrl, label: {
                Label("Leave a Review", systemImage: "star")
            })

            Button {  MailComposeViewController.shared.sendEmail() } label: {
                Label("Email Support", systemImage: "square.and.pencil")
            }

            Link(destination: githubUrl, label: {
                Label("Contribute on GitHub", systemImage: "chevron.left.slash.chevron.right")
            })

            NavigationLink { ThridPartyLibraries() } label: {
                Label("Third Party Libraries", systemImage: "building.columns")
            }
        }
        .accentColor(.primary)
    }

    @State private var imageCacheSize: Int = 0
    @State private var showingEraseConfirmation: Bool = false

    var systemSection: some View {
        Section(header: Text("System")) {
            Button(role: .destructive, action: {
                clearImageCache()
            }, label: {
                LabeledContent(
                    "Clear Image Cache",
                    value: ByteCountFormatter().string(fromByteCount: Int64(imageCacheSize))
                )
            }).onAppear {
                calculateImageCacheSize()
            }

            Button("Erase All Settings", role: .destructive) {
                showingEraseConfirmation = true
            }
            .confirmationDialog("Are you sure?", isPresented: $showingEraseConfirmation) {
                Button("Erase All Settings", role: .destructive) {
                    if let bundleID = Bundle.main.bundleIdentifier {
                        instances.removeAll()
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                        showingEraseConfirmation = false
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to erase all settings?")
            }
        }
        .accentColor(.primary)
    }

    func calculateImageCacheSize() {
        let dataCache = try? DataCache(name: "com.github.radarr.DataCache")
        imageCacheSize = dataCache?.totalSize ?? 0
    }

    func clearImageCache() {
        let dataCache = try? DataCache(name: "com.github.radarr.DataCache")
        dataCache?.removeAll()
        imageCacheSize = 0
    }
}

struct ThridPartyLibraries: View {
    var body: some View {
        List {
            Link(destination: URL(string: "https://github.com/kean/Nuke")!, label: {
                HStack {
                    Text("Nuke")
                    Text("12.3.0").foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
            })
        }
        .accentColor(.primary)
        .navigationTitle("Third Party Libraries")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import UIKit
import MessageUI

class MailComposeViewController: UIViewController, MFMailComposeViewControllerDelegate {

    static let shared = MailComposeViewController()

    func sendEmail() {
        let email = "you@yoursite.com"
        let subject = "email subject"

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()

            mail.mailComposeDelegate = self
            mail.setToRecipients([email])
            mail.setSubject(subject)
            mail.setMessageBody("You're so awesome!", isHTML: false)

            view.window?.rootViewController?.present(mail, animated: true)
            // UIApplication.shared.windows.first?.rootViewController?.present(mail, animated: true)
        } else {
            // TODO: refine
            // https://chris-mash.medium.com/goodbye-mfmailcomposeviewcontroller-4d9778e8d862

            // let mailto = "mailto:\(email)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            let mailURLString = "mailto:\(email)?subject=\(subject)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

            if let mailURL = URL(string: mailURLString!) {
                // check not needed, but if desired add mailto to LSApplicationQueriesSchemes in Info.plist
                if UIApplication.shared.canOpenURL(mailURL) {
                    view.window?.windowScene?.open(mailURL, options: nil, completionHandler: nil)
                } else {
                    let githubUrl = URL(string: "https://github.com/tillkruss/ruddarr/issues/")!
                    view.window?.windowScene?.open(githubUrl, options: nil, completionHandler: nil)
                }
            }
        }
    }

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        let test = {
            let alertController = UIAlertController(title: "E-Mail not sent!", message: "E-Mail not sent.", preferredStyle: .alert)

            alertController.addAction(
                UIAlertAction(title: "OK", style: .cancel, handler: { (action: UIAlertAction!) in
            }))

            self.present(alertController, animated: true, completion: nil)
        }

        if let _ = error {
            // TODO: show alert
            controller.dismiss(animated: true, completion: test)
            return
        }

        switch result {
        case .sent, .saved, .cancelled:
            break
        case .failed:
            // TODO: show alert
            controller.dismiss(animated: true, completion: test)
        default:
            fatalError("MFMailComposeResult not handled")
        }

        controller.dismiss(animated: true)
    }
}

#Preview {
    ContentView(selectedTab: .settings)
}
