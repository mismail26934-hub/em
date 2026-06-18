class JackKnifePoint {
  const JackKnifePoint({
    required this.component,
    required this.duration,
    required this.events,
    this.percentImp,
  });

  final String component;
  final double duration;
  final double events;
  final double? percentImp;
}

class JackKnifePanel {
  const JackKnifePanel({
    required this.title,
    required this.points,
    required this.thresholdX,
    required this.thresholdY,
    this.xMax = 120,
    this.yMax = 300,
    this.xLineYMin = 0,
    double? xLineYMax,
    this.yLineXMin = 0,
    double? yLineXMax,
  })  : xLineYMax = xLineYMax ?? yMax,
        yLineXMax = yLineXMax ?? xMax;

  final String title;
  final List<JackKnifePoint> points;
  /// Vertical reference line (Events axis) from [Sumbu X] table.
  final double thresholdX;
  /// Horizontal reference line (Duration axis) from [Sumbu Y] table.
  final double thresholdY;
  final double xMax;
  final double yMax;
  /// Vertical segment: x = [thresholdX], y from [xLineYMin] to [xLineYMax].
  final double xLineYMin;
  final double xLineYMax;
  /// Horizontal segment: y = [thresholdY], x from [yLineXMin] to [yLineXMax].
  final double yLineXMin;
  final double yLineXMax;
}

class JackKnifeDashboardData {
  const JackKnifeDashboardData({required this.panels});

  final List<JackKnifePanel> panels;
}

/// How many components to plot on the Jack Knife scatter chart.
const int jackKnifeChartTopN = 10;

/// Original indices sorted by duration descending.
List<int> jackKnifeIndicesByDuration(List<JackKnifePoint> points) {
  final indices = List.generate(points.length, (i) => i);
  indices.sort((a, b) => points[b].duration.compareTo(points[a].duration));
  return indices;
}

/// Top [jackKnifeChartTopN] indices by duration for chart markers.
List<int> jackKnifeChartPointIndices(List<JackKnifePoint> points) {
  return jackKnifeIndicesByDuration(points).take(jackKnifeChartTopN).toList();
}

class JackKnifeRankedRow {
  const JackKnifeRankedRow({
    required this.rank,
    required this.originalIndex,
    required this.point,
  });

  final int rank;
  final int originalIndex;
  final JackKnifePoint point;
}

List<JackKnifeRankedRow> jackKnifeRankedRows(List<JackKnifePoint> points) {
  final sorted = jackKnifeIndicesByDuration(points);
  return [
    for (var r = 0; r < sorted.length; r++)
      JackKnifeRankedRow(
        rank: r + 1,
        originalIndex: sorted[r],
        point: points[sorted[r]],
      ),
  ];
}
