// Copyright © 2017-2020 Trust Wallet.
//
// This file is part of Trust. The full Trust copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //var buf = [UInt8](count: 32, repeatedValue: 0)
//        print("app init test")
//        let provider_url = "https://cloudflare-eth.com"
//        let provider = try! providerFromUrl(url: provider_url)
//        let wallet = Wallet(password: "1234")
//        let phrase = try! wallet.recoverPhrase(password: "1234")
////        print("new wallet phrase:", phrase)
//        let address = wallet.requestAccounts()
////        print("new wallet address:", address)
//        let encrypted = try! wallet.encryptJson()
////        print("encrypted wallet:\n", encrypted)
//        let decrypted_wallet = try! decryptJson(encrypted: encrypted, password: "1234")
//        let decrypted_address = decrypted_wallet.requestAccounts()
//        assert(address == decrypted_address)

        return true
    }
}
