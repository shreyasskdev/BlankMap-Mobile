import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:blankmap_mobile/shared.dart'; // Uncomment if needed

// ==========================================
// 1. APP ENTRY & THEME MOCKS
// ==========================================
void main() {
  runApp(const BlankMapApp());
}

final List<Map<String, dynamic>> allBlankMaps = [
  {
    'tag': 'r/BrokenBenches',
    'desc': 'Track broken benches in the park.',
    'pins': '42',
    'icon': CupertinoIcons.placemark,
    'hot': true,
    'userCreated': false,
  },
  {
    'tag': 'r/StrayCats',
    'desc': 'Sightings of stray cats around the city.',
    'pins': '128',
    'icon': CupertinoIcons.paw,
    'hot': true,
    'userCreated': false,
  },
];

class BlankMapApp extends StatelessWidget {
  const BlankMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: Changed CupertinoApp to MaterialApp.
    // This natively injects MaterialLocalizations and Material themes required by
    // flutter_iconpicker. Your UI will still look identical since we use Cupertino scaffolds.
    return MaterialApp(
      title: 'BlankMaps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: BM.accent,
        scaffoldBackgroundColor: BM.bg,
        cupertinoOverrideTheme: const CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: BM.accent,
          scaffoldBackgroundColor: BM.bg,
        ),
      ),
      home: BlankMapsScreen(
        onTagSelected: (tag) => debugPrint('Selected map: $tag'),
      ),
    );
  }
}

// ==========================================
// 2. BLANKMAPS SCREEN
// ==========================================
class BlankMapsScreen extends StatefulWidget {
  final Function(String) onTagSelected;
  const BlankMapsScreen({super.key, required this.onTagSelected});

  @override
  State<BlankMapsScreen> createState() => _BlankMapsScreenState();
}

class _BlankMapsScreenState extends State<BlankMapsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _userCreatedMaps = [];
  bool _isSearching = false;
  String _query = '';

  List<Map<String, dynamic>> get _allMaps => [
    ...allBlankMaps,
    ..._userCreatedMaps,
  ];
  List<Map<String, dynamic>> get _trendingMaps =>
      _allMaps.where((m) => m['hot'] == true).toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _allMaps;
    final q = _query.toLowerCase();
    return _allMaps.where((m) {
      return (m['tag'] as String).toLowerCase().contains(q) ||
          (m['desc'] as String).toLowerCase().contains(q);
    }).toList();
  }

  void _openCreateSheet() {
    showCupertinoModalPopup(
      context: context,
      // FIX: Wrap the sheet in a transparent Material widget.
      // This satisfies flutter_iconpicker's need for a Material ancestor when it builds its dialog.
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: _CreateBlankMapSheet(
          onCreated: (newMap) {
            setState(() => _userCreatedMaps.add(newMap));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: BM.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: BM.bg,
        border: const Border(bottom: BorderSide(color: BM.border, width: 0.5)),
        middle: const Text(
          'BlankMaps',
          style: TextStyle(
            color: BM.textPri,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BM.accentSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BM.accent.withOpacity(0.3)),
              ),
              child: Text(
                '${_allMaps.length} maps',
                style: const TextStyle(
                  color: BM.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _openCreateSheet,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: BM.accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: BM.accentGlow, blurRadius: 10)],
                ),
                child: const Icon(CupertinoIcons.plus, color: BM.bg, size: 16),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _SearchBar(
                  controller: _searchCtrl,
                  isSearching: _isSearching,
                  onTap: () => setState(() => _isSearching = true),
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    setState(() {
                      _isSearching = false;
                      _query = '';
                      _searchCtrl.clear();
                      FocusScope.of(context).unfocus();
                    });
                  },
                ),
              ),
            ),
            if (!_isSearching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _CreateBanner(onTap: _openCreateSheet),
                ),
              ),
            if (!_isSearching) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: CupertinoIcons.flame_fill,
                  iconColor: BM.warn,
                  title: 'Trending Today',
                  topPad: 20,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _MapCard(
                      item: _trendingMaps[i],
                      onTap: () =>
                          widget.onTagSelected(_trendingMaps[i]['tag']),
                      showHot: true,
                    ),
                    childCount: _trendingMaps.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: CupertinoIcons.square_grid_2x2_fill,
                  iconColor: BM.textSec,
                  title: 'All BlankMaps',
                  topPad: 20,
                ),
              ),
            ],
            if (_isSearching)
              SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: CupertinoIcons.search,
                  iconColor: BM.accent,
                  title:
                      '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                  topPad: 16,
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final list = _isSearching ? _filtered : _allMaps;
                    return _MapCard(
                      item: list[i],
                      onTap: () => widget.onTagSelected(list[i]['tag']),
                      isUserCreated: list[i]['userCreated'] == true,
                    );
                  },
                  childCount: _isSearching ? _filtered.length : _allMaps.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. CREATE BLANKMAP BOTTOM SHEET
// ==========================================
class _CreateBlankMapSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onCreated;
  const _CreateBlankMapSheet({required this.onCreated});

  @override
  State<_CreateBlankMapSheet> createState() => _CreateBlankMapSheetState();
}

class _CreateBlankMapSheetState extends State<_CreateBlankMapSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  IconPickerIcon _pickedIcon = IconPickerIcon(
    name: 'location_on',
    data: Icons.location_on,
    pack: 'cupertino',
  );
  bool _iconWasPicked = false;
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // FIX: This call will now work flawlessly.
  Future<void> _pickIcon() async {
    final picked = await showIconPicker(
      context,
      configuration: SinglePickerConfiguration(
        iconPackModes: [IconPack.cupertino],
        backgroundColor: BM.surface,
        iconColor: BM.textSec,
        selectedIconBackgroundColor: BM.accent,
        searchHintText: 'Search icons...',
        iconSize: 28,
        iconPickerShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Pick an Icon',
          style: TextStyle(
            color: BM.textPri,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        closeChild: const Text(
          'Cancel',
          style: TextStyle(color: BM.accent, fontSize: 15),
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _pickedIcon = picked;
        _iconWasPicked = true;
      });
    }
  }

  void _submit() {
    final raw = _nameCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    if (raw.length < 3) {
      setState(() => _nameError = 'Must be at least 3 characters');
      return;
    }

    final cleaned = raw.replaceFirst(RegExp(r'^r/'), '');
    final tag = 'r/${cleaned[0].toUpperCase()}${cleaned.substring(1)}';

    widget.onCreated({
      'tag': tag,
      'desc': _descCtrl.text.trim().isEmpty
          ? 'A community-created BlankMap.'
          : _descCtrl.text.trim(),
      'pins': '0',
      'icon': _pickedIcon.data,
      'hot': false,
      'userCreated': true,
    });
    Navigator.pop(context);
  }

  String get _previewTag {
    final raw = _nameCtrl.text.trim().replaceFirst(RegExp(r'^r/'), '');
    return raw.isEmpty ? 'r/YourMap' : 'r/$raw';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: BM.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: BM.border),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: BM.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: BM.accentSoft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: BM.accent.withOpacity(0.4)),
                  ),
                  child: const Icon(
                    CupertinoIcons.plus_circle_fill,
                    color: BM.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a BlankMap',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: BM.textPri,
                      ),
                    ),
                    Text(
                      'Your community layer, your rules.',
                      style: TextStyle(color: BM.textSec, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _FieldLabel(label: 'NAME', hint: 'e.g. BrokenBenches'),
            const SizedBox(height: 8),
            _InputField(
              controller: _nameCtrl,
              placeholder: 'YourBlankMap',
              errorText: _nameError,
              prefix: const Text(
                'r/',
                style: TextStyle(
                  color: BM.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
                setState(() {});
              },
            ),
            const SizedBox(height: 18),
            const _FieldLabel(label: 'DESCRIPTION', hint: 'optional'),
            const SizedBox(height: 8),
            _InputField(
              controller: _descCtrl,
              placeholder: 'What does this BlankMap track?',
              maxLines: 2,
            ),
            const SizedBox(height: 22),
            const _FieldLabel(label: 'ICON'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickIcon,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: BM.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _iconWasPicked
                        ? BM.accent.withOpacity(0.5)
                        : BM.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _iconWasPicked ? BM.accentSoft : BM.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _iconWasPicked
                              ? BM.accent.withOpacity(0.4)
                              : BM.border,
                        ),
                      ),
                      child: Icon(_pickedIcon.data, color: BM.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _iconWasPicked ? 'Icon selected' : 'Choose an icon',
                            style: TextStyle(
                              color: _iconWasPicked ? BM.textPri : BM.textSec,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _iconWasPicked
                                ? 'Tap to change'
                                : 'Tap to browse all icons',
                            style: const TextStyle(
                              color: BM.textTer,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: BM.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BM.accent.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Browse',
                        style: TextStyle(
                          color: BM.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Text(
                  'Preview:',
                  style: TextStyle(color: BM.textTer, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: BM.accentSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BM.accent.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_pickedIcon.data, color: BM.accent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _previewTag,
                        style: const TextStyle(
                          color: BM.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: BM.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: BM.border),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: BM.textSec,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: BM.accent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: BM.accentGlow, blurRadius: 18),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_alt,
                            color: BM.bg,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Create BlankMap',
                            style: TextStyle(
                              color: BM.bg,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. HELPER WIDGETS
// ==========================================
class _CreateBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [BM.accentSoft, BM.accent.withOpacity(0.05)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BM.accent.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: BM.accent,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [BoxShadow(color: BM.accentGlow, blurRadius: 10)],
              ),
              child: const Icon(CupertinoIcons.plus, color: BM.bg, size: 18),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a new BlankMap',
                    style: TextStyle(
                      color: BM.textPri,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Map anything your city is missing.',
                    style: TextStyle(color: BM.textSec, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: BM.textTer,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final String? hint;
  const _FieldLabel({required this.label, this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: BM.textSec,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Text(hint!, style: const TextStyle(color: BM.textTer, fontSize: 11)),
        ],
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final Widget? prefix;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.placeholder,
    this.prefix,
    this.errorText,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: BM.surfaceAlt,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: errorText != null ? BM.danger : BM.border,
              width: errorText != null ? 1.5 : 1.0,
            ),
          ),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            placeholderStyle: const TextStyle(color: BM.textTer, fontSize: 15),
            style: const TextStyle(color: BM.textPri, fontSize: 15),
            decoration: null,
            maxLines: maxLines,
            padding: EdgeInsets.only(
              left: prefix != null ? 6 : 14,
              right: 14,
              top: 13,
              bottom: 13,
            ),
            prefix: prefix != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: prefix,
                  )
                : null,
            onChanged: onChanged,
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                color: BM.danger,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                errorText!,
                style: const TextStyle(color: BM.danger, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.isSearching,
    required this.onTap,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BM.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSearching ? BM.accent : BM.border,
          width: isSearching ? 1.5 : 1.0,
        ),
        boxShadow: isSearching
            ? [BoxShadow(color: BM.accentGlow, blurRadius: 14)]
            : [],
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            color: isSearching ? BM.accent : BM.textTer,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'Search all BlankMaps...',
              placeholderStyle: const TextStyle(
                color: BM.textTer,
                fontSize: 15,
              ),
              style: const TextStyle(color: BM.textPri, fontSize: 15),
              decoration: null,
              onTap: onTap,
              onChanged: onChanged,
            ),
          ),
          if (isSearching)
            GestureDetector(
              onTap: onClear,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: BM.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  color: BM.textSec,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final double topPad;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.topPad = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              color: BM.textSec,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool showHot;
  final bool isUserCreated;

  const _MapCard({
    required this.item,
    required this.onTap,
    this.showHot = false,
    this.isUserCreated = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: BM.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUserCreated ? BM.accent.withOpacity(0.35) : BM.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: BM.accentSoft,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: BM.accent.withOpacity(0.25)),
              ),
              child: Icon(item['icon'] as IconData, color: BM.accent, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item['tag'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: BM.textPri,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showHot && item['hot'] == true) ...[
                        const SizedBox(width: 7),
                        const _Badge(label: 'HOT', color: BM.warn),
                      ],
                      if (isUserCreated) ...[
                        const SizedBox(width: 7),
                        const _Badge(label: 'YOURS', color: BM.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['desc'] as String,
                    style: const TextStyle(color: BM.textSec, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item['pins'] as String,
                  style: const TextStyle(
                    color: BM.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'pins',
                  style: TextStyle(color: BM.textTer, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_right,
              color: BM.textTer,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
