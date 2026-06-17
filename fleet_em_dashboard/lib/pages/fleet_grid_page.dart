import 'package:flutter/material.dart';

import '../models/fleet_dashboard_data.dart';
import '../theme/app_orange.dart';
import '../widgets/fleet_panel_chart.dart';
import 'fleet_panel_fullscreen_page.dart';

/// Full route: all panel cards in a scrollable grid (no carousel).
class FleetGridPage extends StatefulWidget {
  const FleetGridPage({
    super.key,
    required this.initialData,
    required this.getLatestData,
    required this.onRefresh,
    required this.onEditExcelUrl,
    this.onPickExcelFile,
    this.fileLabel,
    this.isLoading = false,
  });

  final FleetDashboardData initialData;
  final FleetDashboardData? Function() getLatestData;
  final Future<void> Function() onRefresh;
  /// Opens URL editor / reload from URL (same as dashboard).
  final Future<void> Function() onEditExcelUrl;
  /// Pilih file .xlsx; di web diunggah ke server PHP, di desktop disimpan lokal.
  final Future<void> Function()? onPickExcelFile;
  final String? fileLabel;
  final bool isLoading;

  @override
  State<FleetGridPage> createState() => _FleetGridPageState();
}

class _FleetGridPageState extends State<FleetGridPage> {
  late FleetDashboardData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
  }

  Future<void> _handleRefresh() async {
    await widget.onRefresh();
    if (!mounted) return;
    final latest = widget.getLatestData();
    if (latest != null) setState(() => _data = latest);
  }

  Future<void> _handleEditUrl() async {
    await widget.onEditExcelUrl();
    if (!mounted) return;
    final latest = widget.getLatestData();
    if (latest != null) setState(() => _data = latest);
  }

  Future<void> _handlePickFile() async {
    final pick = widget.onPickExcelFile;
    if (pick == null) return;
    await pick();
    if (!mounted) return;
    final latest = widget.getLatestData();
    if (latest != null) setState(() => _data = latest);
  }

  void _openPanelFullscreen(BuildContext context, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FleetPanelFullscreenPage(
          data: _data,
          panelIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              elevation: 0.5,
              color: AppOrange.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
                    ),
                    Text(
                      'Semua chart',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppOrange.deepText,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Segarkan data',
                      onPressed: widget.isLoading ? null : _handleRefresh,
                      icon: widget.isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppOrange.primary,
                              ),
                            )
                          : Icon(Icons.refresh, color: Colors.grey.shade800),
                    ),
                    if (widget.onPickExcelFile != null)
                      IconButton(
                        tooltip: 'Unggah / pilih Excel dari perangkat',
                        onPressed: widget.isLoading ? null : _handlePickFile,
                        icon: Icon(Icons.upload_file_outlined, color: Colors.grey.shade800),
                      ),
                    IconButton(
                      tooltip: 'URL sumber Excel',
                      onPressed: widget.isLoading ? null : _handleEditUrl,
                      icon: Icon(Icons.link, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.fileLabel != null)
              Material(
                color: AppOrange.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.link_outlined, size: 18, color: AppOrange.dark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.fileLabel!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  const pad = 12.0;
                  final cols = c.maxWidth >= 1100
                      ? 4
                      : c.maxWidth >= 700
                          ? 2
                          : 1;
                  final childAspect = cols >= 4 ? 1.25 : 1.15;

                  return Padding(
                    padding: const EdgeInsets.all(pad),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: childAspect,
                      ),
                      itemCount: _data.panels.length,
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openPanelFullscreen(context, i),
                              child: FleetPanelChart(
                                panel: _data.panels[i],
                                periodLabels: _data.periodLabels,
                                targetFraction: _data.targetFraction,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
