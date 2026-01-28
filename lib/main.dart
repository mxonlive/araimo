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

// --- CONFIGURATION ---
// 🔥 YOUR SINGLE M3U LINK 🔥
const String m3uUrl = "https://mxonlive.short.gy/araimo-playlist-m3u"; 

const String appName = "Araimo";
const String noticeText = "Welcome to Araimo - Clean & Fast Streaming.";
const String telegramUrl = "https://t.me/araimo";

const Map<String, String> defaultHeaders = {
  "User-Agent": "araimo-clean/3.0 (Android)",
};

// --- CACHE MANAGER ---
final customCacheManager = fcm.CacheManager(
  fcm.Config(
    'araimo_clean_cache', 
    stalePeriod: const Duration(days: 3), 
    maxNrOfCacheObjects: 300, 
    repo: fcm.JsonCacheInfoRepository(databaseName: 'araimo_clean_cache'),
    fileService: fcm.HttpFileService(),
  ),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Prevent Screen Sleep
  WakelockPlus.enable();
  
  // 2. System UI Style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0F0F0F),
    statusBarIconBrightness: Brightness.light,
  ));
  
  runApp(const AraimoApp());
}

// --- DATA MODEL ---
class Channel {
  final String name;
  final String logo;
  final String url;
  final String group;
  final Map<String, String> headers;

  Channel({
    required this.name, 
    required this.logo, 
    required this.url, 
    required this.group, 
    this.headers = const {}
  });
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
        primaryColor: const Color(0xFF00E676), // Green Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Sans'),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// --- LOGO COMPONENT ---
class ChannelLogo extends StatelessWidget {
  final String url;
  const ChannelLogo({super.key, required this.url});
  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || !url.startsWith('http')) return _fallback();
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: customCacheManager,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(child: SpinKitPulse(color: Colors.greenAccent, size: 15)),
      errorWidget: (context, url, error) => _fallback(),
    );
  }
  Widget _fallback() => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Opacity(opacity: 0.3, child: Image.asset('assets/logo.png', fit: BoxFit.contain)),
  );
}

// --- HOME PAGE ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Channel> allChannels = [];
  List<Channel> filteredChannels = [];
  
  // 🔥 Group Management
  List<String> groups = ["All"];
  String selectedGroup = "All";

  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadPlaylist();
  }

  void _showMsg(String msg, {bool isError = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? Colors.red.shade900 : Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // --- FETCH & PARSE M3U ---
  Future<void> loadPlaylist() async {
    setState(() { isLoading = true; searchController.clear(); });
    try {
      final response = await http.get(Uri.parse(m3uUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        parseM3u(response.body);
      } else {
        throw Exception("Failed to load playlist");
      }
    } catch (e) {
      setState(() { isLoading = false; });
      _showMsg("Network Error: ${e.toString()}", isError: true);
    }
  }

  void parseM3u(String content) {
    List<String> lines = const LineSplitter().convert(content);
    List<Channel> channels = [];
    Set<String> uniqueGroups = {}; // To store unique group names
    
    String? name; String? logo; String? group; Map<String, String> currentHeaders = {};

    for (String line in lines) {
      line = line.trim(); if (line.isEmpty) continue;
      
      if (line.startsWith("#EXTINF:")) {
        // Parse Name
        final nameMatch = RegExp(r',(.*)').firstMatch(line); 
        name = nameMatch?.group(1)?.trim();
        if (name == null || name.isEmpty) { 
           final tvgName = RegExp(r'tvg-name="([^"]*)"').firstMatch(line); 
           name = tvgName?.group(1); 
        }
        name ??= "Channel ${channels.length + 1}";

        // Parse Logo
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line); 
        logo = logoMatch?.group(1) ?? "";
        
        // Parse Group
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line); 
        group = groupMatch?.group(1) ?? "Others";
        uniqueGroups.add(group); 

      } else if (line.startsWith("#EXTVLCOPT:") || line.startsWith("#EXTHTTP:") || line.startsWith("#KODIPROP:")) {
        // Parse Headers
        String raw = line.substring(line.indexOf(":") + 1).trim();
        if (raw.toLowerCase().startsWith("http-user-agent=") || raw.toLowerCase().startsWith("user-agent=")) {
          currentHeaders['User-Agent'] = raw.substring(raw.indexOf("=") + 1).trim();
        } else if (raw.toLowerCase().startsWith("http-cookie=")) {
          currentHeaders['Cookie'] = raw.substring(12).trim();
        } else if (raw.toLowerCase().startsWith("http-referrer=") || raw.toLowerCase().startsWith("http-referer=")) {
          currentHeaders['Referer'] = raw.split('=')[1].trim();
        }
      } else if (!line.startsWith("#")) {
        // Create Channel Object
        if (name != null) {
          if (!currentHeaders.containsKey('User-Agent')) currentHeaders['User-Agent'] = defaultHeaders['User-Agent']!;
          channels.add(Channel(name: name, logo: logo ?? "", url: line, group: group ?? "Others", headers: Map.from(currentHeaders)));
          name = null; currentHeaders = {}; 
        }
      }
    }

    // Sort Groups and Add "All"
    List<String> sortedGroups = uniqueGroups.toList()..sort();
    
    setState(() { 
      allChannels = channels; 
      filteredChannels = channels;
      groups = ["All", ...sortedGroups];
      isLoading = false; 
    });
  }

  // --- FILTER LOGIC ---
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

  void _onGroupSelected(String group) {
    setState(() {
      selectedGroup = group;
      _filterData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName, style: TextStyle(letterSpacing: 1.2)),
        leading: Padding(padding: const EdgeInsets.all(10.0), child: Image.asset('assets/logo.png', errorBuilder: (c,o,s)=>const Icon(Icons.tv, color: Colors.greenAccent))),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: loadPlaylist)],
      ),
      body: RefreshIndicator(
        onRefresh: loadPlaylist,
        color: Colors.greenAccent, backgroundColor: const Color(0xFF1E1E1E),
        child: isLoading 
            ? const Center(child: SpinKitFadingCircle(color: Colors.greenAccent, size: 50))
            : Column(children: [
                  // 1. Notice Bar
                  Container(height: 35, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF252525), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))), child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12), color: Colors.greenAccent.withOpacity(0.15), height: double.infinity, child: const Icon(Icons.campaign_rounded, size: 18, color: Colors.greenAccent)), Expanded(child: Marquee(text: noticeText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), scrollAxis: Axis.horizontal, blankSpace: 20.0, velocity: 40.0, startPadding: 10.0))]))),
                  
                  // 2. Search Box
                  Container(height: 45, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white10)), child: TextField(controller: searchController, onChanged: (v) => _filterData(), style: const TextStyle(color: Colors.white), cursorColor: Colors.greenAccent, decoration: InputDecoration(hintText: "Search Channels...", hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14), prefixIcon: const Icon(Icons.search, color: Colors.grey), suffixIcon: searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18, color: Colors.grey), onPressed: () { searchController.clear(); _filterData(); }) : null, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10)))),
                  
                  const SizedBox(height: 10),
                  
                  // 3. 🔥 GROUP FILTER BAR (Replaces Old Server List) 🔥
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: groups.length,
                      itemBuilder: (ctx, index) {
                        final grp = groups[index]; final isSelected = selectedGroup == grp;
                        return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(onTap: () => _onGroupSelected(grp), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? Colors.greenAccent.shade700 : const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: isSelected ? null : Border.all(color: Colors.white10)), child: Center(child: Text(grp, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12))))));
                      },
                    ),
                  ),
                  
                  const Divider(color: Colors.white10, height: 20),
                  
                  // 4. Grid View
                  Expanded(child: filteredChannels.isEmpty 
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.sentiment_dissatisfied, size: 50, color: Colors.grey), const SizedBox(height: 10), const Text("No channels found", style: TextStyle(color: Colors.grey))])) 
                    : GridView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.85, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: filteredChannels.length, itemBuilder: (ctx, i) { final channel = filteredChannels[i]; return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel, allChannels: allChannels))), child: Container(decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Column(children: [Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: ChannelLogo(url: channel.logo))), Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), decoration: const BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))), child: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white70), textAlign: TextAlign.center))]))); })
                  ),
                ]),
      ),
    );
  }
}

// --- PLAYER SCREEN ---
class PlayerScreen extends StatefulWidget {
  final Channel channel; final List<Channel> allChannels;
  const PlayerScreen({super.key, required this.channel, required this.allChannels});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late PodPlayerController _podController; late List<Channel> relatedChannels; bool isError = false;
  
  @override
  void initState() {
    super.initState(); WakelockPlus.enable();
    // Related channels logic
    relatedChannels = widget.allChannels.where((c) => c.group == widget.channel.group && c.name != widget.channel.name).toList();
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    setState(() { isError = false; });
    try {
      _podController = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(widget.channel.url, httpHeaders: widget.channel.headers),
        podPlayerConfig: const PodPlayerConfig(autoPlay: true, isLooping: true, videoQualityPriority: [720, 1080, 480], wakelockEnabled: true)
      )..initialise().then((_) { if(mounted) setState(() {}); });
      
      _podController.addListener(() { if (_podController.videoPlayerValue?.hasError ?? false) { if(mounted) setState(() { isError = true; }); } });
    } catch (e) { if(mounted) setState(() { isError = true; }); }
  }
  
  @override
  void dispose() { try { _podController.dispose(); } catch(e) {} SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); WakelockPlus.disable(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: SafeArea(child: Column(children: [
            AspectRatio(aspectRatio: 16 / 9, child: Container(color: Colors.black, child: isError ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, color: Colors.red, size: 40), const SizedBox(height: 10), const Text("Stream Offline", style: TextStyle(color: Colors.white)), TextButton(onPressed: _initializePlayer, child: const Text("Retry"))])) : PodVideoPlayer(controller: _podController))),
            Expanded(child: Column(children: [
                  GestureDetector(onTap: () => launchUrl(Uri.parse(telegramUrl), mode: LaunchMode.externalApplication), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), color: const Color(0xFF00C853), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.telegram, color: Colors.white), SizedBox(width: 10), Text("JOIN TELEGRAM CHANNEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1))]))),
                  Padding(padding: const EdgeInsets.all(12), child: Align(alignment: Alignment.centerLeft, child: Text("More from ${widget.channel.group}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)))),
                  Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: relatedChannels.length, itemBuilder: (ctx, index) { final ch = relatedChannels[index]; return ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), leading: Container(width: 60, height: 40, decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(6)), child: ChannelLogo(url: ch.logo)), title: Text(ch.name, style: const TextStyle(color: Colors.white)), subtitle: Text(ch.group, style: const TextStyle(color: Colors.grey, fontSize: 10)), trailing: const Icon(Icons.play_circle_outline, color: Colors.greenAccent), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: ch, allChannels: widget.allChannels)))); })),
                ])),
          ])),
    );
  }
}
