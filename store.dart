import 'dart:io';
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

  static Future<String> download(String url,
      {void Function(double)? onProgress}) async {
    final d = await dir();
    final segs = Uri.parse(url).pathSegments;
    final name = segs.isNotEmpty && segs.last.isNotEmpty
        ? Uri.decodeComponent(segs.last)
        : 'indirilen_${DateTime.now().millisecondsSinceEpoch}';
    final path = '${d.path}/$name';
    await Dio().download(url, path, onReceiveProgress: (r, t) {
      if (t > 0) onProgress?.call(r / t);
    });
    return path;
  }
}
