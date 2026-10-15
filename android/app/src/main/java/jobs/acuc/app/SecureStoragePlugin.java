package jobs.acuc.app;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKeys;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Encrypted key store for the ACUC site bridge (it keeps the per-device sign-in key here).
 * Called from the page as get(key) / set(key, value) / remove(key); also accepts { key, value }.
 * Values are encrypted with a key held by Android Keystore and never leave the phone.
 */
@CapacitorPlugin(name = "SecureStorage")
public class SecureStoragePlugin extends Plugin {

    private SharedPreferences prefs;

    private SharedPreferences store() throws Exception {
        if (prefs == null) {
            Context c = getContext();
            String master = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC);
            prefs = EncryptedSharedPreferences.create("acuc_secure", master, c,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM);
        }
        return prefs;
    }

    // The page passes positional arguments, which reach native code as the call's data array/values.
    private String arg(PluginCall call, String name, int index) {
        String v = call.getString(name);
        if (v != null) return v;
        try {
            org.json.JSONArray a = call.getData().optJSONArray("args");
            if (a != null && a.length() > index) return a.optString(index, null);
        } catch (Exception ignored) {}
        return null;
    }

    @PluginMethod
    public void get(PluginCall call) {
        try {
            String key = arg(call, "key", 0);
            if (key == null) { call.reject("Missing key"); return; }
            JSObject r = new JSObject();
            String v = store().getString(key, null);
            r.put("data", v);
            r.put("value", v);
            call.resolve(r);
        } catch (Exception e) { call.reject(e.getMessage()); }
    }

    @PluginMethod
    public void set(PluginCall call) {
        try {
            String key = arg(call, "key", 0), val = arg(call, "value", 1);
            if (val == null) val = arg(call, "data", 1);
            if (key == null) { call.reject("Missing key"); return; }
            store().edit().putString(key, val).apply();
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage()); }
    }

    @PluginMethod
    public void remove(PluginCall call) {
        try {
            String key = arg(call, "key", 0);
            if (key != null) store().edit().remove(key).apply();
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage()); }
    }
}
