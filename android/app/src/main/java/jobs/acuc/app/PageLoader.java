package jobs.acuc.app;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.webkit.CookieManager;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Loads every acuc.jobs screen for the app, so the app — not the WebView — decides what a member sees:
 *  • a screen that loads is shown as usual, and a copy is kept on the phone;
 *  • no internet / a timeout: the last copy of that screen is shown (with a small "offline" note), or the
 *    app's own offline screen that reopens the page by itself when the connection is back;
 *  • a missing page (404) or a server error: the app's own friendly screen — never a "page not found"
 *    or a browser error page.
 */
final class PageLoader {
    private static final long MAX_CACHE = 40L * 1024 * 1024;
    private static final int MAX_PAGE = 4 * 1024 * 1024;
    private static final Pattern SKIP_PATH = Pattern.compile(
            "^/(wp-admin|wp-json|wp-content/uploads|feed)(/|$)|\\.(pdf|docx?|xlsx?|pptx?|zip|csv|ics|png|jpe?g|webp|gif|svg|mp4|mp3|txt|xml|json|js|css|woff2?)$",
            Pattern.CASE_INSENSITIVE);

    private final Context ctx;
    private final File dir;
    private volatile String userAgent;
    private String shellJs;
    private String screenHtml;

    PageLoader(Context ctx) {
        this.ctx = ctx.getApplicationContext();
        this.dir = new File(this.ctx.getCacheDir(), "acuc-pages");
        //noinspection ResultOfMethodCallIgnored
        dir.mkdirs();
    }

    void setUserAgent(String ua) { this.userAgent = ua; }

    String shellJs() {
        if (shellJs == null) shellJs = asset("acuc-shell/shell.js");
        return shellJs;
    }

    private String asset(String name) {
        try (InputStream in = ctx.getAssets().open(name)) {
            return new String(readAll(in, 4 * 1024 * 1024), StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "";
        }
    }

    /* ------------------------------------------------------------------ main entry */

    WebResourceResponse load(WebResourceRequest req) {
        if (req == null || !req.isForMainFrame() || !"GET".equalsIgnoreCase(req.getMethod())) return null;
        Uri u = req.getUrl();
        if (u == null || !"https".equals(u.getScheme()) || !FastStart.isAcucHost(u.getHost())) return null;
        String path = u.getPath() == null ? "/" : u.getPath();
        if (SKIP_PATH.matcher(path).find() || u.getQueryParameter("acuc_web") != null) return null;

        String url = stripFragment(u.toString());
        String key = keyFor(url);
        HttpURLConnection c = null;
        try {
            c = (HttpURLConnection) new URL(url).openConnection();
            c.setInstanceFollowRedirects(false);
            c.setUseCaches(false);
            c.setConnectTimeout(12000);
            c.setReadTimeout(25000);
            Map<String, String> rh = req.getRequestHeaders();
            if (rh != null) {
                for (Map.Entry<String, String> h : rh.entrySet()) {
                    String k = h.getKey();
                    if (k == null || k.equalsIgnoreCase("Accept-Encoding") || k.equalsIgnoreCase("Cookie") || k.equalsIgnoreCase("Host")) continue;
                    c.setRequestProperty(k, h.getValue());
                }
            }
            if (userAgent != null) c.setRequestProperty("User-Agent", userAgent);
            String ck = CookieManager.getInstance().getCookie(url);
            if (ck != null && !ck.isEmpty()) c.setRequestProperty("Cookie", ck);

            int code = c.getResponseCode();          // throws when there is no connection
            storeCookies(url, c);

            if (code >= 300 && code < 400) {
                String loc = c.getHeaderField("Location");
                c.disconnect();
                if (loc == null) return null;
                String to = new URL(new URL(url), loc).toString();
                return html(200, "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width'>"
                        + "<style>html,body{margin:0;background:#F5F7FB}</style><script>location.replace(" + jsString(to) + ");</script>");
            }
            if (code >= 200 && code < 300) {
                String ct = c.getContentType();
                if (code == 204 || ct == null || !ct.toLowerCase(Locale.ROOT).contains("text/html")) { c.disconnect(); return null; }
                String enc = charsetOf(ct);
                Map<String, String> headers = passHeaders(c);
                InputStream in = c.getInputStream();
                return new WebResourceResponse("text/html", enc, 200, "OK", headers, new CachingStream(in, key, c));
            }
            c.disconnect();
            if (code == 404 || code == 410) {
                //noinspection ResultOfMethodCallIgnored
                new File(dir, key).delete();
                return screen("notfound");
            }
            // 5xx, 403, 429…: the last copy if there is one, otherwise the app's "just a moment" screen.
            WebResourceResponse kept = cached(key, false);
            return kept != null ? kept : screen("server");
        } catch (IOException e) {
            if (c != null) try { c.disconnect(); } catch (Exception ignored) {}
            WebResourceResponse kept = cached(key, true);
            return kept != null ? kept : screen("offline");
        } catch (Exception e) {
            if (c != null) try { c.disconnect(); } catch (Exception ignored) {}
            return null;   // anything unexpected: let the WebView load it the normal way
        }
    }

    /* ------------------------------------------------------------------ responses */

    private WebResourceResponse screen(String kind) {
        if (screenHtml == null) screenHtml = asset("acuc-shell/screen.html");
        String h = screenHtml
                .replace("/*ACUC_SHELL*/", shellJs().replace("</script", "<\\/script"))
                .replace("__KIND__", kind)
                .replace("__ONLINE__", isOnline() ? "1" : "0");
        return html(200, h);
    }

    private static WebResourceResponse html(int code, String body) {
        Map<String, String> h = new HashMap<>();
        h.put("Cache-Control", "no-store");
        return new WebResourceResponse("text/html", "utf-8", code, "OK", h, new ByteArrayInputStream(body.getBytes(StandardCharsets.UTF_8)));
    }

    /** The last copy of a screen, with a small note at the top and a reload when the connection is back. */
    private WebResourceResponse cached(String key, boolean offline) {
        File f = new File(dir, key);
        if (!f.exists() || f.length() < 200) return null;
        try (InputStream in = new FileInputStream(f)) {
            String page = new String(readAll(in, MAX_PAGE + 1024), StandardCharsets.UTF_8);
            String note = "<script>(function(){window.ACUC_OFFLINE_PAGE=1;function go(){var b=document.createElement('div');"
                    + "b.style.cssText='position:fixed;left:50%;transform:translateX(-50%);top:10px;z-index:2147483640;background:#0B1A33;color:#fff;font:600 13px/1.35 Manrope,system-ui,sans-serif;padding:8px 14px;border-radius:999px;box-shadow:0 6px 18px rgba(0,0,0,.3);pointer-events:none;max-width:90vw;text-align:center';"
                    + "function s(){b.textContent=navigator.onLine?" + jsString(offline ? "Connection is slow — showing your last saved screen" : "ACUC is busy — showing your last saved screen")
                    + ":'You\\u2019re offline \\u2014 showing your last saved screen';}s();document.body.appendChild(b);"
                    + "addEventListener('offline',s);addEventListener('online',function(){b.textContent='Back online\\u2026';setTimeout(function(){location.reload()},400)});"
                    + "setTimeout(function(){if(navigator.onLine)location.reload()},30000);}"
                    + "if(document.body)go();else document.addEventListener('DOMContentLoaded',go);})();</script>";
            int at = indexOfTagEnd(page, "<head");
            page = at > 0 ? page.substring(0, at) + note + page.substring(at) : note + page;
            //noinspection ResultOfMethodCallIgnored
            f.setLastModified(System.currentTimeMillis());
            return html(200, page);
        } catch (Exception e) {
            return null;
        }
    }

    private static int indexOfTagEnd(String s, String tag) {
        int i = s.toLowerCase(Locale.ROOT).indexOf(tag);
        if (i < 0) return -1;
        int j = s.indexOf('>', i);
        return j < 0 ? -1 : j + 1;
    }

    /* ------------------------------------------------------------------ helpers */

    private static Map<String, String> passHeaders(HttpURLConnection c) {
        Map<String, String> out = new HashMap<>();
        for (Map.Entry<String, List<String>> h : c.getHeaderFields().entrySet()) {
            String k = h.getKey();
            if (k == null || h.getValue() == null || h.getValue().isEmpty()) continue;
            String lk = k.toLowerCase(Locale.ROOT);
            if (lk.equals("set-cookie") || lk.equals("content-length") || lk.equals("content-encoding") || lk.equals("transfer-encoding")
                    || lk.equals("connection") || lk.equals("keep-alive") || lk.equals("content-type") || lk.startsWith("x-android")) continue;
            out.put(k, h.getValue().get(h.getValue().size() - 1));
        }
        return out;
    }

    private static void storeCookies(String url, HttpURLConnection c) {
        try {
            boolean any = false;
            for (Map.Entry<String, List<String>> h : c.getHeaderFields().entrySet()) {
                if (h.getKey() == null || !h.getKey().equalsIgnoreCase("Set-Cookie") || h.getValue() == null) continue;
                for (String v : h.getValue()) { CookieManager.getInstance().setCookie(url, v); any = true; }
            }
            if (any) CookieManager.getInstance().flush();
        } catch (Exception ignored) {}
    }

    private static String charsetOf(String ct) {
        Matcher m = Pattern.compile("charset=([\\w-]+)", Pattern.CASE_INSENSITIVE).matcher(ct);
        return m.find() ? m.group(1) : "utf-8";
    }

    private static String stripFragment(String s) {
        int i = s.indexOf('#');
        return i >= 0 ? s.substring(0, i) : s;
    }

    /** One copy per screen address and per signed-in member (another member never sees it). */
    private String keyFor(String url) {
        String who = "guest";
        try {
            String c = CookieManager.getInstance().getCookie("https://acuc.jobs/");
            if (c != null) {
                for (String part : c.split(";")) {
                    String p = part.trim();
                    if (p.startsWith("wordpress_logged_in_")) { who = p; break; }
                }
            }
        } catch (Exception ignored) {}
        String u = url.replaceAll("([?&])(acuc_app_launch|_ga|fbclid|utm_[a-z]+)=[^&]*", "$1");
        return sha1(who + "|" + u);
    }

    private static String sha1(String s) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-1");
            byte[] d = md.digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte x : d) sb.append(String.format(Locale.ROOT, "%02x", x));
            return sb.toString();
        } catch (Exception e) {
            return Integer.toHexString(s.hashCode());
        }
    }

    private static String jsString(String s) {
        StringBuilder b = new StringBuilder("\"");
        for (char ch : s.toCharArray()) {
            if (ch == '"' || ch == '\\') b.append('\\').append(ch);
            else if (ch == '<') b.append("\\u003c");
            else if (ch < 32) b.append(' ');
            else if (ch > 126) b.append(String.format(Locale.ROOT, "\\u%04x", (int) ch));
            else b.append(ch);
        }
        return b.append('"').toString();
    }

    private static byte[] readAll(InputStream in, int max) throws IOException {
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        byte[] buf = new byte[16384];
        int n;
        while ((n = in.read(buf)) > 0) {
            bo.write(buf, 0, n);
            if (bo.size() > max) break;
        }
        return bo.toByteArray();
    }

    boolean isOnline() {
        try {
            ConnectivityManager cm = (ConnectivityManager) ctx.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) return true;
            NetworkCapabilities nc = cm.getNetworkCapabilities(cm.getActiveNetwork());
            return nc != null && nc.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
        } catch (Exception e) {
            return true;
        }
    }

    private synchronized void trim() {
        File[] files = dir.listFiles();
        if (files == null) return;
        long total = 0;
        for (File f : files) total += f.length();
        if (total <= MAX_CACHE) return;
        Arrays.sort(files, Comparator.comparingLong(File::lastModified));
        for (File f : files) {
            if (total <= MAX_CACHE * 0.75) break;
            total -= f.length();
            //noinspection ResultOfMethodCallIgnored
            f.delete();
        }
    }

    /** Passes the page to the WebView as it arrives and keeps a copy once it has fully arrived. */
    private final class CachingStream extends FilterInputStream {
        private final String key;
        private final HttpURLConnection conn;
        private ByteArrayOutputStream copy = new ByteArrayOutputStream();
        private boolean done = false;

        CachingStream(InputStream in, String key, HttpURLConnection conn) {
            super(in);
            this.key = key;
            this.conn = conn;
        }

        private void keep(byte[] b, int off, int n) {
            if (copy == null) return;
            if (copy.size() + n > MAX_PAGE) { copy = null; return; }
            copy.write(b, off, n);
        }

        private void finish() {
            if (done) return;
            done = true;
            if (copy == null || copy.size() < 200) return;
            File tmp = new File(dir, key + ".part");
            try (OutputStream o = new FileOutputStream(tmp)) {
                copy.writeTo(o);
            } catch (Exception e) {
                //noinspection ResultOfMethodCallIgnored
                tmp.delete();
                return;
            }
            //noinspection ResultOfMethodCallIgnored
            tmp.renameTo(new File(dir, key));
            copy = null;
            trim();
        }

        @Override
        public int read() throws IOException {
            int b = super.read();
            if (b < 0) finish(); else keep(new byte[]{(byte) b}, 0, 1);
            return b;
        }

        @Override
        public int read(byte[] b, int off, int len) throws IOException {
            int n = super.read(b, off, len);
            if (n < 0) finish(); else if (n > 0) keep(b, off, n);
            return n;
        }

        @Override
        public void close() throws IOException {
            try { super.close(); } finally { try { conn.disconnect(); } catch (Exception ignored) {} }
        }
    }
}
