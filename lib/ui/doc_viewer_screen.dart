import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DocViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const DocViewerScreen({super.key, required this.url, required this.title});

  @override
  State<DocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends State<DocViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    
    // Formatting the URL for Google Docs Viewer
    final encodedUrl = Uri.encodeComponent(widget.url);
    final docUrl = 'https://docs.google.com/gview?embedded=true&url=$encodedUrl';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(docUrl));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Failed to load document. It might not be a valid docx file.'),
                ],
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1A237E),
                    ),
                  ),
              ],
            ),
    );
  }
}
