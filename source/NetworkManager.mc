import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// NetworkManager handles synchronization with the backend
class NetworkManager {
    // Configuration
    // TODO: Make this configurable via Application.Properties
    // Using LAN IP to bypass simulator localhost/loopback restrictions
    const SYNC_URL = "http://10.0.0.248:3000/api/sync"; 
    const API_KEY = "your-secret-key-here";

    // Sync status
    enum {
        SYNC_IDLE,
        SYNC_IN_PROGRESS,
        SYNC_SUCCESS,
        SYNC_ERROR
    }
    
    private var _syncStatus = SYNC_IDLE;
    private var _lastError = null;

    // Callback for UI updates
    private var _onSyncStatusChanged = null;

    function initialize() {
    }

    function setStatusCallback(callback as Method(status as Number) as Void) as Void {
        _onSyncStatusChanged = callback;
    }

    function getSyncStatus() as Number {
        return _syncStatus;
    }

    // Trigger a full sync
    function syncAllData() as Void {
        if (_syncStatus == SYNC_IN_PROGRESS) {
            System.println("Sync already in progress");
            return;
        }

        System.println("Starting sync to: " + SYNC_URL);
        _syncStatus = SYNC_IN_PROGRESS;
        if (_onSyncStatusChanged != null) {
            _onSyncStatusChanged.invoke(SYNC_IN_PROGRESS);
        }

        // Get system identifier
        var myDeviceSettings = System.getDeviceSettings();
        var uniqueId = myDeviceSettings.uniqueIdentifier;
        if (uniqueId == null) { uniqueId = "unknown_device"; }

        // payload data
        var records = DataManager.getAllRecords();
        System.println("Syncing " + records.size() + " records...");
        
        var payload = {
            "deviceId" => uniqueId,
            "syncedAt" => DataManager.getTimestampISO(), // Full ISO timestamp
            "records" => records
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "X-API-Key" => API_KEY
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            SYNC_URL,
            payload,
            options,
            method(:onSyncResponse)
        );
    }

    // Handle the server response
    function onSyncResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Sync response code: " + responseCode);
        
        if (responseCode == 200) {
            _syncStatus = SYNC_SUCCESS;
            DataManager.setLastSyncTime(Time.now());
            if (data != null) {
                System.println("Server response data: " + data);
            }
        } else {
            _syncStatus = SYNC_ERROR;
            _lastError = responseCode;
            System.println("Sync failed! Error code: " + responseCode);
        }

        if (_onSyncStatusChanged != null) {
            _onSyncStatusChanged.invoke(_syncStatus);
        }
    }
}
