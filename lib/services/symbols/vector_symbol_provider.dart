/// Vector symbol provider.
///
/// Maps button concepts and labels to scalable, high-contrast Material vector icons (Apache-2.0).
library;

import 'package:flutter/material.dart';

import 'symbol_provider.dart';

class VectorSymbolProvider implements SymbolProvider {
  const VectorSymbolProvider();

  @override
  String get id => 'vector';

  @override
  String get displayName => 'Material Vector Symbols';

  @override
  String get license => 'Apache-2.0';

  @override
  bool canHandle(String uri) => true;

  static IconData resolveIcon(String uriOrLabel) {
    final key = uriOrLabel
        .toLowerCase()
        .replaceAll('assets/symbols/', '')
        .replaceAll('assets/arasaac/', '')
        .replaceAll('.png', '');

    if (key.contains('food') || key.contains('eat') || key.contains('apple') || key.contains('cereal') || key.contains('cookie') || key.contains('pizza') || key.contains('rice') || key.contains('bread')) {
      return Icons.restaurant;
    }
    if (key.contains('water') || key.contains('drink') || key.contains('juice') || key.contains('milk')) {
      return Icons.local_drink;
    }
    if (key.contains('bathroom') || key.contains('toilet')) return Icons.wc;
    if (key.contains('home') || key.contains('house')) return Icons.home;
    if (key.contains('school')) return Icons.school;
    if (key.contains('park') || key.contains('playground')) return Icons.park;
    if (key.contains('store')) return Icons.store;
    if (key.contains('hospital') || key.contains('doctor') || key.contains('nurse')) {
      return Icons.local_hospital;
    }
    if (key.contains('help')) return Icons.help;
    if (key.contains('stop')) return Icons.pan_tool;
    if (key.contains('break')) return Icons.free_breakfast;
    if (key.contains('all_done') || key.contains('done')) return Icons.task_alt;
    if (key.contains('wait')) return Icons.hourglass_empty;
    if (key.contains('more') || key.contains('again')) return Icons.add_circle;
    if (key.contains('play') || key.contains('toy') || key.contains('game')) {
      return Icons.sports_esports;
    }
    if (key.contains('book') || key.contains('read')) return Icons.menu_book;
    if (key.contains('sleep') || key.contains('tired') || key.contains('bed')) {
      return Icons.bedtime;
    }
    if (key.contains('happy') || key.contains('good') || key.contains('excited')) {
      return Icons.sentiment_satisfied_alt;
    }
    if (key.contains('sad') || key.contains('bad')) return Icons.sentiment_very_dissatisfied;
    if (key.contains('scared') || key.contains('worried')) return Icons.sentiment_neutral;
    if (key.contains('hurt') || key.contains('pain')) return Icons.healing;
    if (key.contains('like') || key.contains('love')) return Icons.favorite;
    if (key.contains('yes')) return Icons.check_circle;
    if (key.contains('no')) return Icons.cancel;
    if (key.contains('thank')) return Icons.thumb_up;
    if (key.contains('please')) return Icons.volunteer_activism;
    if (key.contains('sorry')) return Icons.back_hand;
    if (key.contains('where')) return Icons.location_on;
    if (key.contains('who')) return Icons.person_search;
    if (key.contains('when')) return Icons.event;
    if (key.contains('what') || key.contains('why') || key.contains('how')) return Icons.help_outline;
    if (key.contains('folder') || key.contains('nav')) return Icons.folder;
    if (key.contains('car')) return Icons.directions_car;
    if (key.contains('bus')) return Icons.directions_bus;
    if (key.contains('phone')) return Icons.phone;
    if (key.contains('tv')) return Icons.tv;
    if (key.contains('music') || key.contains('sing')) return Icons.music_note;
    if (key.contains('time') || key.contains('clock') || key.contains('now') || key.contains('later')) {
      return Icons.schedule;
    }
    if (key.contains('people') || key.contains('mom') || key.contains('dad') || key.contains('family')) {
      return Icons.people;
    }
    if (key.contains('i') || key.contains('me')) return Icons.person;
    if (key.contains('you')) return Icons.person_outline;
    return Icons.chat_bubble_outline;
  }

  @override
  Widget buildSymbol(
    BuildContext context, {
    required String uri,
    required String label,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
  }) {
    final iconData = resolveIcon(uri.isNotEmpty ? uri : label);
    final size = (width != null && height != null)
        ? (width < height ? width : height)
        : 32.0;
    return Icon(
      iconData,
      size: size,
      color: color ?? const Color(0xFF2C3E50),
      semanticLabel: label,
    );
  }
}
