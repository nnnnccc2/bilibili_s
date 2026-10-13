//
//  CredentialProviderViewController.swift
//  CredentialProvider
//
//  AutoFill Credential Provider Extension (traditional API, iOS 12+)
//  Called by iOS when user taps the key icon in password fields
//

import AuthenticationServices
import UIKit
import SwiftUI

class CredentialProviderViewController: ASCredentialProviderViewController {

    private let sharedStore = SharedAccountStore()
    private var hostingController: UIHostingController<CredentialProviderView>?

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // Called when user taps the key icon in a password field
        let serviceIdentifier = serviceIdentifiers.first?.identifier ?? ""

        let rootView = CredentialProviderView(
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
                self?.extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userCanceled.rawValue
                ))
            }
        )

        let hostingController = UIHostingController(rootView: rootView)
        self.hostingController = hostingController
        addChild(hostingController)
        self.view.addSubview(hostingController.view)
        hostingController.view.frame = self.view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Called when iOS has a matching credential identity stored
        // We don't use the identity store, so cancel to show our UI
        extensionContext.cancelRequest(withError: NSError(
            domain: ASExtensionErrorDomain,
            code: ASExtensionError.userInteractionRequired.rawValue
        ))
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Fallback: show our UI
        prepareCredentialList(for: [])
    }

    private func provideCredential(account: AccountItem) {
        let credential = ASPasswordCredential(
            user: account.username,
            password: account.password
        )
        extensionContext.completeRequest(withSelectedCredential: credential) { _ in }
    }
}
