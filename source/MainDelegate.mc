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
    
    // Handle screen tap — zones:
    // 1. Arrow buttons (year up/down, month up/down) → navigate
    // 2. Minus button → decrement selected month
    // 3. Eggplant circle → increment (today or selected month)
    // 4. Bottom area → set horniness directly (left=1, right=5)
    function onTap(clickEvent as ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var tapX = coords[0];
        var tapY = coords[1];
        
        var screenWidth = System.getDeviceSettings().screenWidth;
        var screenHeight = System.getDeviceSettings().screenHeight;
        var cx = screenWidth / 2;
        var circleCY = _view.getCircleCenterY();
        var circleR = _view.getCircleRadius();

        // --- Invisible Box Touch Zones (Top panel) ---
        // The top panel occupies roughly the top 40% of the screen.
        var topPanelHeight = screenHeight * 0.4;
        
        // 1. Sync Trigger Override (Top Center)
        // Ensure manual sync trigger doesn't consume whole top of screen.
        // Restricting sync to top 15% and center 30%.
        if (tapY < screenHeight * 0.15 && tapX > screenWidth * 0.35 && tapX < screenWidth * 0.65) {
             System.println("-> MANUAL SYNC TRIGGERED");
             getApp().getNetworkManager().syncAllData();
             return true;
        }

        // 2. Year & Month Invisible Touch Zones
        if (tapY < topPanelHeight) {
            var isLeftHalf = (tapX < cx);
            var centerOfTextY = screenHeight * 0.23; // rough center of the large number
            
            if (isLeftHalf) {
                // Year Zone
                if (tapY < centerOfTextY) {
                    _view.nextYear();
                } else {
                    _view.prevYear();
                }
            } else {
                // Month Zone
                if (tapY < centerOfTextY) {
                    _view.nextMonth();
                } else {
                    _view.prevMonth();
                }
            }
            WatchUi.requestUpdate();
            return true;
        }

        // --- Read today's data ---
        var todayLog = DataManager.getTodayLog();
        var currentCount = todayLog[0];
        var currentHorniness = todayLog[1];
        var selYear = _view.getSelectedYear();
        var selMonth = _view.getSelectedMonth();
        
        // --- Minus button ---
        var minusCenter = _view.getMinusButtonCenter();
        var mdx = tapX - minusCenter[0];
        var mdy = tapY - minusCenter[1];
        var minusDistSq = (mdx * mdx) + (mdy * mdy);
        var minusThreshSq = 28 * 28;

        // --- Eggplant circle ---
        var dx = tapX - cx;
        var dy = tapY - circleCY;
        var eggDistSq = (dx * dx) + (dy * dy);
        var eggThreshSq = (circleR + 15) * (circleR + 15);

        if (minusDistSq <= minusThreshSq) {
            var didDecrement = DataManager.decrementInMonth(selYear, selMonth);
            if (didDecrement && Attention has :vibrate) {
                var vibe = [new Attention.VibeProfile(30, 80)] as Array<Attention.VibeProfile>;
                Attention.vibrate(vibe);
            }
            _view.refreshData();
        } else if (eggDistSq <= eggThreshSq) {
            if (_view.isViewingCurrentMonth()) {
                // Current month: add to today with current horniness tracking
                DataManager.incrementDay(DataManager.getTodayISO(), currentHorniness);
            } else {
                // Past month: add to day 1 of selected month
                DataManager.addToMonth(selYear, selMonth, currentHorniness);
            }
            if (Attention has :vibrate) {
                var vibe = [new Attention.VibeProfile(50, 100)] as Array<Attention.VibeProfile>;
                Attention.vibrate(vibe);
            }
            _view.refreshData();
            _view.startAnimation();
        } else {
            // Horniness zone: map X position to level 1-5
            var margin = 40;
            var usableWidth = screenWidth - (2 * margin);
            var relativeX = tapX - margin;
            if (relativeX < 0) { relativeX = 0; }
            if (relativeX > usableWidth) { relativeX = usableWidth; }
            
            var newHorniness = (relativeX * 5 / usableWidth) + 1;
            if (newHorniness < 1) { newHorniness = 1; }
            if (newHorniness > 5) { newHorniness = 5; }
            
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
    
    // Swipe down → Sync (Primary Trigger)
    function onPreviousPage() as Boolean {
        getApp().getNetworkManager().syncAllData();
        return true;
    }
    
    // Menu button → Sync (Backup Trigger / Physical Button)
    function onMenu() as Boolean {
        getApp().getNetworkManager().syncAllData();
        return true;
    }
    
    // Swipe up → History
    function onNextPage() as Boolean {
        var historyView = new HistoryView();
        var historyDelegate = new HistoryDelegate(historyView);
        WatchUi.pushView(historyView, historyDelegate, WatchUi.SLIDE_LEFT);
        return true;
    }
    
    // Physical select button — do nothing on touch (onTap handles it)
    function onSelect() as Boolean {
        // Intentionally empty: on touch devices, onTap handles all tap logic.
        // Returning false lets the event propagate normally.
        return false;
    }
}
