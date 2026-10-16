package jobs.acuc.app;

import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
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
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import java.util.HashSet;
import java.util.Set;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import androidx.core.view.WindowInsetsCompat;

public class MainActivity extends BridgeActivity {

    FastStart fastStart;
    PageLoader pageLoader;
    boolean shellAtStart = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // ACUC's own native pieces, reached by the site's in-app bridge by these exact names:
        // fingerprint / face sign-in ("BiometricAuth") and the encrypted key store ("SecureStorage").
        registerPlugin(BiometricAuthPlugin.class);
        registerPlugin(SecureStoragePlugin.class);
        fastStart = new FastStart(this);
        pageLoader = new PageLoader(this);
        super.onCreate(savedInstanceState);
        if (bridge != null) {
            bridge.setWebViewClient(new AcucWebViewClient(bridge, this));
        }
        keepPagesBelowSystemBars();
        tuneWebView();
        installShell();
    }

    /**
     * The app's own screen layer (instant screen layouts on tap, offline taps, no website service worker),
     * shipped inside the app and run at the start of every acuc.jobs screen.
     */
    private void installShell() {
        try {
            WebView wv = bridge != null ? bridge.getWebView() : null;
            if (wv == null) return;
            pageLoader.setUserAgent(wv.getSettings().getUserAgentString());
            if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                Set<String> origins = new HashSet<>();
                origins.add("https://acuc.jobs");
                origins.add("https://www.acuc.jobs");
                WebViewCompat.addDocumentStartJavaScript(wv, pageLoader.shellJs(), origins);
                shellAtStart = true;
            }
        } catch (Exception ignored) {
            shellAtStart = false;
        }
    }

    /** Smoother scrolling and no Android "glow" at the edges — the app has its own pull-to-refresh. */
    private void tuneWebView() {
        try {
            WebView wv = bridge != null ? bridge.getWebView() : null;
            if (wv == null) return;
            wv.setOverScrollMode(View.OVER_SCROLL_NEVER);
            wv.setBackgroundColor(Color.WHITE);
            wv.getSettings().setOffscreenPreRaster(true);
            wv.getSettings().setCacheMode(android.webkit.WebSettings.LOAD_DEFAULT);
            if (Build.VERSION.SDK_INT >= 26) wv.setRendererPriorityPolicy(WebView.RENDERER_PRIORITY_IMPORTANT, true);
            wv.setHapticFeedbackEnabled(true);
        } catch (Exception ignored) {}
    }

    /**
     * The app always draws the website BETWEEN the status bar and the navigation bar,
     * never underneath them (Android 15+ would otherwise draw the page edge-to-edge,
     * hiding headers under the clock and battery icons). The bars sit on solid white.
     */
    private void keepPagesBelowSystemBars() {
        android.view.Window w = getWindow();
        w.setBackgroundDrawable(new ColorDrawable(Color.WHITE));
        View decor = w.getDecorView();
        decor.setBackgroundColor(Color.WHITE);
        try {
            w.setStatusBarColor(Color.WHITE);
            w.setNavigationBarColor(Color.WHITE);
            if (Build.VERSION.SDK_INT >= 29) {
                w.setStatusBarContrastEnforced(false);
                w.setNavigationBarContrastEnforced(false);
            }
        } catch (Exception ignored) {}
        WindowInsetsControllerCompat barsCtl = WindowCompat.getInsetsController(w, decor);
        barsCtl.setAppearanceLightStatusBars(true);
        barsCtl.setAppearanceLightNavigationBars(true);
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
        public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
            FastStart fs = activity.fastStart;
            if (fs != null && request != null) {
                WebResourceResponse r = fs.launch(request);
                if (r != null) return r;
                r = fs.asset(request);
                if (r != null) return r;
            }
            // Screens are loaded by the app itself (offline copies, the app's own error screens).
            // Only where the start-of-page script works: Capacitor needs it for its bridge otherwise.
            if (activity.pageLoader != null && activity.shellAtStart && request != null) {
                WebResourceResponse r = activity.pageLoader.load(request);
                if (r != null) return r;
            }
            return super.shouldInterceptRequest(view, request);
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            super.onPageFinished(view, url);
            if (activity.fastStart != null && url != null) activity.fastStart.pageFinished(url);
            // Safety net: the screen layer is always there, even where it could not run at the start.
            if (url != null && url.startsWith("https://") && FastStart.isAcucHost(Uri.parse(url).getHost()) && activity.pageLoader != null) {
                String js = activity.pageLoader.shellJs();
                if (!js.isEmpty()) view.evaluateJavascript("if(!window.__acucShell){" + js + "\n}", null);
            }
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
