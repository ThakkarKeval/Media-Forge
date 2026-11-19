import 'dart:async';
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
  final List<ProcessedMedia> _processedItems = [];

  // Video Inspection state
  final Map<String, VideoMetadata> _inspectedVideos = {};
  final Map<String, String> _videoThumbnails = {};

  // Batch Job state
  BatchJob? _activeBatchJob;
  StreamSubscription<ProcessingEvent>? _batchSubscription;
  double? _batchProgressFraction;
  String? _batchStageDescription;
  int _batchCompletedCount = 0;
  int _batchTotalCount = 0;

  String? _statusMessage;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPlatformVersion();
  }

  @override
  void dispose() {
    _batchSubscription?.cancel();
    super.dispose();
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

  Future<void> _pickAndOptimizeImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Picking and optimizing photo (≤ 300 KB)...';
    });

    try {
      final processed = await MediaForge.pickAndProcessImage(
        source: MediaSource.gallery,
        processingOptions: const ImageProcessingOptions(
          maxWidth: 1280,
          maxHeight: 1280,
          quality: 75,
          targetSizeBytes: 300 * 1024, // 300 KB
          stripGpsMetadata: true,
        ),
      );
      if (!mounted) return;
      setState(() {
        if (processed != null) {
          _processedItems.insert(0, processed);
          final savings = processed.savingsPercentage != null
              ? ' (${processed.savingsPercentage!.toStringAsFixed(1)}% saved)'
              : '';
          _statusMessage =
              'Optimization completed: ${_formatBytes(processed.originalSizeBytes)} → ${_formatBytes(processed.sizeBytes)}$savings';
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

  Future<void> _optimizePickedImage(PickedMedia media) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Optimizing ${media.name ?? media.path}...';
    });

    try {
      final processed = await MediaProcessor.processImage(
        media.path,
        options: const ImageProcessingOptions(
          maxWidth: 1280,
          maxHeight: 1280,
          quality: 80,
          targetSizeBytes: 400 * 1024, // 400 KB
          stripGpsMetadata: true,
        ),
      );
      if (!mounted) return;
      setState(() {
        _processedItems.insert(0, processed);
        final savings = processed.savingsPercentage != null
            ? ' (${processed.savingsPercentage!.toStringAsFixed(1)}% saved)'
            : '';
        _statusMessage =
            'Optimized: ${_formatBytes(processed.originalSizeBytes)} → ${_formatBytes(processed.sizeBytes)}$savings';
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

  // --- Milestone 3: Video Inspection & Thumbnail ---

  Future<void> _inspectAndThumbnailVideo(PickedMedia media) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Inspecting video and extracting thumbnail...';
    });

    try {
      final metadata = await MediaForge.inspectVideo(media.path);
      final thumbPath = await MediaForge.createVideoThumbnail(
        videoPath: media.path,
        atTime: const Duration(seconds: 1),
        maxWidth: 400,
        maxHeight: 400,
      );

      if (!mounted) return;
      setState(() {
        _inspectedVideos[media.path] = metadata;
        _videoThumbnails[media.path] = thumbPath;
        _statusMessage =
            'Video inspected: ${metadata.width}×${metadata.height}, ${metadata.duration?.inSeconds}s (thumb extracted)';
      });
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Video inspection error (${e.code.name}): ${e.message}';
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Milestone 3: Bounded-Concurrency Batch Engine ---

  void _startBatchOptimization() {
    final imagePaths = _pickedItems.where((m) => m.isImage).map((m) => m.path).toList();
    if (imagePaths.isEmpty) {
      setState(() {
        _errorMessage = 'No picked photos available for batch processing. Pick photos first.';
      });
      return;
    }

    _batchSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _batchProgressFraction = 0.0;
      _batchCompletedCount = 0;
      _batchTotalCount = imagePaths.length;
      _batchStageDescription = 'Starting batch pool (concurrency: 2)...';
      _statusMessage = 'Batch processing ${imagePaths.length} photos...';
    });

    final job = MediaForge.processImages(
      imagePaths,
      options: const ImageProcessingOptions(
        maxWidth: 1024,
        maxHeight: 1024,
        quality: 75,
        targetSizeBytes: 250 * 1024,
        stripGpsMetadata: true,
      ),
      concurrency: 2,
    );

    _activeBatchJob = job;

    _batchSubscription = job.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _batchCompletedCount = event.completedCount;
        _batchTotalCount = event.totalCount;
        _batchProgressFraction = event.progressFraction;
        _batchStageDescription =
            'Item ${event.itemIndex + 1}/${event.totalCount} [${event.stage.name}]';

        if (event.stage == ProcessingStage.completed && event.result != null) {
          _processedItems.insert(0, event.result!);
        }
      });
    });

    job.result.then((batchResult) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _activeBatchJob = null;
        final status = batchResult.isCancelled ? 'cancelled' : 'finished';
        _statusMessage =
            'Batch $status: ${batchResult.successCount} succeeded, ${batchResult.failureCount} failed of ${batchResult.totalCount} items';
        _batchStageDescription = null;
      });
    }).catchError((err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _activeBatchJob = null;
        _errorMessage = 'Batch error: $err';
      });
    });
  }

  void _cancelActiveBatch() {
    _activeBatchJob?.cancel();
    setState(() {
      _statusMessage = 'Cancellation requested for batch processing...';
    });
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

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await MediaProcessor.clearCache();
      if (!mounted) return;
      setState(() {
        _statusMessage = success
            ? 'Managed cache cleared successfully'
            : 'Cache cleanup finished';
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
      _processedItems.clear();
      _inspectedVideos.clear();
      _videoThumbnails.clear();
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
    final hasImagesToBatch = _pickedItems.any((m) => m.isImage);

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
          if (_pickedItems.isNotEmpty || _processedItems.isNotEmpty)
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
          if (_isLoading && _activeBatchJob == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),

          // Active Batch Progress Bar
          if (_activeBatchJob != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Batch In Progress (Concurrency: 2)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Cancel Batch'),
                          onPressed: _cancelActiveBatch,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _batchProgressFraction,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_batchCompletedCount / $_batchTotalCount items (${((_batchProgressFraction ?? 0) * 100).toStringAsFixed(0)}%)'
                      '${_batchStageDescription != null ? ' • $_batchStageDescription' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
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

          // --- Section 1: Picker Actions ---
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo Picking & Capture (M1)',
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

          // --- Section 2: Video & Mixed Media ---
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video & Mixed Media (M1 + M3 Inspection)',
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

          // --- Section 3: Batch Engine & Processing (M2 + M3) ---
          Card(
            elevation: 1,
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dynamic_feed,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Batch Engine & Optimization (M3)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bounded Concurrency (pool: 2), Event Stream, Cancellation Support',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Pick & Optimize (≤ 300 KB)'),
                        onPressed: _isLoading ? null : _pickAndOptimizeImage,
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.playlist_play),
                        label: const Text('Batch Optimize Picked Photos'),
                        onPressed: (_isLoading || !hasImagesToBatch)
                            ? null
                            : _startBatchOptimization,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Clear Cache'),
                        onPressed: _isLoading ? null : _clearCache,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Section 4: Validation & Recovery Tests ---
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

          // --- Optimized Media Results ---
          if (_processedItems.isNotEmpty) ...[
            Text(
              'Optimized Media (${_processedItems.length})',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            ..._processedItems.map(
              (item) => _buildProcessedCard(context, item),
            ),
            const SizedBox(height: 16),
          ],

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

          if (_pickedItems.isEmpty && _processedItems.isEmpty)
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

  Widget _buildProcessedCard(BuildContext context, ProcessedMedia media) {
    final file = File(media.path);
    final fileExists = file.existsSync();

    final savings = media.savingsPercentage;
    final isTargetMet = media.targetMet;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 76,
                height: 76,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: fileExists
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image),
                      )
                    : const Icon(Icons.image_outlined, size: 36),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          media.path.split('/').last,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (savings != null && savings > 0)
                        _buildBadge(
                          context,
                          '-${savings.toStringAsFixed(1)}%',
                          color: Colors.green,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatBytes(media.originalSizeBytes)} → ${_formatBytes(media.sizeBytes)}',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (media.width != null && media.height != null)
                        _buildBadge(context, '${media.width}×${media.height}'),
                      if (isTargetMet != null)
                        _buildBadge(
                          context,
                          isTargetMet ? 'TARGET MET' : 'TARGET UNMET',
                          color: isTargetMet ? Colors.green : Colors.orange,
                        ),
                      if (media.mimeType != null)
                        _buildBadge(context, media.mimeType!),
                      _buildBadge(
                        context,
                        media.changed ? 'OPTIMIZED' : 'PASSTHROUGH',
                      ),
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

  Widget _buildMediaCard(BuildContext context, PickedMedia media) {
    final file = File(media.path);
    final fileExists = file.existsSync();
    final inspected = _inspectedVideos[media.path];
    final thumbPath = _videoThumbnails[media.path];
    final thumbFile = thumbPath != null ? File(thumbPath) : null;

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
                width: 76,
                height: 76,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: media.isImage && fileExists
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image),
                      )
                    : (thumbFile != null && thumbFile.existsSync())
                        ? Image.file(
                            thumbFile,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.movie_outlined),
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
                      _buildBadge(context, _formatBytes(inspected?.sizeBytes ?? media.sizeBytes)),
                      if ((inspected?.width ?? media.width) != null &&
                          (inspected?.height ?? media.height) != null)
                        _buildBadge(
                          context,
                          '${inspected?.width ?? media.width}×${inspected?.height ?? media.height}',
                        ),
                      if ((inspected?.duration ?? media.duration) != null)
                        _buildBadge(
                          context,
                          '${(inspected?.duration ?? media.duration)!.inSeconds}s',
                          color: Colors.teal,
                        ),
                      if (inspected?.rotationDegrees != null && inspected!.rotationDegrees > 0)
                        _buildBadge(
                          context,
                          '${inspected.rotationDegrees}° ROT',
                          color: Colors.purple,
                        ),
                      if ((inspected?.mimeType ?? media.mimeType) != null)
                        _buildBadge(context, (inspected?.mimeType ?? media.mimeType)!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (media.isVideo)
                          TextButton.icon(
                            icon: const Icon(Icons.analytics_outlined, size: 16),
                            label: const Text('Inspect & Thumbnail'),
                            onPressed: _isLoading
                                ? null
                                : () => _inspectAndThumbnailVideo(media),
                          ),
                        if (media.isImage)
                          TextButton.icon(
                            icon: const Icon(Icons.tune, size: 16),
                            label: const Text('Optimize (≤ 400 KB)'),
                            onPressed: _isLoading
                                ? null
                                : () => _optimizePickedImage(media),
                          ),
                      ],
                    ),
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
