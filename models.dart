// Ported from data/Models.kt

class PredictionResult {
  final String disease;
  final double confidence;
  final String description;
  final String treatment;
  final String severity;

  const PredictionResult({
    required this.disease,
    required this.confidence,
    required this.description,
    required this.treatment,
    required this.severity,
  });
}

class ScanHistoryItem {
  final int id;
  final String disease;
  final double confidence;
  final String date;
  final String severity;

  const ScanHistoryItem({
    required this.id,
    required this.disease,
    required this.confidence,
    required this.date,
    required this.severity,
  });
}

// ---------------------------------------------------------------------
// DEMO MODE: set this to false once your FastAPI backend is deployed
// and you've wired up real HTTP calls (see WeatherRepository for the
// pattern to follow — swap MockRepository.predictDisease() for a real
// call to your backend's /predict endpoint).
// While true, the app runs entirely on realistic sample data —
// safe to demo with no internet/backend dependency.
// ---------------------------------------------------------------------
class DemoConfig {
  static const bool useMockData = true;
}

class MockRepository {
  // Simulates network delay + returns a realistic result
  static Future<PredictionResult> predictDisease() async {
    await Future.delayed(const Duration(milliseconds: 1800)); // feels like a real inference call
    return const PredictionResult(
      disease: 'Tomato - Early Blight',
      confidence: 94.3,
      description:
          'Fungal disease causing brown concentric ring spots on lower, older leaves. Spreads in warm, humid conditions.',
      treatment:
          'Remove and destroy infected leaves. Apply a copper-based or chlorothalonil fungicide every 7-10 days. Improve airflow by spacing plants properly and avoid overhead watering.',
      severity: 'Moderate',
    );
  }

  static const List<ScanHistoryItem> sampleHistory = [
    ScanHistoryItem(id: 1, disease: 'Tomato - Early Blight', confidence: 94.3, date: '04 Aug 2026', severity: 'Moderate'),
    ScanHistoryItem(id: 2, disease: 'Apple - Black Rot', confidence: 88.7, date: '02 Aug 2026', severity: 'High'),
    ScanHistoryItem(id: 3, disease: 'Potato - Healthy', confidence: 99.1, date: '30 Jul 2026', severity: 'None'),
    ScanHistoryItem(id: 4, disease: 'Grape - Leaf Blight', confidence: 76.5, date: '28 Jul 2026', severity: 'Moderate'),
    ScanHistoryItem(id: 5, disease: 'Corn - Common Rust', confidence: 91.2, date: '25 Jul 2026', severity: 'Low'),
  ];
}
