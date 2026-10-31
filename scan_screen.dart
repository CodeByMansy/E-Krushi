
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../data/prediction_api.dart';
import '../data/models.dart';
import '../data/weather_repository.dart';
import '../data/esp32_sensor_repository.dart';
import 'live_feed_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _imageFile;
  PredictionResult? _result;
  bool _loading = false;

  static const String _prefsEspKey = 'esp32_cam_address';
  String _esp32BaseUrl = 'http://192.168.1.50';

  Esp32SensorData? _espSensors;
  bool _sensorLoading = false;
  String? _sensorError;
  Timer? _sensorTimer;

  CurrentWeather? _weather;
  bool _weatherLoading = false;
  String? _weatherError;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSavedEspAddress();
    _startSensorPolling();
  }

  @override
  void dispose() {
    _sensorTimer?.cancel();
    super.dispose();
  }

  String _normalizeAddress(String input) {
    var value = input.trim();
    if (value.isEmpty) return value;

    if (!value.startsWith('http://') &&
        !value.startsWith('https://')) {
      value = 'http://$value';
    }

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Future<void> _loadSavedEspAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsEspKey);

      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => _esp32BaseUrl = _normalizeAddress(saved));
        _refreshEspSensors();
      }
    } catch (_) {}
  }

  void _startSensorPolling() {
    _sensorTimer?.cancel();
    _refreshEspSensors();

    _sensorTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshEspSensors(),
    );
  }

  Future<void> _refreshEspSensors() async {
    if (_sensorLoading || !mounted) return;

    setState(() => _sensorLoading = true);

    try {
      final readings =
          await Esp32SensorRepository.getReadings(_esp32BaseUrl);

      if (!mounted) return;

      setState(() {
        _espSensors = readings;
        _sensorError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _sensorError =
            'Cannot connect to ESP32. Check the IP address and Wi-Fi.';
      });
    } finally {
      if (mounted) {
        setState(() => _sensorLoading = false);
      }
    }
  }

  Future<void> _showEspAddressDialog() async {
    final controller = TextEditingController(text: _esp32BaseUrl);

    final newAddress = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.router),
        title: const Text('ESP32-CAM Address'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'IP address',
            hintText: '192.168.1.50',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newAddress == null) return;
    final normalized = _normalizeAddress(newAddress);
    if (normalized.isEmpty || !mounted) return;

    setState(() {
      _esp32BaseUrl = normalized;
      _espSensors = null;
      _sensorError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsEspKey, normalized);
    } catch (_) {}

    _startSensorPolling();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ESP32 address saved: $normalized')),
      );
    }
  }

  Future<void> _openEspLiveFeed() async {
    if (_loading) return;

    final captured = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => const LiveFeedScreen(selectMode: true),
      ),
    );

    await _loadSavedEspAddress();

    if (captured != null && mounted) {
      setState(() {
        _imageFile = captured;
        _result = null;
      });
      _showSnack('Leaf image captured from ESP32-CAM!');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadWeatherUsingGps() async {
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on GPS and try again.');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      final weather = await WeatherRepository.getWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _weather = weather;
        _weatherError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _weatherError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _weatherLoading = false);
      }
    }
  }

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _imageFile = File(picked.path);
      _result = null;
    });
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _imageFile = File(picked.path);
      _result = null;
    });
  }

  Future<void> _detectDisease() async {
    final image = _imageFile;
    if (image == null || _loading) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final result = await PredictionApi.predictDisease(image);

      if (!mounted || _imageFile?.path != image.path) return;
      setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        _showSnack('Prediction failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _shareResult(PredictionResult result) {
    final text = '''e-krushi Plant Disease Detection Result

Disease: ${result.disease}
Severity: ${result.severity}
Confidence: ${result.confidence}%

Description:
${result.description}

Recommended Treatment:
${result.treatment}''';

    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'e-krushi Disease Detection Result',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a Leaf')),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _showHelpDialog,
        child: const Icon(Icons.help_outline),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            '🌿 AI Plant Scanner',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          const Text('Detect crop diseases using Artificial Intelligence.'),
          const SizedBox(height: 16),

          _Esp32DeviceCard(
            address: _esp32BaseUrl,
            onEdit: _showEspAddressDialog,
            onLiveFeed: _openEspLiveFeed,
          ),
          const SizedBox(height: 16),

          _Esp32SensorCard(
            sensors: _espSensors,
            loading: _sensorLoading,
            error: _sensorError,
            onRefresh: _refreshEspSensors,
          ),
          const SizedBox(height: 16),

          _WeatherCard(
            weather: _weather,
            loading: _weatherLoading,
            error: _weatherError,
            onGetWeather: _loadWeatherUsingGps,
          ),
          const SizedBox(height: 16),

          const _NearbyAgricultureCenterCard(),
          const SizedBox(height: 16),

          const _ScanTipsCard(),
          const SizedBox(height: 16),

          _ImagePreviewCard(
            imageFile: _imageFile,
            onChange: _pickFromGallery,
            onRemove: () => setState(() {
              _imageFile = null;
              _result = null;
            }),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.videocam,
                  title: 'ESP32-CAM',
                  subtitle: 'Live camera',
                  onTap: _openEspLiveFeed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.photo_library,
                  title: 'Gallery',
                  subtitle: 'Choose image',
                  onTap: _pickFromGallery,
                ),
              ),
            ],
          ),

          if (Platform.isAndroid || Platform.isIOS)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pickFromCamera,
                icon: const Icon(Icons.phone_android),
                label: const Text('Use phone camera'),
              ),
            ),

          const SizedBox(height: 12),
          const _ModelReadyCard(),
          const SizedBox(height: 16),

          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed:
                  _imageFile != null && !_loading ? _detectDisease : null,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'Analyzing...' : 'Detect Disease'),
            ),
          ),

          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],

          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(
              result: _result!,
              onShare: () => _shareResult(_result!),
              onPdf: () => _downloadPdf(_result!),
              onScanAgain: () => setState(() {
                _imageFile = null;
                _result = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How to Scan a Leaf'),
        content: const Text(
          '1. Power on the ESP32-CAM and connect your phone to the same Wi-Fi.\n\n'
          '2. Open the live camera and capture a leaf.\n\n'
          '3. Use natural daylight and keep one leaf in the center.\n\n'
          '4. Tap Detect Disease to analyze the image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(PredictionResult result) async {
    try {
      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          build: (_) => pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'e-Krushi Plant Disease Report',
                  style: pw.TextStyle(
                    fontSize: 23,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Disease: ${result.disease}'),
                pw.SizedBox(height: 8),
                pw.Text('Severity: ${result.severity}'),
                pw.SizedBox(height: 8),
                pw.Text('Confidence: ${result.confidence}%'),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Description',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text(result.description),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Recommended Treatment',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text(result.treatment),
              ],
            ),
          ),
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/eKrushi_Report_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      await file.writeAsBytes(await doc.save());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ${file.path}')),
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) _showSnack('Could not create PDF: $e');
    }
  }
}

// ---------------- DEVICE CARD ----------------

class _Esp32DeviceCard extends StatelessWidget {
  final String address;
  final VoidCallback onEdit;
  final VoidCallback onLiveFeed;

  const _Esp32DeviceCard({
    required this.address,
    required this.onEdit,
    required this.onLiveFeed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.developer_board, size: 30, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portable Scanner (ESP32-CAM)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    address,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: onLiveFeed,
                    child: const Text('Open live camera'),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- LIVE SENSOR CARD ----------------

class _Esp32SensorCard extends StatelessWidget {
  final Esp32SensorData? sensors;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  const _Esp32SensorCard({
    required this.sensors,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = sensors;

    final temperature = data?.temperature == null
        ? '--'
        : '${data!.temperature!.toStringAsFixed(1)} °C';

    final humidity = data?.humidity == null
        ? '--'
        : '${data!.humidity!.toStringAsFixed(1)}%';

    final soil = data?.soilStatus ?? 'UNKNOWN';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: colors.primary, size: 27),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Live Hardware Sensors',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text(
              data?.wifiConnected == true
                  ? 'ESP32 connected'
                  : 'Waiting for ESP32 data',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Row(
              children: [
                _SensorValue(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value: temperature,
                ),
                _SensorValue(
                  icon: Icons.water_drop,
                  label: 'Humidity',
                  value: humidity,
                ),
                _SensorValue(
                  icon: Icons.grass,
                  label: 'Soil',
                  value: soil,
                ),
              ],
            ),
            if (loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SensorValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SensorValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: colors.primary, size: 25),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ---------------- WEATHER CARD ----------------

class _WeatherCard extends StatelessWidget {
  final CurrentWeather? weather;
  final bool loading;
  final String? error;
  final VoidCallback onGetWeather;

  const _WeatherCard({
    required this.weather,
    required this.loading,
    required this.error,
    required this.onGetWeather,
  });

  String? _riskMessage() {
    if (weather == null) return null;

    if (weather!.humidity >= 80 &&
        weather!.temperature >= 20 &&
        weather!.temperature <= 30) {
      return 'High humidity and suitable temperatures may increase fungal disease risk.';
    }

    if (weather!.humidity >= 65) {
      return 'Moderate humidity. Inspect plants regularly for symptoms.';
    }

    return 'Current weather indicates a lower environmental disease risk.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final risk = _riskMessage();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather Conditions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text('Online weather based on your GPS location'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onGetWeather,
                icon: const Icon(Icons.my_location),
                label: Text(
                  loading ? 'Getting weather...' : 'Get Weather Using GPS',
                ),
              ),
            ),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 14),
            Row(
              children: [
                _WeatherValue(
                  icon: Icons.thermostat,
                  value: weather == null
                      ? '--'
                      : '${weather!.temperature.toInt()}°C',
                  label: 'Temperature',
                ),
                _WeatherValue(
                  icon: Icons.water_drop,
                  value: weather == null ? '--' : '${weather!.humidity}%',
                  label: 'Humidity',
                ),
                _WeatherValue(
                  icon: Icons.air,
                  value: weather == null
                      ? '--'
                      : '${weather!.windSpeed.toInt()} km/h',
                  label: 'Wind',
                ),
              ],
            ),
            if (risk != null) ...[
              const SizedBox(height: 12),
              Text(risk, style: TextStyle(color: colors.primary)),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeatherValue extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _WeatherValue({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(height: 5),
          Text(value, textAlign: TextAlign.center),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ---------------- AGRICULTURE CENTER ----------------

class _NearbyAgricultureCenterCard extends StatelessWidget {
  const _NearbyAgricultureCenterCard();

  Future<void> _openMaps(BuildContext context) async {
    final uri = Uri.parse('https://www.google.com/maps/search/agriculture+center+near+me');

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on),
        title: const Text('Nearby Agriculture Center'),
        subtitle: const Text('Find agricultural support near you'),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => _openMaps(context),
      ),
    );
  }
}

// ---------------- SCAN TIPS ----------------

class _ScanTipsCard extends StatelessWidget {
  const _ScanTipsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Tips',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('✓ Use natural sunlight'),
            Text('✓ Capture one leaf at a time'),
            Text('✓ Keep the leaf in the center'),
            Text('✓ Avoid blurry images and shadows'),
          ],
        ),
      ),
    );
  }
}

// ---------------- IMAGE PREVIEW ----------------

class _ImagePreviewCard extends StatelessWidget {
  final File? imageFile;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  const _ImagePreviewCard({
    required this.imageFile,
    required this.onChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final file = imageFile;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 280,
        child: file == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.document_scanner, size: 55),
                    SizedBox(height: 12),
                    Text('Capture or select a leaf image'),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filled(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: ElevatedButton.icon(
                      onPressed: onChange,
                      icon: const Icon(Icons.edit),
                      label: const Text('Change image'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------- ACTION CARD ----------------

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 115,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: colors.primary),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- MODEL STATUS ----------------

class _ModelReadyCard extends StatelessWidget {
  const _ModelReadyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Model Ready',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('✓ ESP32-CAM capture supported'),
            Text('✓ Gallery image supported'),
            Text('✓ Disease detection available'),
          ],
        ),
      ),
    );
  }
}

// ---------------- RESULT CARD ----------------

class _ResultCard extends StatelessWidget {
  final PredictionResult result;
  final VoidCallback onShare;
  final VoidCallback onPdf;
  final VoidCallback onScanAgain;

  const _ResultCard({
    required this.result,
    required this.onShare,
    required this.onPdf,
    required this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = (result.confidence / 100).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detection Result',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              result.disease,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Severity: ${result.severity}'),
            const SizedBox(height: 8),
            Text('Confidence: ${result.confidence}%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 18),
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(result.description),
            const SizedBox(height: 18),
            Text(
              'Recommended Treatment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(result.treatment),
            const SizedBox(height: 16),
            Text(
              'Prevention',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              '• Remove heavily infected leaves.\n'
              '• Avoid overwatering.\n'
              '• Maintain good spacing between plants.\n'
              '• Inspect plants regularly and clean tools.',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onScanAgain,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan Again'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Download PDF Report'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI predictions can be uncertain. Verify important crop-treatment decisions with a qualified agricultural expert.',
              style: TextStyle(color: colors.outline, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
