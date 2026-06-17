import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/fleet_dashboard_data.dart';
import '../services/carousel_prefs.dart';
import '../services/excel_current_service.dart';
import '../services/excel_local_path_prefs.dart';
import '../services/excel_upload_service.dart';
import '../services/excel_url_prefs.dart';
import '../services/fleet_excel_parser.dart';
import '../services/fleet_server_config.dart';
import '../services/workbook_loader.dart';
import '../services/workbook_read_result.dart';
import '../theme/app_orange.dart';
import '../widgets/fleet_panel_chart.dart';
import 'fleet_grid_page.dart';

class FleetDashboardPage extends StatefulWidget {
  const FleetDashboardPage({super.key});

  @override
  State<FleetDashboardPage> createState() => _FleetDashboardPageState();
}

class _FleetDashboardPageState extends State<FleetDashboardPage> with SingleTickerProviderStateMixin {
  FleetDashboardData? _data;
  String? _fileLabel;
  String? _error;
  bool _loading = false;
  final PageController _carouselController = PageController();
  int _carouselIndex = 0;
  /// `0` = auto-advance off until the user sets an interval (see [loadCarouselIntervalMinutes]).
  int _carouselIntervalMinutes = 0;
  /// Drives auto-advance and the linear progress bar (0 → 1 over [Duration] minutes).
  late final AnimationController _carouselTickController;
  late final TextEditingController _excelUrlController;
  /// Set after sukses baca file lokal (VM/desktop); dipakai [_refreshWorkbook].
  String? _manualAbsolutePath;

  /// Bumped when the user saves carousel prefs so a late [_loadCarouselPrefs] from
  /// [initState] cannot overwrite the new value (e.g. still had 5 after user set 1).
  int _carouselPrefsGen = 0;

  /// Carousel tick dijeda saat pointer di atas batang chart (lihat [FleetPanelChart.onBarHovered]).
  bool _carouselPausedForBarHover = false;

  static const List<int> _carouselMinutePresets = [1, 3, 5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _carouselTickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addStatusListener(_onCarouselTickStatus);
    _excelUrlController = TextEditingController();
    unawaited(_loadCarouselPrefs());
    unawaited(_primeExcelUrlField());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLoad());
  }

  void _onCarouselTickStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final n = _data?.panels.length ?? 0;
    if (n <= 1) return;
    final next = (_carouselIndex + 1) % n;
    if (_carouselController.hasClients) {
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _carouselTickController.dispose();
    _carouselController.dispose();
    _excelUrlController.dispose();
    super.dispose();
  }

  Future<void> _primeExcelUrlField() async {
    final u = await loadExcelDataUrl();
    if (!mounted || u.isEmpty) return;
    if (_excelUrlController.text.trim().isEmpty) {
      _excelUrlController.text = u;
    }
  }

  Future<WorkbookReadResult> _loadWorkbookPrimary() async {
    final serverUrl = await ExcelCurrentService.resolveServerExcelUrl();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      final server = await WorkbookLoader.loadFromHttpUrl(serverUrl);
      if (server.isOk) return server;
    }

    final saved = await loadExcelDataUrl();
    if (saved.isNotEmpty) {
      return WorkbookLoader.loadFromHttpUrl(saved);
    }
    if (!kIsWeb) {
      final storedPath = (await loadExcelLocalPath()).trim();
      if (storedPath.isNotEmpty) {
        final r = await WorkbookLoader.readPath(storedPath);
        if (r.isOk) return r;
        await saveExcelLocalPath('');
      }
    }
    return WorkbookLoader.loadFromEnvironment();
  }

  /// Path absolut untuk refresh file lokal; `null` jika sumbernya URL.
  String? _desktopPathForRefresh(String? label) {
    if (kIsWeb || label == null || label.isEmpty) return null;
    final t = label.trim();
    final lower = t.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return null;
    return t;
  }

  /// Tombol unggah di toolbar: file lokal, atau field URL kosong.
  bool _showToolbarDeviceUploadForUrlField(String urlText) {
    final manual = _manualAbsolutePath?.trim();
    if (manual != null && manual.isNotEmpty) return true;
    return urlText.trim().isEmpty;
  }

  bool _toolbarSourceLooksLikeUrl() {
    final label = _fileLabel?.trim() ?? '';
    if (label.isEmpty) return false;
    final lower = label.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Future<void> _loadCarouselPrefs() async {
    final gen = ++_carouselPrefsGen;
    var m = await loadCarouselIntervalMinutes();
    if (!mounted || gen != _carouselPrefsGen) return;
    if (m < 0) m = 0;
    if (m > kCarouselStoredMaxMinutes) m = kCarouselStoredMaxMinutes;
    setState(() => _carouselIntervalMinutes = m);
    _armCarouselTimer();
  }

  void _armCarouselTimer() {
    _carouselTickController.stop();
    if (_carouselIntervalMinutes <= 0) {
      _carouselPausedForBarHover = false;
      _carouselTickController.reset();
      return;
    }
    final d = _data;
    if (d == null || d.panels.length <= 1) {
      _carouselPausedForBarHover = false;
      _carouselTickController.reset();
      return;
    }

    _carouselTickController.duration = Duration(minutes: _carouselIntervalMinutes);
    _carouselTickController.reset();
    if (!_carouselPausedForBarHover) {
      _carouselTickController.forward();
    }
  }

  void _onCarouselBarChartBarHovered(bool barHovered) {
    if (!mounted) return;
    final carouselActive = _carouselIntervalMinutes > 0 && ((_data?.panels.length ?? 0) > 1);
    if (!carouselActive) {
      _carouselPausedForBarHover = false;
      return;
    }
    _carouselPausedForBarHover = barHovered;
    if (barHovered) {
      if (_carouselTickController.isAnimating) {
        _carouselTickController.stop(canceled: false);
      }
    } else if (_carouselTickController.value < 1.0 && !_carouselTickController.isAnimating) {
      _carouselTickController.forward();
    }
  }

  void _onCarouselPageChanged(int i) {
    setState(() => _carouselIndex = i);
    _armCarouselTimer();
  }

  Future<void> _showCarouselTimerSettings() async {
    final controller = TextEditingController(text: '$_carouselIntervalMinutes');
    var dialogError = '';

    int? picked;
    try {
      picked = await showDialog<int>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: const Text('Timer carousel'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Otomatis pindah ke chart berikutnya. '
                        'Hitungan diatur ulang setelah Anda menggeser manual.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Interval (menit)',
                          hintText: 'Menit (0 = mati)',
                          errorText: dialogError.isEmpty ? null : dialogError,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) {
                          if (dialogError.isNotEmpty) {
                            setLocal(() => dialogError = '');
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bilangan bulat 0 sampai $kCarouselStoredMaxMinutes.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Cepat',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _carouselMinutePresets)
                            ActionChip(
                              label: Text('$p menit'),
                              onPressed: () {
                                controller.text = '$p';
                                setLocal(() => dialogError = '');
                              },
                            ),
                          ActionChip(
                            label: const Text('Matikan (0)'),
                            onPressed: () {
                              controller.text = '0';
                              setLocal(() => dialogError = '');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final raw = controller.text.trim();
                      if (raw.isEmpty) {
                        setLocal(() => dialogError = 'Isi jumlah menit.');
                        return;
                      }
                      final v = int.tryParse(raw);
                      if (v == null) {
                        setLocal(() => dialogError = 'Hanya angka bulat.');
                        return;
                      }
                      if (v < 0 || v > kCarouselStoredMaxMinutes) {
                        setLocal(() => dialogError = 'Rentang 0 s/d $kCarouselStoredMaxMinutes.');
                        return;
                      }
                      Navigator.of(context).pop(v);
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }

    if (!mounted || picked == null) return;
    final minutes = picked;
    _carouselPrefsGen++;
    final saved = await saveCarouselIntervalMinutes(minutes);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal menyimpan interval timer. '
            'Di web: pastikan penyimpanan lokal tidak diblokir (bukan mode pribadi ketat).',
          ),
        ),
      );
      return;
    }
    setState(() => _carouselIntervalMinutes = minutes);
    _armCarouselTimer();
  }

  Future<void> _tryAutoLoad() async {
    final r = await _loadWorkbookPrimary();
    if (!mounted) return;
    if (r.isOk) {
      await _loadBytes(
        r.bytes!,
        r.label ?? 'Workbook',
        manualDesktopPath: _desktopPathForRefresh(r.label),
      );
      return;
    }
    if (r.error != null) {
      setState(() => _error = r.error);
    }
  }

  Future<void> _refreshWorkbook() async {
    if (_loading) return;
    final manual = _manualAbsolutePath;
    if (!kIsWeb && manual != null && manual.isNotEmpty) {
      final local = await WorkbookLoader.readPath(manual);
      if (!mounted) return;
      if (local.isOk) {
        await saveExcelDataUrl('');
        await _loadBytes(local.bytes!, local.label ?? manual, manualDesktopPath: manual);
        return;
      }
    }
    final r = await _loadWorkbookPrimary();
    if (!mounted) return;
    if (r.isOk) {
      await _loadBytes(
        r.bytes!,
        r.label ?? 'Workbook',
        manualDesktopPath: _desktopPathForRefresh(r.label),
      );
      return;
    }
    setState(() {
      _data = null;
      _error = r.error ?? 'Gagal memuat ulang data dari URL / sumber.';
    });
    if (mounted) _armCarouselTimer();
  }

  Future<void> _loadBytes(
    List<int> bytes,
    String label, {
    String? manualDesktopPath,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final parsed = parseFleetExcelBytes(bytes);
      if (!kIsWeb) {
        final p = manualDesktopPath?.trim();
        if (p != null && p.isNotEmpty) {
          await saveExcelLocalPath(p);
        } else {
          await saveExcelLocalPath('');
        }
      }
      final path = manualDesktopPath?.trim();
      if (path != null && path.isNotEmpty) {
        _excelUrlController.clear();
      }
      setState(() {
        _data = parsed;
        _fileLabel = label;
        _loading = false;
        _carouselIndex = 0;
        _manualAbsolutePath = manualDesktopPath;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _carouselController.hasClients) {
          _carouselController.jumpToPage(0);
        }
        if (mounted) _armCarouselTimer();
      });
    } catch (e, st) {
      debugPrint('$e\n$st');
      setState(() {
        _data = null;
        _error = e.toString();
        _loading = false;
      });
      if (mounted) _armCarouselTimer();
    }
  }

  Future<void> _loadFromEnteredUrl() async {
    final url = _excelUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Isi URL file Excel (.xlsx) terlebih dahulu.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await WorkbookLoader.loadFromHttpUrl(url);
    if (!mounted) return;
    if (!r.isOk) {
      setState(() {
        _loading = false;
        _error = r.error ?? 'Gagal memuat dari URL.';
      });
      return;
    }
    await saveExcelDataUrl(url);
    await _loadBytes(r.bytes!, url, manualDesktopPath: null);
  }

  Future<void> _pickExcelFromFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      setState(() => _error = 'Tidak dapat membaca isi file (bytes kosong).');
      return;
    }

    if (kIsWeb && FleetServerConfig.hasUploadEndpoint) {
      setState(() {
        _loading = true;
        _error = null;
      });
      final uploaded = await ExcelUploadService.uploadBytes(bytes, f.name);
      if (!mounted) return;
      if (!uploaded.ok) {
        setState(() {
          _loading = false;
          _error = uploaded.error ?? 'Gagal mengunggah ke server.';
        });
        return;
      }
      await saveExcelDataUrl('');
      final url = uploaded.url?.trim();
      if (url == null || url.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Upload berhasil tetapi server tidak mengembalikan URL file.';
        });
        return;
      }
      final r = await WorkbookLoader.loadFromHttpUrl(url);
      if (!mounted) return;
      if (!r.isOk) {
        setState(() {
          _loading = false;
          _error = r.error ?? 'File tersimpan di server, tetapi gagal dimuat ulang.';
        });
        return;
      }
      await _loadBytes(
        r.bytes!,
        uploaded.filename ?? url,
        manualDesktopPath: null,
      );
      return;
    }

    await saveExcelDataUrl('');
    final path = f.path;
    await _loadBytes(
      bytes,
      f.name,
      manualDesktopPath: (path != null && path.isNotEmpty) ? path : null,
    );
  }
  Future<void> _showExcelUrlEditor() async {
    final ctrl = TextEditingController(text: _excelUrlController.text.trim());
    String? submitted;
    try {
      submitted = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('URL sumber Excel'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'HTTPS atau HTTP menuju file .xlsx. '
                    'Di web, unggah file akan disimpan ke server (strakin.tech) '
                    'dan dipakai semua perangkat. URL manual opsional jika server default gagal.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      hintText: 'https://…/Dashboard_EM.xlsx',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
                child: const Text('Simpan & muat'),
              ),
            ],
          );
        },
      );
    } finally {
      ctrl.dispose();
    }
    if (!mounted || submitted == null) return;
    if (submitted.isEmpty) return;
    _excelUrlController.text = submitted;
    await _loadFromEnteredUrl();
  }

  void _openAllChartsGrid() {
    final d = _data;
    if (d == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FleetGridPage(
          initialData: d,
          fileLabel: _fileLabel,
          isLoading: _loading,
          getLatestData: () => _data,
          onRefresh: _refreshWorkbook,
          onEditExcelUrl: _showExcelUrlEditor,
          onPickExcelFile: _pickExcelFromFile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _body(context)),
      floatingActionButton: _data == null
          ? ValueListenableBuilder<TextEditingValue>(
              valueListenable: _excelUrlController,
              builder: (context, urlValue, _) {
                final noLink = urlValue.text.trim().isEmpty;
                if (!noLink) {
                  return FloatingActionButton.extended(
                    heroTag: 'fab_url_only',
                    onPressed: _loading ? null : _loadFromEnteredUrl,
                    icon: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_download_outlined),
                    label: Text(_loading ? 'Memuat…' : 'Muat dari URL'),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fab_pick_xlsx',
                      tooltip: 'Unggah / pilih Excel dari perangkat',
                      onPressed: _loading ? null : _pickExcelFromFile,
                      child: const Icon(Icons.upload_file_outlined),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'fab_url_xlsx',
                      onPressed: _loading ? null : _loadFromEnteredUrl,
                      icon: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                      label: Text(_loading ? 'Memuat…' : 'Muat dari URL'),
                    ),
                  ],
                );
              },
            )
          : null,
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null && _data == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppOrange.dark, size: 26),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Gagal memuat workbook',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppOrange.deepText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(_error!, style: const TextStyle(fontSize: 13, height: 1.35)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _error = null);
                            _tryAutoLoad();
                          },
                          icon: const Icon(Icons.cloud_download_outlined, size: 20),
                          label: const Text('Coba lagi'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() => _error = null);
                            _showExcelUrlEditor();
                          },
                          icon: const Icon(Icons.link),
                          label: const Text('Atur URL'),
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _excelUrlController,
                    builder: (context, urlValue, _) {
                      if (urlValue.text.trim().isNotEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() => _error = null);
                                    _pickExcelFromFile();
                                  },
                            icon: const Icon(Icons.upload_file_outlined, size: 20),
                            label: const Text('Unggah Excel dari perangkat'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_data == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded, size: 52, color: AppOrange.primary),
                  const SizedBox(height: 18),
                  Text(
                    'Sumber data: URL atau file Excel',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppOrange.deepText,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tempel link ke berkas .xlsx, atau unggah file dari perangkat '
                    '(komputer / tablet / ponsel). URL tersimpan di perangkat bila dipakai. '
                    'Tombol unggah muncul jika kotak URL dikosongkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Struktur sheet mengikuti skrip Python em_dashboard.py '
                    '(baris judul berisi "Fleet", kolom Fleet berisi nama seri, '
                    'blok 8 kolom nilai + baris Target).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _excelUrlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'URL file .xlsx',
                      hintText: 'https://contoh.com/path/Dashboard_EM.xlsx',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Opsional: build dengan --dart-define=FLEET_EXCEL_URL=… '
                    'atau FLEET_EXCEL_PATH=… (desktop) bila tidak memakai URL tersimpan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 18),
                  if (_loading) ...[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppOrange.primary),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    onPressed: _loading ? null : _loadFromEnteredUrl,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Muat data'),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _excelUrlController,
                    builder: (context, urlValue, _) {
                      if (urlValue.text.trim().isNotEmpty) return const SizedBox.shrink();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _pickExcelFromFile,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Unggah Excel dari perangkat'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final d = _data!;
    final showToolbarTextLabels = MediaQuery.sizeOf(context).width >= 600;
    final padH = 14.0;
    final nPanels = d.panels.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_fileLabel != null)
          Material(
            elevation: 2,
            shadowColor: AppOrange.primary.withValues(alpha: 0.2),
            color: AppOrange.surface,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppOrange.primary, width: 5),
                  bottom: BorderSide(color: Color(0x33FFB74D)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _toolbarSourceLooksLikeUrl() ? Icons.link_outlined : Icons.folder_open_outlined,
                    size: 20,
                    color: AppOrange.dark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _fileLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atur timer carousel (menit)',
                    onPressed: _showCarouselTimerSettings,
                    icon: const Icon(Icons.timer_outlined),
                  ),
                  IconButton(
                    tooltip: 'Semua chart (tanpa carousel)',
                    onPressed: _loading ? null : _openAllChartsGrid,
                    icon: const Icon(Icons.grid_view),
                  ),
                  IconButton(
                    tooltip: 'Segarkan data',
                    onPressed: _loading ? null : _refreshWorkbook,
                    icon: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppOrange.primary,
                            ),
                          )
                        : const Icon(Icons.refresh),
                  ),
                  if (showToolbarTextLabels)
                    TextButton.icon(
                      onPressed: _loading ? null : _showExcelUrlEditor,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Ubah URL'),
                    )
                  else
                    IconButton(
                      tooltip: 'Ubah URL',
                      onPressed: _loading ? null : _showExcelUrlEditor,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _excelUrlController,
                    builder: (context, urlValue, _) {
                      if (!_showToolbarDeviceUploadForUrlField(urlValue.text)) return const SizedBox.shrink();
                      if (showToolbarTextLabels) {
                        return TextButton.icon(
                          onPressed: _loading ? null : _pickExcelFromFile,
                          icon: const Icon(Icons.upload_file_outlined, size: 18),
                          label: const Text('Unggah file'),
                        );
                      }
                      return IconButton(
                        tooltip: 'Unggah file',
                        onPressed: _loading ? null : _pickExcelFromFile,
                        icon: const Icon(Icons.upload_file_outlined),
                      );
                    },
                  ),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppOrange.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _carouselController,
                  itemCount: nPanels,
                  onPageChanged: _onCarouselPageChanged,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(padH, 10, padH, 6),
                      child: FleetPanelChart(
                        panel: d.panels[i],
                        periodLabels: d.periodLabels,
                        targetFraction: d.targetFraction,
                        onBarHovered: _onCarouselBarChartBarHovered,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_carouselIntervalMinutes > 0 && nPanels > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListenableBuilder(
                          listenable: _carouselTickController,
                          builder: (context, _) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                value: _carouselTickController.value.clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade200,
                                color: AppOrange.primary,
                              ),
                            );
                          },
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_carouselIndex + 1} / $nPanels',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_carouselIntervalMinutes > 0)
                              Text(
                                'Timer $_carouselIntervalMinutes menit',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(nPanels, (i) {
                                final active = i == _carouselIndex;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: InkWell(
                                    onTap: () => _carouselController.animateToPage(
                                      i,
                                      duration: const Duration(milliseconds: 320),
                                      curve: Curves.easeOutCubic,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      height: 8,
                                      width: active ? 22 : 8,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: active ? AppOrange.primary : Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
