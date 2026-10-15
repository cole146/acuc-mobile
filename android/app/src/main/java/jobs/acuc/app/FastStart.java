package jobs.acuc.app;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import android.webkit.CookieManager;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Makes opening the app fast:
 *  1. Launch shortcut — a signed-in member opens straight on their home page (remembered from the last
 *     launch) instead of first asking the server "where should I go?" (one whole round trip saved).
 *  2. Asset cache — the site's versioned script, style, font and image files (…?ver=123) are kept on the
 *     phone and served from it, so each launch only downloads the page itself. A new ?ver= is a new
 *     address, so an updated file is fetched fresh automatically.
 */
final class FastStart {
    private static final String PREFS = "acuc_fast_start";
    private static final String K_HOME = "home";
    private static final long MAX_BYTES = 80L * 1024 * 1024;

    private final Context ctx;
    private final File dir;
    private final ExecutorService pool = Executors.newFixedThreadPool(3);
    private final Set<String> inFlight = ConcurrentHashMap.newKeySet();
    private boolean launched = false;

    FastStart(Context ctx) {
        this.ctx = ctx.getApplicationContext();
        this.dir = new File(this.ctx.getCacheDir(), "acuc-assets");
        //noinspection ResultOfMethodCallIgnored
        dir.mkdirs();
    }

    static boolean isAcucHost(String host) {
        if (host == null) return false;
        host = host.toLowerCase(Locale.ROOT);
        return host.equals("acuc.jobs") || host.endsWith(".acuc.jobs");
    }

    /* ------------------------------------------------------------------ launch shortcut */

    private boolean signedIn() {
        try {
            String c = CookieManager.getInstance().getCookie("https://acuc.jobs/");
            return c != null && c.contains("wordpress_logged_in_");
        } catch (Exception e) {
            return false;
        }
    }

    private boolean learnNext = false;

    /** The launch address (…?acuc_app_launch=1), when we already know where a signed-in member goes. */
    WebResourceResponse launch(WebResourceRequest req) {
        if (launched || !req.isForMainFrame()) return null;
        Uri u = req.getUrl();
        if (u == null || !isAcucHost(u.getHost()) || u.getQueryParameter("acuc_app_launch") == null) return null;
        launched = true;
        SharedPreferences sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        int n = sp.getInt("launches", 0) + 1;
        sp.edit().putInt("launches", n).apply();
        String home = sp.getString(K_HOME, null);
        // First launch, signed out, or every 10th launch: the server decides (and we learn its answer).
        if (home == null || !signedIn() || n % 10 == 0) {
            learnNext = true;
            return null;
        }
        String html = "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width'>"
                + "<style>html,body{margin:0;background:#fff}</style><script>location.replace(" + jsString(home) + ");</script>";
        Map<String, String> h = new HashMap<>();
        h.put("Cache-Control", "no-store");
        return new WebResourceResponse("text/html", "utf-8", 200, "OK", h, new ByteArrayInputStream(html.getBytes(StandardCharsets.UTF_8)));
    }

    /** Remember the member's home: the first page the server sent the launch to. */
    void pageFinished(String url) {
        if (!learnNext) return;
        try {
            Uri u = Uri.parse(url);
            if (!isAcucHost(u.getHost())) return;
            String p = u.getPath() == null ? "" : u.getPath();
            if (u.getQueryParameter("acuc_app_launch") != null) return;
            learnNext = false;
            if (p.startsWith("/acuc-lo") || p.startsWith("/wp-login") || p.startsWith("/register") || !signedIn()) return;
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(K_HOME, url).apply();
        } catch (Exception ignored) {}
    }

    private static String jsString(String s) {
        StringBuilder b = new StringBuilder("\"");
        for (char c : s.toCharArray()) {
            if (c == '"' || c == '\\') b.append('\\').append(c);
            else if (c == '<') b.append("\\u003c");
            else if (c < 32) b.append(' ');
            else b.append(c);
        }
        return b.append('"').toString();
    }

    /* ------------------------------------------------------------------ asset cache */

    private static String mimeFor(String path) {
        String p = path.toLowerCase(Locale.ROOT);
        if (p.endsWith(".js") || p.endsWith(".mjs")) return "application/javascript";
        if (p.endsWith(".css")) return "text/css";
        if (p.endsWith(".woff2")) return "font/woff2";
        if (p.endsWith(".woff")) return "font/woff";
        if (p.endsWith(".ttf")) return "font/ttf";
        if (p.endsWith(".svg")) return "image/svg+xml";
        if (p.endsWith(".png")) return "image/png";
        if (p.endsWith(".webp")) return "image/webp";
        if (p.endsWith(".jpg") || p.endsWith(".jpeg")) return "image/jpeg";
        if (p.endsWith(".gif")) return "image/gif";
        return null;
    }

    private static boolean versioned(Uri u) {
        for (String k : new String[]{"ver", "v", "version"}) {
            String v = u.getQueryParameter(k);
            if (v != null && !v.isEmpty()) return true;
        }
        return false;
    }

    private String keyFor(String url) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-1");
            byte[] d = md.digest(url.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte x : d) sb.append(String.format(Locale.ROOT, "%02x", x));
            return sb.toString();
        } catch (Exception e) {
            return Integer.toHexString(url.hashCode());
        }
    }

    /** Returns the cached file, or starts caching it in the background and returns null (normal load). */
    WebResourceResponse asset(WebResourceRequest req) {
        try {
            if (!"GET".equalsIgnoreCase(req.getMethod())) return null;
            Uri u = req.getUrl();
            if (u == null || !"https".equals(u.getScheme()) || !isAcucHost(u.getHost())) return null;
            String path = u.getPath() == null ? "" : u.getPath();
            String mime = mimeFor(path);
            if (mime == null || !versioned(u)) return null;
            if (path.contains("/wp-admin/") || path.contains("/wp-json/")) return null;
            String url = u.toString();
            File f = new File(dir, keyFor(url));
            if (f.exists() && f.length() > 0) {
                //noinspection ResultOfMethodCallIgnored
                f.setLastModified(System.currentTimeMillis());
                Map<String, String> h = new HashMap<>();
                h.put("Access-Control-Allow-Origin", "*");
                h.put("Cache-Control", "public, max-age=31536000, immutable");
                InputStream in = new FileInputStream(f);
                String enc = mime.startsWith("text/") || mime.contains("javascript") ? "utf-8" : null;
                return new WebResourceResponse(mime, enc, 200, "OK", h, in);
            }
            fetchLater(url);
        } catch (Exception ignored) {}
        return null;
    }

    private void fetchLater(final String url) {
        if (!inFlight.add(url)) return;
        pool.execute(() -> {
            HttpURLConnection c = null;
            File tmp = null;
            try {
                c = (HttpURLConnection) new URL(url).openConnection();
                c.setConnectTimeout(15000);
                c.setReadTimeout(30000);
                c.setRequestProperty("User-Agent", "ACUCApp asset cache");
                c.setInstanceFollowRedirects(true);
                if (c.getResponseCode() != 200) return;
                String ct = c.getContentType();
                if (ct != null && ct.toLowerCase(Locale.ROOT).startsWith("text/html")) return;   // an error page, not the file
                tmp = new File(dir, keyFor(url) + ".part");
                try (InputStream in = c.getInputStream(); OutputStream out = new FileOutputStream(tmp)) {
                    byte[] buf = new byte[16384];
                    int n;
                    long total = 0;
                    while ((n = in.read(buf)) > 0) {
                        out.write(buf, 0, n);
                        total += n;
                        if (total > 8L * 1024 * 1024) return;   // nothing that big belongs here
                    }
                }
                File f = new File(dir, keyFor(url));
                if (!tmp.renameTo(f)) return;
                tmp = null;
                trim();
            } catch (Exception ignored) {
            } finally {
                if (c != null) c.disconnect();
                if (tmp != null) //noinspection ResultOfMethodCallIgnored
                    tmp.delete();
                inFlight.remove(url);
            }
        });
    }

    /** Keeps the cache under MAX_BYTES, dropping the least recently used files. */
    private synchronized void trim() {
        File[] files = dir.listFiles();
        if (files == null) return;
        long total = 0;
        for (File f : files) total += f.length();
        if (total <= MAX_BYTES) return;
        Arrays.sort(files, Comparator.comparingLong(File::lastModified));
        for (File f : files) {
            if (total <= MAX_BYTES * 0.8) break;
            total -= f.length();
            //noinspection ResultOfMethodCallIgnored
            f.delete();
        }
    }
}
