
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live camera screen for the ESP32-CAM.
class LiveFeedScreen extends StatefulWidget {
  final bool selectMode;

  const LiveFeedScreen({
    super.key,
    this.selectMode = false,
  });

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends State<LiveFeedScreen> {
  static const String _prefsEspKey = 'esp32_cam_address';

  final TextEditingController _ipController = TextEditingController();

  String? _streamUrl;
  bool _streaming = false;
  bool _capturing = false;

  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  String _extractHost(String input) {
    var value = input.trim();
    value = value.replaceFirst(RegExp(r'^https?://'), '');

    final slash = value.indexOf('/');
    if (slash != -1) {
      value = value.substring(0, slash);
    }

    final colon = value.indexOf(':');
    if (colon != -1) {
      value = value.substring(0, colon);
    }

    return value;
  }

  Future<void> _loadSavedIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsEspKey);

      if (saved != null && saved.isNotEmpty) {
        _ipController.text = _extractHost(saved);

        if (mounted) {
          _connect();
        }
      }
    } catch (_) {}
  }

  Future<void> _connect() async {
    final host = _extractHost(_ipController.text);

    if (host.isEmpty) {
      _showSnack('Please enter the ESP32-CAM IP address.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsEspKey, 'http://$host');
    } catch (_) {}

    if (!mounted) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _streamUrl = 'http://$host:81/stream';
      _streamKey = UniqueKey();
      _streaming = true;
    });
  }

  void _disconnect() {
    setState(() {
      _streaming = false;
      _streamUrl = null;
    });
  }

  Future<void> _captureAndReturn() async {
    final host = _extractHost(_ipController.text);

    if (host.isEmpty || _capturing) return;

    setState(() {
      _capturing = true;
      _streaming = false;
      _streamUrl = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600));

      final response = await http
          .get(Uri.parse('http://$host/capture'))
          .timeout(const Duration(seconds: 15));

      final bytes = response.bodyBytes;

      if (response.statusCode != 200 ||
          bytes.length < 4 ||
          bytes[0] != 0xFF ||
          bytes[1] != 0xD8) {
        throw Exception('Camera did not return a valid JPEG image.');
      }

      final dir = await getTemporaryDirectory();

      final file = File(
        '${dir.path}/esp32_leaf_'
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      Navigator.of(context).pop(file);
    } on SocketException {
      _showSnack(
        'Cannot reach ESP32-CAM. Check power, Wi-Fi and IP address.',
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');

      _showSnack(
        message.contains('TimeoutException')
            ? 'ESP32-CAM timed out. Check the camera and Wi-Fi.'
            : 'Capture failed: $message',
      );
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Live Camera'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _connect(),
              decoration: const InputDecoration(
                labelText: 'ESP32-CAM IP address',
                hintText: 'e.g. 192.168.1.45',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.videocam),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _capturing ? null : _connect,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      _streaming ? 'Reconnect' : 'Start Live Feed',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (_streaming && !_capturing) ? _disconnect : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _capturing
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.green,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Capturing leaf...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      )
                    : (_streaming && _streamUrl != null)
                        ? Esp32MjpegView(
                            key: _streamKey,
                            url: _streamUrl!,
                            onRetry: _connect,
                          )
                        : const Center(
                            child: Text(
                              'Enter the camera IP and tap Start',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
              ),
            ),

            if (widget.selectMode) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed:
                      (_streaming && !_capturing)
                          ? _captureAndReturn
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.camera),
                  label: const Text('Capture Leaf & Use'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Displays JPEG frames received from an ESP32-CAM MJPEG HTTP stream.
class Esp32MjpegView extends StatefulWidget {
  final String url;
  final VoidCallback onRetry;

  const Esp32MjpegView({
    super.key,
    required this.url,
    required this.onRetry,
  });

  @override
  State<Esp32MjpegView> createState() => _Esp32MjpegViewState();
}

class _Esp32MjpegViewState extends State<Esp32MjpegView> {
  late final http.Client _client;

  Uint8List? _frame;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _startStream();
  }

  Future<void> _startStream() async {
    try {
      final request = http.Request(
        'GET',
        Uri.parse(widget.url),
      );

      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Camera returned HTTP ${response.statusCode}');
      }

      final buffer = <int>[];

      await for (final chunk in response.stream) {
        if (!mounted) return;

        buffer.addAll(chunk);

        while (true) {
          var start = -1;

          // Find the JPEG start marker: FF D8.
          for (var i = 0; i + 1 < buffer.length; i++) {
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
              start = i;
              break;
            }
          }

          if (start == -1) {
            // Retain one byte in case a marker crosses chunks.
            if (buffer.length > 1) {
              buffer.removeRange(0, buffer.length - 1);
            }
            break;
          }

          if (start > 0) {
            buffer.removeRange(0, start);
          }

          var end = -1;

          // Find the JPEG end marker: FF D9.
          for (var i = 2; i + 1 < buffer.length; i++) {
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
              end = i + 2;
              break;
            }
          }

          if (end == -1) {
            break;
          }

          final image = Uint8List.fromList(
            buffer.sublist(0, end),
          );

          buffer.removeRange(0, end);

          if (mounted) {
            setState(() {
              _frame = image;
              _loading = false;
              _error = null;
            });
          }
        }

        // Protect against an invalid or unusually large incomplete frame.
        if (buffer.length > 2 * 1024 * 1024) {
          buffer.clear();
        }
      }

      if (mounted && _frame == null) {
        setState(() {
          _loading = false;
          _error = 'No image received from the camera.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Cannot connect to camera. Check its IP and Wi-Fi.';
      });
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frame != null) {
      return SizedBox.expand(
        child: Image.memory(
          _frame!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Text(
                'Unable to display camera frame.',
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Camera connection failed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
