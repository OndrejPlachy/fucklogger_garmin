import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Main application entry point for FUCK LOGGER
class FuckLoggerApp extends Application.AppBase {

    var _networkManager as NetworkManager?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        _networkManager = new NetworkManager();
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application
    function getInitialView() as [Views] or [Views, InputDelegates] {
        if (_networkManager == null) { _networkManager = new NetworkManager(); }
        var mainView = new MainView();
        var mainDelegate = new MainDelegate(mainView);
        return [mainView, mainDelegate];
    }
    
    function getNetworkManager() as NetworkManager {
        if (_networkManager == null) { _networkManager = new NetworkManager(); }
        return _networkManager as NetworkManager;
    }
}

// This function is used to get the application instance
function getApp() as FuckLoggerApp {
    return Application.getApp() as FuckLoggerApp;
}
