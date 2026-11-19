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
      title: 'MediaForge Image Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ImageStudioHomePage(),
    );
  }
}

class ImageStudioHomePage extends StatefulWidget {
  const ImageStudioHomePage({super.key});

  @override
  State<ImageStudioHomePage> createState() => _ImageStudioHomePageState();
}

class _ImageStudioHomePageState extends State<ImageStudioHomePage> {
  String _platformVersion = 'Unknown';
  final _mediaForgePlugin = const MediaForge();

  // Picked & processed state
  final List<PickedMedia> _pickedImages = [];
  final Map<String, ProcessedMedia> _processedMap = {};
  final Set<String> _processingPaths = {};

  // Custom compression settings
  double _quality = 80;
  double _maxWidth = 1440;
  double _targetSizeKb = 300;
  bool _enableTargetBudget = true;
  bool _stripGps = true;
  ImageFormat _format = ImageFormat.jpeg;
  String _customPrefix = 'forge_opt';
  bool _useCustomFileName = false;
  final TextEditingController _fileNameController = TextEditingController(text: 'forge_opt');

  // Batch Job state
  BatchJob? _activeBatchJob;
  StreamSubscription<ProcessingEvent>? _batchSub;
  double? _batchFraction;
  int _batchDone = 0;
  int _batchTotal = 0;
  String? _batchStage;
  String? _batchCurrentItem;

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
    _batchSub?.cancel();
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformVersion() async {
    final version = await _mediaForgePlugin.getPlatformVersion() ?? 'Unknown';
    if (!mounted) return;
    setState(() {
      _platformVersion = version;
    });
  }

  ImageProcessingOptions get _currentOptions => ImageProcessingOptions(
        maxWidth: _maxWidth > 0 ? _maxWidth.toInt() : null,
        maxHeight: _maxWidth > 0 ? _maxWidth.toInt() : null,
        quality: _quality.toInt(),
        targetSizeBytes:
            _enableTargetBudget ? (_targetSizeKb * 1024).toInt() : null,
        stripGpsMetadata: _stripGps,
        format: _format,
        outputFileName: _useCustomFileName && _customPrefix.trim().isNotEmpty
            ? _customPrefix.trim()
            : 'media_forge_opt',
      );

  // --- Picker Actions ---

  Future<void> _pickImage(MediaSource source) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Opening ${source.name}...';
    });

    try {
      final photo = await MediaForge.pickImage(source: source);
      if (!mounted) return;
      setState(() {
        if (photo != null) {
          _pickedImages.insert(0, photo);
          _statusMessage = 'Selected: ${photo.name ?? photo.path.split('/').last}';
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

  Future<void> _pickMultipleImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Selecting multiple photos...';
    });

    try {
      final photos = await MediaForge.pickMultiple(
        type: MediaType.image,
        maxItems: 10,
      );
      if (!mounted) return;
      setState(() {
        if (photos.isNotEmpty) {
          _pickedImages.insertAll(0, photos);
          _statusMessage = 'Selected ${photos.length} photos';
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

  // --- Optimization Actions ---

  Future<void> _optimizeSingleImage(PickedMedia media) async {
    final path = media.path;
    setState(() {
      _processingPaths.add(path);
      _errorMessage = null;
      _statusMessage = 'Compressing ${media.name ?? path.split('/').last}...';
    });

    try {
      final baseCustomName = _useCustomFileName && _customPrefix.trim().isNotEmpty
          ? _customPrefix.trim()
          : null;
      final options = baseCustomName != null
          ? _currentOptions
          : _currentOptions;

      final stopwatch = Stopwatch()..start();
      final result = await MediaForge.processImage(path, options: options);
      stopwatch.stop();

      if (!mounted) return;
      setState(() {
        _processedMap[path] = result;
        _processingPaths.remove(path);
        final pct = result.savingsPercentage?.toStringAsFixed(1) ?? '0.0';
        _statusMessage =
            'Compressed in ${stopwatch.elapsedMilliseconds}ms! Saved $pct% (${_formatBytes(result.originalSizeBytes)} → ${_formatBytes(result.sizeBytes)})';
      });
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _processingPaths.remove(path);
        _errorMessage = 'Compression failed (${e.code.name}): ${e.message}';
        _statusMessage = null;
      });
    }
  }

  void _startBatchOptimization() {
    if (_pickedImages.isEmpty) {
      setState(() => _errorMessage = 'Please select photos first.');
      return;
    }

    _batchSub?.cancel();
    final paths = _pickedImages.map((m) => m.path).toList();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _batchFraction = 0.0;
      _batchDone = 0;
      _batchTotal = paths.length;
      _batchStage = 'Initializing bounded concurrency pool (pool: 2)...';
      _batchCurrentItem = null;
      _statusMessage = 'Batch processing ${paths.length} photos...';
    });

    final job = MediaForge.processImages(
      paths,
      options: _currentOptions,
      concurrency: 2,
    );

    _activeBatchJob = job;

    _batchSub = job.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _batchDone = event.completedCount;
        _batchTotal = event.totalCount;
        _batchFraction = event.progressFraction;
        _batchCurrentItem = event.itemPath.split('/').last;
        _batchStage = 'Item ${event.itemIndex + 1}/$event.totalCount [${event.stage.name}]';

        if (event.stage == ProcessingStage.completed && event.result != null) {
          _processedMap[event.itemPath] = event.result!;
        }
      });
    });

    job.result.then((batchResult) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _activeBatchJob = null;
        final state = batchResult.isCancelled ? 'cancelled' : 'completed';
        _statusMessage =
            'Batch $state: ${batchResult.successCount} succeeded, ${batchResult.failureCount} failed of ${batchResult.totalCount} items';
        _batchStage = null;
        _batchCurrentItem = null;
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

  void _cancelBatch() {
    _activeBatchJob?.cancel();
    setState(() {
      _statusMessage = 'Cancellation requested...';
    });
  }

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ok = await MediaForge.clearCache();
      if (!mounted) return;
      setState(() {
        _processedMap.clear();
        _statusMessage = ok ? 'Managed cache cleared' : 'Cleanup completed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearAll() {
    setState(() {
      _pickedImages.clear();
      _processedMap.clear();
      _processingPaths.clear();
      _statusMessage = 'Workspace cleared';
      _errorMessage = null;
    });
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediaForge Image Studio'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Text(
              'Running on: $_platformVersion • Local-Only Processing',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        actions: [
          if (_pickedImages.isNotEmpty || _processedMap.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All',
              onPressed: _clearAll,
            ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Clear Cache',
            onPressed: _clearCache,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Global error banner
          if (_errorMessage != null)
            Card(
              color: theme.colorScheme.errorContainer,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Global status banner
          if (_statusMessage != null && _errorMessage == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Active Batch Progress Bar
          if (_activeBatchJob != null)
            Card(
              color: theme.colorScheme.primaryContainer,
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Batch Processing (Pool: 2)',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel'),
                          onPressed: _cancelBatch,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _batchFraction,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_batchDone of $_batchTotal items completed (${((_batchFraction ?? 0) * 100).toStringAsFixed(0)}%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_batchCurrentItem != null)
                          Text(
                            _batchCurrentItem!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                      ],
                    ),
                    if (_batchStage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _batchStage!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withAlpha(200),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // --- Configuration Card ---
          _buildConfigurationCard(context),
          const SizedBox(height: 16),

          // --- Selection Buttons ---
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Choose Source Photos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Single Photo'),
                        onPressed: _isLoading ? null : () => _pickImage(MediaSource.gallery),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capture Photo'),
                        onPressed: _isLoading ? null : () => _pickImage(MediaSource.camera),
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.perm_media),
                        label: const Text('Multi-Photo (Max 10)'),
                        onPressed: _isLoading ? null : _pickMultipleImages,
                      ),
                      if (_pickedImages.isNotEmpty)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.tertiary,
                            foregroundColor: theme.colorScheme.onTertiary,
                          ),
                          icon: const Icon(Icons.auto_awesome),
                          label: Text('Batch Optimize All (${_pickedImages.length})'),
                          onPressed: _isLoading ? null : _startBatchOptimization,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Gallery & Comparison List ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Photos (${_pickedImages.length})',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_processedMap.isNotEmpty)
                Text(
                  '${_processedMap.length} optimized',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_pickedImages.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No photos selected yet.\nPick or capture photos above to test compression.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._pickedImages.map((media) => _buildImageDetailCard(context, media)),
        ],
      ),
    );
  }

  // --- Compression Settings Panel ---

  Widget _buildConfigurationCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.tune, color: theme.colorScheme.primary),
        title: Text(
          'Compression & Optimization Parameters',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Quality: ${_quality.toInt()}% • Max: ${_maxWidth.toInt()}px • Budget: ${_enableTargetBudget ? "${_targetSizeKb.toInt()} KB" : "Disabled"}',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quality Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quality: ${_quality.toInt()}%', style: theme.textTheme.bodyMedium),
                    Text(
                      _quality >= 85
                          ? 'High'
                          : _quality >= 60
                              ? 'Balanced'
                              : 'Aggressive',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _quality,
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '${_quality.toInt()}%',
                  onChanged: (val) => setState(() => _quality = val),
                ),

                // Max Dimension Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Max Dimension: ${_maxWidth.toInt()} px', style: theme.textTheme.bodyMedium),
                    Text(
                      _maxWidth >= 2048
                          ? 'Full HD+'
                          : _maxWidth >= 1280
                              ? 'Standard Web'
                              : 'Thumbnail',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _maxWidth,
                  min: 480,
                  max: 2560,
                  divisions: 13,
                  label: '${_maxWidth.toInt()}px',
                  onChanged: (val) => setState(() => _maxWidth = val),
                ),

                // Target Size Budget
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enforce Target Byte Budget (Iterative Search)'),
                  subtitle: Text(
                    _enableTargetBudget
                        ? 'Native binary-search targets ≤ ${_targetSizeKb.toInt()} KB'
                        : 'Single-pass quality compression only',
                  ),
                  value: _enableTargetBudget,
                  onChanged: (val) => setState(() => _enableTargetBudget = val),
                ),

                if (_enableTargetBudget)
                  Slider(
                    value: _targetSizeKb,
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: '${_targetSizeKb.toInt()} KB',
                    onChanged: (val) => setState(() => _targetSizeKb = val),
                  ),

                // Format & Strip GPS
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ImageFormat>(
                        initialValue: _format,
                        decoration: const InputDecoration(
                          labelText: 'Output Format',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: ImageFormat.jpeg, child: Text('JPEG')),
                          DropdownMenuItem(value: ImageFormat.png, child: Text('PNG')),
                          DropdownMenuItem(value: ImageFormat.webp, child: Text('WebP')),
                        ],
                        onChanged: (fmt) {
                          if (fmt != null) setState(() => _format = fmt);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Strip GPS EXIF', style: TextStyle(fontSize: 13)),
                        value: _stripGps,
                        onChanged: (v) => setState(() => _stripGps = v ?? true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Custom Filename Option
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Custom Output Filename'),
                  subtitle: const Text('Specify exact base name (extension auto-resolved)'),
                  value: _useCustomFileName,
                  onChanged: (val) => setState(() => _useCustomFileName = val),
                ),

                if (_useCustomFileName)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: TextField(
                      controller: _fileNameController,
                      decoration: InputDecoration(
                        labelText: 'File Name',
                        hintText: 'e.g. avatar_small, profile_photo',
                        helperText: 'Saved as: ${_fileNameController.text.trim().isEmpty ? "forge_opt" : _fileNameController.text.trim()}.${_format.name == "jpeg" ? "jpg" : _format.name}',
                        prefixIcon: const Icon(Icons.drive_file_rename_outline),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _customPrefix = val;
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Detailed Image Comparison Card ---

  Widget _buildImageDetailCard(BuildContext context, PickedMedia media) {
    final theme = Theme.of(context);
    final isProcessing = _processingPaths.contains(media.path);
    final processed = _processedMap[media.path];

    final originalFile = File(media.path);
    final originalExists = originalFile.existsSync();
    final processedFile = processed != null ? File(processed.path) : null;
    final processedExists = processedFile?.existsSync() ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with filename and action button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.name ?? media.path.split('/').last,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        media.path,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FilledButton.tonalIcon(
                    icon: Icon(processed != null ? Icons.refresh : Icons.compress),
                    label: Text(processed != null ? 'Re-optimize' : 'Optimize'),
                    onPressed: _isLoading ? null : () => _optimizeSingleImage(media),
                  ),
              ],
            ),
            const Divider(height: 24),

            // Side-by-side or stacked visual comparison
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel(context, 'ORIGINAL', Colors.blueGrey),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: originalExists
                              ? Image.file(
                                  originalFile,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Center(child: Icon(Icons.broken_image)),
                                )
                              : const Center(child: Icon(Icons.image_not_supported)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow('Size', _formatBytes(media.sizeBytes)),
                      if (media.width != null && media.height != null)
                        _buildMetricRow('Resolution', '${media.width} × ${media.height}'),
                      if (media.mimeType != null)
                        _buildMetricRow('MIME', media.mimeType!),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Processed side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel(
                        context,
                        processed != null ? 'OPTIMIZED' : 'NOT PROCESSED',
                        processed != null ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: processedExists
                              ? Image.file(
                                  processedFile!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Center(child: Icon(Icons.broken_image)),
                                )
                              : Center(
                                  child: isProcessing
                                      ? const CircularProgressIndicator()
                                      : const Icon(Icons.hourglass_empty, color: Colors.grey),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (processed != null) ...[
                        _buildMetricRow(
                          'Size',
                          _formatBytes(processed.sizeBytes),
                          highlightColor: Colors.green,
                        ),
                        if (processed.width != null && processed.height != null)
                          _buildMetricRow('Resolution', '${processed.width} × ${processed.height}'),
                        if (processed.savingsPercentage != null)
                          _buildMetricRow(
                            'Saved',
                            '${processed.savingsPercentage!.toStringAsFixed(1)}% (-${_formatBytes(processed.savingsBytes)})',
                            highlightColor: Colors.green,
                          ),
                        _buildMetricRow(
                          'File',
                          processed.path.split('/').last,
                        ),
                      ] else ...[
                        _buildMetricRow('Size', '—'),
                        _buildMetricRow('Resolution', '—'),
                        _buildMetricRow('Status', isProcessing ? 'Processing...' : 'Pending'),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Performance badges and budget outcome
            if (processed != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildBadge(
                    context,
                    processed.changed ? 'ENCODED' : 'PASSTHROUGH',
                    color: processed.changed ? Colors.indigo : Colors.grey,
                  ),
                  if (processed.targetMet != null)
                    _buildBadge(
                      context,
                      processed.targetMet! ? 'TARGET BUDGET MET' : 'BUDGET UNMET',
                      color: processed.targetMet! ? Colors.green : Colors.orange,
                    ),
                  if (processed.mimeType != null)
                    _buildBadge(context, processed.mimeType!),
                  if (_stripGps)
                    _buildBadge(context, 'GPS STRIPPED', color: Colors.teal),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, {Color? color}) {
    final badgeColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withAlpha(70)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}
