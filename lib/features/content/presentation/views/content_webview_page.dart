import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ContentWebViewPage extends StatefulWidget {
  const ContentWebViewPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<ContentWebViewPage> createState() => _ContentWebViewPageState();
}

class _ContentWebViewPageState extends State<ContentWebViewPage> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loadingProgress = 100);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loadingProgress < 100)
            LinearProgressIndicator(value: _loadingProgress / 100),
        ],
      ),
    );
  }
}
