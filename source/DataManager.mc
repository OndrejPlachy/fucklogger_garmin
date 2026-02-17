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

    // Get horniness distribution from a log entry (handles migration)
    // Returns [h1count, h2count, h3count, h4count, h5count]
    function getDistribution(data as Array<Number>?) as Array<Number> {
        if (data != null && data.size() >= 7) {
            return [data[2], data[3], data[4], data[5], data[6]] as Array<Number>;
        }
        // Migrate old 2-element format: assign all count to stored horniness
        if (data != null && data.size() >= 2 && data[0] > 0) {
            var dist = [0, 0, 0, 0, 0] as Array<Number>;
            var h = data[1];
            if (h >= 1 && h <= 5) { dist[h - 1] = data[0]; }
            return dist;
        }
        return [0, 0, 0, 0, 0] as Array<Number>;
    }

    // Save a log entry — preserves existing horniness distribution
    function saveLog(isoDate as String, interactionCount as Number, horninessLevel as Number) as Void {
        var oldData = getLog(isoDate);
        var oldCount = 0;
        var stats = getGlobalStats();

        // Preserve existing distribution
        var dist = getDistribution(oldData);

        // 1. Revert old stats
        if (oldData != null) {
            oldCount = oldData[0];
            var oldHorniness = oldData[1];
            stats["totalCount"] -= oldCount;
            if (oldCount > 0) {
                 stats["daysWithInteraction"] -= 1;
                 stats["dailyHorninessSum"] -= oldHorniness;
            }
        }

        // 2. Add new stats
        stats["totalCount"] += interactionCount;
        if (interactionCount > 0) {
            stats["daysWithInteraction"] += 1;
            stats["dailyHorninessSum"] += horninessLevel;
        }

        // 3. Save stats and 7-element log
        saveGlobalStats(stats);
        var data = [interactionCount, horninessLevel, dist[0], dist[1], dist[2], dist[3], dist[4]] as Array<Number>;
        Storage.setValue(isoDate, data);

        // 4. Update month total cache
        if (_monthTotalCache != null && _monthTotalMonth != null && isoDate.length() >= 7) {
            var dateMonth = isoDate.substring(0, 7);
            if (dateMonth.equals(_monthTotalMonth)) {
                _monthTotalCache = _monthTotalCache + (interactionCount - oldCount);
            }
        }
    }

    // Log one intercourse, tracking horniness level at this moment
    function incrementDay(isoDate as String, horniness as Number) as Void {
        var oldData = getLog(isoDate);
        var oldCount = 0;
        var dist = getDistribution(oldData);
        var stats = getGlobalStats();

        if (oldData != null) {
            oldCount = oldData[0];
            var oldHorniness = oldData[1];
            stats["totalCount"] -= oldCount;
            if (oldCount > 0) {
                stats["daysWithInteraction"] -= 1;
                stats["dailyHorninessSum"] -= oldHorniness;
            }
        }

        var newCount = oldCount + 1;
        if (horniness >= 1 && horniness <= 5) {
            dist[horniness - 1] += 1;
        }

        stats["totalCount"] += newCount;
        stats["daysWithInteraction"] += 1;
        stats["dailyHorninessSum"] += horniness;

        saveGlobalStats(stats);
        var data = [newCount, horniness, dist[0], dist[1], dist[2], dist[3], dist[4]] as Array<Number>;
        Storage.setValue(isoDate, data);

        if (_monthTotalCache != null && _monthTotalMonth != null && isoDate.length() >= 7) {
            var dateMonth = isoDate.substring(0, 7);
            if (dateMonth.equals(_monthTotalMonth)) {
                _monthTotalCache = _monthTotalCache + 1;
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
    // Calculate sum of interactions for a specific year
    function getYearTotalFor(year as Number) as Number {
        var yearStr = year.format("%04d");
        var total = 0;

        for (var m = 1; m <= 12; m++) {
            var monthStr = m.format("%02d");
            for (var d = 1; d <= 31; d++) {
                var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, d.format("%02d")]);
                var data = getLog(dateKey);
                if (data != null) {
                    total += data[0];
                }
            }
        }
        return total;
    }

    // Calculate sum of interactions for a specific month
    function getMonthTotalFor(year as Number, month as Number) as Number {
        var yearStr = year.format("%04d");
        var monthStr = month.format("%02d");
        var total = 0;

        for (var d = 1; d <= 31; d++) {
            var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, d.format("%02d")]);
            var data = getLog(dateKey);
            if (data != null) {
                total += data[0];
            }
        }
        return total;
    }

    // Decrement the most recent day in a specific month that has count > 0
    // Also decrements the horniness distribution bucket
    function decrementInMonth(year as Number, month as Number) as Boolean {
        var yearStr = year.format("%04d");
        var monthStr = month.format("%02d");

        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var maxDay = 31;
        if (year == info.year && month == info.month) {
            maxDay = info.day;
        }

        for (var d = maxDay; d >= 1; d--) {
            var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, d.format("%02d")]);
            var data = getLog(dateKey);
            if (data != null && data[0] > 0) {
                var newCount = data[0] - 1;
                var dist = getDistribution(data);
                // Decrement from a bucket (prefer highest populated)
                for (var h = 4; h >= 0; h--) {
                    if (dist[h] > 0) {
                        dist[h] -= 1;
                        break;
                    }
                }
                var newData = [newCount, data[1], dist[0], dist[1], dist[2], dist[3], dist[4]] as Array<Number>;
                // Update stats
                var stats = getGlobalStats();
                stats["totalCount"] -= data[0];
                if (data[0] > 0) { stats["daysWithInteraction"] -= 1; stats["dailyHorninessSum"] -= data[1]; }
                stats["totalCount"] += newCount;
                if (newCount > 0) { stats["daysWithInteraction"] += 1; stats["dailyHorninessSum"] += data[1]; }
                saveGlobalStats(stats);
                Storage.setValue(dateKey, newData);
                // Update cache
                if (_monthTotalCache != null && _monthTotalMonth != null) {
                    var dm = dateKey.substring(0, 7);
                    if (dm.equals(_monthTotalMonth)) { _monthTotalCache = _monthTotalCache - 1; }
                }
                return true;
            }
        }
        return false;
    }

    // Add interaction to day 1 of a specific month (uses incrementDay for tracking)
    function addToMonth(year as Number, month as Number, horniness as Number) as Void {
        var yearStr = year.format("%04d");
        var monthStr = month.format("%02d");
        var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, "01"]);
        incrementDay(dateKey, horniness);
    }

    // Get daily breakdown for a specific month
    // Returns array of dictionaries: { "day" => 1, "dow" => "MON", "count" => 2, "horn" => 3 }
    // Only includes days with data (count > 0)
    function getDailyBreakdown(year as Number, month as Number) as Array<Dictionary> {
        var yearStr = year.format("%04d");
        var monthStr = month.format("%02d");
        var result = [] as Array<Dictionary>;
        var dowNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

        for (var d = 1; d <= 31; d++) {
            var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, d.format("%02d")]);
            var data = getLog(dateKey);
            if (data != null && data[0] > 0) {
                // Calculate day of week using Gregorian
                var options = {
                    :year => year,
                    :month => month,
                    :day => d,
                    :hour => 12
                };
                var moment = Gregorian.moment(options);
                var info = Gregorian.info(moment, Time.FORMAT_SHORT);
                var dow = info.day_of_week; // 1=Sunday, 7=Saturday
                var dowStr = dowNames[dow - 1];

                result.add({
                    "day" => d,
                    "dow" => dowStr,
                    "count" => data[0],
                    "horn" => data[1]
                } as Dictionary);
            }
        }
        return result;
    }

    // Get horniness distribution for a specific month
    // Returns array of 5 Numbers: count of intercourses at each horniness level [1..5]
    // Get horniness distribution for a month (reads from per-intercourse tracking)
    function getHorninessCounts(year as Number, month as Number) as Array<Number> {
        var yearStr = year.format("%04d");
        var monthStr = month.format("%02d");
        var counts = [0, 0, 0, 0, 0] as Array<Number>;

        for (var d = 1; d <= 31; d++) {
            var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, d.format("%02d")]);
            var data = getLog(dateKey);
            if (data != null && data[0] > 0) {
                var dist = getDistribution(data);
                for (var h = 0; h < 5; h++) {
                    counts[h] += dist[h];
                }
            }
        }
        return counts;
    }

    // Get horniness distribution for an entire year
    function getYearHorninessCounts(year as Number) as Array<Number> {
        var counts = [0, 0, 0, 0, 0] as Array<Number>;
        for (var m = 1; m <= 12; m++) {
            var mc = getHorninessCounts(year, m);
            for (var h = 0; h < 5; h++) {
                counts[h] += mc[h];
            }
        }
        return counts;
    }

    // Get day-of-week distribution for a month
    function getDowCounts(year as Number, month as Number) as Array<Number> {
        var yearStr = year.format("%04d");
        var monthStr = month.format("%02d");
        var counts = [0, 0, 0, 0, 0, 0, 0] as Array<Number>; // SUN-SAT

        for (var d = 1; d <= 31; d++) {
            var dateKey = Lang.format("$1$-$2$-$3$", [yearStr, monthStr, d.format("%02d")]);
            var data = getLog(dateKey);
            if (data != null && data[0] > 0) {
                var options = { :year => year, :month => month, :day => d, :hour => 12 };
                var moment = Gregorian.moment(options);
                var dinfo = Gregorian.info(moment, Time.FORMAT_SHORT);
                var dow = dinfo.day_of_week; // 1=Sun, 7=Sat
                counts[dow - 1] += data[0];
            }
        }
        return counts;
    }

    // Get day-of-week distribution for an entire year
    function getYearDowCounts(year as Number) as Array<Number> {
        var counts = [0, 0, 0, 0, 0, 0, 0] as Array<Number>;
        for (var m = 1; m <= 12; m++) {
            var mc = getDowCounts(year, m);
            for (var i = 0; i < 7; i++) {
                counts[i] += mc[i];
            }
        }
        return counts;
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
