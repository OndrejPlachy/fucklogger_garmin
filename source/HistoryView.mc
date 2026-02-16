import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// History View - Monthly summary of intercourses
// Shows: Month label + total count per month, newest first
class HistoryView extends WatchUi.View {
    
    private var _months as Array<Dictionary>;
    private var _scrollOffset as Number = 0;
    private const HOT_PINK = 0xFF69B4;
    
    function initialize() {
        View.initialize();
        _months = [];
    }

    function onLayout(dc as Dc) as Void {
        loadData();
    }

    function onShow() as Void {
        loadData();
    }
    
    private function loadData() as Void {
        _months = DataManager.getMonthlyHistory();
    }
    
    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Title
        dc.setColor(HOT_PINK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx, 45,
            Graphics.FONT_SMALL, "HISTORY",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        
        if (_months.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, height / 2,
                Graphics.FONT_SMALL, "No data yet",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }
        
        // Monthly rows — centered for round display
        var startY = 80;
        var rowH = 80;
        var maxVisible = (height - startY - 40) / rowH;
        
        for (var i = 0; i < maxVisible && (i + _scrollOffset) < _months.size(); i++) {
            var idx = i + _scrollOffset;
            var entry = _months[idx];
            var yPos = startY + (i * rowH);
            
            var monthLabel = entry.get("month") as String;
            var total = entry.get("total") as Number;
            var avgHorn = entry.get("avgHorn") as Number;
            
            // Month name — white, vertically centered in top half
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, yPos + 15,
                Graphics.FONT_SMALL, monthLabel,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            
            // Count + Avg Horniness — pink, vertically centered in bottom half
            
            // Main count
            dc.setColor(HOT_PINK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, yPos + 42,
                Graphics.FONT_TINY, total.toString() + " times",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            
            // Average horniness indicator (small text below count, color-coded)
            if (avgHorn > 0) {
                var hornColors = [0x6EC6FF, 0x4DD0E1, 0xFFB74D, 0xFF7043, 0xFF4081];
                var hornIdx = avgHorn - 1;
                if (hornIdx < 0) { hornIdx = 0; }
                if (hornIdx > 4) { hornIdx = 4; }
                dc.setColor(hornColors[hornIdx] as Number, Graphics.COLOR_TRANSPARENT);
                var hornLabels = ["Cold", "Cool", "Warm", "Hot", "Fire"];
                dc.drawText(
                    cx, yPos + 60,
                    Graphics.FONT_XTINY, "Avg: " + hornLabels[hornIdx],
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
            
            // Subtle separator at the very bottom of the row
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(width * 0.25, yPos + rowH - 4, width * 0.75, yPos + rowH - 4);
        }
    }
    
    function scrollDown() as Void {
        if (_scrollOffset < _months.size() - 1) {
            _scrollOffset++;
            WatchUi.requestUpdate();
        }
    }
    
    function scrollUp() as Void {
        if (_scrollOffset > 0) {
            _scrollOffset--;
            WatchUi.requestUpdate();
        }
    }

    function getScrollOffset() as Number {
        return _scrollOffset;
    }
}

// Input delegate for History View
class HistoryDelegate extends WatchUi.BehaviorDelegate {
    
    private var _view as HistoryView?;
    
    function initialize() {
        BehaviorDelegate.initialize();
    }
    
    function setView(view as HistoryView) as Void {
        _view = view;
    }
    
    function onMenu() as Boolean {
        // Go to stats view
        WatchUi.pushView(new StatsView(), new StatsDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
    
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
    
    function onNextPage() as Boolean {
        if (_view != null) {
            _view.scrollDown();
        }
        return true;
    }
    
    function onPreviousPage() as Boolean {
        if (_view != null && _view.getScrollOffset() > 0) {
            _view.scrollUp();
        } else {
            // At the top — swipe down goes back to main
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
        return true;
    }
}
