package com.reotech.mortgage_calculator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import android.util.Log

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            Log.d("AdMob", "Registering Native Ad Factories")
            // Register the Native Ad Factories
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine, "adFactoryExample", NativeAdFactoryExample(layoutInflater)
            )
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine, "toolsNativeFactory", NativeAdFactoryExample(layoutInflater)
            )
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine, "scheduleNativeFactory", NativeAdFactoryExample(layoutInflater)
            )
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine, "listTile", NativeAdFactoryExample(layoutInflater)
            )
            Log.d("AdMob", "Native Ad Factories registered successfully")
        } catch (e: Exception) {
            Log.e("AdMob", "Error registering Native Ad Factories", e)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "adFactoryExample")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "toolsNativeFactory")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "scheduleNativeFactory")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
    }
}

// Proper Native Ad Factory that inflates an XML layout.
class NativeAdFactoryExample(private val layoutInflater: LayoutInflater) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.ad_unified, null) as NativeAdView

        // Map the ad components to the NativeAdView's properties.
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.bodyView = adView.findViewById(R.id.ad_body)
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        adView.iconView = adView.findViewById(R.id.ad_app_icon)
        adView.mediaView = adView.findViewById(R.id.ad_media)
        adView.starRatingView = adView.findViewById(R.id.ad_stars)
        adView.advertiserView = adView.findViewById(R.id.ad_advertiser)

        // Set the ad content.
        (adView.headlineView as TextView).text = nativeAd.headline
        adView.mediaView?.setMediaContent(nativeAd.mediaContent)

        if (nativeAd.body == null) {
            adView.bodyView?.visibility = View.INVISIBLE
        } else {
            adView.bodyView?.visibility = View.VISIBLE
            (adView.bodyView as TextView).text = nativeAd.body
        }

        if (nativeAd.callToAction == null) {
            adView.callToActionView?.visibility = View.INVISIBLE
        } else {
            adView.callToActionView?.visibility = View.VISIBLE
            (adView.callToActionView as Button).text = nativeAd.callToAction
        }

        if (nativeAd.icon == null) {
            adView.iconView?.visibility = View.GONE
        } else {
            (adView.iconView as ImageView).setImageDrawable(nativeAd.icon?.drawable)
            adView.iconView?.visibility = View.VISIBLE
        }

        if (nativeAd.starRating == null) {
            adView.starRatingView?.visibility = View.INVISIBLE
        } else {
            (adView.starRatingView as RatingBar).rating = nativeAd.starRating!!.toFloat()
            adView.starRatingView?.visibility = View.VISIBLE
        }

        if (nativeAd.advertiser == null) {
            adView.advertiserView?.visibility = View.INVISIBLE
        } else {
            (adView.advertiserView as TextView).text = nativeAd.advertiser
            adView.advertiserView?.visibility = View.VISIBLE
        }

        // IMPORTANT: Call setNativeAd to enable user interactions.
        adView.setNativeAd(nativeAd)

        return adView
    }
}
