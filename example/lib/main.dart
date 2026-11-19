import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:media_forge/media_forge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Forge Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MediaForgeHomePage(),
    );
  }
}

class MediaForgeHomePage extends StatefulWidget {
  const MediaForgeHomePage({super.key});

  @override
  State<MediaForgeHomePage> createState() => _MediaForgeHomePageState();
}

class _MediaForgeHomePageState extends State<MediaForgeHomePage> {
  String _platformVersion = 'Unknown';
  final _mediaForgePlugin = const MediaForge();
  final List<PickedMedia> _pickedItems = [];
  String? _statusMessage;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPlatformVersion();
  }

  Future<void> _loadPlatformVersion() async {
    final version = await _mediaForgePlugin.getPlatformVersion() ?? 'Unknown';
    if (!mounted) return;
    setState(() {
      _platformVersion = version;
    });
  }

  Future<void> _pickSingleImage(MediaSource source) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Launching ${source.name} picker...';
    });

    try {
      final media = await MediaPicker.pickImage(source: source);
      if (!mounted) return;
      setState(() {
        if (media != null) {
          _pickedItems.insert(0, media);
          _statusMessage = 'Selected photo: ${media.name ?? media.path}';
        } else {
          _statusMessage = 'Photo selection cancelled';
        }
      });
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${e.code.name}: ${e.message}';
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickSingleVideo(MediaSource source) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Launching ${source.name} video picker...';
    });

    try {
      final media = await MediaPicker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (!mounted) return;
      setState(() {
        if (media != null) {
          _pickedItems.insert(0, media);
          _statusMessage = 'Selected video: ${media.name ?? media.path}';
        } else {
          _statusMessage = 'Video selection cancelled';
        }
      });
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${e.code.name}: ${e.message}';
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMultiple(MediaType type) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Picking multiple ${type.name} items...';
    });

    try {
      final items = await MediaPicker.pickMultiple(type: type, maxItems: 5);
      if (!mounted) return;
      setState(() {
        if (items.isNotEmpty) {
          _pickedItems.insertAll(0, items);
          _statusMessage = 'Selected ${items.length} ${type.name} items';
        } else {
          _statusMessage = 'Selection cancelled';
        }
      });
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${e.code.name}: ${e.message}';
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _testValidationConstraint() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Picking image with strict 500 KB limit...';
    });

    try {
      final media = await MediaPicker.pickImage(
        source: MediaSource.gallery,
        options: const MediaSelectionOptions(
          maxSizeBytes: 500 * 1024, // 500 KB
        ),
      );
      if (!mounted) return;
      setState(() {
        if (media != null) {
          _pickedItems.insert(0, media);
          _statusMessage = 'Image within 500 KB limit accepted!';
        } else {
          _statusMessage = 'Selection cancelled';
        }
      });
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Validation Error (${e.code.name}): ${e.message}';
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _retrieveLostData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await MediaPicker.retrieveLostData();
      if (!mounted) return;
      setState(() {
        if (response.items.isNotEmpty) {
          _pickedItems.insertAll(0, response.items);
          _statusMessage = 'Recovered ${response.items.length} lost items!';
        } else if (response.exception != null) {
          _errorMessage = 'Lost Data Error: ${response.exception!.message}';
        } else {
          _statusMessage = 'No pending lost data found';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearResults() {
    setState(() {
      _pickedItems.clear();
      _statusMessage = 'Results cleared';
      _errorMessage = null;
    });
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Forge Demo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Running on: $_platformVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        actions: [
          if (_pickedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Results',
              onPressed: _clearResults,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),

          if (_errorMessage != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_statusMessage != null && _errorMessage == null)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // --- Actions ---
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo Picking & Capture',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Pick Photo'),
                        onPressed: _isLoading
                            ? null
                            : () => _pickSingleImage(MediaSource.gallery),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capture Photo'),
                        onPressed: _isLoading
                            ? null
                            : () => _pickSingleImage(MediaSource.camera),
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Multi-Photo (Max 5)'),
                        onPressed: _isLoading
                            ? null
                            : () => _pickMultiple(MediaType.image),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video & Mixed Media',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.video_library),
                        label: const Text('Pick Video'),
                        onPressed: _isLoading
                            ? null
                            : () => _pickSingleVideo(MediaSource.gallery),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.videocam),
                        label: const Text('Capture Video'),
                        onPressed: _isLoading
                            ? null
                            : () => _pickSingleVideo(MediaSource.camera),
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.perm_media_outlined),
                        label: const Text('Mixed Media (Max 5)'),
                        onPressed: _isLoading
                            ? null
                            : () => _pickMultiple(MediaType.mixed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Validation & Recovery Tests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.rule),
                        label: const Text('Constraint Test (≤ 500 KB)'),
                        onPressed: _isLoading
                            ? null
                            : _testValidationConstraint,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.history),
                        label: const Text('Check Lost Data (Android)'),
                        onPressed: _isLoading ? null : _retrieveLostData,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Picked Media Results ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Media (${_pickedItems.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_pickedItems.isEmpty)
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No media selected yet. Choose an action above.'),
                ),
              ),
            )
          else
            ..._pickedItems.map((media) => _buildMediaCard(context, media)),
        ],
      ),
    );
  }

  Widget _buildMediaCard(BuildContext context, PickedMedia media) {
    final file = File(media.path);
    final fileExists = file.existsSync();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 72,
                height: 72,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: media.isImage && fileExists
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image),
                      )
                    : Icon(
                        media.isVideo
                            ? Icons.movie_outlined
                            : Icons.image_outlined,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.name ?? media.path.split('/').last,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    media.path,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildBadge(context, media.type.name.toUpperCase()),
                      _buildBadge(context, _formatBytes(media.sizeBytes)),
                      if (media.width != null && media.height != null)
                        _buildBadge(context, '${media.width}×${media.height}'),
                      if (media.duration != null)
                        _buildBadge(
                          context,
                          '${media.duration!.inSeconds}s',
                          color: Colors.teal,
                        ),
                      if (media.mimeType != null)
                        _buildBadge(context, media.mimeType!),
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

  Widget _buildBadge(BuildContext context, String text, {Color? color}) {
    final badgeColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withAlpha(70)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}
