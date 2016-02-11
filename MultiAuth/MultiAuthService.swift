//
//  MultiAuthService.swift
//  MultiAuth
//
//  Created by Ben Norris on 2/10/16.
//  Copyright © 2016 BSN Design. All rights reserved.
//

import UIKit

struct AuthenticationService {
    
    // MARK: - Public properties
    
    var networkAccess: AuthenticationNetworkAccess = AuthenticationNetworkAPIAccess()
    var handler: ((username: String?, password: String?, errorMessage: String?) -> ())?
    
    
    // MARK: - Public constants
    
    static let findLoginAction = "org.appextension.find-login-action"
    static let URLStringKey = "url_string"
    
    
    // MARK: - Constants
    
    private static let usernameKey = "username"
    private static let passwordKey = "password"
    private static let logInViaSharedCredentialsKey = "logInViaSharedCredentials"
    
    
    // MARK: - Private properties
    
    private let serverPath: String
    
    
    // MARK: - Initializer
    
    init(serverPath: String) {
        self.serverPath = serverPath
    }
    
    
    // MARK: - Public API
    
    func logIn(username: String, password: String, completion: (error: String?) -> Void) {
        networkAccess.logIn(username, password: password) { success, error in
            if success && error == nil {
                self.saveSharedCredentials(username: username, password: password)
                completion(error: nil)
            } else if let error = error as? NSError {
                completion(error: error.localizedDescription)
            } else {
                completion(error: "Unknown error")
            }
        }
    }
    
    func logOut() {
        networkAccess.logOut()
    }
    
    func retrieveCredentials(URLString: String, viewController: UIViewController, sender: AnyObject) {
        let activityViewController = configuredActivityViewController(URLString, sender: sender)
        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
            if let returnedItems = returnedItems, extensionItem = returnedItems.first as? NSExtensionItem, itemProvider = extensionItem.attachments?.first as? NSItemProvider where itemProvider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                itemProvider.loadItemForTypeIdentifier(kUTTypePropertyList as String, options: nil) { itemDictionary, itemProviderError in
                    if let itemDictionary = itemDictionary as? [String: String] where itemProviderError == nil {
                        let username = itemDictionary[AuthenticationService.usernameKey]
                        let password = itemDictionary[AuthenticationService.passwordKey]
                        self.handler?(username: username, password: password, errorMessage: nil)
                    } else {
                        print("status=failed-to-load-item error=\(itemProviderError)")
                    }
                }
            } else {
                print("status=failed-to-find-login URLString=\(URLString) error=\(activityError)")
                self.handler?(username: nil, password: nil, errorMessage: nil)
            }
        }
        viewController.presentViewController(activityViewController, animated: true, completion: nil)
    }
    
    static func recordLogInViaSharedCredentials() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: logInViaSharedCredentialsKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
}


// MARK: - Private functions

private extension AuthenticationService {
    
    func configuredActivityViewController(URLString: String, sender: AnyObject) -> UIActivityViewController {
        let item = [AuthenticationService.URLStringKey: URLString]
        let itemProvider = NSItemProvider(item: item, typeIdentifier: AuthenticationService.findLoginAction)
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
    
    func saveSharedCredentials(username username: String, password: String) {
        if AuthenticationService.didRecordLogInViaSharedCredentials() { return }
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
                AuthenticationService.recordLogInViaSharedCredentials()
            }
        }
    }
    
    static func didRecordLogInViaSharedCredentials() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(logInViaSharedCredentialsKey)
    }
    
}
