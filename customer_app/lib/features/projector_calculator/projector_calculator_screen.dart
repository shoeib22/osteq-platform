import 'package:flutter/material.dart';
import 'projector_math.dart';

enum InstallationType { desktop, ceiling }

class ProjectorCalculatorScreen extends StatefulWidget {
  const ProjectorCalculatorScreen({super.key});

  @override
  State<ProjectorCalculatorScreen> createState() => _ProjectorCalculatorScreenState();
}

class _ProjectorCalculatorScreenState extends State<ProjectorCalculatorScreen> {
  InstallationType _installationType = InstallationType.desktop;
  ProjectorAspectRatio _ratio = ProjectorAspectRatio.ratio16x9;

  // Room dimension (meters).
  final _roomHController = TextEditingController(text: '2.7');
  final _roomWController = TextEditingController(text: '4.0');
  final _roomLController = TextEditingController(text: '5.0');

  // Projector throw ratio (wide = drives the live calc; tele = zoom-range info only).
  final _throwRatioWideController = TextEditingController(text: '1.2');
  final _throwRatioTeleController = TextEditingController(text: '1.5');

  // Screen size (inches) — all three kept in sync with each other and with distance.
  final _diagonalController = TextEditingController(text: '100');
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  // Projector to screen (meters).
  final _distanceController = TextEditingController();

  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _recomputeFromDiagonal();
  }

  @override
  void dispose() {
    _roomHController.dispose();
    _roomWController.dispose();
    _roomLController.dispose();
    _throwRatioWideController.dispose();
    _throwRatioTeleController.dispose();
    _diagonalController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text.trim());

  double get _throwRatioWide => _parse(_throwRatioWideController) ?? 0;

  void _setText(TextEditingController c, String value) {
    if (c.text == value) return;
    c.value = c.value.copyWith(text: value, selection: TextSelection.collapsed(offset: value.length));
  }

  // All four (diagonal, width, height, distance) are kept consistent with each other
  // using the wide-angle throw ratio — same simplification the real BenQ tool makes:
  // entering a screen size always assumes the widest (largest-image) zoom position,
  // matching how calculateAllValuesByDMm/ByWidth/ByHeight in its update.js always use
  // throw_ratio_wide, never throw_ratio_tele, for that single-value relationship.
  void _applyScreen(ScreenDimensions screen) {
    if (_updating) return;
    _updating = true;
    _setText(_diagonalController, screen.diagonalInches.toStringAsFixed(1));
    _setText(_widthController, screen.widthInches.toStringAsFixed(1));
    _setText(_heightController, screen.heightInches.toStringAsFixed(1));
    if (_throwRatioWide > 0) {
      final distance = throwDistanceMeters(screen.widthMeters, _throwRatioWide);
      _setText(_distanceController, distance.toStringAsFixed(2));
    }
    _updating = false;
    setState(() {});
  }

  void _recomputeFromDiagonal() {
    final diagonal = _parse(_diagonalController);
    if (diagonal == null || diagonal <= 0) return;
    _applyScreen(screenFromDiagonal(_ratio, diagonal));
  }

  void _recomputeFromWidth() {
    final width = _parse(_widthController);
    if (width == null || width <= 0) return;
    _applyScreen(screenFromWidth(_ratio, width));
  }

  void _recomputeFromHeight() {
    final height = _parse(_heightController);
    if (height == null || height <= 0) return;
    final diagonal = height * _ratio.diagonalUnits / _ratio.heightUnits;
    _applyScreen(screenFromDiagonal(_ratio, diagonal));
  }

  void _recomputeFromDistance() {
    if (_updating) return;
    final distance = _parse(_distanceController);
    if (distance == null || distance <= 0 || _throwRatioWide <= 0) return;
    final widthMeters = widthFromThrowDistance(distance, _throwRatioWide);
    _updating = true;
    final screen = screenFromWidth(_ratio, widthMeters / 0.0254);
    _setText(_diagonalController, screen.diagonalInches.toStringAsFixed(1));
    _setText(_widthController, screen.widthInches.toStringAsFixed(1));
    _setText(_heightController, screen.heightInches.toStringAsFixed(1));
    _updating = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projector Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Installation Type'),
          SegmentedButton<InstallationType>(
            segments: const [
              ButtonSegment(value: InstallationType.desktop, label: Text('Desktop / Table')),
              ButtonSegment(value: InstallationType.ceiling, label: Text('Ceiling Mount')),
            ],
            selected: {_installationType},
            onSelectionChanged: (s) => setState(() => _installationType = s.first),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Room Dimension (meters)'),
          Row(
            children: [
              Expanded(child: _numberField(_roomHController, 'Height', onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: _numberField(_roomWController, 'Width', onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: _numberField(_roomLController, 'Length', onChanged: (_) => setState(() {}))),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('Projector'),
          DropdownButtonFormField<ProjectorAspectRatio>(
            initialValue: _ratio,
            decoration: const InputDecoration(labelText: 'Aspect ratio'),
            items: ProjectorAspectRatio.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
            onChanged: (r) {
              setState(() => _ratio = r!);
              _recomputeFromDiagonal();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  _throwRatioWideController,
                  'Throw ratio (wide)',
                  onChanged: (_) => _recomputeFromDiagonal(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  _throwRatioTeleController,
                  'Throw ratio (tele)',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'From the projector spec sheet. Fixed-lens projector? Enter the same value in both fields.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          _sectionLabel('Screen Size (inches)'),
          Text(
            'Edit any one of diagonal, width, or height — the others update automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _numberField(_diagonalController, 'Diagonal', onChanged: (_) => _recomputeFromDiagonal()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _numberField(_widthController, 'Width', onChanged: (_) => _recomputeFromWidth())),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_heightController, 'Height', onChanged: (_) => _recomputeFromHeight())),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('Projector to Screen'),
          Text(
            'Throw distance — editing this updates the screen size above, and vice versa.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _numberField(
            _distanceController,
            'Distance (meters)',
            onChanged: (_) => _recomputeFromDistance(),
          ),
          const SizedBox(height: 24),
          _buildSummary(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _numberField(TextEditingController c, String label, {required ValueChanged<String> onChanged}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }

  Widget _buildSummary() {
    final rows = <String>[];

    final diagonal = _parse(_diagonalController);
    final distance = _parse(_distanceController);
    final roomL = _parse(_roomLController);
    final roomW = _parse(_roomWController);
    final roomH = _parse(_roomHController);
    final widthIn = _parse(_widthController);
    final heightIn = _parse(_heightController);
    final throwRatioTele = _parse(_throwRatioTeleController);

    if (diagonal != null && distance != null) {
      rows.add(
        '${diagonal.toStringAsFixed(0)}" ${_ratio.label} screen at ${distance.toStringAsFixed(2)} m throw distance.',
      );
    }

    if (throwRatioTele != null && throwRatioTele > _throwRatioWide && diagonal != null) {
      final range = throwDistanceRangeForScreen(
        ratio: _ratio,
        diagonalInches: diagonal,
        throwRatioWide: _throwRatioWide,
        throwRatioTele: throwRatioTele,
      );
      rows.add(
        'With this zoom lens, ${range.minMeters.toStringAsFixed(2)}–${range.maxMeters.toStringAsFixed(2)} m '
        'all work for this screen size.',
      );
    }

    rows.add(
      _installationType == InstallationType.desktop
          ? 'Desktop install: mount the projector near table/shelf height, level with the bottom of the screen.'
          : 'Ceiling mount: confirm the ceiling drop clears your room height and lens shift range before installing.',
    );

    final warnings = <String>[];
    if (distance != null && roomL != null && roomL > 0 && distance > roomL) {
      warnings.add(
        'Throw distance (${distance.toStringAsFixed(2)} m) exceeds room length (${roomL.toStringAsFixed(2)} m).',
      );
    }
    if (widthIn != null && roomW != null && roomW > 0) {
      final widthM = widthIn * 0.0254;
      if (widthM > roomW) {
        warnings.add('Screen width (${widthM.toStringAsFixed(2)} m) exceeds room width (${roomW.toStringAsFixed(2)} m).');
      }
    }
    if (heightIn != null && roomH != null && roomH > 0) {
      final heightM = heightIn * 0.0254;
      if (heightM > roomH) {
        warnings.add('Screen height (${heightM.toStringAsFixed(2)} m) exceeds room height (${roomH.toStringAsFixed(2)} m).');
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(row, style: Theme.of(context).textTheme.bodyLarge),
              ),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  warning,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
