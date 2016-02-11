//
//  KeychainActivity.swift
//  MultiAuth
//
//  Created by Ben Norris on 2/10/16.
//  Copyright © 2016 BSN Design. All rights reserved.
//

import UIKit

class KeychainActivity: UIActivity {
    
    // MARK: - Internal properties
    
    var handler: ((username: String?, password: String?, errorMessage: String?) -> ())?
    
    
    // MARK: - Required overrides
    
    override func activityType() -> String? {
        return MultiAuthService.findLoginAction
    }
    
    override func activityTitle() -> String? {
        return "Keychain"
    }
    
    override func activityImage() -> UIImage? {
        return UIImage(named: "Key")
    }
    
    override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        if let extensionItem = activityItems.first as? NSExtensionItem {
            if let itemProvider = extensionItem.attachments?.first as? NSItemProvider where itemProvider.hasItemConformingToTypeIdentifier(MultiAuthService.findLoginAction) {
                return true
            }
        }
        return false
    }
    
    override class func activityCategory() -> UIActivityCategory {
        return .Action
    }
    
    override func performActivity() {
        SecRequestSharedWebCredential(.None, .None) { (credentials, error) -> Void in
            guard error == nil else {
                print("error loading safari credentials: \(error)")
                self.finishActivity(username: nil, password: nil, success: false)
                return
            }
            
            guard let unwrappedCredentials = credentials else {
                print("Error unwrapping credentials array", credentials)
                self.finishActivity(username: nil, password: nil, success: false)
                return
            }
            let arrayCredentials = unwrappedCredentials as [AnyObject]
            guard let typedCredentials = arrayCredentials as? [[String: AnyObject]] else {
                print("error typecasting credentials")
                self.finishActivity(username: nil, password: nil, success: false)
                return
            }
            
            if let credential = typedCredentials.first, username = credential[kSecAttrAccount as String] as? String, password = credential[kSecSharedPassword as String] as? String {
                MultiAuthService.recordLogInViaSharedCredentials()
                self.finishActivity(username: username, password: password, success: true)
            }
        }
    }
    
}


// MARK: - Private functions

private extension KeychainActivity {
    
    func finishActivity(username username: String?, password: String?, success: Bool) {
        handler?(username: username, password: password, errorMessage: success ? nil : "No saved passwords found")
        self.activityDidFinish(success)
    }
    
}
