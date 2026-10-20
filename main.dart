import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

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

// Reklam alan adları (istediğiniz kadar ekleyebilirsiniz)
const _adHosts = [
  'doubleclick\\.net', 'googlesyndication\\.com', 'googleadservices\\.com',
  'adservice\\.google\\.com', 'adnxs\\.com', 'taboola\\.com', 'outbrain\\.com',
  'popads\\.net', 'propellerads\\.com', 'adsterra\\.com', 'moatads\\.com',
];

final _blockers = _adHosts
    .map((h) => ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: '.*$h.*'),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ))
    .toList();

final _mediaRegex =
    RegExp(r'\.(mp3|m4a|wav|ogg|mp4|webm|mkv)(\?|$)', caseSensitive: false);

class BrowserTab {
  final bool incognito;
  InAppWebViewController? controller;
  String url = '';
  String title = 'Yeni sekme';
  double progress = 0;
  String? mediaUrl;
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
  bool adBlock = true;
  double dl = -1;
  final urlCtrl = TextEditingController();

  BrowserTab get tab => tabs[cur];

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
    tab.controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _download(String url) async {
    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final segs = Uri.parse(url).pathSegments;
    final name = segs.isNotEmpty && segs.last.isNotEmpty
        ? segs.last
        : 'indirilen_${DateTime.now().millisecondsSinceEpoch}';
    final path = '${dir.path}/$name';
    setState(() => dl = 0);
    try {
      await Dio().download(url, path, onReceiveProgress: (r, t) {
        if (t > 0) setState(() => dl = r / t);
      });
      _msg('İndirildi: $path');
    } catch (e) {
      _msg('İndirme hatası: $e');
    } finally {
      setState(() => dl = -1);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
      urlCtrl.text = tab.url;
    });
  }

  void _showTabs() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: [
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
                  urlCtrl.text = tab.url;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _webView(BrowserTab t) => InAppWebView(
        key: ObjectKey(t),
        initialUrlRequest: URLRequest(url: WebUri('https://www.google.com')),
        initialSettings: InAppWebViewSettings(
          incognito: t.incognito,
          cacheEnabled: !t.incognito,
          useOnLoadResource: true,
          useOnDownloadStart: true,
          contentBlockers: adBlock ? _blockers : [],
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          supportMultipleWindows: false,
        ),
        onWebViewCreated: (c) => t.controller = c,
        onLoadStart: (c, u) => setState(() {
          t.mediaUrl = null;
          t.url = u?.toString() ?? '';
          if (t == tab) urlCtrl.text = t.url;
        }),
        onTitleChanged: (c, title) =>
            setState(() => t.title = title ?? t.url),
        onProgressChanged: (c, p) => setState(() => t.progress = p / 100),
        onLoadResource: (c, res) {
          final u = res.url.toString();
          if (_mediaRegex.hasMatch(u)) setState(() => t.mediaUrl = u);
        },
        onDownloadStartRequest: (c, r) => _download(r.url.toString()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: tab.incognito ? Colors.white : null,
                  onPressed: () => tab.controller?.reload(),
                ),
              ]),
            ),
            if (tab.progress > 0 && tab.progress < 1)
              LinearProgressIndicator(value: tab.progress, minHeight: 2),
            if (dl >= 0) LinearProgressIndicator(value: dl, minHeight: 4),
            Expanded(
              child: IndexedStack(
                index: cur,
                children: tabs.map(_webView).toList(),
              ),
            ),
            BottomAppBar(
              height: 56,
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => tab.controller?.goBack()),
                  IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => tab.controller?.goForward()),
                  IconButton(
                    icon: Icon(Icons.download,
                        color: tab.mediaUrl != null ? Colors.green : null),
                    onPressed: tab.mediaUrl == null
                        ? () => _msg('Bu sayfada indirilebilir medya bulunamadı')
                        : () => _download(tab.mediaUrl!),
                  ),
                  IconButton(
                      icon: Badge(
                          label: Text('${tabs.length}'),
                          child: const Icon(Icons.tab)),
                      onPressed: _showTabs),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'new') _newTab();
                      if (v == 'incognito') _newTab(incognito: true);
                      if (v == 'adblock') {
                        setState(() => adBlock = !adBlock);
                        _msg(adBlock
                            ? 'Reklam engelleyici açık (yeni sekmede geçerli)'
                            : 'Reklam engelleyici kapalı (yeni sekmede geçerli)');
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'new', child: Text('Yeni sekme')),
                      const PopupMenuItem(value: 'incognito', child: Text('Gizli sekme')),
                      CheckedPopupMenuItem(
                          value: 'adblock',
                          checked: adBlock,
                          child: const Text('Reklam engelleyici')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
