// Copyright © 2017-2020 Trust Wallet.
//
// This file is part of Trust. The full Trust copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

// Some hidden helpers/extensions from trustwallet core
// https://github.com/trustwallet/wallet-core/blob/master/swift/Sources/Extensions/Data%2BHex.swift
import UIKit
import WebKit
import WalletCore
import TrustWeb3Provider
import BigInt

extension TrustWeb3Provider {
    static func createEthereum(address: String, chainId: Int, rpcUrl: String) -> TrustWeb3Provider {
        return TrustWeb3Provider(config: .init(ethereum: .init(address: address, chainId: chainId, rpcUrl: rpcUrl)))
    }
}

class DAppWebViewController: UIViewController {

    @IBOutlet weak var urlField: UITextField!

    //#NOTE https://github.com/alpha-carbon/payments-contract
    //this is a demo project that can imitate an evm blockchain + smart contract interactions
    var homepage: String {
//        return "http://localhost:3000"
        return "https://staging.wellcomemax.cryptosports.one/"
        // return "https://app.animeswap.org/#/?chain=aptos_devnet"
    }
    
    var switchToCustomChainID = false
    static var customChainID = 13370
//    static var address = "0x9d8a62f656a8d1615c1294fd71e9cfb3e4855a4f"
    static var address = "0xE513673FE758193EFb8aFd7765171cD70263736C"
    static var customURL = "https://aminoxtestnet.node.alphacarbon.network/"

    static let wallet = try! fromMnemonic(mnemonic: "bottom drive obey lake curtain smoke basket hold race lonely fit walk", password: "1234", chainId: 13370)

//    static let wallet = HDWallet(strength: 128, passphrase: "")!

    var current: TrustWeb3Provider = TrustWeb3Provider(config: .init(ethereum: ethereumConfigs[0])) //預設provider config

    var providers: [Int: TrustWeb3Provider] = {
        var result = [Int: TrustWeb3Provider]()
        ethereumConfigs.forEach {
            print("eth config", $0.chainId)
            result[$0.chainId] = TrustWeb3Provider(config: .init(ethereum: $0))
        }
        return result
    }()

    static var ethereumConfigs = [
        TrustWeb3Provider.Config.EthereumConfig(
            address: wallet.requestAccounts()[0],
            chainId: 13370,
            rpcUrl: "https://aminoxtestnet.node.alphacarbon.network/"
        ),
        TrustWeb3Provider.Config.EthereumConfig(
            address: wallet.requestAccounts()[0],
            chainId: 88888,
            rpcUrl: "http://localhost:9933"
        ),
        TrustWeb3Provider.Config.EthereumConfig(
            address: "0x9d8a62f656a8d1615c1294fd71e9cfb3e4855a4f",
            chainId: 1,
            rpcUrl: "https://cloudflare-eth.com"
        ),
        TrustWeb3Provider.Config.EthereumConfig(
            address: address,
            chainId: 10,
            rpcUrl: "https://mainnet.optimism.io"
        ),
        TrustWeb3Provider.Config.EthereumConfig(
            address: address,
            chainId: 56,
            rpcUrl: "https://bsc-dataseed4.ninicoin.io"
        ),
        TrustWeb3Provider.Config.EthereumConfig(
            address: address,
            chainId: 137,
            rpcUrl: "https://polygon-rpc.com"
        ),
        TrustWeb3Provider.Config.EthereumConfig(
            address: address,
            chainId: 250,
            rpcUrl: "https://rpc.ftm.tools"
        ),
        TrustWeb3Provider.Config.EthereumConfig(
            address: address,
            chainId: 42161,
            rpcUrl: "https://arb1.arbitrum.io/rpc"
        ),
        TrustWeb3Provider.Config.EthereumConfig(
            address: address,
            chainId: customChainID,
            rpcUrl: customURL
        )
    ]

    var cosmosChains = ["osmosis-1", "cosmoshub", "cosmoshub-4", "kava_2222-10", "evmos_9001-2"]
    var currentCosmosChain = "osmosis-1"

    lazy var webview: WKWebView = {
        let config = WKWebViewConfiguration()

        let controller = WKUserContentController()
        controller.addUserScript(current.providerScript)
        controller.addUserScript(current.injectScript)
        controller.add(self, name: TrustWeb3Provider.scriptHandlerName)
        print("injectScript:", current.injectScript.source)
        print("scriptHandlerName:", TrustWeb3Provider.scriptHandlerName)

        config.userContentController = controller
        config.allowsInlineMediaPlayback = true

        let webview = WKWebView(frame: .zero, configuration: config)
        webview.translatesAutoresizingMaskIntoConstraints = false
        webview.uiDelegate = self
        webview.navigationDelegate = self
        if #available(iOS 16.4, *) { 
            webview.isInspectable = true
        }

        return webview
    }()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        setupSubviews()
        urlField.text = homepage
        navigate(to: homepage)
    }

    func setupSubviews() {
        urlField.keyboardType = .URL
        urlField.delegate = self

        view.addSubview(webview)
        NSLayoutConstraint.activate([
            webview.topAnchor.constraint(equalTo: urlField.bottomAnchor),
            webview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webview.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
    }

    func navigate(to url: String) {
        guard let url = URL(string: url) else { return }
        webview.load(URLRequest(url: url))
    }

    var cosmosCoin: CoinType {
        switch currentCosmosChain {
        case "osmosis-1":
            return .osmosis
        case "cosmoshub", "cosmoshub-4":
            return .cosmos
        case "kava_2222-10":
            return .kava
        case "evmos_9001-2":
            return .nativeEvmos
        default:
            fatalError("no coin found for the current config")
        }
    }
}

extension DAppWebViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        navigate(to: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }
}

extension DAppWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let json = message.json
        print(json)
        guard
            let method = extractMethod(json: json),
            let id = json["id"] as? Int64,
            let network = extractNetwork(json: json)
        else {
            return
        }
        switch method {
        case .requestAccounts:
            if network == .cosmos {
                if let chainId = extractCosmosChainId(json: json), currentCosmosChain != chainId {
                    currentCosmosChain = chainId
                }
            }

            handleRequestAccounts(network: network, id: id)
        case .signTransaction:
            switch network {
            case .cosmos:
                break;
            case .aptos:
                break;
            case .ethereum:
                // #NOTE there is a JS bug here where sendTransaction is sent to signTransaction.
                // Currently the js isn't buildable for me so we will keep the
                // implementation here
                if let params = json["object"] as? [String: Any] {
                    aethersHandleSendTransaction(id, params)
                }                 

            default: break
            }

        case .signRawTransaction:
            switch network {
            case .solana:
                break;
            case .cosmos:
                break;
            default:
                print("\(network.rawValue) doesn't support signRawTransaction")
                break
            }
        case .signMessage:
            guard let data = extractMessage(json: json) else {
                print("data is missing")
                return
            }
            switch network {
            case .ethereum:
                handleSignMessage(id: id, data: data, addPrefix: false)
            case .solana, .aptos:
                break;
            case .cosmos:
                break;
            }
        case .signPersonalMessage:
            guard let data = extractMessage(json: json) else {
                print("data is missing")
                return
            }
            handleSignMessage(id: id, data: data, addPrefix: true)
        case .signTypedMessage:
            guard
                let data = extractMessage(json: json),
                let raw = extractRaw(json: json)
            else {
                print("data or raw json is missing")
                return
            }
            handleSignTypedMessage(id: id, data: data, raw: raw)
        case .sendTransaction:
            switch network {
            case .cosmos:
                guard
                    let mode = extractMode(json: json),
                    let raw = extractRaw(json: json)
                else {
                    print("mode or raw json is missing")
                    return
                }
                handleCosmosSendTransaction(id, mode, raw)
            case .aptos:
                guard let object = json["object"] as? [String: Any], let tx = object["tx"] as? [String: Any] else {
                    return
                }
                handleAptosSendTransaction(tx, id: id)
            case .ethereum:
                print("ETHEREUM SEND TRANSACTION")
            default:
                break
            }

        case .ecRecover:
            guard let tuple = extractSignature(json: json) else {
                print("signature or message is missing")
                return
            }
            let recovered = ecRecover(signature: tuple.signature, message: tuple.message) ?? ""
            print(recovered)
            DispatchQueue.main.async {
                self.webview.tw.send(network: .ethereum, result: recovered, to: id)
            }
        case .addEthereumChain:
            guard let (chainId, name, rpcUrls) = extractChainInfo(json: json) else {
                print("extract chain info error")
                return
            }
            if providers[chainId] != nil {
                handleSwitchEthereumChain(id: id, chainId: chainId)
            } else {
                handleAddChain(id: id, name: name, chainId: chainId, rpcUrls: rpcUrls)
            }
        case .switchChain, .switchEthereumChain:
            switch network {
            case .ethereum:
                guard
                    let chainId = extractEthereumChainId(json: json)
                else {
                    print("chain id is invalid")
                    return
                }
                handleSwitchEthereumChain(id: id, chainId: chainId)
            case .solana, .aptos:
                fatalError()
            case .cosmos:
                guard
                    let chainId = extractCosmosChainId(json: json)
                else {
                    print("chain id is invalid")
                    return
                }
                handleSwitchCosmosChain(id: id, chainId: chainId)
            }
        case .getTransactionReceipt:
            print("receive getTransactionReceipt event")
            break
        default:
            break
        }
    }

    func handleRequestAccounts(network: ProviderNetwork, id: Int64) {
        let alert = UIAlertController(
            title: webview.title,
            message: "\(webview.url?.host! ?? "Website") would like to connect your account",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: network, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "Connect", style: .default, handler: { [weak webview] _ in
            switch network {
            case .ethereum:
                let address = self.current.config.ethereum.address
                print("jayden test", network.rawValue, self.current.config.ethereum.chainId)
                webview?.tw.set(network: network.rawValue, address: address)
                webview?.tw.send(network: network, results: [address], to: id)
            case .solana:
                let address = "H4JcMPicKkHcxxDjkyyrLoQj7Kcibd9t815ak4UvTr9M"
                webview?.tw.send(network: network, results: [address], to: id)
//            case .cosmos:
//                let pubKey = Self.wallet.getKeyForCoin(coin: self.cosmosCoin).getPublicKeySecp256k1(compressed: true).description
//                let address = Self.wallet.getAddressForCoin(coin: self.cosmosCoin)
//                let json = try! JSONSerialization.data(
//                    withJSONObject: ["pubKey": pubKey, "address": address]
//                )
//                let jsonString = String(data: json, encoding: .utf8)!
//                webview?.tw.send(network: network, result: jsonString, to: id)
//            case .aptos:
//                let pubKey = Self.wallet.getKeyForCoin(coin: .aptos).getPublicKeySecp256k1(compressed: true).description
//                let address = Self.wallet.getAddressForCoin(coin: .aptos)
//                let json = try! JSONSerialization.data(
//                    withJSONObject: ["publicKey": pubKey, "address": address]
//                )
//                let jsonString = String(data: json, encoding: .utf8)!
//                webview?.tw.send(network: network, result: jsonString, to: id)
            default:
                break
            }

        }))
        present(alert, animated: true, completion: nil)
    }

    func handleSignMessage(id: Int64, data: Data, addPrefix: Bool) {
        let alert = UIAlertController(
            title: "Sign Ethereum Message",
            message: addPrefix ? String(data: data, encoding: .utf8) ?? "" : data.hexString,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
            let signed = try! Self.wallet.signTypedMessage(message: [UInt8](data))
            print("typed message: ", signed)
            webview?.tw.send(network: .ethereum, result: "0x" + signed, to: id)
        }))
        present(alert, animated: true, completion: nil)
    }

    func handleSignTypedMessage(id: Int64, data: Data, raw: String) {
        let alert = UIAlertController(
            title: "Sign Typed Message",
            message: raw,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
            let signed = try! Self.wallet.signTypedMessage(message: [UInt8](data))
            print("typed message: ", signed)
            webview?.tw.send(network: .ethereum, result: "0x" + signed, to: id)
            // let signed = self.signMessage(data: data, addPrefix: false)
            // webview?.tw.send(network: .ethereum, result: "0x" + signed.hexString, to: id)
        }))
        present(alert, animated: true, completion: nil)
    }

    func handleSignMessage(id: Int64, network: ProviderNetwork, data: Data) {
        let alert = UIAlertController(
            title: "Sign Solana Message",
            message: String(data: data, encoding: .utf8) ?? data.hexString,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .solana, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
//            let coin: CoinType = network == .solana ? .solana : .aptos
//            let signed = Self.wallet.(coin: coin).sign(digest: data, curve: .ed25519)!
//            webview?.tw.send(network: network, result: "0x" + signed.hexString, to: id)
            let signed = try! Self.wallet.signTypedMessage(message: [UInt8](data))
            print("typed message: ", signed)
            webview?.tw.send(network: .ethereum, result: "0x" + signed, to: id)
        }))
        present(alert, animated: true, completion: nil)
    }

    func handleSignTransaction(network: ProviderNetwork, id: Int64, onSign: @escaping (() -> Void)) {
        let alert = UIAlertController(
            title: "Sign Transaction",
            message: "Smart contract call",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: network, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            onSign()
        }))
        present(alert, animated: true, completion: nil)
    }

    func handleAddChain(id: Int64, name: String, chainId: Int, rpcUrls: [String]) {
        let alert = UIAlertController(
            title: "Add: " + name,
            message: "ChainId: \(chainId)\nRPC: \(rpcUrls.joined(separator: "\n"))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            guard let `self` = self else { return }
            self.providers[chainId] = TrustWeb3Provider.createEthereum(address: self.current.config.ethereum.address, chainId: chainId, rpcUrl: rpcUrls[0])
            print("\(name) added")
            self.webview.tw.sendNull(network: .ethereum, id: id)
        }))
        present(alert, animated: true, completion: nil)
    }

    func handleSwitchEthereumChain(id: Int64, chainId: Int) {
        print("SWITCHING CHAIN")
        guard let provider = providers[chainId] else {
            alert(title: "Error", message: "Unknown chain id: \(chainId)")
            webview.tw.send(network: .ethereum, error: "Unknown chain id", to: id)
            return
        }
        
        let currentConfig = current.config.ethereum
        let switchToConfig = provider.config.ethereum
        print("jayden test", chainId, provider.config.ethereum.chainId)
        if chainId == currentConfig.chainId {
            print("No need to switch, already on chain \(chainId)")
            webview.tw.sendNull(network: .ethereum, id: id)
        } else {
            let alert = UIAlertController(
                title: "Switch Chain",
                message: "ChainId: \(chainId)\nRPC: \(switchToConfig.rpcUrl)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
                webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                guard let `self` = self else { return }
                self.current = provider
                print("jayden test", chainId, self.current.config.ethereum.chainId)
                let provider = TrustWeb3Provider.createEthereum(
                    address: switchToConfig.address,
                    chainId: switchToConfig.chainId,
                    rpcUrl: switchToConfig.rpcUrl
                )
                print("jayden test", chainId, provider.config.ethereum.chainId)
                self.webview.tw.set(config: provider.config)
                self.webview.tw.emitChange(chainId: chainId)
                self.webview.tw.sendNull(network: .ethereum, id: id)
            }))
            present(alert, animated: true, completion: nil)
        }
    }

    func handleSwitchCosmosChain(id: Int64, chainId: String) {
        if !cosmosChains.contains(chainId) {
            alert(title: "Error", message: "Unknown chain id: \(chainId)")
            webview.tw.send(network: .ethereum, error: "Unknown chain id", to: id)
            return
        }

        if currentCosmosChain == chainId {
            print("No need to switch, already on chain \(chainId)")
            webview.tw.sendNull(network: .cosmos, id: id)
        } else {
            let alert = UIAlertController(
                title: "Switch Chain",
                message: "ChainId: \(chainId)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
                webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                guard let `self` = self else { return }
                self.currentCosmosChain = chainId
                self.webview.tw.sendNull(network: .cosmos, id: id)
            }))
            present(alert, animated: true, completion: nil)
        }
    }

    func handleAptosSendTransaction(_ tx: [String: Any], id: Int64) {
        let url = URL(string: "https://fullnode.devnet.aptoslabs.com/v1/transactions")!
        tx.postRequest(to: url) { (result: Result<[String: Any], Error>) -> Void in
            switch result {
            case .failure(let error):
                self.webview.tw.send(network: .aptos, error: error.localizedDescription, to: id)
            case .success(let json):
                if let _ = json["error_code"] as? String, let message = json["message"] as? String {
                    self.webview.tw.send(network: .aptos, error: message, to: id)
                    return
                }
                let hash = json["hash"] as! String
                self.webview.tw.send(network: .aptos, result: hash, to: id)
            }
        }
    }

    func handleCosmosSendTransaction(_ id: Int64,_ mode: String,_ raw: String) {
        let url = URL(string: "https://lcd-osmosis.keplr.app/cosmos/tx/v1beta1/txs")!
        ["mode": mode, "tx_bytes": raw].postRequest(to: url) { (result: Result<[String: Any], Error>) -> Void in
            switch result {
            case .failure(let error):
                self.webview.tw.send(network: .cosmos, error: error.localizedDescription, to: id)
            case .success(let json):
                guard let response = json["tx_response"] as? [String: Any],
                      let txHash = response["txhash"] as? String else {
                    self.webview.tw.send(network: .cosmos, error: "error json parsing", to: id)
                    return
                }
                self.webview.tw.send(network: .cosmos, result: txHash, to: id)
            }
        }
    }

    func aethersHandleSendTransaction(_ id: Int64, _ params: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: params, options: [])
        let payload = String(decoding: data, as: UTF8.self)
        let alert = UIAlertController(
            title: "Send Transaction",
            message: payload,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak webview] _ in
            webview?.tw.send(network: .ethereum, error: "Canceled", to: id)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak webview] _ in
            let provider_url = self.current.config.ethereum.rpcUrl
            if let provider = try? providerFromUrl(url: provider_url){
                // #HACK I have no idea how to get the raw body as a byte or string from the WKScriptMessage
                // it seems like the body is already pre-parsed to a dictionary
                // this re-serialization is easier than trying to create a matching object on all interfaces
                // (the TransactionRequest object)
                do {
                    let txHash = try Self.wallet.sendTransaction(provider: provider, payload: payload)
                    print("sent txHash", txHash)
                    webview?.tw.send(network: .ethereum, result: txHash, to: id)
                } catch {
                    print(error)
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    func alert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func extractMethod(json: [String: Any]) -> DAppMethod? {
        guard
            let name = json["name"] as? String
        else {
            return nil
        }
        return DAppMethod(rawValue: name)
    }

    private func extractNetwork(json: [String: Any]) -> ProviderNetwork? {
        guard
            let network = json["network"] as? String
        else {
            return nil
        }
        return ProviderNetwork(rawValue: network)
    }

    private func extractMessage(json: [String: Any]) -> Data? {
        guard
            let params = json["object"] as? [String: Any],
            let string = params["data"] as? String,
            let data = Data(hexString: string)
        else {
            return nil
        }
        return data
    }

    private func extractSignature(json: [String: Any]) -> (signature: Data, message: Data)? {
        guard
            let params = json["object"] as? [String: Any],
            let signature = params["signature"] as? String,
            let message = params["message"] as? String
        else {
            return nil
        }
        return (Data(hexString: signature)!, Data(hexString: message)!)
    }

    private func extractChainInfo(json: [String: Any]) ->(chainId: Int, name: String, rpcUrls: [String])? {
        guard
            let params = json["object"] as? [String: Any],
            let string = params["chainId"] as? String,
            let chainId = Int(String(string.dropFirst(2)), radix: 16),
            let name = params["chainName"] as? String,
            let urls = params["rpcUrls"] as? [String]
        else {
            return nil
        }
        return (chainId: chainId, name: name, rpcUrls: urls)
    }

    private func extractCosmosChainId(json: [String: Any]) -> String? {
        guard
            let params = json["object"] as? [String: Any],
            let chainId = params["chainId"] as? String
        else {
            return nil
        }
        return chainId
    }

    private func extractEthereumChainId(json: [String: Any]) -> Int? {
        guard
            let params = json["object"] as? [String: Any],
            let string = params["chainId"] as? String,
            let chainId = Int(String(string.dropFirst(2)), radix: 16),
            chainId > 0
        else {
            return nil
        }
        return chainId
    }

    private func extractRaw(json: [String: Any]) -> String? {
        guard
            let params = json["object"] as? [String: Any],
            let raw = params["raw"] as? String
        else {
            return nil
        }
        return raw
    }

    private func extractMode(json: [String: Any]) -> String? {
        guard
            let params = json["object"] as? [String: Any],
            let mode = params["mode"] as? String
        else {
            return nil
        }

        switch mode {
          case "async":
            return "BROADCAST_MODE_ASYNC"
          case "block":
            return "BROADCAST_MODE_BLOCK"
          case "sync":
            return "BROADCAST_MODE_SYNC"
          default:
            return "BROADCAST_MODE_UNSPECIFIED"
        }
    }

    private func ecRecover(signature: Data, message: Data) -> String? {
        let data = ethereumMessage(for: message)
        let hash = Hash.keccak256(data: data)
        guard let publicKey = PublicKey.recover(signature: signature, message: hash),
              PublicKey.isValid(data: publicKey.data, type: publicKey.keyType) else {
            return nil
        }
        return CoinType.ethereum.deriveAddressFromPublicKey(publicKey: publicKey).lowercased()
    }

    private func ethereumMessage(for data: Data) -> Data {
        let prefix = "\u{19}Ethereum Signed Message:\n\(data.count)".data(using: .utf8)!
        return prefix + data
    }
}

extension DAppWebViewController: WKNavigationDelegate{
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // Accept the certificate regardless of its validity
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            // Handle other types of challenges if needed
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("載入失敗: \(error.localizedDescription)")
        
        // 做一些特定操作（例如顯示錯誤訊息）
        let alertController = UIAlertController(title: "載入失敗", message: error.localizedDescription, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "確定", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
        
        // 或者你可以繼續載入網頁
        // webView.reload()
    }
}

extension DAppWebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.request.url != nil else {
            return nil
        }
        _ = webView.load(navigationAction.request)
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default, handler: { _ in
            completionHandler()
        }))
        present(alert, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default, handler: { _ in
            completionHandler(true)
        }))
        alert.addAction(.init(title: "Cancel", style: .cancel, handler: { _ in
            completionHandler(false)
        }))
        present(alert, animated: true, completion: nil)
    }
}

extension Dictionary where Key == String {
    func postRequest<T: Any>(to rpc: URL, completion: @escaping (Result<T, Error>) -> Void) {
        do {
            let data = try JSONSerialization.data(withJSONObject: self, options: [])
            data.postRequest(to: rpc, completion: completion)
        } catch(let error) {
            print("error is \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
}

extension Data {
    func postRequest<T: Any>(to rpc: URL, contentType: String = "application/json", completion: @escaping (Result<T, Error>) -> Void) {
        var request = URLRequest(url: rpc)
        request.httpMethod = "POST"
        request.httpBody = self
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("error is \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard
                let data = data,
                let result = (try? JSONSerialization.jsonObject(with: data) as? T) ?? data as? T
            else {
                return
            }
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
        task.resume()
    }
}
//# Helpful tools in swift that should be implemented somewhere
//https://github.com/trustwallet/wallet-core/blob/master/swift/Sources/Extensions/Data%2BHex.swift
//https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex-string-in-swift
