import Toybox.Graphics;
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

    // Navigation state
    private var _selectedYear as Number = 2026;
    private var _selectedMonth as Number = 1;

    // Month names for display (abbreviated to fit)
    private const MONTH_NAMES = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                  "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    // Color constants for panel
    private const YEAR_COLOR = 0x6EC6FF;   // Light blue
    private const MONTH_COLOR = 0xFF69B4;  // Hot pink

    // Animation state
    private var _animationTimer as Timer.Timer?;
    private var _isAnimating as Boolean = false;
    private var _animScale as Float = 1.0; // Scale factor for "pop" effect
    private var _animPhase as Number = 0;
    
    // Colors
    private const HOT_PINK = 0xFF69B4;
    private const ARC_TRACK_COLOR = 0x222222; // Very dark gray for empty track

    // Horniness arc colors: cold blue → hot red (5 levels)
    // 1=cold, 2=cool, 3=warm, 4=hot, 5=fire
    private const HORN_COLORS_ACTIVE = [
        0x6EC6FF,  // light blue (cold)
        0x4DD0E1,  // cyan
        0xFFB74D,  // warm orange
        0xFF7043,  // hot coral
        0xFF4081   // hot pink/red
    ];
    // unused HORN_COLOR_OFF removed
    
    function initialize() {
        View.initialize();
        // Initialize to current date
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        _selectedYear = info.year;
        _selectedMonth = info.month;
    }

    function onLayout(dc as Dc) as Void {
        _eggplantBitmap = WatchUi.loadResource(Rez.Drawables.EggplantIcon) as BitmapResource;
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

        // --- SECTION 1: TOP — Split panel [Year | Month] with arrows ---
        var labelY = height * 15 / 100;      // ~59px - labels row
        var numberY = height * 24 / 100;     // ~94px - numbers row
        var leftColX = width * 37 / 100;     // ~144px - year column center
        var rightColX = width * 63 / 100;    // ~246px - month column center
        var arrowLX = width * 19 / 100;      // ~74px - left arrows X
        var arrowRX = width * 81 / 100;      // ~316px - right arrows X

        // Convex curved background panel (follows watch bezel)
        var panelArcRadius = width / 2 - 4;  // Just inside the bezel
        dc.setPenWidth(height * 18 / 100);   // Thick arc as background fill
        // Left half - subtle dark blue
        dc.setColor(0x0D1B2A, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, panelArcRadius, Graphics.ARC_CLOCKWISE, 130, 90);
        // Right half - subtle dark pink
        dc.setColor(0x2A0D1B, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, panelArcRadius, Graphics.ARC_CLOCKWISE, 90, 50);

        // Vertical divider line
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx, height * 11 / 100, cx, height * 28 / 100);

        // Year label and number (left column - blue)
        dc.setColor(YEAR_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftColX, labelY, Graphics.FONT_XTINY, _selectedYear.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftColX, numberY, Graphics.FONT_MEDIUM, yearCount.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Month label and number (right column - pink)
        dc.setColor(MONTH_COLOR, Graphics.COLOR_TRANSPARENT);
        var monthLabel = MONTH_NAMES[_selectedMonth - 1];
        dc.drawText(rightColX, labelY, Graphics.FONT_XTINY, monthLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightColX, numberY, Graphics.FONT_MEDIUM, monthCount.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Year arrows (left side - blue triangles)
        dc.setColor(YEAR_COLOR, Graphics.COLOR_TRANSPARENT);
        // Up arrow
        dc.fillPolygon([[arrowLX, labelY - 8], [arrowLX - 7, labelY + 2], [arrowLX + 7, labelY + 2]]);
        // Down arrow
        dc.fillPolygon([[arrowLX, numberY + 8], [arrowLX - 7, numberY - 2], [arrowLX + 7, numberY - 2]]);

        // Month arrows (right side - pink triangles)
        dc.setColor(MONTH_COLOR, Graphics.COLOR_TRANSPARENT);
        // Up arrow
        dc.fillPolygon([[arrowRX, labelY - 8], [arrowRX - 7, labelY + 2], [arrowRX + 7, labelY + 2]]);
        // Down arrow
        dc.fillPolygon([[arrowRX, numberY + 8], [arrowRX - 7, numberY - 2], [arrowRX + 7, numberY - 2]]);

        // --- SECTION 2: CENTER — Eggplant button ---
        // Center circle logic with scale animation
        var baseRadius = 50;
        var currentRadius = baseRadius * _animScale;
        var circleCY = cy + 5;

        // Draw animated circle
        if (_isAnimating && _animPhase < 2) {
            // Flash phase
            dc.setColor(HOT_PINK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, circleCY, currentRadius);
        } else {
            // Normal phase
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawCircle(cx, circleCY, currentRadius);
        }

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

        // --- Minus button: small circle with '−' to the left ---
        var minusBtnX = cx - baseRadius - 40; // Moved slightly further left
        var minusBtnY = circleCY;
        var minusBtnR = 14;
        
        // Subtle background
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(minusBtnX, minusBtnY, minusBtnR);
        
        // Red accent for "remove" action
        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT); 
        dc.setPenWidth(2);
        dc.drawLine(minusBtnX - 6, minusBtnY, minusBtnX + 6, minusBtnY); // Minus sign

        // --- SECTION 3: BOTTOM — Horniness arc slider ---
        var arcRadius = (width / 2) - 18;
        var arcWidth = 14;
        var totalArcSpan = 100;
        // unused maxDegrees removed
        var startAngle = 220;
        
        dc.setPenWidth(arcWidth);
        
        // 1. Draw "Track" (background)
        dc.setColor(ARC_TRACK_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, arcRadius, Graphics.ARC_COUNTER_CLOCKWISE, startAngle, startAngle + totalArcSpan);

        // 2. Draw Active Segments
        var segmentGap = 3;
        var segmentSpan = (totalArcSpan - (4 * segmentGap)) / 5;
        
        for (var i = 0; i < 5; i++) {
            if (i < horniness) {
                var segStart = startAngle + (i * (segmentSpan + segmentGap));
                var color = HORN_COLORS_ACTIVE[i] as Number;
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, arcRadius, Graphics.ARC_COUNTER_CLOCKWISE, segStart, segStart + segmentSpan);
            }
        }

        // Horniness label below the eggplant
        var hornLabelY = circleCY + baseRadius + 22;
        var hornLabels = ["COLD", "COOL", "WARM", "HOT", "FIRE"];
        if (horniness > 0 && horniness <= 5) {
            dc.setColor(HORN_COLORS_ACTIVE[horniness - 1] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hornLabelY, Graphics.FONT_SYSTEM_XTINY, hornLabels[horniness - 1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
    
    // Log interaction
    function logInteraction() as Void {
        _interactionCount += 1;
        DataManager.saveLog(DataManager.getTodayISO(), _interactionCount, _horniness);
        refreshData();
        startAnimation();
    }
    
    // Undo interaction
    function undoInteraction() as Void {
        if (_interactionCount > 0) {
            _interactionCount -= 1;
            // Decrement distribution bucket
            var todayISO = DataManager.getTodayISO();
            var data = DataManager.getLog(todayISO);
            var dist = DataManager.getDistribution(data);
            for (var h = 4; h >= 0; h--) {
                if (dist[h] > 0) {
                    dist[h] -= 1;
                    break;
                }
            }
            var newData = [_interactionCount, _horniness, dist[0], dist[1], dist[2], dist[3], dist[4]] as Array<Number>;
            // Use saveLog to handle stats (it will preserve the dist we're passing indirectly)
            DataManager.saveLog(todayISO, _interactionCount, _horniness);
            // Now overwrite with correct distribution
            Application.Storage.setValue(todayISO, newData);
        }
        refreshData();
    }
    
    // Animation: Pop effect (Scale Up -> Scale Down)
    function startAnimation() as Void {
        if (_animationTimer != null) {
            _isAnimating = true;
            _animPhase = 0;
            _animScale = 1.0;
            _animationTimer.start(method(:animateFrame), 50, true); // 50ms frames
        }
    }
    
    function animateFrame() as Void {
        _animPhase++;
        
        if (_animPhase == 1) {
            _animScale = 1.15; // Pop up
        } else if (_animPhase == 2) {
            _animScale = 1.05; // Scaling down
        } else if (_animPhase >= 3) {
            _animScale = 1.0; // Back to normal
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
        return 50;
    }

    function getMinusButtonCenter() as Array<Number> {
        var cx = System.getDeviceSettings().screenWidth / 2;
        var cy = (System.getDeviceSettings().screenHeight / 2) + 5;
        return [cx - 50 - 40, cy] as Array<Number>;
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
