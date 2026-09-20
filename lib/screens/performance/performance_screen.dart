import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/benchmark_service.dart';
import '../../services/knowledge_service.dart';
import '../../widgets/metric_tile.dart';

class PerformanceScreen extends StatefulWidget {
  final BenchmarkService benchmarkService;
  final KnowledgeService knowledgeService;

  const PerformanceScreen({
    super.key,
    required this.benchmarkService,
    required this.knowledgeService,
  });

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  @override
  Widget build(BuildContext context) {
    final metrics = widget.benchmarkService.getLatestMetrics();
    final recent = widget.benchmarkService.recentQueries;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1325),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B35),
        elevation: 0,
        title: const Text(
          'Performance & Benchmarks',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MEASURED RUNTIME METRICS',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8,
              children: [
                MetricTile(
                  title: 'Query Embedding',
                  value: '${metrics.queryEmbeddingMs}',
                  unit: 'ms',
                  icon: Icons.electric_bolt,
                  color: const Color(0xFF38BDF8),
                ),
                MetricTile(
                  title: 'Vector Search',
                  value: '${metrics.vectorSearchMs}',
                  unit: 'ms',
                  icon: Icons.search,
                  color: const Color(0xFF10B981),
                ),
                MetricTile(
                  title: 'Retrieval Latency',
                  value: '${metrics.retrievalLatencyMs}',
                  unit: 'ms',
                  icon: Icons.speed,
                  color: const Color(0xFFF59E0B),
                ),
                MetricTile(
                  title: 'Time to First Token',
                  value: '${metrics.timeToFirstTokenMs}',
                  unit: 'ms',
                  icon: Icons.hourglass_top,
                  color: const Color(0xFFA78BFA),
                ),
                MetricTile(
                  title: 'Generation Speed',
                  value: metrics.tokensPerSecond.toStringAsFixed(1),
                  unit: 'tok/s',
                  icon: Icons.flash_on,
                  color: const Color(0xFFEC4899),
                ),
                MetricTile(
                  title: 'Total Latency',
                  value: '${metrics.totalLatencyMs}',
                  unit: 'ms',
                  icon: Icons.timer,
                  color: const Color(0xFF60A5FA),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Performance Chart
            const Text(
              'RECENT QUERY LATENCY (MS)',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111E38),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2D4A)),
              ),
              child: recent.isEmpty
                  ? const Center(
                      child: Text(
                        'No query metrics recorded yet.\nRun a query in Chat to populate live benchmarks.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(color: const Color(0xFF1E2D4A), strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (val, meta) => Text(
                                '${val.toInt()}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: recent.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), e.value.totalTimeMs.toDouble());
                            }).toList(),
                            isCurved: true,
                            color: const Color(0xFF38BDF8),
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // Device Specifications Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111E38),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2D4A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DEVICE EXECUTION PROFILE',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 12),
                  _specRow('Target Architecture', 'arm64-v8a (ARM64)'),
                  _specRow('Vector Dimensions', '384 Dense Float32'),
                  _specRow('Embedding Model', 'sentence-transformers/all-MiniLM-L6-v2 (ONNX)'),
                  _specRow('Similarity Metric', 'Cosine Similarity (Normalized Dot Product)'),
                  _specRow('Storage Engine', 'SQLite-vec + Embedded WAL'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
