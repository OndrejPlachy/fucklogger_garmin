import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;
import Toybox.System;

// DataManager module handles all storage operations
// Storage format: Key = "YYYY-MM-DD", Value = [interactionCount, horninessLevel]
module DataManager {

    const KEY_GLOBAL_STATS = "GlobalStats";

    // Stats cache
    var _globalStats = null;

    // Month total cache (avoids 31 Storage reads per tap)
    var _monthTotalCache = null;
    var _monthTotalMonth = null;

    // Get today's date as ISO string (YYYY-MM-DD)
    function getTodayISO() as String {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [
            info.year.format("%04d"),
            info.month.format("%02d"),
            info.day.format("%02d")
        ]);
    }

    // Convert ISO date to display format (DD.MM.YYYY)
    function formatDateDisplay(isoDate as String) as String {
        // Parse "YYYY-MM-DD" -> "DD.MM.YYYY"
        if (isoDate.length() >= 10) {
            var year = isoDate.substring(0, 4);
            var month = isoDate.substring(5, 7);
            var day = isoDate.substring(8, 10);
            return Lang.format("$1$.$2$.$3$", [day, month, year]);
        }
        return isoDate;
    }

    // Helper to get/init stats
    function getGlobalStats() as Dictionary<String, Number> {
        if (_globalStats == null) {
            _globalStats = Storage.getValue(KEY_GLOBAL_STATS);
        }
        if (_globalStats == null) {
            _globalStats = {
                "totalCount" => 0,
                "daysWithInteraction" => 0, 
                "dailyHorninessSum" => 0
            };
        }
        return _globalStats as Dictionary<String, Number>;
    }

    // Helper to save stats
    function saveGlobalStats(stats as Dictionary<String, Number>) as Void {
        _globalStats = stats;
        Storage.setValue(KEY_GLOBAL_STATS, stats);
    }

    // Save a log entry for a specific date
    function saveLog(isoDate as String, interactionCount as Number, horninessLevel as Number) as Void {
        // Get previous value to update stats incrementally
        var oldData = getLog(isoDate);
        var oldCount = 0;
        var stats = getGlobalStats();

        // 1. Revert old stats contribution if exists
        if (oldData != null) {
            oldCount = oldData[0];
            var oldHorniness = oldData[1];
            
            stats["totalCount"] -= oldCount;
            
            if (oldCount > 0) {
                 stats["daysWithInteraction"] -= 1;
                 stats["dailyHorninessSum"] -= oldHorniness;
            }
        }

        // 2. Add new stats contribution
        stats["totalCount"] += interactionCount;
        if (interactionCount > 0) {
            stats["daysWithInteraction"] += 1;
            stats["dailyHorninessSum"] += horninessLevel;
        }

        // 3. Save stats and log
        saveGlobalStats(stats);
        
        var data = [interactionCount, horninessLevel] as Array<Number>;
        Storage.setValue(isoDate, data);

        // 4. Update month total cache incrementally
        //    Check if this date falls in the currently cached month
        if (_monthTotalCache != null && _monthTotalMonth != null && isoDate.length() >= 7) {
            var dateMonth = isoDate.substring(0, 7); // "YYYY-MM"
            if (dateMonth.equals(_monthTotalMonth)) {
                // Adjust cache by the delta
                _monthTotalCache = _monthTotalCache + (interactionCount - oldCount);
            }
        }
    }

    // Get log entry for a specific date, returns null if not found
    function getLog(isoDate as String) as Array<Number>? {
        var data = Storage.getValue(isoDate);
        if (data != null && data instanceof Array) {
            return data as Array<Number>;
        }
        return null;
    }

    // Get today's log or create default [0, 3]
    function getTodayLog() as Array<Number> {
        var today = getTodayISO();
        var log = getLog(today);
        if (log == null) {
            return [0, 3] as Array<Number>; // Default: No interaction, horniness 3
        }
        return log;
    }

    // Calculate sum of interactions for current month
    // Uses in-memory cache; only does 31 storage reads on first call per month
    function getMonthTotal() as Number {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        
        var yearStr = info.year.format("%04d");
        var monthStr = info.month.format("%02d");
        var currentMonth = yearStr + "-" + monthStr; // "YYYY-MM"

        // Return cached value if still the same month
        if (_monthTotalCache != null && _monthTotalMonth != null && currentMonth.equals(_monthTotalMonth)) {
            return _monthTotalCache;
        }

        // Cache miss — compute from storage (happens once per month/app launch)
        var total = 0;
        for (var d = 1; d <= 31; d++) {
            var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, d.format("%02d")]);
            var data = getLog(dateKey);
            if (data != null) {
                total += data[0];
            }
        }

        // Store in cache
        _monthTotalMonth = currentMonth;
        _monthTotalCache = total;
        return total;
    }

    // Calculate current streak (consecutive days with interaction)
    function getCurrentStreak() as Number {
        var streak = 0;
        var now = Time.now();
        
        // Check backwards from today (max 365 days)
        for (var i = 0; i < 365; i++) {
            var checkTime = now.subtract(new Time.Duration(i * Gregorian.SECONDS_PER_DAY));
            var info = Gregorian.info(checkTime, Time.FORMAT_SHORT);
            var dateKey = Lang.format("$1$-$2$-$3$", [
                info.year.format("%04d"),
                info.month.format("%02d"),
                info.day.format("%02d")
            ]);
            
            var log = getLog(dateKey);
            if (log != null && log.size() >= 1 && log[0] > 0) { // Only count if interactions > 0
                streak++;
            } else if (i == 0) {
                // If checking today and it's empty/0, don't count it, but don't break yet? 
                // Usually streak means "consecutive days ending yesterday/today".
                // If today has 0, streak is "streak so far" which might be 0 or from yesterday.
                // Simple logic: Stop at first gap.
                // If today is 0, then streak is 0?
                // Let's assume if today is 0, we check yesterday.
                // Wait, if I haven't logged *yet* today, streak shouldn't reset.
                // But simplified: Stop if count 0.
                if (log != null && log[0] == 0) {
                     // If it's today (i=0) and 0, maybe we check yesterday?
                     // But strictly, streak is consecutive days *with* interaction.
                     // If today 0, streak is 0.
                     break;
                }
                 else if (log == null) {
                     break; 
                 }
            } else {
                break;
            }
        }
        return streak;
    }

    // Calculate average horniness for days with interaction
    function getAverageHorniness() as Float {
        var stats = getGlobalStats();
        var days = stats["daysWithInteraction"];
        var sum = stats["dailyHorninessSum"];
        
        if (days != null && sum != null && days > 0) {
            return sum.toFloat() / days.toFloat();
        }
        return 0.0f;
    }

    // Get all-time total count
    function getTotalCount() as Number {
        var stats = getGlobalStats();
        var total = stats["totalCount"];
        if (total != null) {
            return total;
        }
        return 0;
    }
    // Get monthly history (newest first, up to 12 months)
    // Returns array of { "month" => "Feb 2026", "total" => 5, "avgHorn" => 3 }
    function getMonthlyHistory() as Array<Dictionary> {
        var result = [] as Array<Dictionary>;
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var curYear = info.year;
        var curMonth = info.month;

        // Scan back 12 months
        for (var m = 0; m < 12; m++) {
            var checkMonth = curMonth - m;
            var checkYear = curYear;

            // Handle year wrapping
            while (checkMonth <= 0) {
                checkMonth += 12;
                checkYear -= 1;
            }

            var yearStr = checkYear.format("%04d");
            var monthStr = checkMonth.format("%02d");
            var total = 0;
            var hornSum = 0;
            var hornDays = 0;

            // Sum all days in this month
            for (var d = 1; d <= 31; d++) {
                var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, d.format("%02d")]);
                var log = getLog(dateKey);
                if (log != null) {
                    total += log[0];
                    if (log[1] > 0) {
                        hornSum += log[1];
                        hornDays++;
                    }
                }
            }

            if (total > 0) {
                var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                var monthName = monthNames[checkMonth - 1];
                var label = monthName + " " + checkYear.toString();
                var avgHorn = (hornDays > 0) ? (hornSum / hornDays) : 0;

                result.add({
                    "month" => label,
                    "total" => total,
                    "avgHorn" => avgHorn
                } as Dictionary);
            }
        }

        return result;
    }
}
