import 'package:csv/csv.dart';
import 'package:flutter_cpc_music_list/helper/dbFunctions.dart';
import 'package:flutter_cpc_music_list/models/music.dart';
import 'package:flutter_cpc_music_list/models/service.dart';
import 'package:http/http.dart' as http;
import "package:collection/collection.dart";

var musicLink =
    'https://docs.google.com/spreadsheets/d/1r71O_Bm_-dkKBTtyAPMYMfhh1lg5-MwypKAnEs2eYkQ/gviz/tq?tqx=out:csv&sheet=schedule';

Future<Service?> fetchMusic() async {
  print('fetching music');
  var allServices = await DbFunctions().getServiceList();

  if (allServices == null) {
    updateMusicDb();
  }
  return await DbFunctions().getNextService();
}

void updateMusicDb() async {
  print('updating db');
  final response = await http.get((Uri.parse(musicLink)));
  if (response.statusCode == 200) {
    var parsedMusic = parseCsv(response.body);
    if (parsedMusic.isEmpty) {
      return null;
    }
    await DbFunctions().deleteAllMusic();
    await DbFunctions().addMultipleMusic(parsedMusic);
  } else {
    throw Exception('Failed to load music.');
  }
}

List<Music> parseCsv(String csv) {
  List<List<dynamic>> parsedList =
      const CsvToListConverter().convert(csv, eol: '\n');
  final keys = parsedList.first;

  var mappedList =
      parsedList.skip(1).map((v) => Map.fromIterables(keys, v)).toList();

  var musicList = mappedList.map((e) => Music.fromCsv(e)).toList();

  return musicList;
}

List<Service> groupMusic(List<Music> musicList) {
  var newMap = groupBy(musicList, (item) => '${item.date},${item.serviceType}');

  var serviceList = <Service>[];

  newMap.forEach((k, v) => serviceList.add(
      Service(date: k.split(',')[0], serviceType: k.split(',')[1], music: v)));
  return serviceList;
}
