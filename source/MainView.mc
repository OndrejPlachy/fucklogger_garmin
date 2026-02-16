import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.Math;

// Main View - The "Action" Screen
// Layout:
//   Top:    "MONTH TOTAL" label + count
//   Center: Eggplant icon in circle (flashes pink on tap)
//   Bottom: Curved horniness arc (cold blue → hot red)
class MainView extends WatchUi.View {
    
    private var _eggplantBitmap as BitmapResource?;
    private var _monthTotal as Number = 0;
    private var _horniness as Number = 3;
    private var _interactionCount as Number = 0;

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
        _monthTotal = DataManager.getMonthTotal();
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
        
        var monthCount = _monthTotal;
        var horniness = _horniness;

        // --- SECTION 1: TOP — "MONTH TOTAL" + number ---
        // Using distinct fonts for modern look
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT); // Light gray
        dc.drawText(cx, height * 0.13, Graphics.FONT_XTINY, "MONTH TOTAL", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // Large, clean number
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.24, Graphics.FONT_NUMBER_MEDIUM, monthCount.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

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
        var labelY = circleCY + baseRadius + 22;
        var hornLabels = ["COLD", "COOL", "WARM", "HOT", "FIRE"];
        if (horniness > 0 && horniness <= 5) {
            dc.setColor(HORN_COLORS_ACTIVE[horniness - 1] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, labelY, Graphics.FONT_SYSTEM_XTINY, hornLabels[horniness - 1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
        }
        DataManager.saveLog(DataManager.getTodayISO(), _interactionCount, _horniness);
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
}
