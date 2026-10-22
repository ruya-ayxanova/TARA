import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Bookmark {
  final String title, url;
  Bookmark(this.title, this.url);
}

class Store {
  static Future<List<Bookmark>> bookmarks() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList('bm') ?? []).map((s) {
      final i = s.indexOf('|||');
      return Bookmark(s.substring(0, i), s.substring(i + 3));
    }).toList();
  }

  static Future<void> saveBookmarks(List<Bookmark> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('bm', l.map((b) => '${b.title}|||${b.url}').toList());
  }

  static Future<Directory> dir() async {
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/Infinity');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// m3u8 (HLS) videoyu parçalarıyla indirip tek dosyada birleştirir.
  static Future<String> downloadHls(String url,
      {String? referer, CancelToken? cancel, void Function(double)? onProgress}) async {
    final headers = {if (referer != null && referer.isNotEmpty) 'Referer': referer};
    final textDio = Dio(BaseOptions(headers: headers, responseType: ResponseType.plain));
    var pl = Uri.parse(url);
    var text = (await textDio.getUri(pl, cancelToken: cancel)).data as String;
    if (text.contains('#EXT-X-STREAM-INF')) {
      final lines = text.split('\n').map((l) => l.trim()).toList();
      var best = -1;
      String? bestUri;
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].startsWith('#EXT-X-STREAM-INF')) continue;
        final bw = int.tryParse(RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i])?.group(1) ?? '') ?? 0;
        for (var j = i + 1; j < lines.length; j++) {
          if (lines[j].isNotEmpty && !lines[j].startsWith('#')) {
            if (bw >= best) {
              best = bw;
              bestUri = lines[j];
            }
            break;
          }
        }
      }
      if (bestUri == null) throw Exception('Oynatma listesi okunamadı');
      pl = pl.resolve(bestUri);
      text = (await textDio.getUri(pl, cancelToken: cancel)).data as String;
    }
    if (RegExp(r'#EXT-X-KEY:(?!METHOD=NONE)').hasMatch(text)) {
      throw Exception('Video şifreli, indirilemiyor');
    }
    final segs = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => pl.resolve(l).toString())
        .toList();
    if (segs.isEmpty) throw Exception('Video parçası bulunamadı');
    final mapUri = RegExp(r'#EXT-X-MAP:URI="([^"]+)"').firstMatch(text)?.group(1);
    final d = await dir();
    final ext = mapUri != null ? 'mp4' : 'ts';
    final out = File('${d.path}/video_${DateTime.now().millisecondsSinceEpoch}.$ext');
    final sink = out.openWrite();
    final bytesDio = Dio(BaseOptions(headers: headers, responseType: ResponseType.bytes));
    try {
      if (mapUri != null) {
        sink.add((await bytesDio.get<List<int>>(pl.resolve(mapUri).toString(), cancelToken: cancel)).data!);
      }
      for (var i = 0; i < segs.length; i += 8) {
        final batch = segs.skip(i).take(8).toList();
        final res = await Future.wait(batch.map((s) => bytesDio.get<List<int>>(s, cancelToken: cancel)));
        for (final r in res) {
          sink.add(r.data!);
        }
        onProgress?.call(min(1.0, (i + batch.length) / segs.length));
      }
    } finally {
      await sink.close();
    }
    return out.path;
  }

  static Future<String> download(String url,
      {String? referer, CancelToken? cancel, void Function(double)? onProgress}) async {
    final d = await dir();
    final segs = Uri.parse(url).pathSegments;
    final name = segs.isNotEmpty && segs.last.isNotEmpty
        ? Uri.decodeComponent(segs.last)
        : 'indirilen_${DateTime.now().millisecondsSinceEpoch}';
    var path = '${d.path}/$name';
    if (await File(path).exists()) {
      path = '${d.path}/${DateTime.now().millisecondsSinceEpoch}_$name';
    }
    final dio = Dio(BaseOptions(headers: {
      if (referer != null && referer.isNotEmpty) 'Referer': referer,
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
    }));
    await dio.download(url, path, cancelToken: cancel, onReceiveProgress: (r, t) {
      if (t > 0) onProgress?.call(r / t);
    });
    return path;
  }
}
