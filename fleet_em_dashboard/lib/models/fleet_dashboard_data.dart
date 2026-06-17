class FleetPanel {
  const FleetPanel({
    required this.title,
    required this.seriesKey,
    required this.values,
  });

  final String title;
  final String seriesKey;
  final List<double> values;
}

class FleetDashboardData {
  const FleetDashboardData({
    required this.periodLabels,
    required this.panels,
    required this.targetFraction,
  });

  final List<String> periodLabels;
  final List<FleetPanel> panels;
  final double targetFraction;
}
