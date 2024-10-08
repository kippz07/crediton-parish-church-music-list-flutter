import 'package:flutter/material.dart';
import 'package:flutter_cpc_music_list/helper/dbFunctions.dart';
import 'package:flutter_cpc_music_list/helper/fetchCatalogue.dart';
import 'package:flutter_cpc_music_list/helper/fetchMusic.dart';
import 'package:flutter_cpc_music_list/helper/navScroll.dart';
import 'package:flutter_cpc_music_list/models/catalogue.dart';
import 'package:flutter_cpc_music_list/models/music.dart';
import 'package:flutter_cpc_music_list/models/service.dart';
import 'package:flutter_cpc_music_list/screens/catalogueScreen.dart';
import 'package:flutter_cpc_music_list/themes/themes.dart';
import 'package:get/get_common/get_reset.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ServiceState(),
      child: MaterialApp(
        title: 'CPC Music',
        theme: GlobalThemeData.lightThemeData,
        darkTheme: GlobalThemeData.darkThemeData,
        home: const MyHomePage(title: 'CPC Music'),
      ),
    );
  }
}

class ServiceState extends ChangeNotifier {
  late Service currentService;
  Service? nextService;
  List<Service>? serviceList;
  List<Catalogue>? catalogueList;
  List<Catalogue>? filteredCatalogueList;
  String seasonMenuValue = 'season (all)';
  String partsMenuValue = 'parts (all)';
  int navIndex = 0;
  Map<String, int> navScrollIndexMapping = {};
  var alphabetList =
      List.generate(26, (index) => String.fromCharCode(index + 65));
  bool initMusicSpinner = true;
  bool initCatalogueSpinner = true;

  void setCurrentService(Service service) {
    currentService = service;
    notifyListeners();
  }

  void setNextService(Service service) {
    nextService = service;
    notifyListeners();
  }

  Future<void> initNextService() async {
    final service = await DbFunctions().getNextService();
    nextService = service;
  }

  Future<void> setServiceList() async {
    final service = await DbFunctions().getServiceList();
    serviceList = service;
    notifyListeners();
  }

  Future<void> updateMusicList() async {
    updateMusicDb();
    final service = await DbFunctions().getServiceList();
    serviceList = service;
    final next = await DbFunctions().getNextService();
    nextService = next;
    notifyListeners();
  }

  Future<void> setCatalogueList(List<Catalogue>? catalogue) async {
    catalogueList = catalogue;
    filterCatalogueListNotify();
    print('catalogue set');
    notifyListeners();
  }

  Future<List<Catalogue>?> filterCatalogueList() async {
    var filteredList = catalogueList;
    if (seasonMenuValue.toLowerCase() != 'season (all)') {
      final filteredSeasonCatalogue = filteredList
          ?.where((music) =>
              music.season!.toLowerCase() == seasonMenuValue.toLowerCase())
          .toList();
      filteredList = filteredSeasonCatalogue;
    }
    if (partsMenuValue.toLowerCase() != 'parts (all)') {
      final filteredPartsCatalogue = filteredList
          ?.where((music) =>
              music.parts.toLowerCase() == partsMenuValue.toLowerCase())
          .toList();
      filteredList = filteredPartsCatalogue;
    }

    filteredCatalogueList = filteredList;
    if (filteredList != null) {
      setnavScrollIndexMapping(filteredList);
    }
    return filteredCatalogueList;
  }

  void filterCatalogueListNotify() {
    filterCatalogueList();
    notifyListeners();
  }

  void setNavIndex(int index) {
    navIndex = index;
    notifyListeners();
  }

  void setnavScrollIndexMapping(List<Catalogue> catalogueList) {
    navScrollIndexMapping = createIndexes(catalogueList);
    alphabetList = navScrollIndexMapping.keys.toList();
    navIndex = 0;
  }
}

void updateNextServiceWidget(Service service) {
  late String hymnNumbers;
  late String date;
  late String serviceType;
  late String psalm;

  for (var music in service.music) {
    if (music.musicType == 'Hymns') {
      hymnNumbers = music.title;
      date = music.date;
      serviceType = music.serviceType;
    } else if (music.musicType == 'Psalm') {
      psalm = music.title;
    }
  }

  HomeWidget.saveWidgetData<String>('service_date', date);
  HomeWidget.saveWidgetData<String>('service_type', serviceType);
  HomeWidget.saveWidgetData<String>('hymn_numbers', 'Hymns: $hymnNumbers');
  HomeWidget.saveWidgetData<String>('psalm', 'Psalm: $psalm');
  HomeWidget.updateWidget(androidName: 'NextServiceWidget');
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // late Future<Service?> futureNextService;
  Service? upcomingService;
  List<Service>? serviceList = <Service>[];
  int? catalogueCount = 0;
  static const String sundayBySundayUrl = 'https://sbs.rscm.org.uk/';

  @override
  void initState() {
    DbFunctions().getServiceList().then((data) => setState(() {
          context.read<ServiceState>().serviceList = data;
          serviceList = data;
          if (data == null) {
            updateMusicDb().then((data) => {
                  DbFunctions().getServiceList().then((data) => setState(() {
                        context.read<ServiceState>().serviceList = data;
                        serviceList = data;
                        DbFunctions()
                            .getNextService()
                            .then((data) => setState(() {
                                  context.read<ServiceState>().nextService =
                                      data;
                                  context
                                      .read<ServiceState>()
                                      .initMusicSpinner = false;
                                }));
                      }))
                });
          } else {
            DbFunctions().getNextService().then((data) => setState(() {
                  context.read<ServiceState>().nextService = data;
                  context.read<ServiceState>().initMusicSpinner = false;
                }));
          }
        }));

    DbFunctions().getCatalogueCount().then((data) => setState(() {
          catalogueCount = data;
          if (catalogueCount == 0) {
            print('fetching catalogue');
            updateCatalogueDb().then((data) => {
                  DbFunctions().getCatalogue().then((data) => setState(() {
                        context.read<ServiceState>().catalogueList = data;
                      }))
                });
          } else {
            DbFunctions().getCatalogue().then((data) => setState(() {
                  context.read<ServiceState>().catalogueList = data;
                }));
          }
        }));

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ServiceState>();

    return Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            title: Text(widget.title),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  setState(() {
                    updateMusicDb().then((data) => {
                          DbFunctions()
                              .getServiceList()
                              .then((data) => setState(() {
                                    context.read<ServiceState>().serviceList =
                                        data;
                                    serviceList = data;
                                    DbFunctions()
                                        .getNextService()
                                        .then((data) => setState(() {
                                              context
                                                  .read<ServiceState>()
                                                  .nextService = data;
                                              context
                                                  .read<ServiceState>()
                                                  .initMusicSpinner = false;
                                            }));
                                  }))
                        });
                  });
                },
              )
            ]),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const ImageSection(image: 'images/church.png'),
              if (!appState.initMusicSpinner)
                Column(
                  children: [
                    if (appState.nextService == null)
                      const ListTile(
                        title: Text('Next service:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('No upcoming services'),
                      ),
                    if (appState.nextService != null)
                      ListTile(
                        title: const Text('Next service:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${Music.parseDate(appState.nextService!.date)} - ${appState.nextService!.serviceType}'),
                      ),
                    if (appState.nextService != null)
                      Card(
                        child: ListTile(
                          title: const Text('View next service',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            appState.setCurrentService(appState.nextService!);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ServiceMusicPage()),
                            );
                          },
                        ),
                      ),
                    if (appState.nextService != null)
                      Card(
                        child: ListTile(
                          title: const Text('View upcoming services',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () async {
                            appState.setServiceList();

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ServiceListPage()),
                            );
                          },
                        ),
                      ),
                  ],
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              Card(
                child: ListTile(
                  title: const Text('Sunday by Sunday login',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await launchUrl(Uri.parse(sundayBySundayUrl));
                  },
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('View music catalogue',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const CataloguePage()),
                    );
                  },
                ),
              ),
            ],
          ),
        ));
  }
}

class ImageSection extends StatelessWidget {
  const ImageSection({super.key, required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    return Image.asset(image, fit: BoxFit.cover);
  }
}

class ServiceListPage extends StatefulWidget {
  const ServiceListPage({super.key});

  @override
  State<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ServiceState>();
    var serviceList = appState.serviceList;

    return Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    appState.updateMusicList();
                  });
                },
              )
            ]),
        body: SingleChildScrollView(
          child: Center(child: () {
            if (serviceList != null) {
              return Column(children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 8),
                  child: Text('Upcoming services',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      )),
                ),
                ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: serviceList!.length,
                  itemBuilder: (context, index) {
                    var date = Music.parseDate(serviceList[index].date);
                    return ListTile(
                      title: Text(date,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(serviceList![index].serviceType),
                      trailing: const Icon(Icons.info_outline),
                      onTap: () {
                        appState.setCurrentService(serviceList[index]);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const ServiceMusicPage()),
                        );
                      },
                    );
                  },
                ),
              ]);
            } else {
              return const Text('No upcoming services');
            }
          }()),
        ));
  }
}

class ServiceMusicPage extends StatelessWidget {
  const ServiceMusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ServiceState>();
    var currentService = appState.currentService;

    return Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            title: Text(Music.parseDate(currentService.date))),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  currentService.serviceType,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ),
              ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: currentService.music.length,
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          currentService.music[index].musicType,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          // textAlign: TextAlign.left,
                        ),
                      ),
                      MusicElementWidget(music: currentService.music[index])
                    ],
                  );
                },
              ),
            ],
          ),
        ));
  }
}

class MusicElementWidget extends StatelessWidget {
  const MusicElementWidget({
    super.key,
    required this.music,
  });

  final Music? music;

  @override
  Widget build(BuildContext context) {
    if (music!.composer != '') {
      return ListTile(
        title: Text(music!.title),
        subtitle: Text(
          music!.composer as String,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
        trailing: music!.link != '' ? PlayLinkWidget(music: music) : null,
      );
    }
    return ListTile(
      title: Text(music!.title),
      trailing: music!.link != '' ? PlayLinkWidget(music: music) : null,
    );
  }
}

class PlayLinkWidget extends StatelessWidget {
  const PlayLinkWidget({
    super.key,
    required this.music,
  });

  final Music? music;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.play_arrow),
      onPressed: () {
        final snackBar = SnackBar(
          content: const Text('Open link in YouTube?'),
          action: SnackBarAction(
            label: 'Yes',
            onPressed: () async {
              await launchUrl(Uri.parse(music!.link as String));
            },
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      },
    );
  }
}
