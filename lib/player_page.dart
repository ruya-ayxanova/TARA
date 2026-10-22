import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerPage extends StatefulWidget {
  final String source; // dosya yolu veya internet adresi
  final String title;
  final String? referer;
  const PlayerPage({super.key, required this.source, required this.title, this.referer});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    final isUrl = widget.source.startsWith('http');
    player.open(Media(widget.source,
        httpHeaders: isUrl && widget.referer != null && widget.referer!.isNotEmpty
            ? {'Referer': widget.referer!}
            : null));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<double>(
              icon: const Icon(Icons.speed),
              onSelected: (v) => player.setRate(v),
              itemBuilder: (_) => [
                for (final v in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  PopupMenuItem(value: v, child: Text('${v}x')),
              ],
            ),
          ],
        ),
        body: Video(controller: controller),
      );
}
