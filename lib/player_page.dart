import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PlayerPage extends StatefulWidget {
  final String source; // dosya yolu veya internet adresi
  final String title;
  final String? referer;
  const PlayerPage({super.key, required this.source, required this.title, this.referer});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? vc;
  ChewieController? cc;
  String? error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final isUrl = widget.source.startsWith('http');
      final c = isUrl
          ? VideoPlayerController.networkUrl(
              Uri.parse(widget.source),
              httpHeaders: {
                if (widget.referer != null && widget.referer!.isNotEmpty)
                  'Referer': widget.referer!,
              },
            )
          : VideoPlayerController.file(File(widget.source));
      await c.initialize();
      vc = c;
      cc = ChewieController(
        videoPlayerController: c,
        autoPlay: true,
        allowedScreenSleep: false,
        playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = 'Oynatılamadı: $e');
    }
  }

  @override
  void dispose() {
    cc?.dispose();
    vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error!, style: const TextStyle(color: Colors.white)),
                ),
              )
            : cc == null
                ? const Center(child: CircularProgressIndicator())
                : Chewie(controller: cc!),
      );
}
