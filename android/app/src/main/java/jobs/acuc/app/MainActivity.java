package jobs.acuc.app;

import android.graphics.Color;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import com.getcapacitor.Bridge;
import com.getcapacitor.BridgeActivity;
import com.getcapacitor.BridgeWebViewClient;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

public class MainActivity extends BridgeActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (bridge != null) {
            bridge.setWebViewClient(new AcucWebViewClient(bridge, this));
        }
        keepPagesBelowSystemBars();
    }

    /**
     * The app always draws the website BETWEEN the status bar and the navigation bar,
     * never underneath them (Android 15+ would otherwise draw the page edge-to-edge,
     * hiding headers under the clock and battery icons). The bars sit on solid white.
     */
    private void keepPagesBelowSystemBars() {
        View decor = getWindow().getDecorView();
        decor.setBackgroundColor(Color.WHITE);
        ViewCompat.setOnApplyWindowInsetsListener(decor, (v, insets) -> {
            Insets bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
            Insets ime = insets.getInsets(WindowInsetsCompat.Type.ime());
            boolean kb = insets.isVisible(WindowInsetsCompat.Type.ime());
            v.setPadding(bars.left, bars.top, bars.right, kb ? Math.max(ime.bottom, bars.bottom) : bars.bottom);
            // Tell the page there is nothing to avoid (it is already below the bars).
            return new WindowInsetsCompat.Builder(insets)
                .setInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout(), Insets.of(0, 0, 0, 0))
                .build();
        });
        ViewCompat.requestApplyInsets(decor);
    }

    /**
     * Capacitor shows the "offline" screen for ANY failed page — including a normal
     * 404/500 from the website and harmless aborted loads. ACUC only shows it when the
     * phone really cannot reach the internet; every other page is shown as the site sent it.
     */
    static class AcucWebViewClient extends BridgeWebViewClient {
        private final Bridge acucBridge;
        private final MainActivity activity;

        AcucWebViewClient(Bridge bridge, MainActivity activity) {
            super(bridge);
            this.acucBridge = bridge;
            this.activity = activity;
        }

        @Override
        public void onReceivedHttpError(WebView view, WebResourceRequest request, WebResourceResponse errorResponse) {
            // A 404 / 403 / 5xx page is a real page from acuc.jobs: show it, never the offline screen.
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
            if (request == null || !request.isForMainFrame()) return;
            int code = error != null ? error.getErrorCode() : 0;
            boolean network =
                code == WebViewClient.ERROR_HOST_LOOKUP ||
                code == WebViewClient.ERROR_CONNECT ||
                code == WebViewClient.ERROR_TIMEOUT ||
                code == WebViewClient.ERROR_PROXY_AUTHENTICATION ||
                code == WebViewClient.ERROR_IO;
            if (!network) return;   // cancelled loads, unknown links, etc. — ignore
            String errorUrl = acucBridge.getErrorUrl();
            if (errorUrl == null) return;
            String failed = request.getUrl() != null ? request.getUrl().toString() : "";
            String q = "?u=" + Uri.encode(failed) + (isOnline() ? "&on=1" : "");
            view.loadUrl(errorUrl + q);
        }

        private boolean isOnline() {
            try {
                ConnectivityManager cm = (ConnectivityManager) activity.getSystemService(CONNECTIVITY_SERVICE);
                if (cm == null) return true;
                NetworkCapabilities nc = cm.getNetworkCapabilities(cm.getActiveNetwork());
                return nc != null && nc.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
            } catch (Exception e) {
                return true;
            }
        }
    }
}
