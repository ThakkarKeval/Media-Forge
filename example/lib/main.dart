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
      title: 'MediaForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E293B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF94A3B8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          color: const Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

/// Persistent user configuration for image optimization.
class CompressionConfig {
  CompressionConfig({
    this.quality = 80,
    this.maxWidth = 1440,
    this.targetSizeKb = 300,
    this.enableTargetBudget = true,
    this.stripGps = true,
    this.format = ImageFormat.jpeg,
    this.outputFileName = 'forge_opt',
    this.useCustomFileName = false,
  });

  double quality;
  double maxWidth;
  double targetSizeKb;
  bool enableTargetBudget;
  bool stripGps;
  ImageFormat format;
  String outputFileName;
  bool useCustomFileName;

  ImageProcessingOptions toOptions() {
    return ImageProcessingOptions(
      maxWidth: maxWidth > 0 ? maxWidth.toInt() : null,
      maxHeight: maxWidth > 0 ? maxWidth.toInt() : null,
      quality: quality.toInt(),
      targetSizeBytes: enableTargetBudget ? (targetSizeKb * 1024).toInt() : null,
      stripGpsMetadata: stripGps,
      format: format,
      outputFileName: useCustomFileName && outputFileName.trim().isNotEmpty
          ? outputFileName.trim()
          : 'media_forge_opt',
    );
  }

  String get summaryLabel {
    final budgetStr = enableTargetBudget ? '≤ ${targetSizeKb.toInt()}KB' : 'No budget';
    final nameStr = useCustomFileName && outputFileName.trim().isNotEmpty
        ? ' • "${outputFileName.trim()}"'
        : '';
    return '${format.name.toUpperCase()} • ${quality.toInt()}% • ${maxWidth.toInt()}px • $budgetStr$nameStr';
  }
}

/// Minimal, uncluttered Home Screen focusing on picking and viewing results.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CompressionConfig _config = CompressionConfig();

  final List<PickedMedia> _pickedImages = [];
  final Map<String, ProcessedMedia> _processedMap = {};
  final Set<String> _processingPaths = {};

  BatchJob? _activeBatchJob;
  StreamSubscription<ProcessingEvent>? _batchSub;
  double? _batchFraction;
  int _batchDone = 0;
  int _batchTotal = 0;

  bool _isLoading = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _batchSub?.cancel();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(config: _config),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickImage(MediaSource source) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final photo = await MediaForge.pickImage(source: source);
      if (!mounted) return;
      if (photo != null) {
        setState(() {
          _pickedImages.insert(0, photo);
          _statusMessage = 'Added photo';
        });
      }
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMultipleImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final photos = await MediaForge.pickMultiple(
        type: MediaType.image,
        maxItems: 12,
      );
      if (!mounted) return;
      if (photos.isNotEmpty) {
        setState(() {
          _pickedImages.insertAll(0, photos);
          _statusMessage = 'Added ${photos.length} photos';
        });
      }
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _optimizeSingle(PickedMedia media) async {
    final path = media.path;
    setState(() {
      _processingPaths.add(path);
      _errorMessage = null;
    });

    try {
      final result = await MediaForge.processImage(path, options: _config.toOptions());
      if (!mounted) return;
      setState(() {
        _processedMap[path] = result;
        _processingPaths.remove(path);
      });
    } on MediaForgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _processingPaths.remove(path);
        _errorMessage = e.message;
      });
    }
  }

  void _startBatch() {
    if (_pickedImages.isEmpty) return;

    _batchSub?.cancel();
    final paths = _pickedImages.map((m) => m.path).toList();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _batchFraction = 0.0;
      _batchDone = 0;
      _batchTotal = paths.length;
    });

    final job = MediaForge.processImages(
      paths,
      options: _config.toOptions(),
      concurrency: 2,
    );
    _activeBatchJob = job;

    _batchSub = job.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _batchDone = event.completedCount;
        _batchTotal = event.totalCount;
        _batchFraction = event.progressFraction;
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
        _statusMessage = 'Optimized ${batchResult.successCount} of ${batchResult.totalCount} items';
      });
    }).catchError((err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _activeBatchJob = null;
        _errorMessage = err.toString();
      });
    });
  }

  void _cancelBatch() {
    _activeBatchJob?.cancel();
  }

  void _clearAll() {
    setState(() {
      _pickedImages.clear();
      _processedMap.clear();
      _processingPaths.clear();
      _errorMessage = null;
      _statusMessage = null;
    });
  }

  Future<void> _clearCache() async {
    await MediaForge.clearCache();
    if (!mounted) return;
    setState(() {
      _processedMap.clear();
      _statusMessage = 'Cache cleared';
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
        title: const Text(
          'MediaForge',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Configuration',
            onPressed: _openSettings,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'clear_all') _clearAll();
              if (val == 'clear_cache') _clearCache();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 10),
                    Text('Clear List'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Clear Disk Cache'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-header Preset Indicator
          InkWell(
            onTap: _openSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _config.summaryLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),

          // Batch Progress Banner (when running)
          if (_activeBatchJob != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.primaryContainer,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Optimizing $_batchDone of $_batchTotal...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelBatch,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _batchFraction,
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),

          // Global Alerts
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _errorMessage = null),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),

          if (_statusMessage != null && _errorMessage == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _statusMessage = null),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),

          // Main Media List or Empty State
          Expanded(
            child: _pickedImages.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pickedImages.length,
                    itemBuilder: (context, index) {
                      final media = _pickedImages[index];
                      return _buildMediaCard(context, media);
                    },
                  ),
          ),

          // Minimal Bottom Dock with Quick Actions
          _buildBottomDock(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_outlined,
                size: 40,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Photos Added',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick single or multiple photos to see side-by-side compression results.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withAlpha(40),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Add Single'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : () => _pickImage(MediaSource.gallery),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : () => _pickImage(MediaSource.camera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.collections_outlined, size: 18),
                label: const Text('Multiple'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _pickMultipleImages,
              ),
            ),
            if (_pickedImages.isNotEmpty) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Batch'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _startBatch,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(BuildContext context, PickedMedia media) {
    final theme = Theme.of(context);
    final isProcessing = _processingPaths.contains(media.path);
    final processed = _processedMap[media.path];

    final originalFile = File(media.path);
    final processedFile = processed != null ? File(processed.path) : null;

    final fileName = media.name ?? media.path.split('/').last;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Title & Action
            Row(
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isProcessing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      processed != null ? Icons.refresh : Icons.compress,
                      size: 16,
                    ),
                    label: Text(
                      processed != null ? 'Re-run' : 'Optimize',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: _isLoading ? null : () => _optimizeSingle(media),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Clean 2-column comparison preview
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original thumbnail & stat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: originalFile.existsSync()
                              ? Image.file(originalFile, fit: BoxFit.cover)
                              : const Icon(Icons.broken_image, size: 24),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Original',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        _formatBytes(media.sizeBytes),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (media.width != null && media.height != null)
                        Text(
                          '${media.width}×${media.height}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Optimized thumbnail & stat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: processed != null && processedFile != null && processedFile.existsSync()
                              ? Image.file(processedFile, fit: BoxFit.cover)
                              : Center(
                                  child: isProcessing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(
                                          'Pending',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        processed != null ? 'Optimized' : 'Target Result',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: processed != null ? Colors.green.shade700 : theme.colorScheme.outline,
                        ),
                      ),
                      if (processed != null) ...[
                        Row(
                          children: [
                            Text(
                              _formatBytes(processed.sizeBytes),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                            if (processed.savingsPercentage != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '-${processed.savingsPercentage!.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${processed.width}×${processed.height} • ${processed.path.split('/').last}',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        Text(
                          '—',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated Configuration Screen for all image parameters and filename settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.config});

  final CompressionConfig config;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config.outputFileName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compression Settings', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section: Quality
          _buildSectionHeader('Quality Factor'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quality: ${cfg.quality.toInt()}%', style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                cfg.quality >= 80 ? 'High Fidelity' : cfg.quality >= 50 ? 'Balanced' : 'Small Size',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
              ),
            ],
          ),
          Slider(
            value: cfg.quality,
            min: 10,
            max: 100,
            divisions: 18,
            label: '${cfg.quality.toInt()}%',
            onChanged: (val) => setState(() => cfg.quality = val),
          ),
          const SizedBox(height: 16),

          // Section: Dimensions
          _buildSectionHeader('Resolution Limit'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Max Bound: ${cfg.maxWidth.toInt()} px', style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                cfg.maxWidth >= 1920 ? 'Full HD' : cfg.maxWidth >= 1080 ? 'Standard' : 'Compact',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
              ),
            ],
          ),
          Slider(
            value: cfg.maxWidth,
            min: 480,
            max: 2560,
            divisions: 13,
            label: '${cfg.maxWidth.toInt()}px',
            onChanged: (val) => setState(() => cfg.maxWidth = val),
          ),
          const SizedBox(height: 16),

          // Section: Byte Budget
          _buildSectionHeader('Target File Size'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enforce Target Byte Budget', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              cfg.enableTargetBudget
                  ? 'Iterative native binary-search targets ≤ ${cfg.targetSizeKb.toInt()} KB'
                  : 'Single-pass quality compression only',
              style: const TextStyle(fontSize: 12),
            ),
            value: cfg.enableTargetBudget,
            onChanged: (val) => setState(() => cfg.enableTargetBudget = val),
          ),
          if (cfg.enableTargetBudget)
            Slider(
              value: cfg.targetSizeKb,
              min: 50,
              max: 1000,
              divisions: 19,
              label: '${cfg.targetSizeKb.toInt()} KB',
              onChanged: (val) => setState(() => cfg.targetSizeKb = val),
            ),
          const SizedBox(height: 16),

          // Section: Format & Privacy
          _buildSectionHeader('Format & Metadata'),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ImageFormat>(
                  initialValue: cfg.format,
                  decoration: const InputDecoration(
                    labelText: 'Output Format',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: ImageFormat.jpeg, child: Text('JPEG (.jpg)')),
                    DropdownMenuItem(value: ImageFormat.png, child: Text('PNG (.png)')),
                    DropdownMenuItem(value: ImageFormat.webp, child: Text('WebP (.webp)')),
                    DropdownMenuItem(value: ImageFormat.heic, child: Text('HEIC (.heic)')),
                  ],
                  onChanged: (fmt) {
                    if (fmt != null) setState(() => cfg.format = fmt);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Strip GPS', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Remove EXIF location', style: TextStyle(fontSize: 11)),
                  value: cfg.stripGps,
                  onChanged: (v) => setState(() => cfg.stripGps = v ?? true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section: Filename Customization
          _buildSectionHeader('File Naming'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Custom Output Filename', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Specify output name without file path', style: TextStyle(fontSize: 12)),
            value: cfg.useCustomFileName,
            onChanged: (val) => setState(() => cfg.useCustomFileName = val),
          ),
          if (cfg.useCustomFileName)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Base Filename',
                  hintText: 'e.g. profile_photo, compressed_img',
                  helperText: 'Saved as: ${_nameController.text.trim().isEmpty ? "forge_opt" : _nameController.text.trim()}.${cfg.format.name == "jpeg" ? "jpg" : cfg.format.name}',
                  prefixIcon: const Icon(Icons.drive_file_rename_outline, size: 20),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) {
                  setState(() {
                    cfg.outputFileName = val;
                  });
                },
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Colors.grey,
        ),
      ),
    );
  }
}
