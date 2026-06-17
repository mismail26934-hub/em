import 'package:flutter/material.dart';

import '../models/fleet_dashboard_data.dart';
import '../theme/app_orange.dart';
import '../widgets/fleet_panel_chart.dart';

/// Satu chart [FleetPanelChart] memakai seluruh area di bawah app bar.
class FleetPanelFullscreenPage extends StatelessWidget {
  const FleetPanelFullscreenPage({
    super.key,
    required this.data,
    required this.panelIndex,
  });

  final FleetDashboardData data;
  final int panelIndex;

  @override
  Widget build(BuildContext context) {
    final panel = data.panels[panelIndex];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppOrange.surface,
        foregroundColor: AppOrange.deepText,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Kembali',
        ),
        title: Text(
          panel.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox.expand(
            child: FleetPanelChart(
              panel: panel,
              periodLabels: data.periodLabels,
              targetFraction: data.targetFraction,
            ),
          ),
        ),
      ),
    );
  }
}
