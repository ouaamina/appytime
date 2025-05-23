package com.example.appytime

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.*
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import android.os.Process
import android.util.Base64
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.*
import android.content.Intent
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app/usage"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppUsage" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        result.success(getAppUsage())
                    } else {
                        result.error("UNAVAILABLE", "Usage stats not available on this device", null)
                    }
                }

                "getAppState" -> {
                    val packageName = call.argument<String>("packageName")
                    val month = call.argument<Int>("month")
                    if (packageName != null && month != null) {
                        result.success(getAppState(packageName, month))
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing packageName or month", null)
                    }
                }

                "isUsagePermissionGranted" -> {
                    val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                    val mode = appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        packageName
                    )
                    result.success(mode == AppOpsManager.MODE_ALLOWED)
                }

                "openUsageSettings" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun getAppUsage(): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val packageManager = packageManager
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.add(Calendar.DAY_OF_YEAR, -1)
        val startTime = calendar.timeInMillis

        val usageStatsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            startTime,
            endTime
        )

        val usageMap = mutableMapOf<String, Long>()
        for (usageStats in usageStatsList) {
            usageMap[usageStats.packageName] = usageStats.totalTimeInForeground
        }

        val appUsageList = mutableListOf<Map<String, Any>>()
        val apps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)

        for (app in apps) {
            try {
                val appName = packageManager.getApplicationLabel(app).toString()
                val appIcon = packageManager.getApplicationIcon(app)

                val appIconBase64 = when (appIcon) {
                    is BitmapDrawable -> {
                        val stream = ByteArrayOutputStream()
                        appIcon.bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                    }

                    is AdaptiveIconDrawable -> {
                        val bitmap = Bitmap.createBitmap(
                            appIcon.intrinsicWidth,
                            appIcon.intrinsicHeight,
                            Bitmap.Config.ARGB_8888
                        )
                        val canvas = Canvas(bitmap)
                        appIcon.setBounds(0, 0, canvas.width, canvas.height)
                        appIcon.draw(canvas)
                        val stream = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                    }

                    else -> ""
                }

                val appCategory = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    when (app.category) {
                        ApplicationInfo.CATEGORY_GAME -> "Game"
                        ApplicationInfo.CATEGORY_AUDIO -> "Audio"
                        ApplicationInfo.CATEGORY_VIDEO -> "Video"
                        ApplicationInfo.CATEGORY_IMAGE -> "Image"
                        ApplicationInfo.CATEGORY_SOCIAL -> "Social"
                        ApplicationInfo.CATEGORY_NEWS -> "News"
                        ApplicationInfo.CATEGORY_MAPS -> "Maps"
                        ApplicationInfo.CATEGORY_PRODUCTIVITY -> "Productivity"
                        else -> "Other"
                    }
                } else "Other"

                val timeUsed = (usageMap[app.packageName] ?: 0L) / 60000 // convert ms to minutes

                appUsageList.add(
                    mapOf(
                        "appName" to appName,
                        "appPackageName" to app.packageName,
                        "appIcon" to appIconBase64,
                        "appCategory" to appCategory,
                        "timeUsed" to timeUsed
                    )
                )
            } catch (e: Exception) {
                Log.e("MainActivity", "Error processing app ${app.packageName}", e)
            }
        }

        return appUsageList
    }


    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun getAppState(packageName: String, month: Int): Map<String, List<Map<String, Int>>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val dailyUsage = mutableListOf<Map<String, Int>>()

        val calendar = Calendar.getInstance()
        val currentYear = calendar.get(Calendar.YEAR)

        calendar.set(Calendar.YEAR, currentYear)
        calendar.set(Calendar.MONTH, month - 1)
        calendar.set(Calendar.DAY_OF_MONTH, 1)

        val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

        for (day in 1..daysInMonth) {
            val usage = getAppStateByDay(packageName, currentYear, month, day)
            dailyUsage.add(mapOf("day" to day, "timeUsed" to usage))
        }

        return mapOf("dailyUsage" to dailyUsage)
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun getAppStateByDay(packageName: String, year: Int, month: Int, day: Int): Int {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val calendarStart = Calendar.getInstance().apply {
            set(year, month - 1, day, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = calendarStart.timeInMillis

        val calendarEnd = calendarStart.clone() as Calendar
        calendarEnd.set(Calendar.HOUR_OF_DAY, 23)
        calendarEnd.set(Calendar.MINUTE, 59)
        calendarEnd.set(Calendar.SECOND, 59)
        calendarEnd.set(Calendar.MILLISECOND, 999)
        val endTime = calendarEnd.timeInMillis

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )

        for (usageStat in stats) {
            if (usageStat.packageName == packageName) {
                return (usageStat.totalTimeInForeground / 60000).toInt()
            }
        }

        return 0
    }
}
