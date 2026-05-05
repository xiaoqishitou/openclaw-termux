package com.xiaoqi.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.BatteryManager
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.app.Activity
import android.content.Context
import android.os.Environment
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.projection.MediaProjectionManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.provider.ContactsContract
import android.provider.CallLog
import android.provider.Telephony
import android.telephony.SmsManager
import android.net.wifi.WifiManager
import android.net.wifi.WifiInfo
import java.io.File
import java.net.NetworkInterface
import java.util.Collections
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.xiaoqi.openclawproot/native"
    private val EVENT_CHANNEL = "com.xiaoqi.openclawproot/gateway_logs"

    private lateinit var bootstrapManager: BootstrapManager
    private lateinit var processManager: ProcessManager
    private var screenCaptureResult: MethodChannel.Result? = null
    private var screenCaptureDurationMs: Long = 5000L
    private var setupDone = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val filesDir = applicationContext.filesDir.absolutePath
        val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir

        bootstrapManager = BootstrapManager(applicationContext, filesDir, nativeLibDir)
        processManager = ProcessManager(filesDir, nativeLibDir)

        // Ensure directories and resolv.conf exist on every app start.
        // Android may clear filesDir during APK update (#40).
        if (!setupDone) {
            setupDone = true
            Thread {
                try { bootstrapManager.setupDirectories() } catch (_: Exception) {}
                try { bootstrapManager.writeResolvConf() } catch (_: Exception) {}
            }.start()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getProotPath" -> {
                    result.success(processManager.getProotPath())
                }
                "getArch" -> {
                    result.success(ArchUtils.getArch())
                }
                "getFilesDir" -> {
                    result.success(filesDir)
                }
                "getNativeLibDir" -> {
                    result.success(nativeLibDir)
                }
                "isBootstrapComplete" -> {
                    result.success(bootstrapManager.isBootstrapComplete())
                }
                "getBootstrapStatus" -> {
                    result.success(bootstrapManager.getBootstrapStatus())
                }
                "extractRootfs" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        Thread {
                            try {
                                bootstrapManager.extractRootfs(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("EXTRACT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "runInProot" -> {
                    val command = call.argument<String>("command")
                    val timeout = call.argument<Int>("timeout")?.toLong() ?: 900L
                    if (command != null) {
                        Thread {
                            try {
                                val output = processManager.runInProotSync(command, timeout)
                                runOnUiThread { result.success(output) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("PROOT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "command required", null)
                    }
                }
                "startGateway" -> {
                    try {
                        GatewayService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopGateway" -> {
                    try {
                        GatewayService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isGatewayRunning" -> {
                    result.success(GatewayService.isProcessAlive())
                }
                "isEmulator" -> {
                    result.success(isEmulator())
                }
                "startTerminalService" -> {
                    try {
                        TerminalSessionService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopTerminalService" -> {
                    try {
                        TerminalSessionService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isTerminalServiceRunning" -> {
                    result.success(TerminalSessionService.isRunning)
                }
                "startNodeService" -> {
                    try {
                        NodeForegroundService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopNodeService" -> {
                    try {
                        NodeForegroundService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isNodeServiceRunning" -> {
                    result.success(NodeForegroundService.isRunning)
                }
                "updateNodeNotification" -> {
                    val text = call.argument<String>("text") ?: "Node connected"
                    NodeForegroundService.updateStatus(text)
                    result.success(true)
                }
                "startSshd" -> {
                    val port = call.argument<Int>("port") ?: 8022
                    try {
                        SshForegroundService.start(applicationContext, port)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopSshd" -> {
                    try {
                        SshForegroundService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isSshdRunning" -> {
                    result.success(SshForegroundService.isRunning)
                }
                "getSshdPort" -> {
                    result.success(SshForegroundService.currentPort)
                }
                "getDeviceIps" -> {
                    result.success(SshForegroundService.getDeviceIps())
                }
                "setRootPassword" -> {
                    val password = call.argument<String>("password")
                    if (password != null) {
                        Thread {
                            try {
                                val escaped = password.replace("'", "'\\''")
                                processManager.runInProotSync(
                                    "echo 'root:$escaped' | chpasswd", 15
                                )
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("SSH_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "password required", null)
                    }
                }
                "requestBatteryOptimization" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${packageName}")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "isBatteryOptimized" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                }
                "getBatteryStatus" -> {
                    try {
                        val batteryIntent =
                            registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                        if (batteryIntent == null) {
                            result.error("BATTERY_ERROR", "Battery status unavailable", null)
                            return@setMethodCallHandler
                        }

                        val level = batteryIntent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                        val scale = batteryIntent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                        val temperature =
                            batteryIntent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)
                        val voltage = batteryIntent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)
                        val status = batteryIntent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                        val plugged = batteryIntent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)

                        val percentage =
                            if (level >= 0 && scale > 0) ((level * 100f) / scale).toInt() else -1

                        val statusText = when (status) {
                            BatteryManager.BATTERY_STATUS_CHARGING -> "CHARGING"
                            BatteryManager.BATTERY_STATUS_DISCHARGING -> "DISCHARGING"
                            BatteryManager.BATTERY_STATUS_FULL -> "FULL"
                            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "NOT_CHARGING"
                            else -> "UNKNOWN"
                        }

                        val pluggedText = when {
                            (plugged and BatteryManager.BATTERY_PLUGGED_AC) != 0 -> "AC"
                            (plugged and BatteryManager.BATTERY_PLUGGED_USB) != 0 -> "USB"
                            (plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS) != 0 -> "WIRELESS"
                            else -> "UNPLUGGED"
                        }

                        val data = hashMapOf<String, Any>(
                            "percentage" to percentage,
                            "level" to level,
                            "scale" to scale,
                            "status" to statusText,
                            "plugged" to pluggedText,
                            "isCharging" to (
                                status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                    status == BatteryManager.BATTERY_STATUS_FULL
                                ),
                            "temperatureC" to if (temperature >= 0) temperature / 10.0 else -1.0,
                            "voltageMv" to voltage,
                        )

                        result.success(data)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "setupDirs" -> {
                    Thread {
                        try {
                            bootstrapManager.setupDirectories()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SETUP_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "installBionicBypass" -> {
                    Thread {
                        try {
                            bootstrapManager.installBionicBypass()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("BYPASS_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "writeResolv" -> {
                    Thread {
                        try {
                            bootstrapManager.writeResolvConf()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RESOLV_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "extractDebPackages" -> {
                    Thread {
                        try {
                            val count = bootstrapManager.extractDebPackages()
                            runOnUiThread { result.success(count) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DEB_EXTRACT_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "extractNodeTarball" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        Thread {
                            try {
                                bootstrapManager.extractNodeTarball(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("NODE_EXTRACT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "createBinWrappers" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        Thread {
                            try {
                                bootstrapManager.createBinWrappers(packageName)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BIN_WRAPPER_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "packageName required", null)
                    }
                }
                "startSetupService" -> {
                    try {
                        SetupService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "updateSetupNotification" -> {
                    val text = call.argument<String>("text")
                    val progress = call.argument<Int>("progress") ?: -1
                    if (text != null) {
                        SetupService.updateNotification(text, progress)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                "stopSetupService" -> {
                    try {
                        SetupService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "showUrlNotification" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title") ?: "URL Detected"
                    if (url != null) {
                        showUrlNotification(url, title)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "url required", null)
                    }
                }
                "copyToClipboard" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("URL", text))
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                "requestScreenCapture" -> {
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 5000L
                    screenCaptureResult = result
                    screenCaptureDurationMs = durationMs
                    ScreenCaptureService.clearResult()
                    val projectionManager =
                        getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    startActivityForResult(
                        projectionManager.createScreenCaptureIntent(),
                        SCREEN_CAPTURE_REQUEST
                    )
                }
                "stopScreenCapture" -> {
                    try {
                        stopService(Intent(applicationContext, ScreenCaptureService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "vibrate" -> {
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 200L
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager =
                                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                            val vibrator = vibratorManager.defaultVibrator
                            vibrator.vibrate(
                                VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(
                                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(durationMs)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VIBRATE_ERROR", e.message, null)
                    }
                }
                "requestStoragePermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            // Android 11+: MANAGE_EXTERNAL_STORAGE
                            if (!Environment.isExternalStorageManager()) {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                            }
                        } else {
                            // Android 10 and below: READ/WRITE_EXTERNAL_STORAGE
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(
                                    Manifest.permission.READ_EXTERNAL_STORAGE,
                                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                                ),
                                STORAGE_PERMISSION_REQUEST
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "hasStoragePermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Environment.isExternalStorageManager()
                    } else {
                        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(hasPermission)
                }
                "getExternalStoragePath" -> {
                    result.success(Environment.getExternalStorageDirectory().absolutePath)
                }
                "readRootfsFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        Thread {
                            try {
                                val content = bootstrapManager.readRootfsFile(path)
                                runOnUiThread { result.success(content) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ROOTFS_READ_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path required", null)
                    }
                }
                "writeRootfsFile" -> {
                    val path = call.argument<String>("path")
                    val content = call.argument<String>("content")
                    if (path != null && content != null) {
                        Thread {
                            try {
                                bootstrapManager.writeRootfsFile(path, content)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ROOTFS_WRITE_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path and content required", null)
                    }
                }
                "bringToForeground" -> {
                    try {
                        val intent = Intent(applicationContext, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        }
                        applicationContext.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FOREGROUND_ERROR", e.message, null)
                    }
                }
                "readSensor" -> {
                    val sensorType = call.argument<String>("sensor") ?: "accelerometer"
                    Thread {
                        try {
                            val sensorManager =
                                getSystemService(Context.SENSOR_SERVICE) as SensorManager
                            val type = when (sensorType) {
                                "accelerometer" -> Sensor.TYPE_ACCELEROMETER
                                "gyroscope" -> Sensor.TYPE_GYROSCOPE
                                "magnetometer" -> Sensor.TYPE_MAGNETIC_FIELD
                                "barometer" -> Sensor.TYPE_PRESSURE
                                else -> Sensor.TYPE_ACCELEROMETER
                            }
                            val sensor = sensorManager.getDefaultSensor(type)
                            if (sensor == null) {
                                runOnUiThread {
                                    result.error("SENSOR_ERROR", "Sensor $sensorType not available", null)
                                }
                                return@Thread
                            }
                            var received = false
                            val listener = object : SensorEventListener {
                                override fun onSensorChanged(event: SensorEvent?) {
                                    if (received || event == null) return
                                    received = true
                                    sensorManager.unregisterListener(this)
                                    val data = hashMapOf<String, Any>(
                                        "sensor" to sensorType,
                                        "timestamp" to event.timestamp,
                                        "accuracy" to event.accuracy
                                    )
                                    when (sensorType) {
                                        "accelerometer", "gyroscope", "magnetometer" -> {
                                            data["x"] = event.values[0].toDouble()
                                            data["y"] = event.values[1].toDouble()
                                            data["z"] = event.values[2].toDouble()
                                        }
                                        "barometer" -> {
                                            data["pressure"] = event.values[0].toDouble()
                                        }
                                    }
                                    runOnUiThread { result.success(data) }
                                }
                                override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
                            }
                            sensorManager.registerListener(
                                listener, sensor, SensorManager.SENSOR_DELAY_NORMAL
                            )
                            // Timeout after 3 seconds
                            Thread.sleep(3000)
                            if (!received) {
                                sensorManager.unregisterListener(listener)
                                runOnUiThread {
                                    result.error("SENSOR_ERROR", "Sensor read timed out", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SENSOR_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "copyBundledAsset" -> {
                    val assetPath = call.argument<String>("assetPath")
                    val destPath = call.argument<String>("destPath")
                    if (assetPath != null && destPath != null) {
                        Thread {
                            try {
                                val copied = bootstrapManager.copyBundledAsset(assetPath, destPath)
                                runOnUiThread { result.success(copied) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ASSET_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "assetPath and destPath required", null)
                    }
                }
                // ========== 文件系统工具 ==========
                "listDirectory" -> {
                    val path = call.argument<String>("path") ?: "/"
                    Thread {
                        try {
                            val dir = File(path)
                            val entries = if (dir.exists() && dir.isDirectory) {
                                dir.listFiles()?.map { file ->
                                    hashMapOf<String, Any>(
                                        "name" to file.name,
                                        "path" to file.absolutePath,
                                        "isDirectory" to file.isDirectory,
                                        "size" to file.length(),
                                        "lastModified" to file.lastModified()
                                    )
                                } ?: emptyList()
                            } else {
                                emptyList()
                            }
                            val data = hashMapOf<String, Any>(
                                "path" to path,
                                "entries" to entries,
                                "count" to entries.size
                            )
                            runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("FS_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "readFile" -> {
                    val path = call.argument<String>("path")
                    val limit = call.argument<Int>("limit")
                    if (path != null) {
                        Thread {
                            try {
                                val file = File(path)
                                if (!file.exists() || !file.canRead()) {
                                    runOnUiThread { result.success(null) }
                                    return@Thread
                                }
                                val content = if (limit != null && limit > 0) {
                                    file.readText(Charsets.UTF_8).take(limit)
                                } else {
                                    file.readText(Charsets.UTF_8)
                                }
                                runOnUiThread { result.success(content) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("FS_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path required", null)
                    }
                }
                "writeFile" -> {
                    val path = call.argument<String>("path")
                    val content = call.argument<String>("content")
                    if (path != null && content != null) {
                        Thread {
                            try {
                                val file = File(path)
                                file.parentFile?.mkdirs()
                                file.writeText(content, Charsets.UTF_8)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("FS_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path and content required", null)
                    }
                }
                "deleteFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        Thread {
                            try {
                                val file = File(path)
                                val success = file.deleteRecursively()
                                runOnUiThread { result.success(success) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("FS_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path required", null)
                    }
                }
                "createDirectory" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        Thread {
                            try {
                                val success = File(path).mkdirs()
                                runOnUiThread { result.success(success) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("FS_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path required", null)
                    }
                }
                "getFileInfo" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        Thread {
                            try {
                                val file = File(path)
                                val data = hashMapOf<String, Any>(
                                    "exists" to file.exists(),
                                    "isDirectory" to file.isDirectory,
                                    "isFile" to file.isFile,
                                    "size" to file.length(),
                                    "lastModified" to file.lastModified(),
                                    "canRead" to file.canRead(),
                                    "canWrite" to file.canWrite(),
                                    "absolutePath" to file.absolutePath
                                )
                                runOnUiThread { result.success(data) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("FS_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path required", null)
                    }
                }
                // ========== 应用管理工具 ==========
                "getInstalledApps" -> {
                    Thread {
                        try {
                            val pm = packageManager
                            val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                                .filter { app ->
                                    // Only return apps that can be launched
                                    pm.getLaunchIntentForPackage(app.packageName) != null
                                }
                                .map { app ->
                                    hashMapOf<String, Any>(
                                        "packageName" to app.packageName,
                                        "name" to pm.getApplicationLabel(app).toString(),
                                        "isSystem" to ((app.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0)
                                    )
                                }
                                .sortedBy { it["name"] as String }
                            runOnUiThread { result.success(apps) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("APPS_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        try {
                            val intent = packageManager.getLaunchIntentForPackage(packageName)
                            if (intent != null) {
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("APPS_ERROR", "App not found or cannot be launched", null)
                            }
                        } catch (e: Exception) {
                            result.error("APPS_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "packageName required", null)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("APPS_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "url required", null)
                    }
                }
                // ========== 剪贴板工具 ==========
                "getClipboardText" -> {
                    try {
                        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = clipboard.primaryClip
                        if (clip != null && clip.itemCount > 0) {
                            val text = clip.getItemAt(0).text?.toString()
                            result.success(text)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("CLIPBOARD_ERROR", e.message, null)
                    }
                }
                "setClipboardText" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        try {
                            val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("OpenClaw", text))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CLIPBOARD_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                // ========== 手电筒工具 ==========
                "toggleFlashlight" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    try {
                        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                        val cameraId = cameraManager.cameraIdList.find { id ->
                            val characteristics = cameraManager.getCameraCharacteristics(id)
                            characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                        }
                        if (cameraId != null) {
                            cameraManager.setTorchMode(cameraId, on)
                            result.success(true)
                        } else {
                            result.error("FLASHLIGHT_ERROR", "No flashlight available", null)
                        }
                    } catch (e: Exception) {
                        result.error("FLASHLIGHT_ERROR", e.message, null)
                    }
                }
                "isFlashlightAvailable" -> {
                    try {
                        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                        val available = cameraManager.cameraIdList.any { id ->
                            val characteristics = cameraManager.getCameraCharacteristics(id)
                            characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                        }
                        result.success(available)
                    } catch (e: Exception) {
                        result.error("FLASHLIGHT_ERROR", e.message, null)
                    }
                }
                // ========== 设备信息工具 ==========
                "getDeviceInfo" -> {
                    try {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        val wifiInfo = wifiManager.connectionInfo
                        val data = hashMapOf<String, Any>(
                            "brand" to Build.BRAND,
                            "model" to Build.MODEL,
                            "device" to Build.DEVICE,
                            "manufacturer" to Build.MANUFACTURER,
                            "product" to Build.PRODUCT,
                            "androidVersion" to Build.VERSION.RELEASE,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "board" to Build.BOARD,
                            "hardware" to Build.HARDWARE,
                            "host" to Build.HOST,
                            "id" to Build.ID,
                            "type" to Build.TYPE,
                            "user" to Build.USER,
                            "display" to Build.DISPLAY,
                            "fingerprint" to Build.FINGERPRINT,
                            "tags" to Build.TAGS,
                            "time" to Build.TIME,
                            "isEmulator" to (
                                Build.FINGERPRINT.startsWith("generic") ||
                                Build.FINGERPRINT.startsWith("unknown") ||
                                Build.MODEL.contains("google_sdk") ||
                                Build.MODEL.contains("Emulator") ||
                                Build.MODEL.contains("Android SDK built for x86") ||
                                Build.MANUFACTURER.contains("Genymotion") ||
                                (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
                                "google_sdk" == Build.PRODUCT
                            )
                        )
                        // Network info
                        try {
                            val interfaces = NetworkInterface.getNetworkInterfaces()
                            val ipList = mutableListOf<String>()
                            for (intf in Collections.list(interfaces)) {
                                for (addr in Collections.list(intf.inetAddresses)) {
                                    if (!addr.isLoopbackAddress) {
                                        ipList.add(addr.hostAddress ?: "")
                                    }
                                }
                            }
                            data["ips"] = ipList.filter { it.isNotEmpty() }
                            data["wifiSsid"] = wifiInfo?.ssid?.replace("\"", "") ?: ""
                            data["wifiBssid"] = wifiInfo?.bssid ?: ""
                        } catch (_: Exception) {}
                        result.success(data)
                    } catch (e: Exception) {
                        result.error("DEVICEINFO_ERROR", e.message, null)
                    }
                }
                // ========== 联系人工具 ==========
                "getContacts" -> {
                    Thread {
                        try {
                            val contactsList = mutableListOf<Map<String, Any>>()
                            val cursor = contentResolver.query(
                                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                                arrayOf(
                                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                                    ContactsContract.CommonDataKinds.Phone.NUMBER
                                ),
                                null, null,
                                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
                            )
                            cursor?.use {
                                val nameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                                val numberIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                                while (it.moveToNext()) {
                                    val name = if (nameIndex >= 0) it.getString(nameIndex) else ""
                                    val number = if (numberIndex >= 0) it.getString(numberIndex) else ""
                                    if (name != null && number != null) {
                                        contactsList.add(hashMapOf(
                                            "name" to name,
                                            "phoneNumber" to number
                                        ))
                                    }
                                }
                            }
                            runOnUiThread { result.success(contactsList) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("CONTACTS_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "getCallLogs" -> {
                    val limit = call.argument<Int>("limit") ?: 100
                    Thread {
                        try {
                            val logsList = mutableListOf<Map<String, Any>>()
                            val cursor = contentResolver.query(
                                CallLog.Calls.CONTENT_URI,
                                arrayOf(
                                    CallLog.Calls.NUMBER,
                                    CallLog.Calls.TYPE,
                                    CallLog.Calls.DATE,
                                    CallLog.Calls.DURATION
                                ),
                                null, null,
                                CallLog.Calls.DATE + " DESC LIMIT $limit"
                            )
                            cursor?.use {
                                val numberIndex = it.getColumnIndex(CallLog.Calls.NUMBER)
                                val typeIndex = it.getColumnIndex(CallLog.Calls.TYPE)
                                val dateIndex = it.getColumnIndex(CallLog.Calls.DATE)
                                val durationIndex = it.getColumnIndex(CallLog.Calls.DURATION)
                                while (it.moveToNext()) {
                                    val number = if (numberIndex >= 0) it.getString(numberIndex) else ""
                                    val type = if (typeIndex >= 0) it.getInt(typeIndex) else 0
                                    val date = if (dateIndex >= 0) it.getLong(dateIndex) else 0L
                                    val duration = if (durationIndex >= 0) it.getLong(durationIndex) else 0L
                                    val typeName = when (type) {
                                        CallLog.Calls.INCOMING_TYPE -> "incoming"
                                        CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                                        CallLog.Calls.MISSED_TYPE -> "missed"
                                        CallLog.Calls.REJECTED_TYPE -> "rejected"
                                        else -> "unknown"
                                    }
                                    logsList.add(hashMapOf(
                                        "number" to (number ?: ""),
                                        "type" to typeName,
                                        "date" to date,
                                        "duration" to duration
                                    ))
                                }
                            }
                            runOnUiThread { result.success(logsList) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("CALLLOGS_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "getSmsMessages" -> {
                    val limit = call.argument<Int>("limit") ?: 100
                    Thread {
                        try {
                            val smsList = mutableListOf<Map<String, Any>>()
                            val cursor = contentResolver.query(
                                Telephony.Sms.CONTENT_URI,
                                arrayOf(
                                    Telephony.Sms.ADDRESS,
                                    Telephony.Sms.BODY,
                                    Telephony.Sms.DATE,
                                    Telephony.Sms.TYPE
                                ),
                                null, null,
                                Telephony.Sms.DATE + " DESC LIMIT $limit"
                            )
                            cursor?.use {
                                val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
                                val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
                                val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)
                                val typeIndex = it.getColumnIndex(Telephony.Sms.TYPE)
                                while (it.moveToNext()) {
                                    val address = if (addressIndex >= 0) it.getString(addressIndex) else ""
                                    val body = if (bodyIndex >= 0) it.getString(bodyIndex) else ""
                                    val date = if (dateIndex >= 0) it.getLong(dateIndex) else 0L
                                    val type = if (typeIndex >= 0) it.getInt(typeIndex) else 0
                                    val typeName = when (type) {
                                        Telephony.Sms.MESSAGE_TYPE_INBOX -> "received"
                                        Telephony.Sms.MESSAGE_TYPE_SENT -> "sent"
                                        Telephony.Sms.MESSAGE_TYPE_DRAFT -> "draft"
                                        else -> "unknown"
                                    }
                                    smsList.add(hashMapOf(
                                        "address" to (address ?: ""),
                                        "body" to (body ?: ""),
                                        "date" to date,
                                        "type" to typeName
                                    ))
                                }
                            }
                            runOnUiThread { result.success(smsList) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SMS_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    if (phoneNumber != null && message != null) {
                        try {
                            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                applicationContext.getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }
                            smsManager?.sendTextMessage(phoneNumber, null, message, null, null)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SMS_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "phoneNumber and message required", null)
                    }
                }
                // ========== 无障碍服务工具 ==========
                "isAccessibilityEnabled" -> {
                    result.success(OpenClawAccessibilityService.isRunning())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "tapScreen" -> {
                    val x = call.argument<Double>("x")?.toFloat() ?: 0f
                    val y = call.argument<Double>("y")?.toFloat() ?: 0f
                    result.success(OpenClawAccessibilityService.click(x, y))
                }
                "swipeScreen" -> {
                    val x1 = call.argument<Double>("x1")?.toFloat() ?: 0f
                    val y1 = call.argument<Double>("y1")?.toFloat() ?: 0f
                    val x2 = call.argument<Double>("x2")?.toFloat() ?: 0f
                    val y2 = call.argument<Double>("y2")?.toFloat() ?: 0f
                    val duration = call.argument<Int>("duration")?.toLong() ?: 300L
                    result.success(OpenClawAccessibilityService.swipe(x1, y1, x2, y2, duration))
                }
                "tapBack" -> {
                    result.success(OpenClawAccessibilityService.tapBack())
                }
                "tapHome" -> {
                    result.success(OpenClawAccessibilityService.tapHome())
                }
                "getScreenSize" -> {
                    val (width, height) = OpenClawAccessibilityService.getScreenSize()
                    result.success(mapOf("width" to width, "height" to height))
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        createUrlNotificationChannel()
        requestNotificationPermission()

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    GatewayService.logSink = events
                }
                override fun onCancel(arguments: Any?) {
                    GatewayService.logSink = null
                }
            }
        )
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST
                )
            }
        }
    }

    private fun createUrlNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                URL_CHANNEL_ID,
                "OpenClaw URLs",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for detected URLs"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private var urlNotificationId = 100

    private fun showUrlNotification(url: String, title: String) {
        val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        val openPending = PendingIntent.getActivity(
            this, urlNotificationId, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, URL_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(url)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentIntent(openPending)
                .setAutoCancel(true)
                .setStyle(Notification.BigTextStyle().bigText(url))
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle(title)
                .setContentText(url)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentIntent(openPending)
                .setAutoCancel(true)
                .build()
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(urlNotificationId++, notification)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val intent = Intent(applicationContext, ScreenCaptureService::class.java).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("durationMs", screenCaptureDurationMs)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                // Poll for result
                Thread {
                    val startTime = System.currentTimeMillis()
                    val timeout = screenCaptureDurationMs + 5000L
                    while (ScreenCaptureService.resultPath == null &&
                        System.currentTimeMillis() - startTime < timeout
                    ) {
                        Thread.sleep(200)
                    }
                    val path = ScreenCaptureService.resultPath
                    runOnUiThread {
                        screenCaptureResult?.success(path)
                        screenCaptureResult = null
                    }
                }.start()
            } else {
                screenCaptureResult?.success(null)
                screenCaptureResult = null
            }
        }
    }

    companion object {
        const val URL_CHANNEL_ID = "openclaw_urls"
        const val NOTIFICATION_PERMISSION_REQUEST = 1001
        const val SCREEN_CAPTURE_REQUEST = 1002
        const val STORAGE_PERMISSION_REQUEST = 1003
    }

    /// 检测是否在模拟器上运行
    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic") ||
                Build.FINGERPRINT.startsWith("unknown") ||
                Build.MODEL.contains("google_sdk") ||
                Build.MODEL.contains("Emulator") ||
                Build.MODEL.contains("Android SDK built for x86") ||
                Build.MANUFACTURER.contains("Genymotion") ||
                (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
                "google_sdk" == Build.PRODUCT ||
                Build.HARDWARE.contains("goldfish") ||
                Build.HARDWARE.contains("ranchu") ||
                Build.HARDWARE.contains("emulator"))
    }
}
