// ╔══════════════════════════════════════════════════════╗
// ║         MathMind — Flutter App (iOS + Android)       ║
// ║  File: lib/main.dart                                 ║
// ╚══════════════════════════════════════════════════════╝
//
// Setup:
//   flutter create mathmind
//   Replace lib/main.dart with this file
//   Add to pubspec.yaml dependencies:
//     http: ^1.2.1
//     image_picker: ^1.1.2
//
// Then run: flutter pub get
import 'config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// ── IMPORTANT: Replace with your Railway URL after deploying ───────────────
 const String serverUrl = "https://mathmind-backend-qbs3.onrender.com";

void main() {
  runApp(const MathMindApp());
}

// ── App ────────────────────────────────────────────────────────────────────
class MathMindApp extends StatelessWidget {
  const MathMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MathMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0A0E1A),
          // use this instead of background
          primary: Color(0xFF63B3ED),
          secondary: Color(0xFF76E4F7),
          error: Color(0xFFFc8181),
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const SolverPage(),
    );
  }
}

// ── Colors ─────────────────────────────────────────────────────────────────
const kBg      = Color(0xFF0A0E1A);
const kSurface = Color(0xFF111827);
const kSurface2= Color(0xFF1A2235);
const kBorder  = Color(0xFF1E3050);
const kBlue    = Color(0xFF63B3ED);
const kCyan    = Color(0xFF76E4F7);
const kGreen   = Color(0xFF68D391);
const kRed     = Color(0xFFFC8181);
const kText    = Color(0xFFE2E8F0);
const kSoft    = Color(0xFF94A3B8);
const kDim     = Color(0xFF4A5568);

// ── Grade data ─────────────────────────────────────────────────────────────
const List<Map<String, String>> kGrades = [
  {"id": "5th",  "label": "5th",  "info": "Arithmetic, fractions, decimals"},
  {"id": "6th",  "label": "6th",  "info": "Ratios, percentages, intro algebra"},
  {"id": "7th",  "label": "7th",  "info": "Linear equations, integers"},
  {"id": "8th",  "label": "8th",  "info": "Systems, Pythagoras, factoring"},
  {"id": "9th",  "label": "9th",  "info": "Quadratics, coordinate geometry"},
  {"id": "10th", "label": "10th", "info": "Trigonometry, circles, statistics"},
  {"id": "11th", "label": "11th", "info": "Limits, derivatives, probability"},
  {"id": "12th", "label": "12th", "info": "Integration, vectors, diff eq"},
  {"id": "Uni",  "label": "Uni",  "info": "Calculus, linear algebra"},
  {"id": "Adv",  "label": "Adv",  "info": "Advanced — full rigor"},
];

// ── Main Solver Page ───────────────────────────────────────────────────────
class SolverPage extends StatefulWidget {
  const SolverPage({super.key});
  @override
  State<SolverPage> createState() => _SolverPageState();
}

class _SolverPageState extends State<SolverPage> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _selectedGrade = "9th";
  String _mode = "text"; // "text" or "image"
  XFile? _pickedImage;
  String _result = "";
  bool _solving = false;
  String _error = "";

  // ── Solve text ────────────────────────────────────────────────────────
  Future<void> _solveText() async {
    final problem = _controller.text.trim();
    if (problem.isEmpty) return;

    setState(() { _solving = true; _error = ""; _result = ""; });

    try {
      final res = await http.post(
        Uri.parse("${ServerConfig.serverUrl}/solve"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"problem": problem, "grade": _selectedGrade}),
      ).timeout(const Duration(seconds: 60));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() { _result = data["answer"] ?? ""; });
      } else {
        setState(() { _error = data["error"] ?? "Something went wrong"; });
      }
    } catch (e) {
      setState(() { _error = e.toString().contains('SocketException') || e.toString().contains('Failed host') ? 'No internet connection. Please check your WiFi or Mobile Data.' : 'Something went wrong. Please try again.'; });
    } finally {
      setState(() { _solving = false; });
      _scrollToResult();
    }
  }

  // ── Solve image ───────────────────────────────────────────────────────
  Future<void> _solveImage() async {
    if (_pickedImage == null) return;

    setState(() { _solving = true; _error = ""; _result = ""; });

    try {
      final bytes = await File(_pickedImage!.path).readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = _pickedImage!.mimeType ?? "image/jpeg";

      final res = await http.post(
        Uri.parse("${ServerConfig.serverUrl}/solve-image"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "image_b64": b64,
          "mime_type": mime,
          "grade": _selectedGrade,
          "note": "",
        }),
      ).timeout(const Duration(seconds: 90));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() { _result = data["answer"] ?? ""; });
      } else {
        setState(() { _error = data["error"] ?? "Something went wrong"; });
      }
    } catch (e) {
      setState(() { _error = "Network error: $e"; });
    } finally {
      setState(() { _solving = false; });
      _scrollToResult();
    }
  }
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 85);
    if (img != null) {
      setState(() {
        _pickedImage = img;
      });
    }
  }
  void _scrollToResult() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  void _copyResult() {
    Clipboard.setData(ClipboardData(text: _result));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✓ Copied to clipboard"),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildGradeSelector(),
              const SizedBox(height: 16),
              _buildModeToggle(),
              const SizedBox(height: 12),
              _mode == "text" ? _buildTextInput() : _buildImageInput(),
              const SizedBox(height: 12),
              _buildSolveButton(),
              const SizedBox(height: 20),
              if (_solving) _buildLoading(),
              if (_error.isNotEmpty) _buildError(),
              if (_result.isNotEmpty) _buildResult(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: kBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: kBlue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text("AI Powered", style: TextStyle(color: kBlue, fontSize: 11, letterSpacing: 1)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text("MathMind",
            style: TextStyle(color: kText, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        const Text("Step-by-step equation solver",
            style: TextStyle(color: kSoft, fontSize: 14)),
      ],
    );
  }

  // ── Grade selector ────────────────────────────────────────────────────
  Widget _buildGradeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("📚  SELECT YOUR GRADE"),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kGrades.map((g) {
              final active = _selectedGrade == g["id"];
              return GestureDetector(
                onTap: () => setState(() => _selectedGrade = g["id"]!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? kBlue.withOpacity(0.15) : kSurface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? kBlue.withOpacity(0.5) : kBorder,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Text(g["label"]!,
                      style: TextStyle(
                        color: active ? kBlue : kSoft,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "📚  ${kGrades.firstWhere((g) => g['id'] == _selectedGrade)['info']}",
              style: const TextStyle(color: kBlue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode toggle ───────────────────────────────────────────────────────
  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          _modeBtn("✏️  Type", "text"),
          _modeBtn("📷  Image", "image"),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, String val) {
    final active = _mode == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? kBlue.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: active ? kBlue.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? kBlue : kSoft,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  // ── Text input ────────────────────────────────────────────────────────
  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("ENTER EQUATION OR PROBLEM"),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            style: const TextStyle(color: kText, fontFamily: 'Courier', fontSize: 15),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "e.g.  2x + 5 = 13   or   x² - 5x + 6 = 0",
              hintStyle: const TextStyle(color: kDim, fontSize: 13),
              filled: true,
              fillColor: kSurface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBlue, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: ["2x + 5 = 13", "x² - 5x + 6 = 0", "∫x² dx", "sin²θ + cos²θ"]
                .map((ex) => GestureDetector(
              onTap: () => setState(() => _controller.text = ex),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kSurface2,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: kBorder),
                ),
                child: Text(ex, style: const TextStyle(
                    color: kSoft, fontSize: 11, fontFamily: 'Courier')),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── Image input ───────────────────────────────────────────────────────
  Widget _buildImageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("UPLOAD EQUATION PHOTO"),
          const SizedBox(height: 12),
          if (_pickedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(_pickedImage!.path),
                  height: 200, width: double.infinity, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(child: _imgBtn("📷  Camera", () => _pickImage(ImageSource.camera))),
              const SizedBox(width: 8),
              Expanded(child: _imgBtn("🖼  Gallery", () => _pickImage(ImageSource.gallery))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imgBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: kSoft, fontSize: 13)),
      ),
    );
  }

  // ── Solve button ──────────────────────────────────────────────────────
  Widget _buildSolveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _solving ? null : (_mode == "text" ? _solveText : _solveImage),
        style: ElevatedButton.styleFrom(
          backgroundColor: kBlue,
          foregroundColor: kBg,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          _solving ? "Solving..." : (_mode == "text" ? "⚡  Solve Now" : "⚡  Solve from Image"),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: kBlue, strokeWidth: 2),
          SizedBox(height: 14),
          Text("Crunching the math...",
              style: TextStyle(color: kSoft, fontSize: 14, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: kRed, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error, style: const TextStyle(color: kRed, fontSize: 13))),
        ],
      ),
    );
  }

  // ── Result ────────────────────────────────────────────────────────────
  Widget _buildResult() {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: kGreen, size: 16),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: kGreen.withOpacity(0.3)),
                  ),
                  child: const Text("Solved",
                      style: TextStyle(color: kGreen, fontSize: 12)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _copyResult,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: const Text("Copy",
                        style: TextStyle(color: kSoft, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_result,
                style: const TextStyle(color: kText, fontSize: 14, height: 1.8)),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(color: kBlue, fontSize: 10,
            letterSpacing: 1.2, fontWeight: FontWeight.bold));
  }
}
