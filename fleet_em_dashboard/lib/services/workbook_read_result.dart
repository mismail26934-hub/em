/// Result of reading an Excel workbook from disk or network.
class WorkbookReadResult {
  const WorkbookReadResult({this.bytes, this.label, this.error});

  final List<int>? bytes;
  final String? label;
  final String? error;

  bool get isOk => bytes != null && bytes!.isNotEmpty;
}
