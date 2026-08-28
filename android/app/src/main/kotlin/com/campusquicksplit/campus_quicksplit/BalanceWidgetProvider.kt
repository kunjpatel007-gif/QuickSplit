package com.campusquicksplit.campus_quicksplit
// NOTE: update this package declaration to match your actual applicationId
// (see android/app/build.gradle), and place this file at the matching path
// under android/app/src/main/kotlin/<your/package/path>/

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale
import com.campusquicksplit.campus_quicksplit.R
/**
 * Native widget provider backing the "Net Balance" home screen widget.
 * Data is written from Flutter via WidgetService (home_widget package),
 * stored in the app's SharedPreferences, and read here on each update.
 */
class BalanceWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val balance = prefs.getFloat("net_balance", 0.0f)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.balance_widget_layout)

            val formatter = NumberFormat.getCurrencyInstance(Locale.getDefault())
            val formattedBalance = formatter.format(balance)

            views.setTextViewText(R.id.widget_balance_text, formattedBalance)
            views.setTextViewText(R.id.widget_label, "Net Balance")

            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("quicksplit://add"))
            val pendingIntent = android.app.PendingIntent.getActivity(
                context,
                0,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add_button, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onEnabled(context: Context) {
        // Called the first time an instance of this widget is placed.
    }

    override fun onDisabled(context: Context) {
        // Called when the last instance of this widget is removed.
    }
}
