import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// Stats View - Shows summary statistics
// Displays: Current Streak, Avg Horniness, Total Count
class StatsView extends WatchUi.View {
    
    private var _streak as Number = 0;
    private var _avgHorniness as Float = 0.0f;
    private var _totalCount as Number = 0;
    private const HOT_PINK = 0xFF69B4;
    
    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        loadStats();
    }

    function onShow() as Void {
        loadStats();
    }
    
    private function loadStats() as Void {
        _streak = DataManager.getCurrentStreak();
        _avgHorniness = DataManager.getAverageHorniness();
        _totalCount = DataManager.getTotalCount();
    }
    
    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Clear with black background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Title
        dc.setColor(HOT_PINK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            height * 0.12,
            Graphics.FONT_SMALL,
            "STATISTICS",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        
        // === Current Streak ===
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            height * 0.30,
            Graphics.FONT_TINY,
            "Current Streak",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(HOT_PINK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            height * 0.40,
            Graphics.FONT_LARGE,
            _streak.toString() + " days",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        
        // === Average Horniness ===
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            height * 0.55,
            Graphics.FONT_TINY,
            "Avg Horniness",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(HOT_PINK, Graphics.COLOR_TRANSPARENT);
        var avgText = _avgHorniness.format("%.1f") + "/5";
        dc.drawText(
            width / 2,
            height * 0.65,
            Graphics.FONT_LARGE,
            avgText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        
        // === Total Count ===
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            height * 0.80,
            Graphics.FONT_TINY,
            "Total Count",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(HOT_PINK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            height * 0.90,
            Graphics.FONT_LARGE,
            _totalCount.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

// Input delegate for Stats View
class StatsDelegate extends WatchUi.BehaviorDelegate {
    
    function initialize() {
        BehaviorDelegate.initialize();
    }
    
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
    
    function onMenu() as Boolean {
        // Go back one level (to History)
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
