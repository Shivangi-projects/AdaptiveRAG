import 'package:flutter/material.dart';
import '../../services/settings_service.dart';

class OnboardingScreen extends StatefulWidget {
  final SettingsService settingsService;
  final VoidCallback onFinished;

  const OnboardingScreen({
    super.key,
    required this.settingsService,
    required this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'EdgeRAG',
      'subtitle': 'Private AI. Anywhere.',
      'description': 'Ask questions from your documents without sending a single byte to the cloud.',
      'icon': Icons.shield_outlined,
      'color': Color(0xFF38BDF8),
    },
    {
      'title': '100% Local Processing',
      'subtitle': 'Zero Cloud Dependencies',
      'description': 'Documents, embeddings, vector database, and language models execute directly on your smartphone processor.',
      'icon': Icons.wifi_off_outlined,
      'color': Color(0xFF10B981),
    },
    {
      'title': 'Portable Knowledge Packs',
      'subtitle': 'Instant Pre-Indexed Domain SOPs',
      'description': 'Import ready-to-use domain packs (.edgepack) for disaster response, first aid, maritime, or field engineering.',
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFFF59E0B),
    },
    {
      'title': 'On-Device GGUF SLM',
      'subtitle': 'Powered by llama.cpp & MiniLM',
      'description': 'Run quantized local language models (Llama 3.2, Qwen 2.5) with streaming generation or use instant Retrieval-Only mode.',
      'icon': Icons.memory_outlined,
      'color': Color(0xFF8B5CF6),
    },
    {
      'title': 'Ready to Begin',
      'subtitle': 'Offline Intelligence in Your Pocket',
      'description': 'Your personal private knowledge assistant is ready to safeguard and search your information.',
      'icon': Icons.check_circle_outline,
      'color': Color(0xFF06B6D4),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1325),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () async {
                  await widget.settingsService.completeOnboarding();
                  widget.onFinished();
                },
                child: const Text('Skip', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final color = page['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withOpacity(0.3), width: 2),
                          ),
                          child: Icon(page['icon'] as IconData, size: 64, color: color),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          page['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          page['subtitle'] as String,
                          style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['description'] as String,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (idx) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == idx ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == idx ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (_currentPage < _pages.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      await widget.settingsService.completeOnboarding();
                      widget.onFinished();
                    }
                  },
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Continue',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
