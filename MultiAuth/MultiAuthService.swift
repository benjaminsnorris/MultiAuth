//
//  MultiAuthService.swift
//  MultiAuth
//
//  Created by Ben Norris on 2/10/16.
//  Copyright © 2016 BSN Design. All rights reserved.
//

import UIKit
import MobileCoreServices

public struct MultiAuthService {
    
    // MARK: - Internal constants
    
    static let findLoginAction = "org.appextension.find-login-action"
    static let URLStringKey = "url_string"
    
    
    // MARK: - Private constants
    
    private static let usernameKey = "username"
    private static let passwordKey = "password"
    private static let logInViaSharedCredentialsKey = "MultiAuth.logInViaSharedCredentials"
    
    
    // MARK: - Private properties
    
    private let serverPath: String
    
    
    // MARK: - Initializer
    
    public init(serverPath: String) {
        self.serverPath = serverPath
    }
    
    
    // MARK: - Public API
        
    public func retrieveCredentialsFromActivityViewController(urlString: String, fromViewController viewController: UIViewController, sender: AnyObject, storedHandler: (username: String?, password: String?, errorMessage: String?) -> ()) {
        let activityViewController = configuredActivityViewController(urlString, sender: sender, handler: storedHandler)
        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
            if let returnedItems = returnedItems, extensionItem = returnedItems.first as? NSExtensionItem, itemProvider = extensionItem.attachments?.first as? NSItemProvider where itemProvider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                itemProvider.loadItemForTypeIdentifier(kUTTypePropertyList as String, options: nil) { itemDictionary, itemProviderError in
                    if let itemDictionary = itemDictionary as? [String: String] where itemProviderError == nil {
                        let username = itemDictionary[MultiAuthService.usernameKey]
                        let password = itemDictionary[MultiAuthService.passwordKey]
                        storedHandler(username: username, password: password, errorMessage: nil)
                    } else {
                        print("status=failed-to-load-item error=\(itemProviderError)")
                    }
                }
            } else {
                print("status=failed-to-find-login URLString=\(urlString) error=\(activityError)")
                storedHandler(username: nil, password: nil, errorMessage: nil)
            }
        }
        viewController.presentViewController(activityViewController, animated: true, completion: nil)
    }
    
    public func saveSharedCredentials(username username: String, password: String) {
        if MultiAuthService.didRecordLogInViaSharedCredentials() { return }
        guard let URL = NSURL(string: serverPath) else { fatalError("Invalid URL") }
        let baseURL: NSURL
        if let _baseURL = URL.baseURL {
            baseURL = _baseURL
        } else {
            baseURL = URL
        }
        guard let components = NSURLComponents(URL: baseURL, resolvingAgainstBaseURL: false), host = components.host else { fatalError("Could not get host from URL:\(baseURL)") }
        SecAddSharedWebCredential(host, username, password) { error in
            if let error = error {
                print("status=failed-to-save-credentials error=\(error)")
            } else {
                MultiAuthService.recordLogInViaSharedCredentials()
            }
        }
    }
    
}


// MARK: - Internal functions

extension MultiAuthService {
    
    static func recordLogInViaSharedCredentials() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: logInViaSharedCredentialsKey)
    }
    
}


// MARK: - Private functions

private extension MultiAuthService {
    
    func configuredActivityViewController(URLString: String, sender: AnyObject, handler: (username: String?, password: String?, errorMessage: String?) -> ()) -> UIActivityViewController {
        let item = [MultiAuthService.URLStringKey: URLString]
        let itemProvider = NSItemProvider(item: item, typeIdentifier: MultiAuthService.findLoginAction)
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [itemProvider]
        let keychainActivity = KeychainActivity()
        keychainActivity.handler = handler
        let activityViewController = UIActivityViewController(activityItems: [extensionItem], applicationActivities: [keychainActivity])
        if let barButtonItem = sender as? UIBarButtonItem {
            activityViewController.popoverPresentationController?.barButtonItem = barButtonItem
        } else if let senderView = sender as? UIView {
            activityViewController.popoverPresentationController?.sourceView = senderView.superview
            activityViewController.popoverPresentationController?.sourceRect = senderView.frame
        }
        return activityViewController
    }
    
    static func didRecordLogInViaSharedCredentials() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(logInViaSharedCredentialsKey)
    }
    
}
