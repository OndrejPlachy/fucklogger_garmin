import Toybox.Graphics;
import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.System;

// Main View - The "Action" Screen
// Layout:
//   Top:    Split panel [Year Total | Month Total] with navigation arrows
//   Center: Eggplant icon in circle (flashes pink on tap)
//   Bottom: Curved horniness arc (cold blue → hot red)
class MainView extends WatchUi.View {
    
    private var _eggplantBitmap as BitmapResource?;
    private var _yearTotal as Number = 0;
    private var _monthTotal as Number = 0;
    private var _horniness as Number = 3;
    private var _interactionCount as Number = 0;
    
    // Sync state
    private var _syncStatus as Number = 0; // 0=IDLE

    // Navigation state
    private var _selectedYear as Number = 2026;
    private var _selectedMonth as Number = 1;

    // Month names for display (abbreviated to fit)
    private const MONTH_NAMES = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                  "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    // Color constants for panel
    private const YEAR_COLOR = 0x4DD0E1;   // Teal
    private const MONTH_COLOR = 0xFF69B4;  // Hot pink

    // Animation state
    private var _animationTimer as Timer.Timer?;
    private var _isAnimating as Boolean = false;
    private var _animPhase as Number = 0;

    // Horniness arc colors: cold blue → hot red (5 levels)
    // 1=cold, 2=cool, 3=warm, 4=hot, 5=fire
    private const HORN_COLORS_ACTIVE = [
        0x00AAFF,  // light blue (cold)
        0x4DD0E1,  // cyan (cool)
        0xFFB74D,  // warm orange/amber (warm)
        0xFF8800,  // hot orange (hot)
        0xFF0000   // hot red (fire)
    ];
    
    function initialize() {
        View.initialize();
        // Initialize to current date
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        _selectedYear = info.year;
        _selectedMonth = info.month;
        
        // Register for sync updates
        getApp().getNetworkManager().setStatusCallback(method(:onSyncStatus));
    }

    function onLayout(dc as Dc) as Void {
        _eggplantBitmap = WatchUi.loadResource(Rez.Drawables.AppIcon) as BitmapResource;
        _animationTimer = new Timer.Timer();
        refreshData();
    }

    function onShow() as Void {
        refreshData();
    }
    
    function refreshData() as Void {
        _yearTotal = DataManager.getYearTotalFor(_selectedYear);
        _monthTotal = DataManager.getMonthTotalFor(_selectedYear, _selectedMonth);
        var todayLog = DataManager.getTodayLog();
        _interactionCount = todayLog[0];
        _horniness = todayLog[1];
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;
        
        var yearCount = _yearTotal;
        var monthCount = _monthTotal;
        var horniness = _horniness;

        // --- SECTION 1: TOP — Split panel [Year | Month] ---
        // Vertical stacked layout without backgrounds
        // Hardcode locY positioning to strictly enforce a grid
        var arrowUpY = 30;
        var headerY = 50;
        var numberY = 85;
        var labelY = 120;
        var arrowDownY = 140;
        
        var leftColX = width * 32 / 100;     // Shifted slightly left from center
        var rightColX = width * 68 / 100;    // Shifted slightly right from center

        // Year Column (left - teal)
        dc.setColor(YEAR_COLOR, Graphics.COLOR_TRANSPARENT);
        // Up arrow ▲ (small)
        dc.fillPolygon([[leftColX, arrowUpY - 5], [leftColX - 6, arrowUpY + 3], [leftColX + 6, arrowUpY + 3]]);
        // Header: 2026
        dc.drawText(leftColX, headerY, Graphics.FONT_XTINY, _selectedYear.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // Value: 30
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftColX, numberY, Graphics.FONT_MEDIUM, yearCount.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // Label: YTD
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftColX, labelY, Graphics.FONT_XTINY, "YTD", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // Down arrow ▼ (small)
        dc.setColor(YEAR_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[leftColX, arrowDownY + 5], [leftColX - 6, arrowDownY - 3], [leftColX + 6, arrowDownY - 3]]);

        // Month Column (right - pink)
        dc.setColor(MONTH_COLOR, Graphics.COLOR_TRANSPARENT);
        // Up arrow ▲ (small)
        dc.fillPolygon([[rightColX, arrowUpY - 5], [rightColX - 6, arrowUpY + 3], [rightColX + 6, arrowUpY + 3]]);
        // Header: FEB
        var monthLabel = MONTH_NAMES[_selectedMonth - 1];
        dc.drawText(rightColX, headerY, Graphics.FONT_XTINY, monthLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // Value: 16
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightColX, numberY, Graphics.FONT_MEDIUM, monthCount.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // Label: MTD
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightColX, labelY, Graphics.FONT_XTINY, "MTD", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // Down arrow ▼ (small)
        dc.setColor(MONTH_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[rightColX, arrowDownY + 5], [rightColX - 6, arrowDownY - 3], [rightColX + 6, arrowDownY - 3]]);

        // --- SECTION 2: CENTER — Eggplant button ---
        var circleCY = cy + 5;

        // Eggplant icon
        if (_eggplantBitmap != null) {
            var bmpWidth = _eggplantBitmap.getWidth();
            var bmpHeight = _eggplantBitmap.getHeight();
            var drawX = cx - (bmpWidth / 2);
            var drawY = circleCY - (bmpHeight / 2);
            
            // Jiggle effect during animation
            if (_isAnimating) {
                 drawX += (Math.rand() % 4) - 2;
                 drawY += (Math.rand() % 4) - 2;
            }
            
            dc.drawBitmap(drawX, drawY, _eggplantBitmap);
        }

        // --- SECTION 3: BOTTOM — Horniness arc slider ---
        var arcRadius = (width / 2) - 18;
        var arcWidth = 10; // Substantial gauge thickness
        var startAngle = 214; // Starting quadrant
        var endAngle = 326; // Ending quadrant
        var totalArcSpan = endAngle - startAngle; // 112 degrees total
        
        dc.setPenWidth(arcWidth);
        
        // 1. Draw Segments (Background + Active fillable gauge)
        var segmentGap = 2; // 2-degree visual gap
        // (112 - 8) / 5 = 104 / 5 = 20.8 (Requires exact integers to prevent slight rounding gaps)
        // Let's use 108 deg span: (108 - 8) / 5 = 20 exactly.
        // 270 is perfectly bottom center. 270 - (108/2) = 216 -> 270 + 54 = 324
        startAngle = 216;
        endAngle = 324;
        totalArcSpan = endAngle - startAngle; // 108
        var segmentSpan = Math.floor((totalArcSpan - (4 * segmentGap)) / 5).toNumber(); // Exactly 20
        
        for (var i = 0; i < 5; i++) {
            var segStart = startAngle + (i * (segmentSpan + segmentGap));
            var color = 0x333333; // Default inactive dark grey
            
            if (i < horniness) {
                color = HORN_COLORS_ACTIVE[i] as Number; // Lit up tier color
            }
            
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, arcRadius, Graphics.ARC_COUNTER_CLOCKWISE, segStart, segStart + segmentSpan);
        }

        // Horniness label below the eggplant
        var hornLabelY = 285; // Snug right below ring and above the arc
        var hornLabels = ["COLD", "COOL", "WARM", "HOT", "FIRE"];
        if (horniness > 0 && horniness <= 5) {
            dc.setColor(HORN_COLORS_ACTIVE[horniness - 1] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hornLabelY, Graphics.FONT_XTINY, hornLabels[horniness - 1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // --- SECTION 4: Sync Indicator (Top Center) ---
        // IDLE=0, PROGRESS=1, SUCCESS=2, ERROR=3
        if (_syncStatus != 0) {
            var indY = 8; 
            var indR = 3;
            var indColor = Graphics.COLOR_BLACK; // Default idle = invisible
            
            if (_syncStatus == 1) { // Progress
                indColor = 0x00AAFF; // Blue
            } else if (_syncStatus == 2) { // Success
                indColor = 0x00FF00; // Green
            } else if (_syncStatus == 3) { // Error
                indColor = 0xFF0000; // Red
            }
            
            // Only draw if not idle
            if (indColor != Graphics.COLOR_BLACK) {
                dc.setColor(indColor, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx, indY, indR);
            }
        }
    }

    function onSyncStatus(status as Number) as Void {
        _syncStatus = status;
        WatchUi.requestUpdate();
        
        // Auto-hide success/error after 3s
        if (status == 2 || status == 3) {
            if (_animationTimer != null) {
                // Reuse the animation timer for this simple delay
                // Note: unique ID for timer would be better but simple reuse is safer than creating new ones
                _animationTimer.stop();
                _animationTimer.start(method(:resetSyncStatus), 3000, false);
            } else {
                 // Should not happen as init in onLayout, but just in case
                 _animationTimer = new Timer.Timer();
                 _animationTimer.start(method(:resetSyncStatus), 3000, false);
            }
        }
    }

    function resetSyncStatus() as Void {
        _syncStatus = 0;
        WatchUi.requestUpdate();
    }
    
    // Log interaction
    function logInteraction() as Void {
        _interactionCount += 1;
        DataManager.saveLog(DataManager.getTodayISO(), _interactionCount, _horniness);
        refreshData();
        startAnimation();
    }
    

    // Animation: Pop effect (Scale Up -> Scale Down)
    function startAnimation() as Void {
        if (_animationTimer != null) {
            _isAnimating = true;
            _animPhase = 0;
            _animationTimer.start(method(:animateFrame), 50, true); // 50ms frames
        }
    }
    
    function animateFrame() as Void {
        _animPhase++;
        
        if (_animPhase >= 3) {
            _isAnimating = false;
            _animationTimer.stop();
        }
        WatchUi.requestUpdate();
    }
    
    function stopAnimation() as Void {
        _isAnimating = false;
        if (_animationTimer != null) {
            _animationTimer.stop();
        }
        WatchUi.requestUpdate();
    }
    
    function isLoggedToday() as Boolean {
        return _interactionCount > 0;
    }
    
    function cycleHorniness() as Void {
        _horniness = (_horniness % 5) + 1;
        DataManager.saveLog(DataManager.getTodayISO(), _interactionCount, _horniness);
        WatchUi.requestUpdate();
    }

    function setHorniness(level as Number) as Void {
        if (level >= 1 && level <= 5) {
            _horniness = level;
            DataManager.saveLog(DataManager.getTodayISO(), _interactionCount, _horniness);
            WatchUi.requestUpdate();
        }
    }

    function getCircleCenterY() as Number {
        var height = System.getDeviceSettings().screenHeight;
        return (height / 2) + 5;
    }
    
    function getCircleRadius() as Number {
        return 54;
    }

    function getMinusButtonCenter() as Array<Number> {
        var cx = System.getDeviceSettings().screenWidth / 2;
        var cy = (System.getDeviceSettings().screenHeight / 2) + 5;
        return [cx - 36 - 40, cy] as Array<Number>;
    }

    // --- Navigation methods ---
    function getSelectedYear() as Number { return _selectedYear; }
    function getSelectedMonth() as Number { return _selectedMonth; }

    function isViewingCurrentMonth() as Boolean {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        return _selectedYear == info.year && _selectedMonth == info.month;
    }

    function nextMonth() as Void {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var newMonth = _selectedMonth + 1;
        var newYear = _selectedYear;
        if (newMonth > 12) { newMonth = 1; newYear += 1; }
        if (newYear > info.year || (newYear == info.year && newMonth > info.month)) { return; }
        _selectedMonth = newMonth;
        _selectedYear = newYear;
        refreshData();
        WatchUi.requestUpdate();
    }

    function prevMonth() as Void {
        var newMonth = _selectedMonth - 1;
        var newYear = _selectedYear;
        if (newMonth < 1) { newMonth = 12; newYear -= 1; }
        if (newYear < 2020) { return; }
        _selectedMonth = newMonth;
        _selectedYear = newYear;
        refreshData();
        WatchUi.requestUpdate();
    }

    function nextYear() as Void {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        if (_selectedYear + 1 > info.year) { return; }
        _selectedYear += 1;
        if (_selectedYear == info.year && _selectedMonth > info.month) {
            _selectedMonth = info.month;
        }
        refreshData();
        WatchUi.requestUpdate();
    }

    function prevYear() as Void {
        if (_selectedYear - 1 < 2020) { return; }
        _selectedYear -= 1;
        refreshData();
        WatchUi.requestUpdate();
    }
}
