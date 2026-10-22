import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'store.dart';

enum Cat { video, music, doc, image, archive, apk, other }

const _catInfo = {
  Cat.video: ('Videolar', Icons.play_circle_fill, Colors.deepPurple),
  Cat.music: ('Müzik', Icons.music_note, Colors.pink),
  Cat.doc: ('Belgeler', Icons.description, Colors.amber),
  Cat.image: ('Resimler', Icons.image, Colors.blue),
  Cat.archive: ('Arşivler', Icons.folder_zip, Colors.teal),
  Cat.apk: ('Uygulamalar', Icons.android, Colors.green),
  Cat.other: ('Diğer', Icons.insert_drive_file, Colors.blueGrey),
};

Cat catOf(String path) {
  final e = path.split('.').last.toLowerCase();
  if (['mp4', 'mkv', 'webm', 'avi', 'mov', '3gp'].contains(e)) return Cat.video;
  if (['mp3', 'm4a', 'wav', 'ogg', 'aac', 'flac'].contains(e)) return Cat.music;
  if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].contains(e)) return Cat.doc;
  if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(e)) return Cat.image;
  if (['zip', 'rar', '7z', 'tar', 'gz'].contains(e)) return Cat.archive;
  if (e == 'apk') return Cat.apk;
  return Cat.other;
}

String _size(int b) {
  if (b > 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(1)} GB';
  if (b > 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
  return '${(b / 1024).toStringAsFixed(0)} KB';
}

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});
  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  List<File> files = [];
  Cat? filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Store.dir();
    final l = d.listSync().whereType<File>().toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    setState(() => files = l);
  }

  @override
  Widget build(BuildContext context) {
    final shown = filter == null ? files : files.where((f) => catOf(f.path) == filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Dosyalar')),
      body: Column(children: [
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: [
              for (final c in Cat.values)
                GestureDetector(
                  onTap: () => setState(() => filter = filter == c ? null : c),
                  child: Container(
                    width: 84,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _catInfo[c]!.$3.withOpacity(filter == c ? 0.28 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_catInfo[c]!.$2, color: _catInfo[c]!.$3),
                      Text(_catInfo[c]!.$1, style: const TextStyle(fontSize: 12)),
                      Text('${files.where((f) => catOf(f.path) == c).length}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('Dosya yok'))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final f = shown[i];
                    final c = catOf(f.path);
                    return ListTile(
                      leading: Icon(_catInfo[c]!.$2, color: _catInfo[c]!.$3),
                      title: Text(f.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_size(f.lengthSync())),
                      onTap: () => OpenFilex.open(f.path),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await f.delete();
                          _load();
                        },
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
