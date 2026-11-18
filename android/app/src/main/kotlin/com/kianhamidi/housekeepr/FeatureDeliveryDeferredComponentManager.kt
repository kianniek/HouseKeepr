package com.kianhamidi.housekeepr

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.SparseArray
import android.util.SparseIntArray
import com.google.android.play.core.splitcompat.SplitCompat
import com.google.android.play.core.splitinstall.SplitInstallException
import com.google.android.play.core.splitinstall.SplitInstallManager
import com.google.android.play.core.splitinstall.SplitInstallManagerFactory
import com.google.android.play.core.splitinstall.SplitInstallRequest
import com.google.android.play.core.splitinstall.SplitInstallSessionState
import com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
import com.google.android.play.core.splitinstall.model.SplitInstallErrorCode
import com.google.android.play.core.splitinstall.model.SplitInstallSessionStatus
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager
import io.flutter.embedding.engine.systemchannels.DeferredComponentChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.lang.ref.WeakReference
import java.util.Collections
import java.util.LinkedList
import java.util.concurrent.ConcurrentHashMap

/**
 * [DeferredComponentManager] backed by `com.google.android.play:feature-delivery:2.1.0`
 * (which uses GMS Tasks instead of legacy Play Core Tasks), allowing dynamic features
 * like `:openGym` to work alongside `in_app_update` without `NoSuchMethodError`.
 */
class FeatureDeliveryDeferredComponentManager(
    private val context: Context,
    private var flutterJNI: FlutterJNI?,
) : DeferredComponentManager {

    private val splitInstallManager: SplitInstallManager =
        SplitInstallManagerFactory.create(context)
    private var channel: DeferredComponentChannel? = null
    private var progressSink: EventChannel.EventSink? = null
    private var activityRef: WeakReference<Activity>? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val sessionIdToName = SparseArray<String>()
    private val sessionIdToLoadingUnitId = SparseIntArray()
    private val sessionIdToState = SparseArray<String>()
    private val nameToSessionId = HashMap<String, Int>()
    private val loadingUnitIdToComponentNames = SparseArray<String>()
    private val loadingUnitIdToSharedLibraryNames = SparseArray<String>()
    private val latestProgressByModule = ConcurrentHashMap<String, Map<String, Any?>>()
    private val pendingStartModules = Collections.synchronizedSet(HashSet<String>())
    private val cancelledBeforeStartModules = Collections.synchronizedSet(HashSet<String>())

    private val listener = SplitInstallStateUpdatedListener { state: SplitInstallSessionState ->
        val sessionId = state.sessionId()
        var componentName = sessionIdToName.get(sessionId)
        if (componentName == null) {
            componentName = state.moduleNames().firstOrNull {
                pendingStartModules.contains(it) || nameToSessionId.containsKey(it)
            } ?: return@SplitInstallStateUpdatedListener
            sessionIdToName.put(sessionId, componentName)
            nameToSessionId[componentName] = sessionId
        }

        val loadingUnitId = sessionIdToLoadingUnitId.get(sessionId, -1)

        when (state.status()) {
            SplitInstallSessionStatus.FAILED -> {
                sessionIdToState.put(sessionId, "failed")
                val errorMessage = formatErrorCode(state.errorCode())
                emitProgress(
                    moduleName = componentName,
                    status = "failed",
                    bytesDownloaded = state.bytesDownloaded(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                    errorCode = state.errorCode(),
                    message = errorMessage,
                )
                flutterJNI?.deferredComponentInstallFailure(
                    loadingUnitId,
                    errorMessage,
                    true,
                )
                channel?.completeInstallError(
                    componentName,
                    errorMessage,
                )
            }
            SplitInstallSessionStatus.INSTALLED -> {
                sessionIdToState.put(sessionId, "installed")
                emitProgress(
                    moduleName = componentName,
                    status = "installed",
                    bytesDownloaded = state.totalBytesToDownload(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                )
                SplitCompat.install(context)
                if (loadingUnitId > 0) {
                    loadDartLibrary(loadingUnitId, componentName)
                }
                channel?.completeInstallSuccess(componentName)
            }
            SplitInstallSessionStatus.CANCELED -> {
                sessionIdToState.put(sessionId, "cancelled")
                emitProgress(
                    moduleName = componentName,
                    status = "cancelled",
                    bytesDownloaded = state.bytesDownloaded(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                    message = "Install was cancelled.",
                )
                flutterJNI?.deferredComponentInstallFailure(
                    loadingUnitId,
                    "Install was cancelled.",
                    true,
                )
                channel?.completeInstallError(componentName, "Install was cancelled.")
            }
            SplitInstallSessionStatus.CANCELING -> {
                sessionIdToState.put(sessionId, "canceling")
                emitProgress(
                    moduleName = componentName,
                    status = "canceling",
                    bytesDownloaded = state.bytesDownloaded(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                )
            }
            SplitInstallSessionStatus.PENDING -> {
                sessionIdToState.put(sessionId, "pending")
                emitProgress(
                    moduleName = componentName,
                    status = "pending",
                    bytesDownloaded = state.bytesDownloaded(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                )
            }
            SplitInstallSessionStatus.REQUIRES_USER_CONFIRMATION -> {
                sessionIdToState.put(sessionId, "requiresUserConfirmation")
                emitProgress(
                    moduleName = componentName,
                    status = "requiresUserConfirmation",
                    bytesDownloaded = state.bytesDownloaded(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                )
                val activity = activityRef?.get()
                if (activity != null && !activity.isFinishing && !activity.isDestroyed) {
                    runCatching {
                        splitInstallManager.startConfirmationDialogForResult(
                            state,
                            activity,
                            CONFIRMATION_REQUEST_CODE,
                        )
                    }
                }
            }
            SplitInstallSessionStatus.DOWNLOADING -> {
                sessionIdToState.put(sessionId, "downloading")
                emitProgress(
                    moduleName = componentName,
                    status = "downloading",
                    bytesDownloaded = state.bytesDownloaded(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                )
            }
            SplitInstallSessionStatus.DOWNLOADED -> {
                sessionIdToState.put(sessionId, "downloaded")
                emitProgress(
                    moduleName = componentName,
                    status = "downloaded",
                    bytesDownloaded = state.totalBytesToDownload(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                )
            }
            SplitInstallSessionStatus.INSTALLING -> {
                sessionIdToState.put(sessionId, "installing")
                emitProgress(
                    moduleName = componentName,
                    status = "installing",
                    bytesDownloaded = state.totalBytesToDownload(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                )
            }
            else -> {
                sessionIdToState.put(sessionId, "unknown")
                emitProgress(
                    moduleName = componentName,
                    status = "unknown",
                    bytesDownloaded = state.bytesDownloaded(),
                    totalBytesToDownload = state.totalBytesToDownload(),
                )
            }
        }
    }

    init {
        splitInstallManager.registerListener(listener)
        initLoadingUnitMapping()
    }

    private fun initLoadingUnitMapping() {
        val appInfo = runCatching {
            context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
        }.getOrNull() ?: return

        val rawMapping = appInfo.metaData?.getString(MAPPING_KEY) ?: return
        for (pair in rawMapping.split(",")) {
            val parts = pair.split(":", limit = 3)
            val loadingUnitId = parts.getOrNull(0)?.toIntOrNull() ?: continue
            val componentName = parts.getOrNull(1) ?: continue
            loadingUnitIdToComponentNames.put(loadingUnitId, componentName)
            if (parts.size > 2) {
                loadingUnitIdToSharedLibraryNames.put(loadingUnitId, parts[2])
            }
        }
    }

    fun setActivity(activity: Activity?) {
        activityRef = if (activity != null) WeakReference(activity) else null
    }

    fun setProgressSink(sink: EventChannel.EventSink?) {
        progressSink = sink
    }

    fun getLatestProgress(moduleName: String): Map<String, Any?> {
        if (splitInstallManager.installedModules.contains(moduleName)) {
            return mapOf(
                "moduleName" to moduleName,
                "status" to "installed",
                "bytesDownloaded" to 0L,
                "totalBytesToDownload" to 0L,
                "errorCode" to null,
                "message" to null,
            )
        }
        return latestProgressByModule[moduleName] ?: mapOf(
            "moduleName" to moduleName,
            "status" to "unknown",
            "bytesDownloaded" to 0L,
            "totalBytesToDownload" to 0L,
            "errorCode" to null,
            "message" to null,
        )
    }

    fun cancelInstall(moduleName: String): Boolean {
        val sessionId = nameToSessionId[moduleName]
        if (sessionId != null) {
            emitProgress(moduleName = moduleName, status = "canceling")
            splitInstallManager.cancelInstall(sessionId)
            return true
        }
        if (pendingStartModules.contains(moduleName)) {
            cancelledBeforeStartModules.add(moduleName)
            emitProgress(moduleName = moduleName, status = "canceling")
            return true
        }
        return false
    }

    private fun emitProgress(
        moduleName: String,
        status: String,
        bytesDownloaded: Long = 0L,
        totalBytesToDownload: Long = 0L,
        errorCode: Int? = null,
        message: String? = null,
    ) {
        val payload = mapOf<String, Any?>(
            "moduleName" to moduleName,
            "status" to status,
            "bytesDownloaded" to bytesDownloaded,
            "totalBytesToDownload" to totalBytesToDownload,
            "errorCode" to errorCode,
            "message" to message,
        )
        latestProgressByModule[moduleName] = payload
        mainHandler.post {
            progressSink?.success(payload)
        }
    }

    private fun formatErrorCode(errorCode: Int): String {
        return when (errorCode) {
            SplitInstallErrorCode.API_NOT_AVAILABLE ->
                "Google Play Feature Delivery API is not available on this device (error $errorCode)."
            SplitInstallErrorCode.NETWORK_ERROR ->
                "Network error while downloading module. Check your connection (error $errorCode)."
            SplitInstallErrorCode.INVALID_REQUEST ->
                "Invalid install request (error $errorCode)."
            SplitInstallErrorCode.SESSION_NOT_FOUND ->
                "Install session not found (error $errorCode)."
            SplitInstallErrorCode.MODULE_UNAVAILABLE ->
                "Module is unavailable. Make sure the app was installed from Google Play (error $errorCode)."
            SplitInstallErrorCode.ACTIVE_SESSIONS_LIMIT_EXCEEDED ->
                "Too many active Play Store downloads. Try again shortly (error $errorCode)."
            SplitInstallErrorCode.INSUFFICIENT_STORAGE ->
                "Insufficient storage space on device (error $errorCode)."
            SplitInstallErrorCode.PLAY_STORE_NOT_FOUND ->
                "Google Play Store app was not found or is disabled (error $errorCode)."
            SplitInstallErrorCode.INCOMPATIBLE_WITH_EXISTING_SESSION ->
                "Incompatible with an existing Play Store install session (error $errorCode)."
            SplitInstallErrorCode.ACCESS_DENIED ->
                "Download not permitted in current device state (error $errorCode)."
            SplitInstallErrorCode.INTERNAL_ERROR ->
                "Google Play internal error (error $errorCode)."
            else -> "Install failed with error code $errorCode."
        }
    }

    override fun setJNI(flutterJNI: FlutterJNI) {
        Log.d(TAG, "setJNI: attached FlutterJNI")
        this.flutterJNI = flutterJNI
    }

    override fun setDeferredComponentChannel(channel: DeferredComponentChannel) {
        this.channel = channel
    }

    override fun installDeferredComponent(loadingUnitId: Int, componentName: String?) {
        val resolvedName = componentName
            ?: loadingUnitIdToComponentNames.get(loadingUnitId)

        if (resolvedName == null) {
            val errorMessage =
                "Unmapped deferred component (loadingUnitId=$loadingUnitId, componentName=$componentName). " +
                    "Check loadingUnitMapping in AndroidManifest.xml."
            Log.e(TAG, errorMessage)
            val fallbackModuleName = if (loadingUnitIdToComponentNames.size() == 1) {
                loadingUnitIdToComponentNames.valueAt(0)
            } else {
                "unknown_$loadingUnitId"
            }
            emitProgress(
                moduleName = fallbackModuleName,
                status = "failed",
                message = errorMessage,
            )
            flutterJNI?.deferredComponentInstallFailure(
                loadingUnitId,
                errorMessage,
                true,
            )
            channel?.completeInstallError(fallbackModuleName, errorMessage)
            return
        }

        Log.d(TAG, "installDeferredComponent: loadingUnitId=$loadingUnitId resolvedName=$resolvedName")

        if (splitInstallManager.installedModules.contains(resolvedName)) {
            Log.d(TAG, "Module '$resolvedName' already installed; loading library.")
            emitProgress(moduleName = resolvedName, status = "installed")
            SplitCompat.install(context)
            if (loadingUnitId > 0) {
                loadDartLibrary(loadingUnitId, resolvedName)
            }
            channel?.completeInstallSuccess(resolvedName)
            return
        }

        pendingStartModules.add(resolvedName)
        cancelledBeforeStartModules.remove(resolvedName)
        emitProgress(moduleName = resolvedName, status = "requesting")

        val request = SplitInstallRequest.newBuilder()
            .addModule(resolvedName)
            .build()

        splitInstallManager.startInstall(request)
            .addOnSuccessListener { sessionId ->
                Log.d(TAG, "startInstall succeeded: module=$resolvedName sessionId=$sessionId")
                pendingStartModules.remove(resolvedName)
                sessionIdToName.put(sessionId, resolvedName)
                sessionIdToLoadingUnitId.put(sessionId, loadingUnitId)
                nameToSessionId[resolvedName] = sessionId
                if (sessionIdToState.get(sessionId) == null) {
                    sessionIdToState.put(sessionId, "pending")
                    emitProgress(moduleName = resolvedName, status = "pending")
                }
                if (cancelledBeforeStartModules.remove(resolvedName)) {
                    splitInstallManager.cancelInstall(sessionId)
                }
            }
            .addOnFailureListener { exception ->
                pendingStartModules.remove(resolvedName)
                cancelledBeforeStartModules.remove(resolvedName)
                val errorCode = (exception as? SplitInstallException)?.errorCode
                val errorMessage = if (errorCode != null) {
                    formatErrorCode(errorCode)
                } else {
                    exception.message ?: "Split install failed."
                }
                Log.e(TAG, "startInstall failed: module=$resolvedName errorCode=$errorCode message=$errorMessage", exception)
                emitProgress(
                    moduleName = resolvedName,
                    status = "failed",
                    errorCode = errorCode,
                    message = errorMessage,
                )
                flutterJNI?.deferredComponentInstallFailure(
                    loadingUnitId,
                    errorMessage,
                    true,
                )
                channel?.completeInstallError(
                    resolvedName,
                    errorMessage,
                )
            }
    }

    override fun getDeferredComponentInstallState(
        loadingUnitId: Int,
        componentName: String?,
    ): String {
        val resolvedName = componentName
            ?: loadingUnitIdToComponentNames.get(loadingUnitId)
            ?: return "unknown"

        if (splitInstallManager.installedModules.contains(resolvedName)) {
            return "installed"
        }
        val sessionId = nameToSessionId[resolvedName] ?: return "unknown"
        return sessionIdToState.get(sessionId, "unknown")
    }

    override fun loadAssets(loadingUnitId: Int, componentName: String?) {
        SplitCompat.install(context)
    }

    override fun loadDartLibrary(loadingUnitId: Int, componentName: String?) {
        val jni = flutterJNI
        if (jni == null) {
            val msg = "loadDartLibrary: flutterJNI is null (loadingUnitId=$loadingUnitId, componentName=$componentName)"
            Log.e(TAG, msg)
            if (componentName != null) {
                emitProgress(moduleName = componentName, status = "failed", message = msg)
                channel?.completeInstallError(componentName, msg)
            }
            return
        }
        if (loadingUnitId < 0) {
            Log.w(TAG, "loadDartLibrary: invalid loadingUnitId=$loadingUnitId")
            return
        }

        var aotSharedLibraryName = loadingUnitIdToSharedLibraryNames.get(loadingUnitId)
        if (aotSharedLibraryName == null) {
            val baseName = FlutterInjector.instance().flutterLoader().findAppBundlePath()
            val libName = File(baseName).name
            // Default Flutter split shared library naming: libapp.so-<loadingUnitId>.so
            aotSharedLibraryName = "libapp.so-$loadingUnitId.so"
            if (libName.isNotEmpty() && libName != "flutter_assets") {
                aotSharedLibraryName = "libapp.so-$loadingUnitId.so"
            }
        }

        val searchPaths = LinkedList<String>()
        searchPaths.add(aotSharedLibraryName)

        val freshContext = runCatching {
            context.createPackageContext(context.packageName, 0)
        }.getOrDefault(context)
        val appInfo = freshContext.applicationInfo
        val nativeDir = appInfo.nativeLibraryDir
        if (nativeDir != null) {
            searchPaths.add("$nativeDir/$aotSharedLibraryName")
        }

        val splitDirs = appInfo.splitSourceDirs
        if (splitDirs != null) {
            val abis = Build.SUPPORTED_ABIS
            for (splitApk in splitDirs) {
                for (abi in abis) {
                    searchPaths.add("$splitApk!/lib/$abi/$aotSharedLibraryName")
                }
            }
        }

        Log.d(
            TAG,
            "loadDartLibrary: unit=$loadingUnitId lib=$aotSharedLibraryName attached=${jni.isAttached} splitDirs=${splitDirs?.joinToString()} searchPaths=${searchPaths.size}",
        )
        jni.loadDartDeferredLibrary(loadingUnitId, searchPaths.toTypedArray())
        Log.d(TAG, "loadDartLibrary: jni.loadDartDeferredLibrary returned for unit=$loadingUnitId")
    }

    override fun uninstallDeferredComponent(loadingUnitId: Int, componentName: String?): Boolean {
        val resolvedName = componentName
            ?: loadingUnitIdToComponentNames.get(loadingUnitId)
            ?: return false
        splitInstallManager.deferredUninstall(listOf(resolvedName))
        return true
    }

    override fun destroy() {
        // FeatureDeliveryDeferredComponentManager is a process-wide singleton in FlutterInjector.
        // Secondary/background FlutterEngines (or recreating an Activity) also call destroy(),
        // so clearing flutterJNI/channel or unregistering the listener here would break the active engine.
        Log.d(TAG, "destroy: preserving singleton JNI/channel/listener")
    }

    companion object {
        private const val TAG = "DeferredComponentMgr"
        private const val MAPPING_KEY =
            "io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager.loadingUnitMapping"
        private const val CONFIRMATION_REQUEST_CODE = 4201
    }
}
