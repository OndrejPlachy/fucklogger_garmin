import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Attention;
import Toybox.System;
import Toybox.Math;

// Input Delegate for Main View
// Tap detection: inside eggplant circle = log, outside = horniness
class MainDelegate extends WatchUi.BehaviorDelegate {
    
    private var _view as MainView;
    
    function initialize(view as MainView) {
        BehaviorDelegate.initialize();
        _view = view;
    }
    
    // Handle screen tap — three zones:
    // 1. Minus button (small circle left of eggplant) → decrement count
    // 2. Eggplant circle → increment count
    // 3. Anywhere else → cycle horniness
    function onTap(clickEvent as ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var tapX = coords[0];
        var tapY = coords[1];
        
        var cx = System.getDeviceSettings().screenWidth / 2;
        var circleCY = _view.getCircleCenterY();
        var circleR = _view.getCircleRadius();
        
        // Read today's data
        var todayLog = DataManager.getTodayLog();
        var currentCount = todayLog[0];
        var currentHorniness = todayLog[1];
        
        // Check minus button first (higher priority, smaller target)
        var minusCenter = _view.getMinusButtonCenter();
        var mdx = tapX - minusCenter[0];
        var mdy = tapY - minusCenter[1];
        var minusDistSq = (mdx * mdx) + (mdy * mdy);
        var minusThreshSq = 22 * 22;

        // Distance from eggplant center
        var dx = tapX - cx;
        var dy = tapY - circleCY;
        var eggDistSq = (dx * dx) + (dy * dy);
        var eggThreshSq = (circleR + 15) * (circleR + 15);

        // Debug output
        System.println("TAP at (" + tapX + "," + tapY + ") eggDist=" + eggDistSq + " thresh=" + eggThreshSq);

        if (minusDistSq <= minusThreshSq) {
            System.println("-> MINUS");
            if (currentCount > 0) {
                var newCount = currentCount - 1;
                DataManager.saveLog(DataManager.getTodayISO(), newCount, currentHorniness);
                if (Attention has :vibrate) {
                    var vibe = [new Attention.VibeProfile(30, 80)] as Array<Attention.VibeProfile>;
                    Attention.vibrate(vibe);
                }
            }
            _view.refreshData();
        } else if (eggDistSq <= eggThreshSq) {
            System.println("-> EGGPLANT");
            var newCount = currentCount + 1;
            DataManager.saveLog(DataManager.getTodayISO(), newCount, currentHorniness);
            if (Attention has :vibrate) {
                var vibe = [new Attention.VibeProfile(50, 100)] as Array<Attention.VibeProfile>;
                Attention.vibrate(vibe);
            }
            _view.refreshData();
            _view.startAnimation();
        } else {
            System.println("-> HORNINESS cycle");
            var newHorniness = (currentHorniness % 5) + 1;
            DataManager.saveLog(DataManager.getTodayISO(), currentCount, newHorniness);
            _view.refreshData();
        }

        WatchUi.requestUpdate(); 
        return true;
    }
    
    // Handle long press / hold — undo last interaction
    function onHold(clickEvent as ClickEvent) as Boolean {
        _view.undoInteraction();
        
        if (Attention has :vibrate) {
            var vibePattern = [
                new Attention.VibeProfile(100, 300)
            ] as Array<Attention.VibeProfile>;
            Attention.vibrate(vibePattern);
        }
        
        WatchUi.requestUpdate();
        return true;
    }
    
    // Menu button → History
    function onMenu() as Boolean {
        var historyView = new HistoryView();
        var historyDelegate = new HistoryDelegate();
        historyDelegate.setView(historyView);
        WatchUi.pushView(historyView, historyDelegate, WatchUi.SLIDE_LEFT);
        return true;
    }
    
    // Swipe up → History
    function onNextPage() as Boolean {
        return onMenu();
    }
    
    // Back → exit app
    function onBack() as Boolean {
        return false;
    }
    
    // Physical select button — do nothing on touch (onTap handles it)
    function onSelect() as Boolean {
        // Intentionally empty: on touch devices, onTap handles all tap logic.
        // Returning false lets the event propagate normally.
        return false;
    }
}
