//
//  MultiAuthService.swift
//  MultiAuth
//
//  Created by Ben Norris on 2/10/16.
//  Copyright © 2016 BSN Design. All rights reserved.
//

import UIKit
import MobileCoreServices
import OnePasswordExtension

public struct MultiAuthService {
    
    // MARK: - Internal constants
    
    static let findLoginAction = "org.appextension.find-login-action"
    static let URLStringKey = "url_string"
    
    
    // MARK: - Private constants
    
    private static let logInViaSharedCredentialsKey = "MultiAuth.logInViaSharedCredentials"
    
    
    // MARK: - Private properties
    
    private let serverURLString: String
    private let onePasswordExtension = OnePasswordExtension.sharedExtension()
    
    
    // MARK: - Initializer
    
    public init(serverURLString: String) {
        self.serverURLString = serverURLString
    }
    
    
    // MARK: - Public API
        
    public func retrieveCredentialsFromActivityViewController(urlString: String, fromViewController viewController: UIViewController, sender: AnyObject, storedHandler: (username: String?, password: String?, errorMessage: String?) -> ()) {
        let keychainActivity = KeychainActivity()
        keychainActivity.handler = storedHandler
        
        onePasswordExtension.findLoginForURLString(urlString, forViewController: viewController, sender: sender, applicationActivities: [keychainActivity]) { loginDictionary, error in
            if let loginDictionary = loginDictionary where error == nil {
                let username = loginDictionary[AppExtensionUsernameKey] as? String
                let password = loginDictionary[AppExtensionPasswordKey] as? String
                dispatch_async(dispatch_get_main_queue()) {
                    storedHandler(username: username, password: password, errorMessage: nil)
                }
            } else if error?.code == Int(AppExtensionErrorCodeCancelledByUser) {
                dispatch_async(dispatch_get_main_queue()) {
                    storedHandler(username: nil, password: nil, errorMessage: nil)
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    storedHandler(username: nil, password: nil, errorMessage: error?.localizedDescription)
                }
            }
        }
    }
    
    public func registerNewUser(appTitle appTitle: String, notes: String? = nil, sectionTitle: String? = nil, username: String = "", password: String = "", urlString: String, fromViewController viewController: UIViewController, sender: AnyObject, completion: (username: String?, password: String?, errorMessage: String?) -> Void) {
        
        var loginDetails: [String: AnyObject] = [
            AppExtensionTitleKey: appTitle,
            AppExtensionUsernameKey: username,
            AppExtensionPasswordKey: password,
        ]
        if let notes = notes {
            loginDetails[AppExtensionNotesKey] = notes
        }
        if let sectionTitle = sectionTitle {
            loginDetails[AppExtensionSectionTitleKey] = sectionTitle
        }
        
        onePasswordExtension.storeLoginForURLString(urlString, loginDetails: loginDetails, passwordGenerationOptions: nil, forViewController: viewController, sender: sender) { loginDictionary, error in
            if let loginDictionary = loginDictionary where error == nil {
                let username = loginDictionary[AppExtensionUsernameKey] as? String
                let password = loginDictionary[AppExtensionPasswordKey] as? String
                dispatch_async(dispatch_get_main_queue()) {
                    completion(username: username, password: password, errorMessage: nil)
                }
            } else if error?.code == Int(AppExtensionErrorCodeCancelledByUser) {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(username: nil, password: nil, errorMessage: nil)
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(username: nil, password: nil, errorMessage: error?.localizedDescription)
                }
            }
        }

    }
    
    public func saveSharedCredentials(username username: String, password: String) {
        if MultiAuthService.didRecordLogInViaSharedCredentials() { return }
        guard let URL = NSURL(string: serverURLString) else { fatalError("Invalid URL") }
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
    
    static func didRecordLogInViaSharedCredentials() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(logInViaSharedCredentialsKey)
    }
    
}
