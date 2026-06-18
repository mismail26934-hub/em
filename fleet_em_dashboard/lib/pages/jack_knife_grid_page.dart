import 'package:flutter/material.dart';

import '../models/jack_knife_dashboard_data.dart';
import '../theme/app_orange.dart';
import '../widgets/jack_knife_panel_chart.dart';
import 'jack_knife_panel_fullscreen_page.dart';

class JackKnifeGridPage extends StatefulWidget {
  const JackKnifeGridPage({
    super.key,
    required this.initialData,
    required this.getLatestData,
    required this.onRefresh,
    required this.onEditExcelUrl,
    this.onPickExcelFile,
    this.fileLabel,
    this.isLoading = false,
  });

  final JackKnifeDashboardData initialData;
  final JackKnifeDashboardData? Function() getLatestData;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onEditExcelUrl;
  final Future<void> Function()? onPickExcelFile;
  final String? fileLabel;
  final bool isLoading;

  @override
  State<JackKnifeGridPage> createState() => _JackKnifeGridPageState();
}

class _JackKnifeGridPageState extends State<JackKnifeGridPage> {
  late JackKnifeDashboardData _data;

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
                      'Semua Jack Knife',
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
                        tooltip: 'Unggah Excel',
                        onPressed: widget.isLoading ? null : widget.onPickExcelFile,
                        icon: Icon(Icons.upload_file_outlined, color: Colors.grey.shade800),
                      ),
                    IconButton(
                      tooltip: 'URL sumber Excel',
                      onPressed: widget.isLoading ? null : widget.onEditExcelUrl,
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
                      Icon(Icons.folder_open_outlined, size: 18, color: AppOrange.dark),
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
                  final cols = c.maxWidth >= 1100
                      ? 3
                      : c.maxWidth >= 700
                          ? 2
                          : 1;
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: cols >= 3 ? 1.15 : 1.05,
                      ),
                      itemCount: _data.panels.length,
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (context) => JackKnifePanelFullscreenPage(
                                      data: _data,
                                      panelIndex: i,
                                    ),
                                  ),
                                );
                              },
                              child: JackKnifePanelChart(panel: _data.panels[i]),
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
