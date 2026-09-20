import 'package:flutter/material.dart';
import '../../models/chunk.dart';
import '../../services/rag_service.dart';
import '../../services/settings_service.dart';
import '../../services/model_service.dart';
import '../../widgets/source_card.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<ChunkItem> sources;
  final bool isRetrievalOnly;
  final int totalTimeMs;
  final double tokensPerSecond;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.isRetrievalOnly = false,
    this.totalTimeMs = 0,
    this.tokensPerSecond = 0.0,
  });
}

class ChatScreen extends StatefulWidget {
  final RagService ragService;
  final SettingsService settingsService;
  final ModelService modelService;

  const ChatScreen({
    super.key,
    required this.ragService,
    required this.settingsService,
    required this.modelService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  String _currentStreamingText = '';

  @override
  void initState() {
    super.initState();
    // Default welcome prompt
    _messages.add(
      ChatMessage(
        text: 'Hello! I am EdgeRAG, your private offline knowledge assistant. Ask me questions based on your indexed SOPs and knowledge base.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final query = _textController.text.trim();
    if (query.isEmpty || _isGenerating) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: query, isUser: true));
      _isGenerating = true;
      _currentStreamingText = '';
    });
    _scrollToBottom();

    final settings = widget.settingsService.settings;

    widget.ragService.executeQueryStream(
      question: query,
      settings: settings,
      onComplete: (result) {
         print("SOURCE COUNT = ${result.sources.length}");

  for (final source in result.sources) {
    print(source.filename);
  }
        if (!mounted) return;

setState(() {
  _messages.add(
    ChatMessage(
      text: result.answer,
      isUser: false,
      sources: result.sources,
      isRetrievalOnly: result.isRetrievalOnly,
      totalTimeMs: result.totalTimeMs,
      tokensPerSecond: result.tokensPerSecond,
    ),
  );
});
        _scrollToBottom();
      },
    ).listen((partial) {
      if (!mounted) return;
      setState(() {
        _currentStreamingText = partial;
      });
      _scrollToBottom();
    }, onDone: () {
  if (!mounted) return;

  setState(() {
    _isGenerating = false;
    _currentStreamingText = '';
  });

  _scrollToBottom();
},onError: (err) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _messages.add(ChatMessage(text: 'Error: $err', isUser: false));
      });
      _scrollToBottom();
    });
  }

  void _stopGeneration() {
    widget.ragService.stopGeneration();
    setState(() {
      _isGenerating = false;
      if (_currentStreamingText.isNotEmpty) {
        _messages.add(ChatMessage(text: _currentStreamingText, isUser: false));
        _currentStreamingText = '';
      }
    });
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          text: 'Conversation cleared. Ask a new emergency health query.',
          isUser: false,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1325),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B35),
        elevation: 0,
        title: const Text(
          'Offline Chat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
            tooltip: 'New Chat',
            onPressed: _newChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat history
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isGenerating ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isGenerating) {
                    return _buildStreamingBubble();
                  }
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),

            // Generating indicator & Stop button
            if (_isGenerating)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                    ),
                    const SizedBox(width: 8),
                    const Text('Inferencing locally...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      onPressed: _stopGeneration,
                      icon: const Icon(Icons.stop, color: Colors.redAccent, size: 14),
                      label: const Text('Stop', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Input bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1B35),
                border: Border(top: BorderSide(color: Color(0xFF1E2D4A))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ask an emergency query (e.g. heat stroke)...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF131D33),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isGenerating ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    print("Sources count: ${msg.sources.length}");
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF2563EB) : const Color(0xFF131D33),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: !msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: Border.all(
            color: msg.isUser ? const Color(0xFF3B82F6) : const Color(0xFF1E2D4A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            if (msg.sources.isNotEmpty) ...[
  const SizedBox(height: 12),
  const Divider(
    color: Color(0xFF1E2D4A),
    height: 1,
  ),
  const SizedBox(height: 8),

  Theme(
  data: Theme.of(context).copyWith(
    dividerColor: Colors.transparent,
  ),
  child: Material(
    color: Colors.transparent,
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: const Color(0xFF38BDF8),
      collapsedIconColor: const Color(0xFF38BDF8),
      title: Row(
        children: [
          const Icon(
            Icons.menu_book,
            size: 14,
            color: Color(0xFF38BDF8),
          ),
          const SizedBox(width: 6),
          Text(
            'Sources (${msg.sources.length} retrieved)',
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      children: msg.sources
          .asMap()
          .entries
          .map(
            (entry) => SourceCard(
              chunk: entry.value,
              index: entry.key + 1,
            ),
          )
          .toList(),
    ),
  ),
),
],
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF131D33),
          borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
        ),
        child: Text(
          _currentStreamingText.isEmpty ? 'Searching vector database...' : _currentStreamingText,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}
