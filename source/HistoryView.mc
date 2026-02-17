import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.System;

// History View
// Modes: 0 = Daily View (Specific Month), 1 = Yearly View (Specific Year)
class HistoryView extends WatchUi.View {
    
    // State
    var _viewMode as Number = 0; // 0=Month, 1=Year
    var _chartMode as Number = 0; // 0=Horniness, 1=DOW
    var _selectedYear as Number = 2026;
    var _selectedMonth as Number = 1;
    var _scrollOffset as Number = 0;

    // Data Cache
    private var _dailyData as Array<Dictionary> = [];
    private var _yearlyData as Array<Dictionary> = []; // For year mode
    private var _hornCounts as Array<Number> = [0,0,0,0,0];
    private var _dowCounts as Array<Number> = [0,0,0,0,0,0,0];

    // Colors
    private const COL_TEAL = 0x4DD0E1;
    private const COL_AMBER = 0xFFB74D;
    private const COL_GRAY_TXT = 0xAAAAAA;
    
    private const MONTH_NAMES = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                  "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    private const HORN_COLORS = [0x6EC6FF, 0x4DD0E1, 0xFFB74D, 0xFF7043, 0xFF4081];
    
    function initialize() {
        View.initialize();
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        _selectedYear = info.year;
        _selectedMonth = info.month;
    }

    function onShow() as Void {
        refreshData();
    }

    function toggleMode() as Void {
        _viewMode = (_viewMode == 0) ? 1 : 0;
        _scrollOffset = 0;
        refreshData();
        WatchUi.requestUpdate();
    }
    
    function toggleChart() as Void {
        _chartMode = (_chartMode == 0) ? 1 : 0;
        WatchUi.requestUpdate();
    }

    function refreshData() as Void {
        if (_viewMode == 0) {
            // Month Mode
            _dailyData = DataManager.getDailyBreakdown(_selectedYear, _selectedMonth);
            _hornCounts = DataManager.getHorninessCounts(_selectedYear, _selectedMonth);
            _dowCounts = DataManager.getDowCounts(_selectedYear, _selectedMonth);
        } else {
            // Year Mode - Build monthly summary for the year
            _yearlyData = [];
            for (var m=1; m<=12; m++) {
                var total = DataManager.getMonthTotalFor(_selectedYear, m);
                if (total > 0) {
                   _yearlyData.add({
                       "month" => m,
                       "name" => MONTH_NAMES[m-1],
                       "count" => total
                   }); 
                }
            }
            _hornCounts = DataManager.getYearHorninessCounts(_selectedYear);
            _dowCounts = DataManager.getYearDowCounts(_selectedYear);
        }
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ============================================================
        // 1. TOP NAV BAR — Title + Arrows + Mode Toggle
        // ============================================================
        // Layout adjusted for 416px round screen:
        // Row 1 (y~35): ◄  FEB  ►
        // Row 2 (y~62): MONTHLY ▼▲ (Toggle)
        
        var titleY = 35;
        var titleStr = "";
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (_viewMode == 0) {
            titleStr = MONTH_NAMES[_selectedMonth-1];
        } else {
            titleStr = _selectedYear.toString();
        }
        dc.drawText(cx, titleY, Graphics.FONT_SMALL, titleStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Arrows (Centered around title)
        var arrowOff = 70; 
        dc.setColor(COL_TEAL, Graphics.COLOR_TRANSPARENT);
        // Left Arrow ◄
        dc.fillPolygon([[cx - arrowOff, titleY], [cx - arrowOff + 10, titleY - 8], [cx - arrowOff + 10, titleY + 8]]);
        // Right Arrow ►
        dc.fillPolygon([[cx + arrowOff, titleY], [cx + arrowOff - 10, titleY - 8], [cx + arrowOff - 10, titleY + 8]]);
        
        // Mode Label + Swap Icon
        var modeY = 62;
        var modeLabel = (_viewMode == 0) ? "MONTHLY" : "YEARLY";
        dc.setColor(COL_GRAY_TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, modeY, Graphics.FONT_XTINY, modeLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        var modeDim = dc.getTextDimensions(modeLabel, Graphics.FONT_XTINY);
        var modeW = modeDim[0];
        drawSwapIcon(dc, cx + (modeW/2) + 10, modeY, COL_TEAL);

        // ============================================================
        // 2. MAIN DATA LIST (top half of screen)
        // ============================================================
        var listTop = 85; 
        var listBot = (h * 55 / 100);    // Table gets 55% of screen
        var rowH = 22;
        
        // Headers
        var col1 = (w * 0.25).toNumber();
        var col2 = (w * 0.50).toNumber();
        var col3 = (w * 0.75).toNumber();
        
        dc.setColor(COL_TEAL, Graphics.COLOR_TRANSPARENT);
        if (_viewMode == 0) {
             dc.drawText(col1, listTop, Graphics.FONT_XTINY, "DAY", Graphics.TEXT_JUSTIFY_CENTER);
             dc.drawText(col2, listTop, Graphics.FONT_XTINY, "CNT", Graphics.TEXT_JUSTIFY_CENTER);
             dc.drawText(col3, listTop, Graphics.FONT_XTINY, "LVL", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
             dc.drawText(col1, listTop, Graphics.FONT_XTINY, "MTH", Graphics.TEXT_JUSTIFY_CENTER);
             dc.drawText(col2, listTop, Graphics.FONT_XTINY, "CNT", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        var listDataTop = listTop + 22;
        var visibleRows = ((listBot - listDataTop) / rowH).toNumber();
        if (visibleRows < 1) { visibleRows = 1; }
        
        var dataSrc = (_viewMode == 0) ? _dailyData : _yearlyData;
        
        if (dataSrc.size() == 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (listDataTop + listBot)/2, Graphics.FONT_XTINY, "No Data", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            for (var i=0; i < visibleRows; i++) {
                var idx = i + _scrollOffset;
                if (idx >= dataSrc.size()) { break; }
                
                var entry = dataSrc[idx];
                var y = listDataTop + (i * rowH);
                
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                
                if (_viewMode == 0) {
                    var d = entry["day"];
                    var c = entry["count"];
                    var dow = entry["dow"];
                    var hrn = entry["horn"];
                    
                    dc.drawText(col1, y, Graphics.FONT_XTINY, d.format("%02d") + " " + dow, Graphics.TEXT_JUSTIFY_CENTER);
                    dc.drawText(col2, y, Graphics.FONT_XTINY, c.toString(), Graphics.TEXT_JUSTIFY_CENTER);
                    
                    if (hrn >= 1 && hrn <= 5) {
                        dc.setColor(HORN_COLORS[hrn - 1] as Number, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(col3, y + 10, 5);
                    }
                } else {
                    var name = entry["name"];
                    var c = entry["count"];
                    dc.drawText(col1, y, Graphics.FONT_XTINY, name, Graphics.TEXT_JUSTIFY_CENTER);
                    dc.drawText(col2, y, Graphics.FONT_XTINY, c.toString(), Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
            
            // Scroll indicator
            if (dataSrc.size() > visibleRows) {
                var sbH = listBot - listDataTop;
                var sbY = (listDataTop + ( (_scrollOffset.toFloat() / dataSrc.size()) * sbH )).toNumber();
                var sbLen = ((visibleRows.toFloat() / dataSrc.size()) * sbH).toNumber();
                if (sbLen < 10) { sbLen = 10; }
                
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(w - 15, listDataTop, 4, sbH);
                dc.setColor(COL_TEAL, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(w - 15, sbY, 4, sbLen);
            }
        }

        // ============================================================
        // 3. CHART AREA (bottom half of screen)
        // ============================================================
        var barTop = listBot + 15;       // Space for value labels above bars
        var barBot = h - 40;             // Leave room for x-axis labels + toggle
        var barH = barBot - barTop;
        if (barH < 10) { barH = 10; }
        
        // Calculate usable width at barBot on a round screen
        var radius = w / 2;
        var distFromCenter = barBot - radius;
        if (distFromCenter < 0) { distFromCenter = -distFromCenter; }
        var usableHalf = radius * radius - distFromCenter * distFromCenter;
        // Simple integer sqrt approximation
        var sqrtVal = 1;
        if (usableHalf > 0) {
            sqrtVal = usableHalf / 2;
            for (var s=0; s<10; s++) {
                if (sqrtVal > 0) { sqrtVal = (sqrtVal + usableHalf / sqrtVal) / 2; }
            }
        }
        var usableW = (sqrtVal * 2 * 85 / 100); // 85% of available circle width

        // --- Build filtered data (skip zero values) ---
        var DOW_LABELS = ["M", "T", "W", "T", "F", "S", "S"];
        // Green palette from lightest to darkest
        var GREEN_SHADES = [0xA5D6A7, 0x81C784, 0x66BB6A, 0x4CAF50, 0x388E3C, 0x2E7D32, 0x1B5E20];
        var filteredVals = [] as Array<Number>;
        var filteredLabels = [] as Array<String>;
        var filteredColors = [] as Array<Number>;
        
        if (_chartMode == 0) {
            for (var i=0; i<5; i++) {
                if (_hornCounts[i] > 0) {
                    filteredVals.add(_hornCounts[i]);
                    filteredLabels.add((i+1).toString());
                    filteredColors.add(HORN_COLORS[i]);
                }
            }
        } else {
            for (var i=0; i<7; i++) {
                if (_dowCounts[i] > 0) {
                    filteredVals.add(_dowCounts[i]);
                    filteredLabels.add(DOW_LABELS[i]);
                    filteredColors.add(0); // placeholder, will color by value
                }
            }
        }
        
        var numBars = filteredVals.size();
        
        if (numBars > 0) {
            // --- Determine max value ---
            var maxVal = 1;
            for (var i=0; i<numBars; i++) {
                if (filteredVals[i] > maxVal) { maxVal = filteredVals[i]; }
            }
            
            // --- For DOW: assign green shade by value intensity ---
            if (_chartMode == 1) {
                for (var i=0; i<numBars; i++) {
                    var intensity = ((filteredVals[i].toFloat() / maxVal) * 6).toNumber();
                    if (intensity > 6) { intensity = 6; }
                    filteredColors[i] = GREEN_SHADES[intensity];
                }
            }
            
            // --- Dynamic bar sizing (fit within usable round screen width) ---
            var chartW = usableW;
            var gap = 3;
            var barW = ((chartW - ((numBars - 1) * gap)) / numBars).toNumber();
            if (barW < 6) { barW = 6; gap = 2; }
            if (barW > 50) { barW = 50; }
            var totalBarsW = (numBars * barW) + ((numBars - 1) * gap);
            var chartStartX = cx - (totalBarsW / 2);
            
            // --- Draw bars + value labels + x-axis labels ---
            for (var i=0; i<numBars; i++) {
                var val = filteredVals[i];
                var bH = ((val.toFloat() / maxVal) * barH).toNumber();
                if (bH < 6) { bH = 6; }
                var bx = chartStartX + (i * (barW + gap));
                
                // Bar
                dc.setColor(filteredColors[i] as Number, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, barBot - bH, barW, bH);
                
                // Value label on top of bar (tiny custom font)
                dc.setColor(COL_GRAY_TXT, Graphics.COLOR_TRANSPARENT);
                drawTinyNumber(dc, bx + (barW/2), barBot - bH - 10, val);
                
                // X-axis label below bar (only for DOW mode, tiny)
                if (_chartMode == 1) {
                    dc.setColor(COL_GRAY_TXT, Graphics.COLOR_TRANSPARENT);
                    drawTinyChar(dc, bx + (barW/2) - 3, barBot + 3, filteredLabels[i] as String);
                }
            }
        } else {
            dc.setColor(COL_GRAY_TXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (barTop + barBot)/2, Graphics.FONT_XTINY, "No Data", 
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        
        // --- Small swap icon at very bottom ---
        var toggleY = h - 10;
        drawSwapIcon(dc, cx, toggleY, COL_AMBER);
    }
    
    // Draw a light swap icon: small ▲ and ▼ side by side
    function drawSwapIcon(dc as Dc, x as Number, y as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Small up triangle (left side)
        dc.fillPolygon([[x - 5, y - 1], [x - 8, y + 4], [x - 2, y + 4]]);
        // Small down triangle (right side)
        dc.fillPolygon([[x + 5, y + 1], [x + 2, y - 4], [x + 8, y - 4]]);
    }
    
    // Draw a number centered at (cx, y) using 5×7 pixel digits
    function drawTinyNumber(dc as Dc, cx as Number, y as Number, num as Number) as Void {
        var s = num.toString();
        var digitW = 6; // 5px digit + 1px gap
        var totalW = s.length() * digitW - 1;
        var startX = cx - (totalW / 2);
        for (var i=0; i<s.length(); i++) {
            var ch = s.substring(i, i+1);
            var dx = startX + (i * digitW);
            drawTinyDigit(dc, dx, y, ch);
        }
    }
    
    // Draw a single character at (x, y) using 5×7 pixel rendering
    function drawTinyChar(dc as Dc, x as Number, y as Number, ch as String) as Void {
        if (ch.equals("M")) {
            dc.fillRectangle(x, y, 1, 7); dc.fillRectangle(x+6, y, 1, 7);
            dc.fillRectangle(x+1, y+1, 1, 1); dc.fillRectangle(x+5, y+1, 1, 1);
            dc.fillRectangle(x+2, y+2, 1, 1); dc.fillRectangle(x+4, y+2, 1, 1);
            dc.fillRectangle(x+3, y+3, 1, 1);
        } else if (ch.equals("T")) {
            dc.fillRectangle(x, y, 7, 1); dc.fillRectangle(x+3, y, 1, 7);
        } else if (ch.equals("W")) {
            dc.fillRectangle(x, y, 1, 7); dc.fillRectangle(x+6, y, 1, 7);
            dc.fillRectangle(x+3, y+3, 1, 4);
            dc.fillRectangle(x+1, y+6, 1, 1); dc.fillRectangle(x+2, y+5, 1, 1);
            dc.fillRectangle(x+4, y+5, 1, 1); dc.fillRectangle(x+5, y+6, 1, 1);
        } else if (ch.equals("F")) {
            dc.fillRectangle(x, y, 1, 7); dc.fillRectangle(x, y, 5, 1); dc.fillRectangle(x, y+3, 4, 1);
        } else if (ch.equals("S")) {
            dc.fillRectangle(x+1, y, 4, 1); dc.fillRectangle(x, y+1, 1, 2);
            dc.fillRectangle(x+1, y+3, 4, 1); dc.fillRectangle(x+5, y+4, 1, 2);
            dc.fillRectangle(x+1, y+6, 4, 1);
        }
    }
    
    // Draw a single 5×7 pixel digit at position (x, y)
    function drawTinyDigit(dc as Dc, x as Number, y as Number, ch as String) as Void {
        if (ch.equals("0")) {
            dc.fillRectangle(x+1, y, 3, 1); dc.fillRectangle(x+1, y+6, 3, 1);
            dc.fillRectangle(x, y+1, 1, 5); dc.fillRectangle(x+4, y+1, 1, 5);
        } else if (ch.equals("1")) {
            dc.fillRectangle(x+2, y, 1, 7);
            dc.fillRectangle(x+1, y+1, 1, 1); dc.fillRectangle(x+1, y+6, 3, 1);
        } else if (ch.equals("2")) {
            dc.fillRectangle(x, y, 5, 1); dc.fillRectangle(x+4, y+1, 1, 2);
            dc.fillRectangle(x, y+3, 5, 1); dc.fillRectangle(x, y+4, 1, 2);
            dc.fillRectangle(x, y+6, 5, 1);
        } else if (ch.equals("3")) {
            dc.fillRectangle(x, y, 5, 1); dc.fillRectangle(x+4, y+1, 1, 2);
            dc.fillRectangle(x+1, y+3, 4, 1); dc.fillRectangle(x+4, y+4, 1, 2);
            dc.fillRectangle(x, y+6, 5, 1);
        } else if (ch.equals("4")) {
            dc.fillRectangle(x, y, 1, 4); dc.fillRectangle(x+4, y, 1, 7);
            dc.fillRectangle(x, y+3, 5, 1);
        } else if (ch.equals("5")) {
            dc.fillRectangle(x, y, 5, 1); dc.fillRectangle(x, y+1, 1, 2);
            dc.fillRectangle(x, y+3, 5, 1); dc.fillRectangle(x+4, y+4, 1, 2);
            dc.fillRectangle(x, y+6, 5, 1);
        } else if (ch.equals("6")) {
            dc.fillRectangle(x+1, y, 4, 1); dc.fillRectangle(x, y+1, 1, 5);
            dc.fillRectangle(x+1, y+3, 4, 1); dc.fillRectangle(x+4, y+4, 1, 2);
            dc.fillRectangle(x+1, y+6, 3, 1);
        } else if (ch.equals("7")) {
            dc.fillRectangle(x, y, 5, 1); dc.fillRectangle(x+4, y+1, 1, 6);
        } else if (ch.equals("8")) {
            dc.fillRectangle(x+1, y, 3, 1); dc.fillRectangle(x+1, y+3, 3, 1);
            dc.fillRectangle(x+1, y+6, 3, 1);
            dc.fillRectangle(x, y+1, 1, 5); dc.fillRectangle(x+4, y+1, 1, 5);
        } else if (ch.equals("9")) {
            dc.fillRectangle(x+1, y, 3, 1); dc.fillRectangle(x+1, y+3, 4, 1);
            dc.fillRectangle(x, y+1, 1, 2); dc.fillRectangle(x+4, y+1, 1, 5);
            dc.fillRectangle(x+1, y+6, 3, 1);
        }
    }
    
    // Actions
    function nextSpan() as Void {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        
        if (_viewMode == 0) {
            _selectedMonth++;
            if (_selectedMonth > 12) { _selectedMonth = 1; _selectedYear++; }
            if (_selectedYear > info.year || (_selectedYear == info.year && _selectedMonth > info.month)) {
                _selectedMonth = info.month; _selectedYear = info.year;
            }
        } else {
            if (_selectedYear < info.year) { _selectedYear++; }
        }
        refreshData();
        WatchUi.requestUpdate();
    }
    
    function prevSpan() as Void {
        if (_viewMode == 0) {
            _selectedMonth--;
            if (_selectedMonth < 1) { _selectedMonth = 12; _selectedYear--; }
            if (_selectedYear < 2020) { _selectedYear = 2020; _selectedMonth = 1; }
        } else {
            if (_selectedYear > 2020) { _selectedYear--; }
        }
        refreshData();
        WatchUi.requestUpdate();
    }
    
    function scroll(dir as Number) as Void {
        var dataSize = (_viewMode == 0) ? _dailyData.size() : _yearlyData.size();
        var visible = 10; // Approx
        if (dir > 0 && _scrollOffset < (dataSize - 3)) {
            _scrollOffset += 1;
            WatchUi.requestUpdate();
        } else if (dir < 0 && _scrollOffset > 0) {
            _scrollOffset -= 1;
             WatchUi.requestUpdate();
        }
    }
}

class HistoryDelegate extends WatchUi.BehaviorDelegate {
    var _view as HistoryView?;
    function initialize(v as HistoryView) {
        BehaviorDelegate.initialize();
        _view = v;
    }
    
    function onTap(evt as ClickEvent) as Boolean {
        if (_view == null) { return false; }
        
        var c = evt.getCoordinates();
        var x = c[0];
        var y = c[1];
        var w = System.getDeviceSettings().screenWidth;
        var h = System.getDeviceSettings().screenHeight;
        var cx = w / 2;
        
        // 1. Top Area — check center toggle FIRST, then arrows
        if (y < h * 0.25) { // Top 25%
            // Mode toggle: generous center zone (y 45-80, x center ±80)
            if (y > 45 && y < 80 && x > (cx - 80) && x < (cx + 80)) {
                _view.toggleMode();
                return true;
            }
            
            // Left/Right arrows for prev/next span (title row y~35)
            var arrowOff = 70;
            if (x < (cx - arrowOff + 40)) {
                _view.prevSpan();
                return true;
            } else if (x > (cx + arrowOff - 40)) {
                _view.nextSpan();
                return true;
            }
        }
        
        // 2. Bottom area — toggle chart mode
        if (y > (h * 55 / 100)) { // Below table area
            _view.toggleChart();
            return true;
        }
        
        return false;
    }
    
    function onSwipe(evt as SwipeEvent) as Boolean {
        if (_view == null) { return false; }
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            _view.scroll(1);
        } else if (dir == WatchUi.SWIPE_DOWN) {
             _view.scroll(-1);
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
         return true;
    }
    
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
     function onNextPage() as Boolean {
         if (_view != null) { _view.scroll(1); }
        return true;
    }
    function onPreviousPage() as Boolean {
         if (_view != null) { _view.scroll(-1); }
        return true;
    }
}
