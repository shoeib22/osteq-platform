import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../catalog/catalog_provider.dart';
import '../catalog/product_model.dart';
import 'projector_math.dart';
import 'throw_distance_diagram.dart';

enum InstallationType { desktop, ceiling }

/// Length unit for display/entry — internal math always stays in meters (throw/room
/// fields) or inches (screen-size fields); this only converts at the text-field layer.
enum DistanceUnit {
  feet('Feet', 'ft', 0.3048),
  inches('Inches', 'in', 0.0254),
  centimeters('Centimeters', 'cm', 0.01),
  meters('Meters', 'm', 1.0);

  const DistanceUnit(this.label, this.abbr, this.metersPerUnit);

  final String label;
  final String abbr;
  final double metersPerUnit;

  double toMeters(double value) => value * metersPerUnit;
  double fromMeters(double meters) => meters / metersPerUnit;
}

class ProjectorCalculatorScreen extends ConsumerStatefulWidget {
  const ProjectorCalculatorScreen({super.key});

  @override
  ConsumerState<ProjectorCalculatorScreen> createState() => _ProjectorCalculatorScreenState();
}

class _ProjectorCalculatorScreenState extends ConsumerState<ProjectorCalculatorScreen> {
  InstallationType _installationType = InstallationType.desktop;
  ProjectorAspectRatio _ratio = ProjectorAspectRatio.ratio16x9;
  Product? _selectedProjector;

  // Display units — Throw Distance applies to the room dimensions and the
  // projector-to-screen distance; Image Size applies to diagonal/width/height.
  DistanceUnit _throwUnit = DistanceUnit.meters;
  DistanceUnit _sizeUnit = DistanceUnit.inches;

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

  // Throw/room fields: displayed in _throwUnit, canonical value is meters.
  double? _parseThrowMeters(TextEditingController c) {
    final v = _parse(c);
    return v == null ? null : _throwUnit.toMeters(v);
  }

  void _setThrowMeters(TextEditingController c, double meters) {
    _setText(c, _throwUnit.fromMeters(meters).toStringAsFixed(2));
  }

  // Screen-size fields: displayed in _sizeUnit, canonical value is inches (what
  // projector_math.dart's screen functions expect).
  double? _parseSizeInches(TextEditingController c) {
    final v = _parse(c);
    if (v == null) return null;
    return _sizeUnit.toMeters(v) / 0.0254;
  }

  void _setSizeInches(TextEditingController c, double inches) {
    final meters = inches * 0.0254;
    _setText(c, _sizeUnit.fromMeters(meters).toStringAsFixed(1));
  }

  // Re-renders every field's displayed text in the newly chosen units without
  // altering the underlying values — captures canonical meters/inches using the
  // OLD unit before switching, then reformats using the NEW unit.
  void _applyUnitChange(DistanceUnit newThrowUnit, DistanceUnit newSizeUnit) {
    final roomH = _parseThrowMeters(_roomHController);
    final roomW = _parseThrowMeters(_roomWController);
    final roomL = _parseThrowMeters(_roomLController);
    final distance = _parseThrowMeters(_distanceController);
    final diagonal = _parseSizeInches(_diagonalController);
    final width = _parseSizeInches(_widthController);
    final height = _parseSizeInches(_heightController);

    setState(() {
      _throwUnit = newThrowUnit;
      _sizeUnit = newSizeUnit;
    });

    if (roomH != null) _setThrowMeters(_roomHController, roomH);
    if (roomW != null) _setThrowMeters(_roomWController, roomW);
    if (roomL != null) _setThrowMeters(_roomLController, roomL);
    if (distance != null) _setThrowMeters(_distanceController, distance);
    if (diagonal != null) _setSizeInches(_diagonalController, diagonal);
    if (width != null) _setSizeInches(_widthController, width);
    if (height != null) _setSizeInches(_heightController, height);
    setState(() {});
  }

  Future<void> _showUnitsDialog() async {
    var throwUnit = _throwUnit;
    var sizeUnit = _sizeUnit;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Units'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Throw Distance & Room', style: Theme.of(dialogContext).textTheme.titleSmall),
                for (final unit in DistanceUnit.values)
                  RadioListTile<DistanceUnit>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(unit.label),
                    value: unit,
                    groupValue: throwUnit,
                    onChanged: (u) => setDialogState(() => throwUnit = u!),
                  ),
                const SizedBox(height: 12),
                Text('Image Size', style: Theme.of(dialogContext).textTheme.titleSmall),
                for (final unit in DistanceUnit.values)
                  RadioListTile<DistanceUnit>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(unit.label),
                    value: unit,
                    groupValue: sizeUnit,
                    onChanged: (u) => setDialogState(() => sizeUnit = u!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('OK')),
          ],
        ),
      ),
    );

    if (confirmed == true) _applyUnitChange(throwUnit, sizeUnit);
  }

  ProjectorAspectRatio _ratioFromSpec(String? label) {
    switch (label) {
      case '4:3':
        return ProjectorAspectRatio.ratio4x3;
      case '16:10':
        return ProjectorAspectRatio.ratio16x10;
      case '21:9':
        return ProjectorAspectRatio.ratio21x9;
      case '16:9':
      default:
        return ProjectorAspectRatio.ratio16x9;
    }
  }

  // Fills the throw-ratio fields (and aspect ratio) from a catalog projector's specs —
  // the fields stay plain TextEditingControllers afterwards, so the user can still hand-edit
  // them (e.g. to model a non-standard lens position) without the picker fighting back.
  void _applyProjectorSpecs(Product product) {
    final specs = product.specs;
    if (specs == null) return;
    final wide = (specs['throwRatioWide'] as num?)?.toDouble();
    final tele = (specs['throwRatioTele'] as num?)?.toDouble();
    setState(() {
      _selectedProjector = product;
      _ratio = _ratioFromSpec(specs['aspectRatio'] as String?);
      if (wide != null) _throwRatioWideController.text = wide.toString();
      if (tele != null) _throwRatioTeleController.text = tele.toString();
    });
    _recomputeFromDiagonal();
  }

  Future<void> _pickProjector() async {
    final products = await ref.read(projectorProductsProvider.future);
    if (!mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No projectors in the catalog yet.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => _ProjectorPickerSheet(
          products: products,
          scrollController: scrollController,
        ),
      ),
    );
    if (selected != null) _applyProjectorSpecs(selected);
  }

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
    _setSizeInches(_diagonalController, screen.diagonalInches);
    _setSizeInches(_widthController, screen.widthInches);
    _setSizeInches(_heightController, screen.heightInches);
    if (_throwRatioWide > 0) {
      final distance = throwDistanceMeters(screen.widthMeters, _throwRatioWide);
      _setThrowMeters(_distanceController, distance);
    }
    _updating = false;
    setState(() {});
  }

  void _recomputeFromDiagonal() {
    final diagonal = _parseSizeInches(_diagonalController);
    if (diagonal == null || diagonal <= 0) return;
    _applyScreen(screenFromDiagonal(_ratio, diagonal));
  }

  void _recomputeFromWidth() {
    final width = _parseSizeInches(_widthController);
    if (width == null || width <= 0) return;
    _applyScreen(screenFromWidth(_ratio, width));
  }

  void _recomputeFromHeight() {
    final height = _parseSizeInches(_heightController);
    if (height == null || height <= 0) return;
    final diagonal = height * _ratio.diagonalUnits / _ratio.heightUnits;
    _applyScreen(screenFromDiagonal(_ratio, diagonal));
  }

  void _recomputeFromDistance() {
    if (_updating) return;
    final distance = _parseThrowMeters(_distanceController);
    if (distance == null || distance <= 0 || _throwRatioWide <= 0) return;
    final widthMeters = widthFromThrowDistance(distance, _throwRatioWide);
    _updating = true;
    final screen = screenFromWidth(_ratio, widthMeters / 0.0254);
    _setSizeInches(_diagonalController, screen.diagonalInches);
    _setSizeInches(_widthController, screen.widthInches);
    _setSizeInches(_heightController, screen.heightInches);
    _updating = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projector Calculator'),
        actions: [
          TextButton.icon(
            onPressed: _showUnitsDialog,
            icon: const Icon(Icons.straighten),
            label: const Text('Units'),
          ),
        ],
      ),
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
          _sectionLabel('Room Dimension (${_throwUnit.abbr})'),
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
          if (_selectedProjector != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: Text(_selectedProjector!.name),
                subtitle: const Text('Specs applied below — edit any field to override.'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear selection',
                  onPressed: () => setState(() => _selectedProjector = null),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _pickProjector,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Choose a projector from the catalog'),
            ),
          const SizedBox(height: 12),
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
          _sectionLabel('Screen Size (${_sizeUnit.abbr})'),
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
            'Distance (${_throwUnit.abbr})',
            onChanged: (_) => _recomputeFromDistance(),
          ),
          const SizedBox(height: 24),
          _buildDiagram(),
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

  Widget _buildDiagram() {
    final distance = _parseThrowMeters(_distanceController);
    final heightIn = _parseSizeInches(_heightController);
    if (distance == null || distance <= 0 || heightIn == null || heightIn <= 0) {
      return const SizedBox.shrink();
    }
    return ThrowDistanceDiagram(
      installationType: _installationType,
      throwDistanceMeters: distance,
      screenHeightMeters: heightIn * 0.0254,
      roomLengthMeters: _parseThrowMeters(_roomLController),
      roomHeightMeters: _parseThrowMeters(_roomHController),
    );
  }

  Widget _buildSummary() {
    final rows = <String>[];

    final diagonal = _parseSizeInches(_diagonalController);
    final distance = _parseThrowMeters(_distanceController);
    final roomL = _parseThrowMeters(_roomLController);
    final roomW = _parseThrowMeters(_roomWController);
    final roomH = _parseThrowMeters(_roomHController);
    final widthIn = _parseSizeInches(_widthController);
    final heightIn = _parseSizeInches(_heightController);
    final throwRatioTele = _parse(_throwRatioTeleController);

    if (diagonal != null && distance != null) {
      final diagonalDisplay = _sizeUnit.fromMeters(diagonal * 0.0254);
      final distanceDisplay = _throwUnit.fromMeters(distance);
      rows.add(
        '${diagonalDisplay.toStringAsFixed(1)} ${_sizeUnit.abbr} ${_ratio.label} screen at '
        '${distanceDisplay.toStringAsFixed(2)} ${_throwUnit.abbr} throw distance.',
      );
    }

    if (throwRatioTele != null && throwRatioTele > _throwRatioWide && diagonal != null) {
      final range = throwDistanceRangeForScreen(
        ratio: _ratio,
        diagonalInches: diagonal,
        throwRatioWide: _throwRatioWide,
        throwRatioTele: throwRatioTele,
      );
      // Recommended = mid-zoom position (average of the wide/tele throw ratios), not
      // just the midpoint of the two distances — matches how a zoom lens is actually
      // driven, and keeps the value meaningful when the ratio-to-distance relationship
      // is non-linear across the zoom range.
      final midRatio = (_throwRatioWide + throwRatioTele) / 2;
      final recommendedMeters = throwDistanceMeters(
        screenFromDiagonal(_ratio, diagonal).widthMeters,
        midRatio,
      );
      final shortest = _throwUnit.fromMeters(range.minMeters);
      final recommended = _throwUnit.fromMeters(recommendedMeters);
      final longest = _throwUnit.fromMeters(range.maxMeters);
      rows.add('Shortest distance (full wide zoom): ${shortest.toStringAsFixed(2)} ${_throwUnit.abbr}');
      rows.add('Recommended distance (mid zoom): ${recommended.toStringAsFixed(2)} ${_throwUnit.abbr}');
      rows.add('Longest distance (full tele zoom): ${longest.toStringAsFixed(2)} ${_throwUnit.abbr}');
    }

    rows.add(
      _installationType == InstallationType.desktop
          ? 'Desktop install: mount the projector near table/shelf height, level with the bottom of the screen.'
          : 'Ceiling mount: confirm the ceiling drop clears your room height and lens shift range before installing.',
    );

    final warnings = <String>[];
    if (distance != null && roomL != null && roomL > 0 && distance > roomL) {
      warnings.add(
        'Throw distance (${_throwUnit.fromMeters(distance).toStringAsFixed(2)} ${_throwUnit.abbr}) exceeds '
        'room length (${_throwUnit.fromMeters(roomL).toStringAsFixed(2)} ${_throwUnit.abbr}).',
      );
    }
    if (widthIn != null && roomW != null && roomW > 0) {
      final widthM = widthIn * 0.0254;
      if (widthM > roomW) {
        warnings.add(
          'Screen width (${_throwUnit.fromMeters(widthM).toStringAsFixed(2)} ${_throwUnit.abbr}) exceeds '
          'room width (${_throwUnit.fromMeters(roomW).toStringAsFixed(2)} ${_throwUnit.abbr}).',
        );
      }
    }
    if (heightIn != null && roomH != null && roomH > 0) {
      final heightM = heightIn * 0.0254;
      if (heightM > roomH) {
        warnings.add(
          'Screen height (${_throwUnit.fromMeters(heightM).toStringAsFixed(2)} ${_throwUnit.abbr}) exceeds '
          'room height (${_throwUnit.fromMeters(roomH).toStringAsFixed(2)} ${_throwUnit.abbr}).',
        );
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

/// Model picker for the calculator — name-only (no product photos) with a search
/// field, since with 300+ projectors in the catalog a flat scroll isn't usable.
class _ProjectorPickerSheet extends StatefulWidget {
  const _ProjectorPickerSheet({required this.products, required this.scrollController});

  final List<Product> products;
  final ScrollController scrollController;

  @override
  State<_ProjectorPickerSheet> createState() => _ProjectorPickerSheetState();
}

class _ProjectorPickerSheetState extends State<_ProjectorPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String? _throwLabel(Product product) {
    final specs = product.specs;
    final wide = specs?['throwRatioWide'];
    final tele = specs?['throwRatioTele'];
    if (wide == null || tele == null) return null;
    return wide == tele ? 'Throw ratio $wide:1' : 'Throw ratio $wide–$tele:1';
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.products
        : widget.products.where((p) => p.name.toLowerCase().contains(query)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search projectors by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No projectors match your search.'))
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final throwLabel = _throwLabel(product);
                    return ListTile(
                      title: Text(product.name),
                      subtitle: throwLabel != null ? Text(throwLabel) : null,
                      onTap: () => Navigator.of(context).pop(product),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
