import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';


// ─────────────────────────────────────────────────────────────
// STAT CARD — Premium istatistik kartı
// ─────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? change;
  final bool isUp;
  final List<double>? sparklineData;
  final String? subtext;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.primary600,
    this.change,
    this.isUp = true,
    this.sparklineData,
    this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isUp ? AppColors.successLight : AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: isUp ? AppColors.successDark : AppColors.dangerDark,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        change!,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isUp ? AppColors.successDark : AppColors.dangerDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.gray900, height: 1),
          ),
          if (sparklineData != null && sparklineData!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Sparkline(data: sparklineData!, color: color, height: 26),
          ],
          if (subtext != null) ...[
            const SizedBox(height: 6),
            Text(
              subtext!,
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w400),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STATS GRID — Row-based for dynamic height and consistent sizing (no overflows)
// ─────────────────────────────────────────────────────────────
class StatsGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double spacing;

  const StatsGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += crossAxisCount) {
      final rowChildren = <Widget>[];
      for (var j = 0; j < crossAxisCount; j++) {
        if (i + j < children.length) {
          rowChildren.add(Expanded(child: children[i + j]));
        } else {
          rowChildren.add(const Expanded(child: SizedBox()));
        }
        if (j < crossAxisCount - 1) {
          rowChildren.add(SizedBox(width: spacing));
        }
      }
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowChildren,
      ));
      if (i + crossAxisCount < children.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

// ─────────────────────────────────────────────────────────────
// CARD CONTAINER — Her kart bu wrapper ile sarılacak
// ─────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final List<BoxShadow>? shadow;
  final Color? color;
  final Color? borderColor;
  final double? borderWidth;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.shadow,
    this.color,
    this.borderColor,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: shadow ?? AppShadows.sm,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth ?? 1.0)
            : null,
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STOCK GAUGE — Animasyonlu ilerleme çubuğu
// ─────────────────────────────────────────────────────────────
class StockGauge extends StatefulWidget {
  final double current;
  final double capacity;
  final String? label;

  const StockGauge({super.key, required this.current, required this.capacity, this.label});

  @override
  State<StockGauge> createState() => _StockGaugeState();
}

class _StockGaugeState extends State<StockGauge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final pct = widget.capacity > 0 ? (widget.current / widget.capacity).clamp(0.0, 1.0) : 0.0;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween(begin: 0.0, end: pct).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pct = widget.capacity > 0 ? (widget.current / widget.capacity).clamp(0.0, 1.0) : 0.0;
    final isWarning = pct > 0.8;
    final color = isWarning ? AppColors.warning : AppColors.primary500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.label != null) Text(widget.label!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
            Text(
              '${widget.current.toStringAsFixed(0)} / ${widget.capacity.toStringAsFixed(0)} LT',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            height: 6,
            decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(99)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _anim.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STATUS BADGE — İnce durum etiketi
// ─────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const StatusBadge({super.key, required this.label, required this.color, required this.bgColor});

  factory StatusBadge.active([String? l]) => StatusBadge(label: l ?? 'Aktif', color: AppColors.successDark, bgColor: AppColors.successLight);
  factory StatusBadge.inactive([String? l]) => StatusBadge(label: l ?? 'Pasif', color: AppColors.gray600, bgColor: AppColors.gray100);
  factory StatusBadge.warning([String? l]) => StatusBadge(label: l ?? 'Dikkat', color: AppColors.warningDark, bgColor: AppColors.warningLight);
  factory StatusBadge.danger([String? l]) => StatusBadge(label: l ?? 'Yüksek', color: AppColors.dangerDark, bgColor: AppColors.dangerLight);
  factory StatusBadge.info([String? l]) => StatusBadge(label: l ?? 'Bilgi', color: AppColors.primary800, bgColor: AppColors.primary100);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SECTION TITLE
// ─────────────────────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray800)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ANIMATED COUNTER — Sayı animasyonu
// ─────────────────────────────────────────────────────────────
class AnimatedCount extends StatefulWidget {
  final int count;
  final TextStyle? style;
  final String? suffix;

  const AnimatedCount({super.key, required this.count, this.style, this.suffix});

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween(begin: 0.0, end: widget.count.toDouble()).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        '${_anim.value.toInt()}${widget.suffix ?? ''}',
        style: widget.style ?? GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.gray900),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LIVE DOT — Canlı yayın göstergesi
// ─────────────────────────────────────────────────────────────
class LiveDot extends StatefulWidget {
  const LiveDot({super.key});
  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.5 + _ctrl.value * 0.5),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: _ctrl.value * 0.4), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 5),
          Text('Canlı', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.successDark)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FAB — Premium floating action button
// ─────────────────────────────────────────────────────────────
class AppFab extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const AppFab({super.key, required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.blue,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.blue,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SPARKLINE — Miniature Chart
// ─────────────────────────────────────────────────────────────
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final double lineWidth;

  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.height = 30.0,
    this.lineWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: SparklinePainter(data: data, color: color, lineWidth: lineWidth),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double lineWidth;

  SparklinePainter({required this.data, required this.color, this.lineWidth = 2.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final double minX = 0;
    final double maxX = data.length - 1.0;
    final double minY = data.reduce((a, b) => a < b ? a : b);
    final double maxY = data.reduce((a, b) => a > b ? a : b);
    final double rangeY = maxY - minY == 0 ? 1 : maxY - minY;

    final path = Path();
    final fillPath = Path();

    double getX(int index) => size.width * (index / maxX);
    double getY(double val) => size.height - (size.height * ((val - minY) / rangeY));

    path.moveTo(getX(0), getY(data[0]));
    fillPath.moveTo(getX(0), size.height);
    fillPath.lineTo(getX(0), getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      path.lineTo(getX(i), getY(data[i]));
      fillPath.lineTo(getX(i), getY(data[i]));
    }

    fillPath.lineTo(getX(data.length - 1), size.height);
    fillPath.close();

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
    ).createShader(rect);

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────
// SEARCHABLE DROPDOWN — Autocomplete support for form fields
// ─────────────────────────────────────────────────────────────
class SearchableDropdown extends StatefulWidget {
  final List<String> items;
  final String? value;
  final String hint;
  final String? label;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  const SearchableDropdown({
    super.key,
    required this.items,
    this.value,
    required this.hint,
    this.label,
    required this.onChanged,
    this.validator,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleTextChanged() {
    if (_controller.text.isEmpty) {
      widget.onChanged(null);
    }
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      // If focus is lost and the text does not match any item in the list, reset or match
      if (!widget.items.contains(_controller.text)) {
        if (_controller.text.isEmpty) {
          widget.onChanged(null);
        } else {
          final match = widget.items.firstWhere(
            (item) => item.toLowerCase() == _controller.text.toLowerCase(),
            orElse: () => '',
          );
          if (match.isNotEmpty) {
            _controller.text = match;
            widget.onChanged(match);
          } else {
            _controller.text = widget.value ?? '';
          }
        }
      }
    }
  }

  @override
  void didUpdateWidget(SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        FormField<String>(
          initialValue: widget.value,
          validator: widget.validator,
          builder: (FormFieldState<String> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RawAutocomplete<String>(
                  textEditingController: _controller,
                  focusNode: _focusNode,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return widget.items;
                    }
                    return widget.items.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    state.didChange(selection);
                    widget.onChanged(selection);
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    // Standard width calculation to avoid LayoutBuilder constraints
                    final dropdownWidth = screenWidth > 600 ? 300.0 : screenWidth - 72;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                        child: Container(
                          width: dropdownWidth,
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: index < options.length - 1
                                      ? const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: AppColors.gray100)),
                                        )
                                      : null,
                                  child: Text(
                                    option,
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: AppColors.gray300),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: AppColors.gray300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: AppColors.primary500, width: 1.5),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.gray500),
                          onPressed: () {
                            if (focusNode.hasFocus) {
                              focusNode.unfocus();
                            } else {
                              focusNode.requestFocus();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
                if (state.hasError) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      state.errorText!,
                      style: GoogleFonts.inter(color: Colors.red, fontSize: 11),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MONTH PERIOD PICKER
// ─────────────────────────────────────────────────────────────
class MonthPeriodPicker extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const MonthPeriodPicker({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(selectedDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: AppColors.gray600),
            onPressed: () {
              onDateChanged(DateTime(selectedDate.year, selectedDate.month - 1));
            },
          ),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              int tempYear = selectedDate.year;
              int tempMonth = selectedDate.month;
              final result = await showDialog<DateTime>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Dönem Seçin'),
                    content: StatefulBuilder(
                      builder: (context, setDlgState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<int>(
                              value: tempYear,
                              decoration: const InputDecoration(labelText: 'Yıl'),
                              items: List.generate(11, (i) => now.year - 5 + i)
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDlgState(() => tempYear = val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: tempMonth,
                              decoration: const InputDecoration(labelText: 'Ay'),
                              items: List.generate(12, (i) => i + 1)
                                  .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(DateFormat('MMMM', 'tr_TR').format(DateTime(2000, m))),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDlgState(() => tempMonth = val);
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Vazgeç'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, DateTime(tempYear, tempMonth)),
                        child: const Text('Seç'),
                      ),
                    ],
                  );
                },
              );
              if (result != null) {
                onDateChanged(result);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 16),
                const SizedBox(width: 8),
                Text(
                  monthStr,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: AppColors.gray600),
            onPressed: () {
              onDateChanged(DateTime(selectedDate.year, selectedDate.month + 1));
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PREMIUM DATE RANGE FILTER
// ─────────────────────────────────────────────────────────────
class PremiumDateRangeFilter extends StatelessWidget {
  final DateTimeRange? selectedRange;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final String label;

  const PremiumDateRangeFilter({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
    this.label = 'Tüm Dönemler',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          initialDateRange: selectedRange ??
              DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 30)),
                end: DateTime.now(),
              ),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('tr', 'TR'),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary600,
                  onPrimary: Colors.white,
                  onSurface: AppColors.gray800,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onRangeChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selectedRange != null ? AppColors.primary50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selectedRange != null ? AppColors.primary200 : AppColors.gray200),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              color: selectedRange != null ? AppColors.primary600 : AppColors.gray500,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedRange != null
                    ? '${DateFormat('dd.MM.yyyy').format(selectedRange!.start)} - ${DateFormat('dd.MM.yyyy').format(selectedRange!.end)}'
                    : label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selectedRange != null ? FontWeight.bold : FontWeight.w500,
                  color: selectedRange != null ? AppColors.primary700 : AppColors.gray700,
                ),
              ),
            ),
            if (selectedRange != null)
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.clear_rounded, size: 14, color: AppColors.danger),
                onPressed: () => onRangeChanged(null),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }
}

