package com.trust.web3.demo

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
            val wallet = Wallet("123456")
            val memo = wallet.recoverPhrase("123456")
            getSharedPreferences("MyWallet", MODE_PRIVATE).edit().putString("recoverPhrase", memo).apply()
            Toast.makeText(this, memo, Toast.LENGTH_LONG).show()
            val json = wallet.encryptJson()
            getSharedPreferences("MyWallet", MODE_PRIVATE).edit().putString("wallet", json).apply()
            val wallet2 = decryptJson(json, "123456")
            val memo2 = wallet2.recoverPhrase("123456")
            Toast.makeText(this, memo2, Toast.LENGTH_LONG).show()
        }
        val loadButton = findViewById<Button>(R.id.btn_load)
        loadButton.setOnClickListener {
            val json = getSharedPreferences("MyWallet", MODE_PRIVATE).getString("wallet", "")
            if (json.isNullOrEmpty()) {
                Toast.makeText(this, "No wallet", Toast.LENGTH_LONG).show()
                return@setOnClickListener
            }else{
                val wallet = decryptJson(json, "123456")
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
                val wallet = fromMnemonic(memo, "654321")
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
