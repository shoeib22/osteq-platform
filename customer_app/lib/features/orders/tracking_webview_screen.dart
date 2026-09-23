import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TrackingWebViewScreen extends StatefulWidget {
  const TrackingWebViewScreen({super.key, required this.url});

  final String url;

  @override
  State<TrackingWebViewScreen> createState() => _TrackingWebViewScreenState();
}

class _TrackingWebViewScreenState extends State<TrackingWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live tracking')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
