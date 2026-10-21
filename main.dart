import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'files_page.dart';
import 'store.dart';

void main() => runApp(const InfinityApp());

class InfinityApp extends StatelessWidget {
  const InfinityApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Infinity Browser',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F3B9C)),
        ),
        home: const BrowserPage(),
      );
}

const _adHosts = [
  'doubleclick\\.net', 'googlesyndication\\.com', 'googleadservices\\.com',
  'adservice\\.google\\.com', 'adnxs\\.com', 'taboola\\.com', 'outbrain\\.com',
  'popads\\.net', 'propellerads\\.com', 'adsterra\\.com', 'moatads\\.com',
];

final _adBlockers = _adHosts
    .map((h) => ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: '.*$h.*'),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ))
    .toList();

final _imageBlocker = ContentBlocker(
  trigger: ContentBlockerTrigger(
      urlFilter: '.*', resourceType: [ContentBlockerTriggerResourceType.IMAGE]),
  action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
);

final _mediaRegex =
    RegExp(r'\.(mp3|m4a|wav|ogg|mp4|webm|mkv)(\?|$)', caseSensitive: false);

const _nightJs =
    "document.documentElement.style.filter='invert(1) hue-rotate(180deg)';"
    "document.querySelectorAll('img,video').forEach(e=>e.style.filter='invert(1) hue-rotate(180deg)');";
const _dayJs = "document.documentElement.style.filter='';"
    "document.querySelectorAll('img,video').forEach(e=>e.style.filter='');";

const _shortcuts = [
  ('Google', 'https://www.google.com', Colors.red),
  ('YouTube', 'https://m.youtube.com', Colors.redAccent),
  ('Facebook', 'https://m.facebook.com', Colors.blue),
  ('X', 'https://x.com', Colors.black87),
  ('Instagram', 'https://www.instagram.com', Colors.purple),
  ('Wikipedia', 'https://www.wikipedia.org', Colors.blueGrey),
  ('Amazon', 'https://www.amazon.com', Colors.orange),
  ('Suno', 'https://suno.com', Colors.teal),
];

class MediaItem {
  final String url, name;
  MediaItem(this.url, this.name);
}

class BrowserTab {
  final bool incognito;
  InAppWebViewController? controller;
  bool isHome = true;
  String url = '';
  String title = 'Yeni sekme';
  double progress = 0;
  final List<MediaItem> media = [];
  BrowserTab({this.incognito = false});
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final List<BrowserTab> tabs = [BrowserTab()];
  int cur = 0;
  bool adBlock = true, noPicture = false, night = false, fullscreen = false;
  double dl = -1;
  final urlCtrl = TextEditingController();

  BrowserTab get tab => tabs[cur];

  List<ContentBlocker> get _blockers =>
      [if (adBlock) ..._adBlockers, if (noPicture) _imageBlocker];

  void _go(String input) {
    final t = input.trim();
    if (t.isEmpty) return;
    String url;
    if (t.startsWith('http://') || t.startsWith('https://')) {
      url = t;
    } else if (t.contains('.') && !t.contains(' ')) {
      url = 'https://$t';
    } else {
      url = Uri.https('www.google.com', '/search', {'q': t}).toString();
    }
    setState(() => tab.isHome = false);
    tab.controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _download(String url) async {
    setState(() => dl = 0);
    try {
      final p = await Store.download(url, onProgress: (v) => setState(() => dl = v));
      _msg('İndirildi: ${p.split('/').last}');
    } catch (e) {
      _msg('İndirme hatası: $e');
    } finally {
      if (mounted) setState(() => dl = -1);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _applySettings() {
    for (final t in tabs) {
      t.controller?.setSettings(
          settings: InAppWebViewSettings(contentBlockers: _blockers));
      t.controller?.reload();
    }
  }

  void _applyNight() {
    for (final t in tabs) {
      t.controller?.evaluateJavascript(source: night ? _nightJs : _dayJs);
    }
  }

  void _setFullscreen(bool v) {
    setState(() => fullscreen = v);
    SystemChrome.setEnabledSystemUIMode(
        v ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  void _newTab({bool incognito = false}) {
    setState(() {
      tabs.add(BrowserTab(incognito: incognito));
      cur = tabs.length - 1;
      urlCtrl.clear();
    });
  }

  void _closeTab(int i) {
    if (tabs.length == 1) return;
    setState(() {
      tabs.removeAt(i);
      cur = cur.clamp(0, tabs.length - 1);
      urlCtrl.text = tab.isHome ? '' : tab.url;
    });
  }

  Future<void> _addBookmark() async {
    if (tab.isHome || tab.url.isEmpty) return;
    final l = await Store.bookmarks();
    l.add(Bookmark(tab.title, tab.url));
    await Store.saveBookmarks(l);
    _msg('Yer imi eklendi');
  }

  Future<void> _openBookmarks() async {
    final url = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const BookmarksPage()));
    if (url != null) _go(url);
  }

  void _showTabs() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(children: [
        for (var i = 0; i < tabs.length; i++)
          ListTile(
            leading: Icon(tabs[i].incognito ? Icons.visibility_off : Icons.tab),
            title: Text(tabs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
            selected: i == cur,
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context);
                _closeTab(i);
              },
            ),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                cur = i;
                urlCtrl.text = tab.isHome ? '' : tab.url;
              });
            },
          ),
      ]),
    );
  }

  void _showMedia() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: tab.media.isEmpty
            ? const SizedBox(
                height: 120,
                child: Center(child: Text('Bu sayfada indirilebilir medya bulunamadı')))
            : ListView(shrinkWrap: true, children: [
                const ListTile(title: Text('Medya algılayıcı', style: TextStyle(fontWeight: FontWeight.bold))),
                for (final m in tab.media)
                  ListTile(
                    leading: Icon(m.name.toLowerCase().contains(RegExp(r'\.(mp3|m4a|wav|ogg)'))
                        ? Icons.music_note
                        : Icons.play_circle_fill),
                    title: Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () {
                        Navigator.pop(context);
                        _download(m.url);
                      },
                    ),
                  ),
              ]),
      ),
    );
  }

  void _showMenu() {
    final items = <(IconData, String, bool, VoidCallback)>[
      (Icons.dark_mode, 'Gece modu', night, () { setState(() => night = !night); _applyNight(); }),
      (Icons.hide_image, 'Resimsiz', noPicture, () { setState(() => noPicture = !noPicture); _applySettings(); }),
      (Icons.fullscreen, 'Tam ekran', fullscreen, () => _setFullscreen(true)),
      (Icons.visibility_off, 'Gizli sekme', false, () => _newTab(incognito: true)),
      (Icons.star_border, 'Yer imi ekle', false, _addBookmark),
      (Icons.bookmarks, 'Yer imleri', false, _openBookmarks),
      (Icons.refresh, 'Yenile', false, () => tab.controller?.reload()),
      (Icons.download, 'İndir', false, _showMedia),
      (Icons.share, 'Paylaş', false, () { if (!tab.isHome) Share.share(tab.url); }),
      (Icons.folder, 'Dosyalar', false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FilesPage()))),
      (Icons.block, 'Reklam engelle', adBlock, () { setState(() => adBlock = !adBlock); _applySettings(); }),
      (Icons.power_settings_new, 'Çıkış', false, () => SystemNavigator.pop()),
    ];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            for (final it in items)
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  it.$4();
                },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(it.$1, color: it.$3 ? Colors.green : null),
                  const SizedBox(height: 4),
                  Text(it.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _home() => Container(
        color: Theme.of(context).colorScheme.surface,
        child: GridView.count(
          crossAxisCount: 4,
          padding: const EdgeInsets.all(16),
          children: [
            for (final s in _shortcuts)
              InkWell(
                onTap: () => _go(s.$2),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: s.$3,
                    child: Text(s.$1[0], style: const TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                  const SizedBox(height: 6),
                  Text(s.$1, style: const TextStyle(fontSize: 12)),
                ]),
              ),
          ],
        ),
      );

  Widget _webView(BrowserTab t) => InAppWebView(
        key: ObjectKey(t),
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
        initialSettings: InAppWebViewSettings(
          incognito: t.incognito,
          cacheEnabled: !t.incognito,
          useOnLoadResource: true,
          useOnDownloadStart: true,
          contentBlockers: _blockers,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          supportMultipleWindows: false,
        ),
        onWebViewCreated: (c) => t.controller = c,
        onLoadStart: (c, u) {
          final s = u?.toString() ?? '';
          if (s == 'about:blank') return;
          setState(() {
            t.media.clear();
            t.url = s;
            if (t == tab) urlCtrl.text = s;
          });
        },
        onLoadStop: (c, u) {
          if (night) c.evaluateJavascript(source: _nightJs);
        },
        onTitleChanged: (c, title) => setState(() => t.title = title ?? t.url),
        onProgressChanged: (c, p) => setState(() => t.progress = p / 100),
        onLoadResource: (c, res) {
          final u = res.url.toString();
          if (_mediaRegex.hasMatch(u) && !t.media.any((m) => m.url == u)) {
            final segs = Uri.parse(u).pathSegments;
            setState(() => t.media.add(MediaItem(
                u, segs.isNotEmpty && segs.last.isNotEmpty ? Uri.decodeComponent(segs.last) : u)));
          }
        },
        onDownloadStartRequest: (c, r) => _download(r.url.toString()),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) async {
        if (fullscreen) return _setFullscreen(false);
        if (!tab.isHome && await tab.controller?.canGoBack() == true) {
          tab.controller?.goBack();
        } else if (!tab.isHome) {
          setState(() => tab.isHome = true);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            if (!fullscreen)
              Container(
                color: tab.incognito ? Colors.grey.shade800 : null,
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Row(children: [
                  if (tab.incognito)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.visibility_off, color: Colors.white),
                    ),
                  Expanded(
                    child: TextField(
                      controller: urlCtrl,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: _go,
                      decoration: InputDecoration(
                        hintText: 'Ara veya adres yaz',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.download,
                        color: tab.media.isNotEmpty ? Colors.green : null),
                    onPressed: _showMedia,
                  ),
                ]),
              ),
            if (tab.progress > 0 && tab.progress < 1 && !tab.isHome)
              LinearProgressIndicator(value: tab.progress, minHeight: 2),
            if (dl >= 0) LinearProgressIndicator(value: dl, minHeight: 4),
            Expanded(
              child: Stack(children: [
                IndexedStack(index: cur, children: tabs.map(_webView).toList()),
                if (tab.isHome) Positioned.fill(child: _home()),
                if (fullscreen)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                        icon: const Icon(Icons.fullscreen_exit),
                        onPressed: () => _setFullscreen(false)),
                  ),
              ]),
            ),
            if (!fullscreen)
              BottomAppBar(
                height: 56,
                padding: EdgeInsets.zero,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => tab.controller?.goBack()),
                  IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => tab.controller?.goForward()),
                  IconButton(
                      icon: const Icon(Icons.home),
                      onPressed: () => setState(() {
                            tab.isHome = true;
                            urlCtrl.clear();
                          })),
                  IconButton(
                      icon: Badge(label: Text('${tabs.length}'), child: const Icon(Icons.tab)),
                      onPressed: _showTabs),
                  IconButton(icon: const Icon(Icons.menu), onPressed: _showMenu),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});
  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Bookmark> list = [];
  @override
  void initState() {
    super.initState();
    Store.bookmarks().then((l) => setState(() => list = l));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yer imleri')),
        body: list.isEmpty
            ? const Center(child: Text('Yer imi yok'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(list[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(list[i].url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, list[i].url),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      list.removeAt(i);
                      await Store.saveBookmarks(list);
                      setState(() {});
                    },
                  ),
                ),
              ),
      );
}
