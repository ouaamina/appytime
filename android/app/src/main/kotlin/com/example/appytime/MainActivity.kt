package com.example.appytime

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*
import android.graphics.drawable.BitmapDrawable
import android.util.Base64
import java.io.ByteArrayOutputStream
import android.graphics.Bitmap

import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.Canvas


class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app/usage"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            print(call.method);

            if (call.method == "getAppUsage") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val appUsage = getAppUsage()
                    result.success(appUsage)
                } else {
                    result.error("UNAVAILABLE", "Usage stats not available on this device", null)
                }
            } else if (call.method == "getAppState") {
                print("packageName");
                val packageName = call.argument<String>("packageName")
                print("month");
                val month = call.argument<Int>("month")
                if (packageName != null && month != null) {
                    val appState = getAppState(packageName, month)
                    result.success(appState)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing packageName or month", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }


    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun getAppUsage(): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.add(Calendar.DAY_OF_YEAR, -1)
        val startTime = calendar.timeInMillis

        val usageStatsList =
            usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        val packageManager = packageManager
        val appUsageList = mutableListOf<Map<String, Any>>()

        Log.d("MainActivity", "Usage stats list size: ${usageStatsList.size}")

        for (usageStats in usageStatsList) {
            try {
                val appInfo = packageManager.getApplicationInfo(usageStats.packageName, 0)
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                val appPackageName = appInfo.packageName;
                val appIcon = packageManager.getApplicationIcon(appInfo)
                val appIconBase64 = when (appIcon) {
                    is BitmapDrawable -> {
                        val byteArrayOutputStream = ByteArrayOutputStream()
                        appIcon.bitmap.compress(
                            Bitmap.CompressFormat.PNG,
                            100,
                            byteArrayOutputStream
                        )
                        Base64.encodeToString(byteArrayOutputStream.toByteArray(), Base64.NO_WRAP)
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
                        val byteArrayOutputStream = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
                        Base64.encodeToString(byteArrayOutputStream.toByteArray(), Base64.NO_WRAP)
                    }

                    else -> ""
                }
                val appCategory = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    when (appInfo.category) {
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
                } else {
                    "Other"
                }
                val timeUsed = usageStats.totalTimeInForeground / 60000 // Convert to minutes
                appUsageList.add(
                    mapOf(
                        "appName" to appName,
                        "appPackageName" to appPackageName,
                        "appIcon" to appIconBase64,
                        "appCategory" to appCategory,
                        "timeUsed" to timeUsed
                    )
                )
            } catch (e: PackageManager.NameNotFoundException) {
                Log.e("MainActivity", "App not found: ${usageStats.packageName}", e)
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

        // Set calendar to the first day of the given month
        calendar.set(Calendar.YEAR, currentYear)
        calendar.set(Calendar.MONTH, month - 1) // Calendar.MONTH is 0-indexed
        calendar.set(Calendar.DAY_OF_MONTH, 1)

        val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

        for (day in 1..daysInMonth) {
            val usage = getAppStateByDay(packageName, currentYear, month, day)
            dailyUsage.add(mapOf("day" to day, "timeUsed" to usage))
        }

        return mapOf(
            "dailyUsage" to dailyUsage
        )
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun getAppStateByDay(packageName: String, year: Int, month: Int, day: Int): Int {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val calendarStart = Calendar.getInstance()
        calendarStart.set(Calendar.YEAR, year)
        calendarStart.set(Calendar.MONTH, month - 1) // Calendar.MONTH is 0-indexed
        calendarStart.set(Calendar.DAY_OF_MONTH, day)
        calendarStart.set(Calendar.HOUR_OF_DAY, 0)
        calendarStart.set(Calendar.MINUTE, 0)
        calendarStart.set(Calendar.SECOND, 0)
        calendarStart.set(Calendar.MILLISECOND, 0)
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
        Log.d("MainActivity", "Stats size: ${stats.size}")

        var dailyUsage = 0

        for (usageStat in stats) {
            if (usageStat.packageName == packageName) {
                dailyUsage = (usageStat.totalTimeInForeground / 60000).toInt() // Convert to minutes
                Log.d("MainActivity", "${startTime} bteween ${endTime}")
                Log.d("MainActivity", "Found usage for $packageName: $dailyUsage minutes")
            }
        }

        return dailyUsage
    }


}