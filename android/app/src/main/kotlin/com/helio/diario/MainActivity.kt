package com.helio.diario

import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        disableAutofill()
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        disableAutofill()
    }

    // Android 10 (moto g9 plus) commits a saved password back into an obscured
    // field on each keystroke. This password never leaves the device, so the
    // window opts out of autofill. NO_EXCLUDE_DESCENDANTS cannot be turned
    // back on by a child view.
    private fun disableAutofill() {
        window.decorView.importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
    }
}
