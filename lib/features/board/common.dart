import 'package:flutter/material.dart';

import '../../github/models.dart';

const statusPalette = [
  Color(0xFF4C8DFF),
  Color(0xFF3FB950),
  Color(0xFFF59E0B),
  Color(0xFFE5484D),
  Color(0xFF8B5CF6),
  Color(0xFF14B8A6),
  Color(0xFF64748B),
  Color(0xFFEC4899),
];

const noStatusColor = Color(0xFF8B949E);

String formatPoints(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

class LabelChip extends StatelessWidget {
  final Label label;
  const LabelChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: label.swatch,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

(IconData, Color) itemIcon(Item i) {
  if (i.hidden) return (Icons.lock_outline, noStatusColor);
  if (i.kind == 'PullRequest') {
    return switch (i.state) {
      'MERGED' => (Icons.call_merge, const Color(0xFF8B5CF6)),
      'CLOSED' => (Icons.cancel_outlined, const Color(0xFFE5484D)),
      _ => (Icons.call_split, const Color(0xFF3FB950)),
    };
  }
  if (i.kind == 'Issue') {
    return i.state == 'CLOSED'
        ? (Icons.check_circle_outline, const Color(0xFF8B5CF6))
        : (Icons.radio_button_unchecked, const Color(0xFF3FB950));
  }
  return (Icons.edit_note, noStatusColor);
}

(IconData?, Color?) checkIcon(String? state) => switch (state) {
  'SUCCESS' => (Icons.check_circle, const Color(0xFF3FB950)),
  'FAILURE' || 'ERROR' => (Icons.error, const Color(0xFFE5484D)),
  'PENDING' || 'EXPECTED' => (Icons.schedule, const Color(0xFFF59E0B)),
  _ => (null, null),
};

enum BoardFilter { all, open, closed, mine, currentIteration }

class FilterChipWidget extends StatelessWidget {
  final BoardFilter value;
  final BoardFilter groupValue;
  final ValueChanged<BoardFilter> onChanged;
  const FilterChipWidget({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = value == groupValue;
    final labels = {
      BoardFilter.all: 'Todo',
      BoardFilter.open: 'Abiertos',
      BoardFilter.closed: 'Cerrados',
      BoardFilter.mine: 'Mías',
      BoardFilter.currentIteration: 'Iteración actual',
    };
    final icons = {
      BoardFilter.all: Icons.list,
      BoardFilter.open: Icons.radio_button_unchecked,
      BoardFilter.closed: Icons.check_circle_outline,
      BoardFilter.mine: Icons.person_outline,
      BoardFilter.currentIteration: Icons.event_repeat,
    };

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[value],
            size: 14,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(labels[value]!),
        ],
      ),
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: cs.primary,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      backgroundColor: cs.surface,
      side: BorderSide(color: cs.outlineVariant),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
