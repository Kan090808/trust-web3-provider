package com.trust.web3.demo

import android.util.Log
import android.graphics.Bitmap
import android.net.http.SslError
import android.os.Bundle
import android.webkit.SslErrorHandler
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    companion object {
        private const val DAPP_URL = "https://www.magiceden.io/me"
        private const val CHAIN_ID = 56
        private const val RPC_URL = "https://bsc-dataseed2.binance.org"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        initLogger()
        Log.i("aethers","implVersion: ${implVersion()}")

        setContentView(R.layout.activity_main)

        val provderJs = loadProviderJs()
        val initJs = loadInitJs(
            CHAIN_ID,
            RPC_URL
        )
        WebView.setWebContentsDebuggingEnabled(true)
        val webview: WebView = findViewById(R.id.webview)
        webview.settings.run {
            javaScriptEnabled = true
            domStorageEnabled = true
        }
        WebAppInterface(this, webview, DAPP_URL).run {
            webview.addJavascriptInterface(this, "_tw_")

            val webViewClient = object : WebViewClient() {
                override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                    super.onPageStarted(view, url, favicon)
                    view?.evaluateJavascript(provderJs, null)
                    view?.evaluateJavascript(initJs, null)
                }

                override fun onReceivedSslError(
                    view: WebView?,
                    handler: SslErrorHandler?,
                    error: SslError?
                ) {
                    // Ignore SSL certificate errors
                    handler?.proceed()
                    println(error.toString())
                }
            }
            webview.webViewClient = webViewClient
            webview.loadUrl(DAPP_URL)
        }
        val createButton = findViewById<Button>(R.id.btn_create)
        createButton.setOnClickListener {
            val chain_id: ULong = 88888u
            val wallet = Wallet("123456", chain_id)
            val memo = wallet.recoverPhrase("123456")
            getSharedPreferences("MyWallet", MODE_PRIVATE).edit().putString("recoverPhrase", memo).apply()
            Toast.makeText(this, memo, Toast.LENGTH_LONG).show()
            val json = wallet.encryptJson()
            getSharedPreferences("MyWallet", MODE_PRIVATE).edit().putString("wallet", json).apply()
            try {
                val jsonString = "{\"crypto\":{\"cipher\":\"aes-128-ctr\",\"cipherparams\":{\"iv\":\"159f7792c62ffe92731a85d730c1613c\"},\"ciphertext\":\"3dd922c6248d07ab3fee4bd1b5d95b5e40e105eeace718355616af13f83e3e2817799379d9cd24aaf57e4c68a25e2133c62a28770856730095dbfce4d0d5d9d7841eee96776de62bfbabb610\",\"kdf\":\"scrypt\",\"kdfparams\":{\"dklen\":32,\"n\":8192,\"p\":1,\"r\":8,\"salt\":\"fc48d2e37f67b4d92c6427b3e9086ed6671dcd9dbe3dff406aec197693494506\"},\"mac\":\"2a606fb39e423c820440b7dd82ae24c477a6521d24d98f419013f1c47a916fbc\"},\"id\":\"0580948c-7ed5-4905-a045-7908971241f4\",\"version\":3}"

                val wallet2 = decryptJson(jsonString, "123456", chain_id)
                val memo2 = wallet2.recoverPhrase("123456")
                Toast.makeText(this, memo2, Toast.LENGTH_LONG).show()
            } catch(ex: InternalException) {
                println("internal exception: " + ex.toString())
            } catch(ex: WalletException) {
                println("wallet exception: " + ex.toString())
            }

        }
        val loadButton = findViewById<Button>(R.id.btn_load)
        loadButton.setOnClickListener {
            val json = getSharedPreferences("MyWallet", MODE_PRIVATE).getString("wallet", "")
            if (json.isNullOrEmpty()) {
                Toast.makeText(this, "No wallet", Toast.LENGTH_LONG).show()
                return@setOnClickListener
            }else{
                val wallet = decryptJson(json, "123456", 88888u)
                val memo = wallet.recoverPhrase("")
                Toast.makeText(this, memo, Toast.LENGTH_LONG).show()
            }
        }
        val loadMomo = findViewById<Button>(R.id.btn_load_memo)
        loadMomo.setOnClickListener {
            val memo = getSharedPreferences("MyWallet", MODE_PRIVATE).getString("recoverPhrase", "")
            if (memo.isNullOrEmpty()) {
                Toast.makeText(this, "No memo", Toast.LENGTH_LONG).show()
                return@setOnClickListener
            }else{
                val wallet = fromMnemonic(memo, "654321", 88888u)
                Toast.makeText(this, wallet.recoverPhrase("654321"), Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun loadProviderJs(): String {
        return resources.openRawResource(R.raw.trust_min).bufferedReader().use { it.readText() }
    }

    private fun loadInitJs(chainId: Int, rpcUrl: String): String {
        val source = """
        (function() {
            var config = {                
                ethereum: {
                    chainId: $chainId,
                    rpcUrl: "$rpcUrl"
                },
                solana: {
                    cluster: "mainnet-beta",
                },
                isDebug: true
            };
            trustwallet.ethereum = new trustwallet.Provider(config);
            trustwallet.solana = new trustwallet.SolanaProvider(config);
            trustwallet.postMessage = (json) => {
                window._tw_.postMessage(JSON.stringify(json));
            }
            window.ethereum = trustwallet.ethereum;
        })();
        """
        return  source
    }
}
