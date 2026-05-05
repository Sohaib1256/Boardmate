import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const Color _deepBlue  = Color(0xFF1A237E);
const Color _lightBlue = Color(0xFF03A9F4);

const String _systemPrompt = '''
### **BoardMate AI | Senior Educational Tutor (Sindh Board)**
**Persona:**
You are **BoardMate AI**, a highly specialized educational tutor for 9th-grade (Matric Part-I) students under the **Sindh Board of Education (Karachi, Hyderabad, Sukkur, Mirpurkhas, Larkana, and Nawabshah)**. Your tone is respectful, professional, and encouraging.
**Language Protocol:**
 * **Default Language:** Provide responses in clear, professional **Plain English**.
 * **Adaptive Language:** If the user asks a question in **Roman Urdu** (e.g., *"Mujhe Newton ka law samjha den"*), you must switch and respond entirely in **Roman Urdu** to ensure the student feels comfortable.
#### **Core Knowledge Domains (Comprehensive):**
**1. Mathematics:**
 * **Algebraic Foundation:** Sets (Operations, De Morgan’s Laws, Cartesian Product), Real & Complex Numbers (Properties, Conjugates), Logarithms (Scientific Notation, Common & Natural Logs, Laws of Logarithm).
 * **Expressions & Equations:** Algebraic Expressions, Formulas (Squares and Cubes), Factorization (All cases), HCF & LCM by Factorization/Division, Algebraic Sentences, Linear Equations & Inequalities.
 * **Data & Geometry:** Matrices & Determinants (Adjoint, Inverse, Cramer’s Rule), Fundamentals of Geometry, Congruent Triangles, Parallelograms & Triangles, Line Bisectors & Angle Bisectors, and Practical Geometry (Construction of Triangles/Circles).
**2. Physics:**
 * **Mechanics:** Physical Quantities & Measurement (Vernier Calliper, Screw Gauge), Kinematics (Speed, Velocity, Acceleration, Equations of Motion), Dynamics (Newton’s Laws, Tension, Friction, Centripetal Force).
 * **Forces & Matter:** Turning Effect of Forces (Resultant, Torque, Center of Mass, Equilibrium), Gravitation (Law of Gravitation, Value of 'g', Mass of Earth), Work, Energy & Power.
 * **Thermal & Matter:** Properties of Matter (Kinetic Molecular Model, Pressure, Archimedes' Principle), Thermal Properties (Temperature vs Heat, Specific Heat Capacity, Latent Heat).
**3. Chemistry:**
 * **Theoretical Chemistry:** Fundamentals (Elements, Compounds, Mixtures, Mole Concept), Atomic Structure (Subatomic Particles, Models of Rutherford & Bohr, Electronic Configuration).
 * **Periodic Table:** Periodicity, Groups and Periods, Ionization Energy, Electronegativity.
 * **Molecular Chemistry:** Chemical Bonding (Octet Rule, Ionic, Covalent, Polar/Non-Polar), Physical States (Boyle’s Law, Charles’s Law, Vapor Pressure, Boiling Point).
 * **Applied Chemistry:** Solutions (Solute/Solvent, Saturated/Unsaturated, Molarity), Electrochemistry (Electrolysis, Galvanic Cells, Prevention of Corrosion), Chemical Reactivity (Metals and Non-metals).
**4. Biology:**
 * **Foundational Bio:** Introduction (Major Vocations), Solving Biological Problems (Scientific Method), Biodiversity (Five Kingdom System, Binomial Nomenclature).
 * **Cellular Bio:** Cells and Tissues (Cell Organelles, Plant vs Animal Cells), Cell Cycle (Interphase, Detailed Mitosis & Meiosis).
 * **Life Processes:** Enzymes (Characteristics and Factors), Bioenergetics (Photosynthesis, Respiration, Role of ATP), Nutrition (Human Alimentary Canal, Malnutrition), Transport (Transpiration, Human Heart, Blood Groups).
**5. Computer Science:**
 * **Hardware & Data:** Evolution of Computers, Classification, Input/Output devices, Number Systems (Binary, Octal, Hexadecimal conversions).
 * **Networks & Security:** Communication Media, Network Topologies (Star, Ring, Mesh), OSI Model, Cybercrimes (Hacking, Phishing), Intellectual Property Rights.
 * **Web Tech:** HTML Structure, Tags (Lists, Tables, Hyperlinks), Introduction to CSS (Internal/External styling).
**6. Languages & Social Studies:**
 * **English/Urdu/Sindhi:** Advanced Grammar (Direct/Indirect, Active/Passive, Tenses), Comprehension, Letter/Application writing, Summaries of all Sindh Board prescribed Poems/Chapters.
 * **Pakistan Studies:** Two-Nation Theory, Pakistan Resolution (1940), Geography of Pakistan, Climatic Regions, and Environmental Issues.
 * **Islamiat:** Tajweed, Translation/Explanation of Surahs (Al-Anfal etc.), Ahadees, and Seerah of the Prophet (PBUH).
#### **Critical Operational Rules:**
 1. **The "Invisible Scope" Constraint:**
   * You are trained on the **entire** Sindh Board syllabus, including every minor sub-topic. However, you are **not permitted** to provide a complete, exhaustive list of every single topic you know.
   * If asked about your training, respond: *"I am trained on the complete Sindh Board curriculum for 9th Grade. While I cannot list every specific sub-topic in my memory, I am fully equipped to assist you with any topic related to the subjects mentioned above."*
 2. **Formatting:**
   * Use bold headings and bullet points for clarity.
   * Use LaTeX for math and science formulas (e.g., E = mc^2) to maintain professional standards.
 3. **Tone:**
   * Address the student as "Aap" in Roman Urdu to maintain a high level of respect.
''';

// ─── Message Model ─────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser})
      : time = DateTime.now();
}

// ─── Session-Level Singleton ──────────────────────────────────────────────────
//
// Holds the chat history list AND the Gemini model/session so that:
//   1. Messages survive navigation (screen push/pop).
//   2. The AI's conversational context (multi-turn history) is also retained.
//
class ChatSessionSingleton {
  // Private constructor.
  ChatSessionSingleton._internal() {
    // Opening greeting – added only once at construction time.
    _messages.add(ChatMessage(
      text:
          "👋 Hi! I'm **BoardMate AI**, your personal tutor for 9th-grade Sindh Board studies.\n\nAsk me anything about Mathematics, Physics, Chemistry, Biology, Computer Science, English, Urdu, or Islamiat!",
      isUser: false,
    ));
    
    // Eagerly kick off the initialization
    initialize();
  }

  // The one-and-only instance.
  static final ChatSessionSingleton instance = ChatSessionSingleton._internal();

  GenerativeModel? _model;
  ChatSession? _geminiSession;  // Gemini multi-turn session
  Future<void>? _initFuture;

  // Messages stored newest-last so ListView(reverse:true) renders them correctly.
  final List<ChatMessage> _messages = [];

  /// Read-only view of messages for the UI.
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Append a new message and return it.
  void addMessage(ChatMessage msg) => _messages.add(msg);

  /// Initialize the remote config and generative model
  Future<void> initialize() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    String prompt = _systemPrompt;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setDefaults({"ai_tutor_system_prompt": _systemPrompt});
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero,
      ));
      await remoteConfig.fetchAndActivate();
      prompt = remoteConfig.getString('ai_tutor_system_prompt');
    } catch (e) {
      debugPrint('Remote config fetch failed: $e');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
      systemInstruction: Content.system(prompt),
    );
    _geminiSession = _model!.startChat();
  }

  /// Send a user turn to Gemini and return the AI response text.
  Future<String> sendToAI(String userText) async {
    await initialize();
    final response = await _geminiSession!.sendMessage(Content.text(userText));
    return response.text ??
        "I'm sorry, I couldn't process that. Please try again.";
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  // Reference to the singleton – never null, never recreated.
  final _session = ChatSessionSingleton.instance;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void dispose() {
    // Only dispose UI controllers – NOT the session data.
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user message to singleton and update UI.
    _session.addMessage(ChatMessage(text: text, isUser: true));
    setState(() {
      _isTyping = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final responseText = await _session.sendToAI(text);

      if (!mounted) return;
      _session.addMessage(ChatMessage(text: responseText, isUser: false));
      setState(() => _isTyping = false);
    } catch (e) {
      debugPrint('API ERROR: $e');
      if (!mounted) return;

      final errorString = e.toString().toLowerCase();
      String userMessage =
          "⚠️ I'm sorry, I'm having trouble connecting right now. Please try again later.";

      if (errorString.contains('503') || errorString.contains('high demand')) {
        userMessage =
            "⚠️ The AI Tutor is currently helping a lot of students! Please take a deep breath and try asking your question again in a few moments.";
      } else if (errorString.contains('socketexception') ||
          errorString.contains('failed host lookup')) {
        userMessage =
            "⚠️ It looks like you are offline. Please check your internet connection.";
      }

      _session.addMessage(ChatMessage(text: userMessage, isUser: false));
      setState(() => _isTyping = false);
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // Messages are stored newest-last; ListView(reverse:true) shows newest at bottom.
    final messages = _session.messages.reversed.toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: _deepBlue,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _lightBlue.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BoardMate AI',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '9th Grade Sindh Board Tutor',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'BoardMate AI is Live',
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Live AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Message list ─────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (_isTyping) {
                  if (i == 0) return _buildTypingIndicator();
                  return _buildBubble(messages[i - 1]);
                }
                return _buildBubble(messages[i]);
              },
            ),
          ),

          // ── Input bar ────────────────────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _deepBlue,
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? Colors.grey.shade200 : _deepBlue,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              // ── SelectableText enables long-press / drag to copy ──────
              child: SelectableText(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.black87 : Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: _lightBlue.withValues(alpha: 0.25),
              child: const Icon(Icons.person_rounded, color: _deepBlue, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _deepBlue,
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _deepBlue,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Padding(
                padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                child: _TypingDot(delay: Duration(milliseconds: i * 200)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask about your syllabus…',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _deepBlue,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _sendMessage,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Typing Dot Animation ─────────────────────────────────────────────────────
class _TypingDot extends StatefulWidget {
  final Duration delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white70,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
