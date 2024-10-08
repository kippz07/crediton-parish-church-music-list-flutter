import 'package:intl/intl.dart';

class Music {
  final String? id;
  final String date;
  final String time;
  final String serviceType;
  final String musicType;
  final String title;
  final String? composer;
  final String? link;

  const Music({
    required this.date,
    required this.time,
    required this.serviceType,
    required this.musicType,
    required this.title,
    this.composer,
    this.link,
    this.id,
  });

  factory Music.fromCsv(Map<dynamic, dynamic> csv) {
    return switch (csv) {
      {
        'date': String date,
        'time': String time,
        'service': String serviceType,
        'type': String musicType,
        'title': String title,
        'composer': String? composer,
        'link': String? link
      } =>
        Music(
            date: date.replaceAll('-', ''),
            time: time.replaceAll(':', ''),
            serviceType: serviceType,
            musicType: musicType,
            title: title,
            composer: composer,
            link: link),
      _ => throw const FormatException('Failed to load music.'),
    };
  }

  factory Music.fromDb(Map<String, dynamic>? dict) {
    return switch (dict) {
      {
        'id': String id,
        'service_date': int date,
        'service_time': int time,
        'serviceType': String serviceType,
        'musicType': String musicType,
        'title': String title,
        'composer': String? composer,
        'link': String? link
      } =>
        Music(
            date: date.toString(),
            time: time.toString(),
            serviceType: serviceType,
            musicType: musicType,
            title: title,
            composer: composer,
            link: link),
      {
        'id': String id,
        'service_date': int date,
        'service_time': int time,
        'serviceType': String serviceType,
        'musicType': String musicType,
        'title': int title,
        'composer': String? composer,
        'link': String? link
      } =>
        Music(
            date: date.toString(),
            time: time.toString(),
            serviceType: serviceType,
            musicType: musicType,
            title: title.toString(),
            composer: composer,
            link: link),
      _ => throw const FormatException('Failed to load music.'),
    };
  }

  Map<String, Object?> toMap() {
    return {
      'id': '$date$serviceType$musicType$title',
      'service_date': date,
      'service_time': time,
      'serviceType': serviceType,
      'musicType': musicType,
      'title': title,
      'composer': composer,
      'link': link
    };
  }

  static String parseDate(String date) {
    final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');
    if (date.length != 8) date = '0$date';
    return dateFormatter.format(DateTime.parse(date));
  }
}
