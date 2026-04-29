import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const LuzApp());
}

class LuzApp extends StatelessWidget {
  const LuzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LuzRD Inteligente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _lastBillReadingController = TextEditingController(text: '4575');
  final TextEditingController _currentReadingController = TextEditingController();
  
  double t1Rate = 5.97;
  double fixedCharge = 40.33; 

  double _currentConsumption = 0;
  double _currentCost = 0;
  double _projectedConsumption = 0;
  double _projectedCost = 0;
  int _daysInCycle = 0;
  bool _hasData = false;

  late SharedPreferences _prefs;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastBillReadingController.text = _prefs.getString('lastReading') ?? '4575';
      String? historyJson = _prefs.getString('history');
      if (historyJson != null) {
        _history = List<Map<String, dynamic>>.from(json.decode(historyJson));
      }
    });
  }

  Future<void> _saveBaseReading() async {
    await _prefs.setString('lastReading', _lastBillReadingController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lectura del recibo guardada como base.')),
    );
  }

  Future<void> _recordReading() async {
    if (_currentReadingController.text.isEmpty) return;
    
    final newReading = {
      'date': DateTime.now().toIso8601String(),
      'value': double.tryParse(_currentReadingController.text) ?? 0,
      'consumption': _currentConsumption,
      'cost': _currentCost,
    };

    setState(() {
      _history.insert(0, newReading);
      if (_history.length > 10) _history.removeLast();
    });

    await _prefs.setString('history', json.encode(_history));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lectura guardada en el historial.')),
    );
  }

  void _calculateProjection() {
    double lastReading = double.tryParse(_lastBillReadingController.text) ?? 4575;
    double currentReading = double.tryParse(_currentReadingController.text) ?? 0;

    if (currentReading < lastReading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La lectura de hoy es menor a la base.')),
      );
      return;
    }

    _currentConsumption = currentReading - lastReading;
    _currentCost = (_currentConsumption * t1Rate) + fixedCharge;

    DateTime now = DateTime.now();
    DateTime lastCut = DateTime(now.year, now.month, 12);
    if (now.day < 12) lastCut = DateTime(now.year, now.month - 1, 12);
    
    _daysInCycle = now.difference(lastCut).inDays;
    if (_daysInCycle <= 0) _daysInCycle = 1;

    double kwhPerDay = _currentConsumption / _daysInCycle;
    _projectedConsumption = kwhPerDay * 30;
    _projectedCost = (_projectedConsumption * t1Rate) + fixedCharge;

    setState(() {
      _hasData = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildInputCard(),
                const SizedBox(height: 24),
                if (_hasData) ...[
                  _buildLiveStatus(),
                  const SizedBox(height: 16),
                  _buildProjectionCard(),
                  const SizedBox(height: 16),
                  _buildSaveButton(),
                ],
                const SizedBox(height: 32),
                if (_history.isNotEmpty) _buildHistorySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LuzRD Inteligente', style: GoogleFonts.outfit(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            Text('Mi Consumo', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        IconButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Configurar Base'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cambia la lectura inicial si tienes un recibo nuevo.'),
                    TextField(
                      controller: _lastBillReadingController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Lectura del Recibo'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  ElevatedButton(
                    onPressed: () {
                      _saveBaseReading();
                      Navigator.pop(context);
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.settings, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildField('Lectura Hoy (Contador)', _currentReadingController, Icons.speed, autofocus: true, hint: 'Ingresa los números'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _calculateProjection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Calcular Ahora', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool autofocus = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 22, color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blueAccent),
            hintText: hint,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatus() {
    return Row(
      children: [
        Expanded(child: _buildMiniCard('Llevas hoy', 'RD\$ ${_currentCost.toStringAsFixed(2)}', Icons.today)),
        const SizedBox(width: 16),
        Expanded(child: _buildMiniCard('Ciclo', '$_daysInCycle / 30 días', Icons.calendar_month)),
      ],
    );
  }

  Widget _buildMiniCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProjectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)]),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3), blurRadius: 20)],
      ),
      child: Column(
        children: [
          const Text('PRÓXIMO RECIBO ESTIMADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text('RD\$ ${_projectedCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Proyección: ${_projectedConsumption.toStringAsFixed(1)} kWh', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _recordReading,
        icon: const Icon(Icons.history),
        label: const Text('Guardar en Historial'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de Lecturas', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        ..._history.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd MMM, hh:mm a').format(DateTime.parse(item['date'])), style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  Text('${item['value'].toStringAsFixed(0)} en contador', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Text('RD\$ ${item['cost'].toStringAsFixed(2)}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        )),
      ],
    );
  }
}
