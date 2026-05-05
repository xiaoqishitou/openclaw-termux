package com.xiaoqi.openclawproot

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class OpenClawAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "OpenClawA11y"
        var instance: OpenClawAccessibilityService? = null
            private set

        fun isRunning(): Boolean = instance != null

        fun click(x: Float, y: Float): Boolean {
            return instance?.performClick(x, y) ?: false
        }

        fun swipe(x1: Float, y1: Float, x2: Float, y2: Float, durationMs: Long): Boolean {
            return instance?.performSwipe(x1, y1, x2, y2, durationMs) ?: false
        }

        fun tapBack(): Boolean {
            return instance?.performGlobalAction(GLOBAL_ACTION_BACK) ?: false
        }

        fun tapHome(): Boolean {
            return instance?.performGlobalAction(GLOBAL_ACTION_HOME) ?: false
        }

        fun tapRecentApps(): Boolean {
            return instance?.performGlobalAction(GLOBAL_ACTION_RECENTS) ?: false
        }

        fun getScreenSize(): Pair<Int, Int> {
            val inst = instance ?: return Pair(0, 0)
            val dm = inst.resources.displayMetrics
            return Pair(dm.widthPixels, dm.heightPixels)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility service connected")
        instance = this

        serviceInfo = serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPE_VIEW_CLICKED or
                    AccessibilityEvent.TYPE_VIEW_FOCUSED or
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Accessibility service destroyed")
        instance = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }

    fun performClick(x: Float, y: Float): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val path = Path().apply { moveTo(x, y) }
                dispatchGestureViaReflection(path, 50L)
            } else {
                findAndClickNodeAtPosition(x.toInt(), y.toInt())
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Click failed", e)
            false
        }
    }

    fun performSwipe(x1: Float, y1: Float, x2: Float, y2: Float, durationMs: Long): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val path = Path().apply {
                    moveTo(x1, y1)
                    lineTo(x2, y2)
                }
                dispatchGestureViaReflection(path, durationMs)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Swipe failed", e)
            false
        }
    }

    /**
     * 通过反射调用 dispatchGesture，绕过 Kotlin 编译器对 GestureDescription 内部类的解析问题
     */
    private fun dispatchGestureViaReflection(path: Path, durationMs: Long) {
        try {
            val gestureDescClass = Class.forName("android.accessibilityservice.AccessibilityService\$GestureDescription")
            val strokeDescClass = Class.forName("android.accessibilityservice.AccessibilityService\$GestureDescription\$StrokeDescription")

            val strokeConstructor = strokeDescClass.getConstructor(Path::class.java, Long::class.javaPrimitiveType, Long::class.javaPrimitiveType)
            val stroke = strokeConstructor.newInstance(path, 0L, durationMs)

            val builderConstructor = gestureDescClass.getDeclaredConstructor()
            val builder = builderConstructor.newInstance()

            val addStrokeMethod = gestureDescClass.getDeclaredMethod("addStroke", strokeDescClass)
            addStrokeMethod.invoke(builder, stroke)

            val buildMethod = gestureDescClass.getDeclaredMethod("build")
            val gesture = buildMethod.invoke(builder)

            val gestureResultCallbackClass = Class.forName("android.accessibilityservice.AccessibilityService\$GestureResultCallback")
            val dispatchGestureMethod = AccessibilityService::class.java.getDeclaredMethod(
                "dispatchGesture",
                gestureDescClass,
                gestureResultCallbackClass,
                android.os.Handler::class.java
            )
            dispatchGestureMethod.invoke(this, gesture, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "dispatchGestureViaReflection failed", e)
        }
    }

    private fun findAndClickNodeAtPosition(x: Int, y: Int): Boolean {
        val root = rootInActiveWindow ?: return false
        try {
            val nodes = mutableListOf<AccessibilityNodeInfo>()
            collectNodes(root, nodes)
            for (node in nodes) {
                val rect = Rect()
                node.getBoundsInScreen(rect)
                if (rect.contains(x, y)) {
                    if (node.isClickable) {
                        return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    }
                    var parent = node.parent
                    while (parent != null) {
                        if (parent.isClickable) {
                            parent.getBoundsInScreen(rect)
                            if (rect.contains(x, y)) {
                                return parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                            }
                        }
                        parent = parent.parent
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "findAndClickNodeAtPosition error", e)
        }
        return false
    }

    private fun collectNodes(node: AccessibilityNodeInfo?, list: MutableList<AccessibilityNodeInfo>) {
        if (node == null) return
        list.add(node)
        for (i in 0 until node.childCount) {
            collectNodes(node.getChild(i), list)
        }
    }
}
