import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // ── Local cache state ──
  String? _localPath;
  bool _isDownloaded = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _initLocalFile();
  }

  // ──────────────────────────────────────────────────────────────
  // Generate safe local path and check if file already cached
  // ──────────────────────────────────────────────────────────────
  Future<void> _initLocalFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      // Extract a safe filename from the Cloudinary URL
      final uri = Uri.parse(widget.url);
      final rawSegment = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'file.pdf';
      // Strip query params from the filename if present
      final filename =
          rawSegment.contains('?') ? rawSegment.split('?').first : rawSegment;
      final safeFilename =
          filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final path = '${dir.path}/$safeFilename';

      final exists = File(path).existsSync();

      debugPrint('Local cache path : $path');
      debugPrint('Already cached   : $exists');

      if (mounted) {
        setState(() {
          _localPath = path;
          _isDownloaded = exists;
        });
      }
    } catch (e) {
      debugPrint('_initLocalFile error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Download file and cache locally
  // ──────────────────────────────────────────────────────────────
  Future<void> _downloadFile() async {
    if (_isDownloading || _localPath == null) return;

    setState(() => _isDownloading = true);
    _showSnackBar('Downloading "${widget.title}"…');

    try {
      debugPrint('Downloading from: ${widget.url}');
      final response = await http.get(Uri.parse(widget.url));

      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      await File(_localPath!).writeAsBytes(response.bodyBytes);

      debugPrint('Saved to: $_localPath');

      if (mounted) {
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
        });
        _showSnackBar('Saved for offline use ✓');
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() => _isDownloading = false);
        _showSnackBar('Download failed: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ── Smart AppBar action: download vs cached checkmark ──
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          else if (_isDownloaded)
            IconButton(
              icon: const Icon(Icons.check_circle_rounded),
              color: Colors.greenAccent,
              tooltip: 'Saved offline',
              onPressed: () =>
                  _showSnackBar('This file is already saved offline.'),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Save for offline use',
              onPressed: _downloadFile,
            ),
        ],
      ),

      // ── Smart PDF Viewer: local file or network ──
      body: _localPath == null
          // Still determining local path — show loader
          ? const Center(child: CircularProgressIndicator())
          : _isDownloaded
              // ✅ Render from local cache (saves mobile data)
              ? InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 1.0,
                  maxScale: 5.0,
                  clipBehavior: Clip.none,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: SfPdfViewer.file(
                      File(_localPath!),
                      canShowScrollStatus: true,
                      canShowPaginationDialog: true,
                      enableDoubleTapZooming: true,
                      onDocumentLoadFailed: (details) {
                        debugPrint(
                            'Local PDF load failed: ${details.error} — ${details.description}');
                        _showSnackBar(
                            'Could not open cached file. Try re-downloading.',
                            isError: true);
                      },
                    ),
                  ),
                )
              // 🌐 Render from network
              : InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 1.0,
                  maxScale: 5.0,
                  clipBehavior: Clip.none,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: SfPdfViewer.network(
                      widget.url,
                      canShowScrollStatus: true,
                      canShowPaginationDialog: true,
                      enableDoubleTapZooming: true,
                      onDocumentLoadFailed: (details) {
                        debugPrint(
                            'Network PDF load failed: ${details.error} — ${details.description}');
                        _showSnackBar('Failed to load PDF: ${details.description}',
                            isError: true);
                      },
                    ),
                  ),
                ),
    );
  }
}
