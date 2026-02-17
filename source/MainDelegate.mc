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

        // --- Arrow zones (same positions as drawn in MainView) ---
        var arrowLX = screenWidth * 19 / 100;
        var arrowRX = screenWidth * 81 / 100;
        var arrowUpY = screenHeight * 15 / 100;
        var arrowDownY = screenHeight * 24 / 100;
        var arrowThreshSq = 25 * 25; // Generous tap target

        // Check year up arrow
        var adx = tapX - arrowLX;
        var ady = tapY - arrowUpY;
        if ((adx * adx + ady * ady) <= arrowThreshSq) {
            System.println("-> YEAR UP");
            _view.nextYear();
            WatchUi.requestUpdate();
            return true;
        }
        // Check year down arrow
        ady = tapY - arrowDownY;
        if ((adx * adx + ady * ady) <= arrowThreshSq) {
            System.println("-> YEAR DOWN");
            _view.prevYear();
            WatchUi.requestUpdate();
            return true;
        }
        // Check month up arrow
        adx = tapX - arrowRX;
        ady = tapY - arrowUpY;
        if ((adx * adx + ady * ady) <= arrowThreshSq) {
            System.println("-> MONTH UP");
            _view.nextMonth();
            WatchUi.requestUpdate();
            return true;
        }
        // Check month down arrow
        ady = tapY - arrowDownY;
        if ((adx * adx + ady * ady) <= arrowThreshSq) {
            System.println("-> MONTH DOWN");
            _view.prevMonth();
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

        System.println("TAP at (" + tapX + "," + tapY + ")");

        if (minusDistSq <= minusThreshSq) {
            System.println("-> MINUS (decrement " + selYear + "-" + selMonth + ")");
            var didDecrement = DataManager.decrementInMonth(selYear, selMonth);
            if (didDecrement && Attention has :vibrate) {
                var vibe = [new Attention.VibeProfile(30, 80)] as Array<Attention.VibeProfile>;
                Attention.vibrate(vibe);
            }
            _view.refreshData();
        } else if (eggDistSq <= eggThreshSq) {
            System.println("-> EGGPLANT");
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
            
            System.println("-> HORNINESS direct: " + newHorniness);
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
        var historyDelegate = new HistoryDelegate(historyView);
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
