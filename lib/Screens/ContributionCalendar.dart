import 'dart:math';
import 'package:flutter/material.dart';
import 'package:leetcode_streak/Model/LeetcodeData.dart';

enum CalendarViewMode { rollingPastYear, calendarYear }

class ContributionCalendar extends StatelessWidget {
  final LeetCodeData data;

  // View mode
  final CalendarViewMode mode;

  // Visuals
  final double maxCellSizePx;
  final double cellPaddingPx;
  final double colSpacingPx;
  final double rowSpacingPx;
  final double monthGapPx;
  final double monthLabelHeight;
  final double horizontalPadding;
  final double verticalPadding;
  final double radius;

  // Rolling window settings (used when mode == rollingPastYear)
  final DateTime? endUtcOverride; // test hook
  final int daysBack; // default 365 (past one year)

  const ContributionCalendar({
    super.key,
    required this.data,
    this.mode = CalendarViewMode.rollingPastYear,
    this.maxCellSizePx = 10.0,
    this.cellPaddingPx = 0.1,
    this.colSpacingPx = 1.0,
    this.rowSpacingPx = 1.0,
    this.monthGapPx = 3.0,
    this.monthLabelHeight = 14.0,
    this.horizontalPadding = 0.0,
    this.verticalPadding = 4.0,
    this.endUtcOverride,
    this.daysBack = 365,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (data.submissionCalendar.isEmpty) {
      return const SizedBox.shrink();
    }

    // 1) Build the global date range
    late final DateTime rangeStartUtc;
    late final DateTime rangeEndUtc;

    if (mode == CalendarViewMode.rollingPastYear) {
      final end = (endUtcOverride ?? DateTime.now().toUtc());
      rangeEndUtc = DateTime.utc(end.year, end.month, end.day);
      // Include both endpoints -> 365 days total
      rangeStartUtc = rangeEndUtc.subtract(Duration(days: max(1, daysBack) - 1));
    } else {
      // Full calendar year based on data.year
      rangeStartUtc = DateTime.utc(data.year, 1, 1);
      rangeEndUtc = DateTime.utc(data.year, 12, 31);
    }

    // 2) Build month segments from start month to end month (inclusive)
    final segments = _buildMonthSegments(rangeStartUtc, rangeEndUtc);

    // Flatten all columns (weeks) across segments for layout
    final flattened = <_ColumnMeta>[];
    final segmentSpans = <_SegmentSpan>[]; // start..end indices for each segment in flattened

    int runningIndex = 0;
    for (final seg in segments) {
      final startIndex = runningIndex;
      for (final sunday in seg.weeks) {
        flattened.add(_ColumnMeta(
          sunday: sunday,
          segmentYear: seg.year,
          segmentMonth: seg.month,
        ));
        runningIndex++;
      }
      final endIndex = runningIndex - 1;
      segmentSpans.add(_SegmentSpan(
        year: seg.year,
        month: seg.month,
        startIndex: startIndex,
        endIndex: endIndex,
      ));
    }

    if (flattened.isEmpty) return const SizedBox.shrink();

    // Month gaps: insert BEFORE the first column of every segment except the first one
    final monthGapIndices = <int>{};
    for (int s = 1; s < segmentSpans.length; s++) {
      monthGapIndices.add(segmentSpans[s].startIndex);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        // 3) Compute cell size to exactly fit width (no overflow)
        final totalWeeks = flattened.length;
        final totalColSpacing = colSpacingPx * max(0, totalWeeks - 1);
        final totalMonthGaps = monthGapPx * monthGapIndices.length;

        final widthBudgetForColumns =
            maxW - 2 * horizontalPadding - totalColSpacing - totalMonthGaps;

        // columnWidth = cell + 2*cellPadding
        double cellSizeByWidth = (widthBudgetForColumns / totalWeeks) - 2 * cellPaddingPx;

        // Height constraint if provided
        double? cellSizeByHeight;
        if (maxH.isFinite) {
          final heightForGrid = maxH - 2 * verticalPadding - monthLabelHeight;
          final perRow = (heightForGrid - (7 - 1) * rowSpacingPx) / 7.0;
          cellSizeByHeight = perRow - 2 * cellPaddingPx;
        }

        // Choose smaller to avoid overflow
        double cellSizePx = cellSizeByWidth;
        if (cellSizeByHeight != null) cellSizePx = min(cellSizePx, cellSizeByHeight);
        cellSizePx = min(cellSizePx, maxCellSizePx);
        cellSizePx = max(cellSizePx, 1.0);

        final columnWidth = cellSizePx + 2 * cellPaddingPx;

        // Heights
        final gridHeight = 7 * (cellSizePx + 2 * cellPaddingPx) + (7 - 1) * rowSpacingPx;
        final containerHeight = 2 * verticalPadding + gridHeight + monthLabelHeight;

        // Precompute left positions for each flattened column (labels use same math)
        final columnLefts = _computeColumnLefts(
          totalColumns: flattened.length,
          monthGapIndices: monthGapIndices,
          columnWidth: columnWidth,
          colSpacingPx: colSpacingPx,
          monthGapPx: monthGapPx,
          leftPadding: horizontalPadding,
        );

        // In rolling mode, you usually don’t want the first and last month label to be identical.
        final hideTrailingDuplicate =
            mode == CalendarViewMode.rollingPastYear &&
            segmentSpans.length >= 2 &&
            segmentSpans.first.month == segmentSpans.last.month;

        return SizedBox(
          height: containerHeight,
          child: Stack(
            children: [
              // Grid
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: gridHeight + 2 * verticalPadding,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(0, 0, 0, 0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: _Grid(
                      radius: radius,
                      columns: flattened,
                      rangeStart: rangeStartUtc,
                      rangeEnd: rangeEndUtc,
                      data: data,
                      cellSizePx: cellSizePx,
                      cellPaddingPx: cellPaddingPx,
                      colSpacingPx: colSpacingPx,
                      rowSpacingPx: rowSpacingPx,
                      monthGapPx: monthGapPx,
                      monthGapIndices: monthGapIndices,
                    ),
                  ),
                ),
              ),

              // Month labels centered per segment
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: monthLabelHeight,
                child: _MonthLabels(
                  spans: hideTrailingDuplicate
                      ? segmentSpans.sublist(0, segmentSpans.length - 1)
                      : segmentSpans,
                  columnLefts: columnLefts,
                  columnWidth: columnWidth,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build month segments (each has its own list of week-start Sundays that cover that month)
  static List<_MonthSegment> _buildMonthSegments(DateTime rangeStart, DateTime rangeEnd) {
    final segments = <_MonthSegment>[];

    // First day of start month, first day after end month
    DateTime m = DateTime.utc(rangeStart.year, rangeStart.month, 1);
    final afterEndMonth = (rangeEnd.month == 12)
        ? DateTime.utc(rangeEnd.year + 1, 1, 1)
        : DateTime.utc(rangeEnd.year, rangeEnd.month + 1, 1);

    while (m.isBefore(afterEndMonth)) {
      final year = m.year;
      final month = m.month;

      final monthStart = DateTime.utc(year, month, 1);
      final monthEnd = DateTime.utc(
        (month == 12) ? year + 1 : year,
        (month == 12) ? 1 : month + 1,
        0, // last day of month
      );

      // Cover the entire month by full weeks (Sun..Sat)
      final startSunday = _sundayOnOrBefore(monthStart);
      final endSaturday = _saturdayOnOrAfter(monthEnd);

      final weeks = <DateTime>[];
      for (DateTime d = startSunday; !d.isAfter(endSaturday); d = d.add(const Duration(days: 7))) {
        weeks.add(d);
      }

      segments.add(_MonthSegment(year: year, month: month, weeks: weeks));

      // next month
      m = DateTime.utc(
        (month == 12) ? year + 1 : year,
        (month == 12) ? 1 : month + 1,
        1,
      );
    }

    return segments;
  }

  // Left positions for each flattened column
  static List<double> _computeColumnLefts({
    required int totalColumns,
    required Set<int> monthGapIndices,
    required double columnWidth,
    required double colSpacingPx,
    required double monthGapPx,
    required double leftPadding,
  }) {
    final lefts = List<double>.filled(totalColumns, 0);
    double x = leftPadding;
    for (int i = 0; i < totalColumns; i++) {
      if (monthGapIndices.contains(i)) x += monthGapPx; // extra gap before this column
      lefts[i] = x;
      x += columnWidth;
      if (i != totalColumns - 1) x += colSpacingPx;
    }
    return lefts;
  }

  static DateTime _sundayOnOrBefore(DateTime d) {
    final base = DateTime.utc(d.year, d.month, d.day);
    final diff = base.weekday % 7; // Mon=1..Sun=7 -> Sun=0
    return base.subtract(Duration(days: diff));
  }

  static DateTime _saturdayOnOrAfter(DateTime d) {
    final base = DateTime.utc(d.year, d.month, d.day);
    final diff = 6 - (base.weekday % 7);
    return base.add(Duration(days: diff));
  }
}

class _Grid extends StatelessWidget {
  final List<_ColumnMeta> columns; // flattened across all segments
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final LeetCodeData data;
  final double radius;

  final double cellSizePx;
  final double cellPaddingPx;
  final double colSpacingPx;
  final double rowSpacingPx;
  final double monthGapPx;
  final Set<int> monthGapIndices;

  const _Grid({
    required this.radius,
    required this.columns,
    required this.rangeStart,
    required this.rangeEnd,
    required this.data,
    required this.cellSizePx,
    required this.cellPaddingPx,
    required this.colSpacingPx,
    required this.rowSpacingPx,
    required this.monthGapPx,
    required this.monthGapIndices,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (int i = 0; i < columns.length; i++) {
      if (monthGapIndices.contains(i)) {
        children.add(SizedBox(width: monthGapPx));
      }

      final col = columns[i];
      children.add(
        _WeekColumnMonthBounded(
          radius: radius,
          weekSunday: col.sunday,
          segmentYear: col.segmentYear,
          segmentMonth: col.segmentMonth,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          data: data,
          cellSizePx: cellSizePx,
          cellPaddingPx: cellPaddingPx,
          rowSpacingPx: rowSpacingPx,
        ),
      );

      if (i != columns.length - 1) {
        children.add(SizedBox(width: colSpacingPx));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _WeekColumnMonthBounded extends StatelessWidget {
  final DateTime weekSunday;
  final int segmentYear;
  final int segmentMonth;
  final double radius; 
  final DateTime rangeStart;
  final DateTime rangeEnd;

  final LeetCodeData data;

  final double cellSizePx;
  final double cellPaddingPx;
  final double rowSpacingPx;

  const _WeekColumnMonthBounded({
    required this.weekSunday,
    required this.segmentYear,
    required this.segmentMonth,
    required this.rangeStart,
    required this.rangeEnd,
    required this.data,
    required this.radius,
    required this.cellSizePx,
    required this.cellPaddingPx,
    required this.rowSpacingPx,
  });

  @override
  Widget build(BuildContext context) {
    final dayCells = <Widget>[];

    for (int d = 0; d < 7; d++) {
      final date = weekSunday.add(Duration(days: d));
      final inRange = !date.isBefore(rangeStart) && !date.isAfter(rangeEnd);
      final inMonth = (date.year == segmentYear && date.month == segmentMonth);

      final showSquare = inRange && inMonth;

      Widget cell;
      if (showSquare) {
        final ts = DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/ 1000;
        final contributions = data.submissionCalendar['$ts'] ?? 0;

        cell = Container(
          width: cellSizePx,
          height: cellSizePx,
          decoration: BoxDecoration(
            color: _bucketColor(contributions),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      } else {
        // Absolutely blank (no background, no zero color), matching LeetCode look
        cell = SizedBox(width: cellSizePx, height: cellSizePx);
      }

      dayCells.add(Padding(
        padding: EdgeInsets.all(cellPaddingPx),
        child: cell,
      ));

      if (d != 6) dayCells.add(SizedBox(height: rowSpacingPx));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: dayCells,
    );
  }

  Color _bucketColor(int count) {
    if (count <= 0) return Colors.grey.shade900; // zero-level box
    if (count == 1) return const Color(0xFF0E4429);
    if (count <= 3) return const Color(0xFF006D32);
    if (count <= 6) return const Color(0xFF26A641);
    return const Color(0xFF39D353);
  }
}

class _MonthLabels extends StatelessWidget {
  final List<_SegmentSpan> spans;
  final List<double> columnLefts;
  final double columnWidth;

  const _MonthLabels({
    required this.spans,
    required this.columnLefts,
    required this.columnWidth,
  });

  @override
  Widget build(BuildContext context) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final labels = <Widget>[];
    for (final s in spans) {
      final left = columnLefts[s.startIndex];
      final right = columnLefts[s.endIndex] + columnWidth;
      final width = right - left;

      labels.add(Positioned(
        left: left,
        width: width,
        child: Center(
          child: Text(
            months[s.month - 1],
            style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Stack(children: labels),
    );
  }
}

class _MonthSegment {
  final int year;
  final int month;
  final List<DateTime> weeks; // Sundays covering this month
  _MonthSegment({
    required this.year,
    required this.month,
    required this.weeks,
  });
}

class _ColumnMeta {
  final DateTime sunday;
  final int segmentYear;
  final int segmentMonth;
  _ColumnMeta({
    required this.sunday,
    required this.segmentYear,
    required this.segmentMonth,
  });
}

class _SegmentSpan {
  final int year;
  final int month;
  final int startIndex;
  final int endIndex;
  _SegmentSpan({
    required this.year,
    required this.month,
    required this.startIndex,
    required this.endIndex,
  });
}