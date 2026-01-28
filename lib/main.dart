import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as fcm; 
import 'package:pod_player/pod_player.dart';
import 'package:marquee/marquee.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// --- 🔥 CONFIGURATION SOURCES (Failover System) 🔥 ---
const String primaryConfigUrl = "https://raw.githubusercontent.com/mxonlive/araimo/refs/heads/main/data.json";
const String backupConfigUrl = "https://raw.githubusercontent.com/mxonlive/araimo/refs/heads/main/data.json"; // Use a different link

const String appName = "Araimo";
const Map<String, String> defaultHeaders = {
  "User-Agent": "araimo-v4/android",
};

// --- CACHE ---
final customCacheManager = fcm.CacheManager(
  fcm.Config(
    'araimo_v4_cache', 
    stalePeriod: const Duration(days: 3), 
    maxNrOfCacheObjects: 300, 
    repo: fcm.JsonCacheInfoRepository(databaseName: 'araimo_v4_cache'),
    fileService: fcm.HttpFileService(),
  ),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0F0F0F),
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const AraimoApp());
}

// --- MODELS ---
class AppConfig {
  String notice;
  String aboutNotice;
  String playlistUrl;
  String telegramUrl;
  Map<String, dynamic>? updateData;

  AppConfig({
    required this.notice,
    required this.aboutNotice,
    required this.playlistUrl,
    required this.telegramUrl,
    this.updateData,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      notice: json['notice'] ?? "Welcome to Araimo",
      aboutNotice: json['about_notice'] ?? "No info available.",
      playlistUrl: json['playlist_url'] ?? "",
      telegramUrl: json['telegram_url'] ?? "",
      updateData: json['update_data'],
    );
  }
}

class Channel {
  final String name;
  final String logo;
  final String url;
  final String group;
  final Map<String, String> headers;
  Channel({required this.name, required this.logo, required this.url, required this.group, this.headers = const {}});
}

// --- APP ROOT ---
class AraimoApp extends StatelessWidget {
  const AraimoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: const Color(0xFF00E676),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Sans'),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// --- SPLASH SCREEN (CONFIG LOADER) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _loadConfigWithFailover();
  }

  Future<void> _loadConfigWithFailover() async {
    try {
      print("Attempting Primary Config...");
      await _fetchAndNavigate(primaryConfigUrl);
    } catch (e) {
      print("Primary Failed. Attempting Backup...");
      try {
        await _fetchAndNavigate(backupConfigUrl);
      } catch (e2) {
        // Only if both fail
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to load configuration. Check Internet.")));
        }
      }
    }
  }

  Future<void> _fetchAndNavigate(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final config = AppConfig.fromJson(data);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(config: config)));
      }
    } else {
      throw Exception("HTTP Error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1E1E1E), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 40)]),
              child: ClipRRect(borderRadius: BorderRadius.circular(100), child: Image.asset('assets/logo.png', width: 100, height: 100)),
            ),
            const SizedBox(height: 30),
            const SpinKitThreeBounce(color: Colors.greenAccent, size: 25),
          ],
        ),
      ),
    );
  }
}

// --- HOME PAGE ---
class HomePage extends StatefulWidget {
  final AppConfig config;
  const HomePage({super.key, required this.config});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Channel> allChannels = [];
  List<Channel> filteredChannels = [];
  List<String> groups = ["All"];
  String selectedGroup = "All";
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadPlaylist();
  }

  Future<void> loadPlaylist() async {
    setState(() { isLoading = true; });
    try {
      final response = await http.get(Uri.parse(widget.config.playlistUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        parseM3u(response.body);
      } else {
        throw Exception("Failed");
      }
    } catch (e) {
      setState(() { isLoading = false; });
    }
  }

  void parseM3u(String content) {
    List<String> lines = const LineSplitter().convert(content);
    List<Channel> channels = [];
    Set<String> uniqueGroups = {};
    String? name; String? logo; String? group; Map<String, String> currentHeaders = {};

    for (String line in lines) {
      line = line.trim(); if (line.isEmpty) continue;
      if (line.startsWith("#EXTINF:")) {
        final nameMatch = RegExp(r',(.*)').firstMatch(line); name = nameMatch?.group(1)?.trim();
        if (name == null || name.isEmpty) { final tvgName = RegExp(r'tvg-name="([^"]*)"').firstMatch(line); name = tvgName?.group(1); }
        name ??= "Channel ${channels.length + 1}";
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line); logo = logoMatch?.group(1) ?? "";
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line); group = groupMatch?.group(1) ?? "Others";
        uniqueGroups.add(group);
      } else if (!line.startsWith("#")) {
        if (name != null) {
          channels.add(Channel(name: name, logo: logo ?? "", url: line, group: group ?? "Others", headers: currentHeaders));
          name = null; currentHeaders = {};
        }
      }
    }

    List<String> sortedGroups = uniqueGroups.toList()..sort();
    setState(() {
      allChannels = channels;
      filteredChannels = channels;
      groups = ["All", ...sortedGroups];
      isLoading = false;
    });
  }

  void _filterData() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredChannels = allChannels.where((c) {
        bool matchesSearch = c.name.toLowerCase().contains(query);
        bool matchesGroup = selectedGroup == "All" || c.group == selectedGroup;
        return matchesSearch && matchesGroup;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName, style: TextStyle(letterSpacing: 1.2)),
        leading: Padding(padding: const EdgeInsets.all(10.0), child: Image.asset('assets/logo.png')),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InfoPage(config: widget.config))),
          )
        ],
      ),
      body: Column(children: [
        // NOTICE
        if(widget.config.notice.isNotEmpty)
          Container(height: 35, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF252525), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))), child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12), color: Colors.greenAccent.withOpacity(0.15), height: double.infinity, child: const Icon(Icons.campaign_rounded, size: 18, color: Colors.greenAccent)), Expanded(child: Marquee(text: widget.config.notice, style: const TextStyle(color: Colors.white), scrollAxis: Axis.horizontal, blankSpace: 20.0, velocity: 40.0))]))),
        
        // SEARCH
        Container(height: 45, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white10)), child: TextField(controller: searchController, onChanged: (v) => _filterData(), style: const TextStyle(color: Colors.white), cursorColor: Colors.greenAccent, decoration: InputDecoration(hintText: "Search Channels...", prefixIcon: const Icon(Icons.search, color: Colors.grey), suffixIcon: searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18, color: Colors.grey), onPressed: () { searchController.clear(); _filterData(); }) : null, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10)))),
        
        const SizedBox(height: 10),

        // 🔥 GROUP FILTERS 🔥
        SizedBox(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: groups.length, itemBuilder: (ctx, index) {
          final grp = groups[index]; final isSelected = selectedGroup == grp;
          return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(onTap: () { setState(() { selectedGroup = grp; _filterData(); }); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? Colors.greenAccent.shade700 : const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: isSelected ? null : Border.all(color: Colors.white10)), child: Center(child: Text(grp, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12))))));
        })),

        const Divider(color: Colors.white10, height: 20),

        // GRID
        Expanded(child: isLoading ? const Center(child: SpinKitFadingCircle(color: Colors.greenAccent)) : GridView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.85, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: filteredChannels.length, itemBuilder: (ctx, i) { final ch = filteredChannels[i]; return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: ch))), child: Container(decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)), child: Column(children: [Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: ChannelLogo(url: ch.logo))), Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6), color: Colors.black26, child: Text(ch.name, maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white70)))]))); }))
      ]),
    );
  }
}

// --- PLAYER ---
class PlayerScreen extends StatefulWidget { final Channel channel; const PlayerScreen({super.key, required this.channel}); @override State<PlayerScreen> createState() => _PlayerScreenState(); }
class _PlayerScreenState extends State<PlayerScreen> {
  late PodPlayerController _ctrl;
  @override void initState() { super.initState(); _ctrl = PodPlayerController(playVideoFrom: PlayVideoFrom.network(widget.channel.url), podPlayerConfig: const PodPlayerConfig(autoPlay: true, wakelockEnabled: true))..initialise(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: Text(widget.channel.name)), body: Center(child: PodVideoPlayer(controller: _ctrl))); }
}

// --- INFO PAGE ---
class InfoPage extends StatelessWidget { final AppConfig config; const InfoPage({super.key, required this.config}); @override Widget build(BuildContext context) {
  final update = config.updateData; final hasUpdate = update != null && update['show'] == true;
  return Scaffold(appBar: AppBar(title: const Text("About")), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    if(hasUpdate) Container(padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Column(children: [Text(update!['version'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(update['note']), const SizedBox(height: 10), ElevatedButton(onPressed: () => launchUrl(Uri.parse(update['download_url'])), child: const Text("Download Update"))])),
    Text(config.aboutNotice, style: const TextStyle(color: Colors.grey, height: 1.5), textAlign: TextAlign.center),
    const Spacer(),
    ListTile(title: const Text("Join Telegram"), trailing: const Icon(Icons.telegram, color: Colors.blue), onTap: () => launchUrl(Uri.parse(config.telegramUrl)))
  ])));
}}

class ChannelLogo extends StatelessWidget { final String url; const ChannelLogo({super.key, required this.url}); @override Widget build(BuildContext context) { return CachedNetworkImage(imageUrl: url, cacheManager: customCacheManager, errorWidget: (c,u,e)=>Image.asset('assets/logo.png')); }}
