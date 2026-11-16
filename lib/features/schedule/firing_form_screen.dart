import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/firing.dart';
import '../../core/models/studio_types.dart';
import '../../core/providers.dart';

class FiringFormScreen extends ConsumerStatefulWidget {
  const FiringFormScreen({super.key});

  @override
  ConsumerState<FiringFormScreen> createState() => _FiringFormScreenState();
}

class _FiringFormScreenState extends ConsumerState<FiringFormScreen> {
  final _title = TextEditingController();
  final _lead = TextEditingController();
  final _notes = TextEditingController();
  final _capacity = TextEditingController(text: '16');
  final _booked = TextEditingController(text: '1');
  String _kiln = kilnNames.first;
  String _cone = '6';
  Atmosphere _atmosphere = Atmosphere.oxidation;
  late DateTime _day;
  int _hour = 17;
  int _duration = 10;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final local = ref.read(clockProvider).now().toLocal();
    _day = DateTime(local.year, local.month, local.day);
  }

  @override
  void dispose() {
    _title.dispose();
    _lead.dispose();
    _notes.dispose();
    _capacity.dispose();
    _booked.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_day.year - 1),
      lastDate: DateTime(_day.year + 2),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _save() async {
    final capacity = int.tryParse(_capacity.text.trim());
    final booked = int.tryParse(_booked.text.trim());
    final draft = FiringDraft(
      title: _title.text,
      kiln: _kiln,
      startsAt: DateTime(_day.year, _day.month, _day.day, _hour),
      endsAt: DateTime(_day.year, _day.month, _day.day, _hour).add(Duration(hours: _duration)),
      cone: _cone,
      atmosphere: _atmosphere,
      lead: _lead.text,
      notes: _notes.text,
      capacity: capacity ?? 0,
      booked: booked ?? -1,
    );
    final error = validateFiringDraft(draft);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(firingRepositoryProvider).create(draft);
      await ref.read(syncControllerProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a firing')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                TextField(
                  key: const Key('firing-title'),
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Firing'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('firing-lead'),
                  controller: _lead,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Lead'),
                ),
                const SizedBox(height: 16),
                const _Label('Kiln'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final kiln in kilnNames)
                      ChoiceChip(
                        label: Text(kiln),
                        selected: _kiln == kiln,
                        onSelected: (_) => setState(() => _kiln = kiln),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle: Text(
                    '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDay,
                ),
                const _Label('Start hour'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final hour in const [7, 8, 9, 10, 11, 16, 17, 18])
                      ChoiceChip(
                        label: Text('$hour:00'),
                        selected: _hour == hour,
                        onSelected: (_) => setState(() => _hour = hour),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Label('Duration'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final hours in const [8, 10, 12, 16, 24, 36])
                      ChoiceChip(
                        label: Text('${hours}h'),
                        selected: _duration == hours,
                        onSelected: (_) => setState(() => _duration = hours),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Label('Cone'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final cone in coneLabels)
                      ChoiceChip(
                        label: Text(cone),
                        selected: _cone == cone,
                        onSelected: (_) => setState(() => _cone = cone),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Label('Atmosphere'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final atmosphere in Atmosphere.values)
                      ChoiceChip(
                        label: Text(atmosphere.label),
                        selected: _atmosphere == atmosphere,
                        onSelected: (_) => setState(() => _atmosphere = atmosphere),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _capacity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Shelves'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _booked,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Booked'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          _SaveBar(
            error: _error,
            saving: _saving,
            label: 'Save firing',
            buttonKey: const Key('save-firing'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.error,
    required this.saving,
    required this.label,
    required this.buttonKey,
    required this.onPressed,
  });

  final String? error;
  final bool saving;
  final String label;
  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Text(
                  error!,
                  key: const Key('form-error'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                key: buttonKey,
                onPressed: saving ? null : onPressed,
                child: Text(saving ? 'Saving…' : label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
