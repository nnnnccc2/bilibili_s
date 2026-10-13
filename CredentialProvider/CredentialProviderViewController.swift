//
//  CredentialProviderViewController.swift
//  CredentialProvider
//
//  AutoFill Credential Provider Extension
//  Called by iOS when user taps the key icon in password fields
//

import AuthenticationServices
import UIKit
import SwiftUI

class CredentialProviderViewController: ASExtensionViewController {

    private let sharedStore = SharedAccountStore()
    private var hostingController: UIHostingController<CredentialProviderView>?

    override func prepareInterfaceForExtensionRequest(_ request: ASExtensionRequest) {
        super.prepareInterfaceForExtensionRequest(request)

        let serviceIdentifiers = request.serviceIdentifiers
        let serviceIdentifier = serviceIdentifiers.first?.identifier ?? ""

        let view = CredentialProviderView(
            serviceIdentifier: serviceIdentifier,
            accounts: sharedStore.loadAccounts(),
            onSelect: { [weak self] account in
                self?.provideCredential(account: account)
            },
            onAdd: { [weak self] account in
                self?.sharedStore.saveAccount(account)
                self?.provideCredential(account: account)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userCanceled.rawValue
                ))
            }
        )

        let hostingController = UIHostingController(rootView: view)
        self.hostingController = hostingController
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }

    private func provideCredential(account: AccountItem) {
        let credential = ASPasswordCredential(
            user: account.username,
            password: account.password
        )
        extensionContext?.completeRequest(withSelectedCredential: credential) { _ in }
    }
}
