import 'package:flutter/material.dart';

import '../models/box_item.dart';
import '../theme/app_theme.dart';

const _weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// When an item came, as DA1 writes it: « 08:42 », « hier », « lun. », « 28 sept. ».
String boxTime(DateTime ts, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(ts.year, ts.month, ts.day);
  final days = DateTime(today.year, today.month, today.day).difference(day).inDays;
  if (days <= 0) return '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
  if (days == 1) return 'hier';
  if (days < 7) return _weekdays[ts.weekday - 1];
  return '${ts.day} ${_months[ts.month - 1]}';
}

/// « Syndic » out of « Syndic <syndic@exemple.fr> » — the address stays in the reader.
String senderName(String from) {
  final name = from.split('<').first.trim().replaceAll('"', '');
  return name.isEmpty ? from.replaceAll(RegExp('[<>]'), '').trim() : name;
}

/// The row's label: « Mail · Syndic », « GitHub », « Agenda »…
String sourceLabel(BoxItem item) => switch (item.source) {
      BoxSource.email => item.from == null ? 'Mail' : 'Mail · ${senderName(item.from!)}',
      BoxSource.calendar => 'Agenda',
      BoxSource.tasks => 'Tâches',
      BoxSource.github => 'GitHub',
      BoxSource.rss => 'RSS',
      BoxSource.ha => 'Maison',
      BoxSource.system => 'Système',
    };

/// The words of a gesture on this item — « Terminé » at GitHub, « Fait » on a task.
String gestureLabel(BoxItem item, BoxGesture g) => switch (g) {
      BoxGesture.open => 'Lire en entier',
      BoxGesture.read => 'Marquer comme lu',
      BoxGesture.unread => 'Marquer non lu',
      BoxGesture.archive => 'Archiver',
      BoxGesture.trash => 'Corbeille',
      BoxGesture.done => item.source == BoxSource.tasks ? 'Fait' : 'Terminé',
    };

/// A section title of the box: « Urgent », « Le reste », « Du hub ».
class BoxSectionTitle extends StatelessWidget {
  const BoxSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Row(
          children: [
            Expanded(child: Text(text, style: _sectionStyle)),
            if (trailing != null) Text(trailing!, style: da(size: 12, color: Palette.lune)),
          ],
        ),
      );

  static final _sectionStyle = da(size: 12, color: Palette.lune, letterSpacing: 0.7);
}
