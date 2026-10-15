package jobs.acuc.app;

import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.FragmentActivity;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Fingerprint / face sign-in for the ACUC site bridge (acuc-native-app/bridge.js):
 *   checkBiometry()          → { isAvailable, biometryType (3 = fingerprint, 4 = face), reason }
 *   authenticate({ reason, androidTitle, androidSubtitle, allowDeviceCredential, cancelTitle })
 *                            → resolves when the person is recognised, rejects otherwise.
 */
@CapacitorPlugin(name = "BiometricAuth")
public class BiometricAuthPlugin extends Plugin {

    private int authenticators(boolean allowDeviceCredential) {
        int a = BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.BIOMETRIC_WEAK;
        if (allowDeviceCredential) a |= BiometricManager.Authenticators.DEVICE_CREDENTIAL;
        return a;
    }

    @PluginMethod
    public void checkBiometry(PluginCall call) {
        BiometricManager bm = BiometricManager.from(getContext());
        int res = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.BIOMETRIC_WEAK);
        JSObject r = new JSObject();
        r.put("isAvailable", res == BiometricManager.BIOMETRIC_SUCCESS);
        boolean face = getContext().getPackageManager().hasSystemFeature("android.hardware.biometrics.face");
        boolean finger = getContext().getPackageManager().hasSystemFeature("android.hardware.fingerprint");
        r.put("biometryType", finger ? 3 : (face ? 4 : 0));
        r.put("reason", res == BiometricManager.BIOMETRIC_SUCCESS ? "" : (res == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ? "No fingerprint or face is set up on this phone." : "Biometrics are not available on this phone."));
        call.resolve(r);
    }

    @PluginMethod
    public void authenticate(final PluginCall call) {
        final String title = call.getString("androidTitle", "ACUC");
        final String subtitle = call.getString("androidSubtitle", call.getString("reason", "Confirm it’s you"));
        final boolean allowCred = Boolean.TRUE.equals(call.getBoolean("allowDeviceCredential", true));
        final String cancel = call.getString("cancelTitle", "Cancel");
        getActivity().runOnUiThread(() -> {
            try {
                FragmentActivity act = (FragmentActivity) getActivity();
                BiometricPrompt prompt = new BiometricPrompt(act, ContextCompat.getMainExecutor(act), new BiometricPrompt.AuthenticationCallback() {
                    @Override public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) { call.resolve(); }
                    @Override public void onAuthenticationError(int code, CharSequence msg) { call.reject(String.valueOf(msg), code == BiometricPrompt.ERROR_USER_CANCELED || code == BiometricPrompt.ERROR_NEGATIVE_BUTTON || code == BiometricPrompt.ERROR_CANCELED ? "userCancel" : "authenticationFailed"); }
                    @Override public void onAuthenticationFailed() { /* the prompt stays open for another try */ }
                });
                BiometricPrompt.PromptInfo.Builder b = new BiometricPrompt.PromptInfo.Builder().setTitle(title).setSubtitle(subtitle);
                if (allowCred && android.os.Build.VERSION.SDK_INT >= 30) {
                    b.setAllowedAuthenticators(authenticators(true));
                } else {
                    b.setAllowedAuthenticators(authenticators(false)).setNegativeButtonText(cancel);
                }
                prompt.authenticate(b.build());
            } catch (Exception e) {
                call.reject(e.getMessage() != null ? e.getMessage() : "Biometric sign-in failed", "authenticationFailed");
            }
        });
    }
}
