import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../downloader/services/ffmpeg_installer_service.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/app_shortcuts.dart';
import '../providers/settings_provider.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _downloadPathController;
  late TextEditingController _speedLimitController;
  late TextEditingController _timeoutController;
  late TextEditingController _maxRetriesController;
  late TextEditingController _retryDelayController;
  late TextEditingController _interTaskDelayController;
  late TextEditingController _proxyHostController;
  late TextEditingController _proxyPortController;
  late TextEditingController _proxyUserController;
  late TextEditingController _proxyPassController;
  late TextEditingController _dohController;

  late AppSettings _tempSettings;
  bool _isFfmpegInstalled = false;
  bool _isInstallingFfmpeg = false;
  double _ffmpegInstallProgress = 0.0;
  String _ffmpegInstallStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tempSettings = ref.read(settingsProvider);

    _downloadPathController = TextEditingController(text: _tempSettings.defaultDownloadPath);
    _speedLimitController = TextEditingController(text: _tempSettings.speedLimitKBps.toStringAsFixed(0));
    _timeoutController = TextEditingController(text: _tempSettings.connectionTimeoutSeconds.toString());
    _maxRetriesController = TextEditingController(text: _tempSettings.maxRetries.toString());
    _retryDelayController = TextEditingController(text: _tempSettings.retryDelaySeconds.toString());
    _interTaskDelayController = TextEditingController(text: _tempSettings.interTaskDelayMs.toString());
    _proxyHostController = TextEditingController(text: _tempSettings.proxyHost);
    _proxyPortController = TextEditingController(text: _tempSettings.proxyPort.toString());
    _proxyUserController = TextEditingController(text: _tempSettings.proxyUsername);
    _proxyPassController = TextEditingController(text: _tempSettings.proxyPassword);
    _dohController = TextEditingController(text: _tempSettings.customDohUrl);

    _checkFfmpegStatus();
  }

  Future<void> _checkFfmpegStatus() async {
    final installed = await FfmpegInstallerService.isFfmpegInstalled();
    if (mounted) {
      setState(() {
        _isFfmpegInstalled = installed;
      });
    }
  }

  Future<void> _downloadPortableFfmpeg() async {
    setState(() {
      _isInstallingFfmpeg = true;
      _ffmpegInstallProgress = 0.05;
      _ffmpegInstallStatus = 'Connecting to download server...';
    });

    final success = await FfmpegInstallerService.downloadAndInstallPortableFfmpeg(
      onProgress: (p, msg) {
        if (mounted) {
          setState(() {
            _ffmpegInstallProgress = p;
            _ffmpegInstallStatus = msg;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isInstallingFfmpeg = false;
        _isFfmpegInstalled = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Portable FFmpeg installed successfully!' : 'FFmpeg installation failed.'),
          backgroundColor: success ? AppTheme.accentGreen : AppTheme.accentRose,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _downloadPathController.dispose();
    _speedLimitController.dispose();
    _timeoutController.dispose();
    _maxRetriesController.dispose();
    _retryDelayController.dispose();
    _interTaskDelayController.dispose();
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    _proxyUserController.dispose();
    _proxyPassController.dispose();
    _dohController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        height: 620,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: AppTheme.primaryLight, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Preferences & Settings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryLight,
              labelColor: AppTheme.primaryLight,
              unselectedLabelColor: AppTheme.darkTextSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.download, size: 16), text: 'Download & Engine'),
                Tab(icon: Icon(Icons.transform, size: 16), text: 'Format & Sniffer'),
                Tab(icon: Icon(Icons.public, size: 16), text: 'Network & DNS'),
                Tab(icon: Icon(Icons.keyboard, size: 16), text: 'Shortcuts (คีย์ลัด)'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDownloadTab(),
                  _buildFormatTab(),
                  _buildNetworkTab(),
                  _buildShortcutsTab(),
                ],
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saveSettings,
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadTab() {
    return ListView(
      children: [
        // Startup Behavior
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.launch, color: AppTheme.accentCyan, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'On Startup (พฤติกรรมเมื่อเปิดโปรแกรม)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<AppStartupBehavior>(
                initialValue: _tempSettings.startupBehavior,
                dropdownColor: AppTheme.darkSurface,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(
                    value: AppStartupBehavior.restoreAll,
                    child: Text('Restore all open tabs (เปิดด้วยทุกแท็บที่เปิดค้างไว้ - แนะนำ)'),
                  ),
                  DropdownMenuItem(
                    value: AppStartupBehavior.newTab,
                    child: Text('Open new tab (เปิดด้วยแท็บใหม่หน้าเดียว)'),
                  ),
                  DropdownMenuItem(
                    value: AppStartupBehavior.lastTab,
                    child: Text('Open last active tab (เปิดด้วยแท็บล่าสุดอันเดียว)'),
                  ),
                  DropdownMenuItem(
                    value: AppStartupBehavior.newTabPlusRestore,
                    child: Text('New tab + Restore previous tabs (เปิดแท็บใหม่ + ทุกแท็บที่ค้างไว้)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _tempSettings = _tempSettings.copyWith(startupBehavior: val);
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Multi-Threaded Range Download Acceleration
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: AppTheme.accentCyan, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Multi-Threaded Download Acceleration (HTTP Range Chunks)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                    ),
                  ),
                  Switch(
                    value: _tempSettings.enableChunkedDownload,
                    activeThumbColor: AppTheme.accentCyan,
                    onChanged: (val) {
                      setState(() {
                        _tempSettings = _tempSettings.copyWith(enableChunkedDownload: val);
                      });
                    },
                  ),
                ],
              ),
              if (_tempSettings.enableChunkedDownload) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Threads per Download: ${_tempSettings.threadsPerDownload} connections',
                      style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                    ),
                    Text(
                      '${_tempSettings.threadsPerDownload} Threads',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                    ),
                  ],
                ),
                Slider(
                  value: _tempSettings.threadsPerDownload.toDouble(),
                  min: 1,
                  max: 16,
                  divisions: 15,
                  activeColor: AppTheme.accentCyan,
                  label: '${_tempSettings.threadsPerDownload} Threads',
                  onChanged: (val) {
                    setState(() {
                      _tempSettings = _tempSettings.copyWith(threadsPerDownload: val.toInt());
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Concurrency Slider
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Max Concurrent Queue Tasks', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
          subtitle: Text(
            'Current: ${_tempSettings.maxConcurrentDownloads} tasks simultaneously',
            style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
          ),
          trailing: SizedBox(
            width: 160,
            child: Slider(
              value: _tempSettings.maxConcurrentDownloads.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppTheme.primaryLight,
              label: '${_tempSettings.maxConcurrentDownloads}',
              onChanged: (val) {
                setState(() {
                  _tempSettings = _tempSettings.copyWith(maxConcurrentDownloads: val.toInt());
                });
              },
            ),
          ),
        ),
        const Divider(),
        // Portable FFmpeg Tool Manager
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.live_tv, size: 18, color: AppTheme.accentAmber),
                      const SizedBox(width: 8),
                      const Text(
                        'FFmpeg Stream Engine (HLS / m3u8)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_isFfmpegInstalled ? AppTheme.accentGreen : AppTheme.accentRose).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (_isFfmpegInstalled ? AppTheme.accentGreen : AppTheme.accentRose).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _isFfmpegInstalled ? 'READY' : 'NOT FOUND',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _isFfmpegInstalled ? AppTheme.accentGreen : AppTheme.accentRose,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'FFmpeg is required to capture and convert live video streams (.m3u8) into MP4.',
                style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
              ),
              const SizedBox(height: 8),
              if (_isInstallingFfmpeg) ...[
                LinearProgressIndicator(
                  value: _ffmpegInstallProgress > 0 ? _ffmpegInstallProgress : null,
                  backgroundColor: AppTheme.darkBackground,
                  color: AppTheme.accentCyan,
                ),
                const SizedBox(height: 4),
                Text(
                  _ffmpegInstallStatus,
                  style: const TextStyle(fontSize: 10, color: AppTheme.accentCyan),
                ),
              ] else ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFfmpegInstalled ? AppTheme.darkSurface : AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: Icon(_isFfmpegInstalled ? Icons.check_circle : Icons.cloud_download, size: 14),
                  label: Text(
                    _isFfmpegInstalled ? 'Update / Reinstall Portable FFmpeg' : 'Download Portable FFmpeg (~25MB)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: _downloadPortableFfmpeg,
                ),
              ],
            ],
          ),
        ),
        const Divider(),
        // Download Path
        const Text('Default Destination Directory', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _downloadPathController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Default: Downloads folder',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Browse', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final result = await FilePicker.getDirectoryPath();
                if (result != null) {
                  setState(() {
                    _downloadPathController.text = result;
                    _tempSettings = _tempSettings.copyWith(defaultDownloadPath: result);
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Auto Categorize Folders
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-categorize subfolders', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
          subtitle: const Text('Separates downloads into /Images, /Videos, /Streams, /Audio', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          value: _tempSettings.autoCategorizeFolders,
          activeThumbColor: AppTheme.accentGreen,
          onChanged: (val) {
            setState(() {
              _tempSettings = _tempSettings.copyWith(autoCategorizeFolders: val);
            });
          },
        ),
        const Divider(),
        // Detailed Tuning Controls: Speed Limit & Timeout
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Speed Limit (KB/s, 0=Unlimited)', style: TextStyle(fontSize: 11, color: AppTheme.darkTextPrimary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _speedLimitController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connection Timeout (seconds)', style: TextStyle(fontSize: 11, color: AppTheme.darkTextPrimary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _timeoutController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Retry Controls: Max Retries, Retry Delay, Inter-task Delay
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Max Retries', style: TextStyle(fontSize: 11, color: AppTheme.darkTextPrimary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _maxRetriesController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Retry Delay (seconds)', style: TextStyle(fontSize: 11, color: AppTheme.darkTextPrimary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _retryDelayController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inter-Task Delay (ms)', style: TextStyle(fontSize: 11, color: AppTheme.darkTextPrimary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _interTaskDelayController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatTab() {
    return ListView(
      children: [
        const Text('Image Conversion on Download', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary)),
        const SizedBox(height: 4),
        const Text('Automatically convert any downloaded image format (e.g. WebP, AVIF) to your preferred output format.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
        const SizedBox(height: 10),
        DropdownButtonFormField<ImageTargetFormat>(
          initialValue: _tempSettings.targetImageFormat,
          dropdownColor: AppTheme.darkSurface,
          decoration: const InputDecoration(
            labelText: 'Target Image Format',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: ImageTargetFormat.original, child: Text('Keep Original Format')),
            DropdownMenuItem(value: ImageTargetFormat.jpg, child: Text('Convert to JPG (.jpg)')),
            DropdownMenuItem(value: ImageTargetFormat.png, child: Text('Convert to PNG (.png)')),
          ],
          onChanged: (format) {
            if (format != null) {
              setState(() {
                _tempSettings = _tempSettings.copyWith(targetImageFormat: format);
              });
            }
          },
        ),
        const SizedBox(height: 16),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Filter Out Tiny Tracking Pixels', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
          subtitle: const Text('Ignores tracking pixels and website icons smaller than 20 KB', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          value: _tempSettings.filterTinyIcons,
          activeThumbColor: AppTheme.accentCyan,
          onChanged: (val) {
            setState(() {
              _tempSettings = _tempSettings.copyWith(filterTinyIcons: val);
            });
          },
        ),
        const SizedBox(height: 16),
        const Divider(),
        // Floating Sniffer Hub Customization
        const Text(
          'Floating Sniffer Hub (แผงควบคุมลอยบนหน้าเว็บ)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Customize the floating media detector widget overlaid on web pages.',
          style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<SnifferHubStyle>(
          initialValue: _tempSettings.snifferHubStyle,
          dropdownColor: AppTheme.darkSurface,
          decoration: const InputDecoration(
            labelText: 'Hub Component Style (รูปแบบแผงลอย)',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: SnifferHubStyle.glassCapsule,
              child: Text('Glass Capsule (แคปซูลกระจกพรีเมียม - แนะนำ)'),
            ),
            DropdownMenuItem(
              value: SnifferHubStyle.miniFab,
              child: Text('Mini FAB Ring (ปุ่มวงกลมมินิมอล)'),
            ),
            DropdownMenuItem(
              value: SnifferHubStyle.slimBar,
              child: Text('Slim Docked Bar (แถบสลิมติดขอบจอ)'),
            ),
          ],
          onChanged: (style) {
            if (style != null) {
              setState(() {
                _tempSettings = _tempSettings.copyWith(snifferHubStyle: style);
              });
            }
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<SnifferHubPosition>(
          initialValue: _tempSettings.snifferHubPosition,
          dropdownColor: AppTheme.darkSurface,
          decoration: const InputDecoration(
            labelText: 'Default Position (ตำแหน่งเริ่มต้นบนหน้าจอ)',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: SnifferHubPosition.bottomRight,
              child: Text('Bottom-Right (มุมล่างขวา - แนะนำ)'),
            ),
            DropdownMenuItem(
              value: SnifferHubPosition.bottomLeft,
              child: Text('Bottom-Left (มุมล่างซ้าย)'),
            ),
            DropdownMenuItem(
              value: SnifferHubPosition.bottomCenter,
              child: Text('Bottom-Center (กึ่งกลางล่าง)'),
            ),
            DropdownMenuItem(
              value: SnifferHubPosition.topRight,
              child: Text('Top-Right (มุมบนขวา)'),
            ),
            DropdownMenuItem(
              value: SnifferHubPosition.topLeft,
              child: Text('Top-Left (มุมบนซ้าย)'),
            ),
            DropdownMenuItem(
              value: SnifferHubPosition.customDraggable,
              child: Text('Custom Draggable (ลากตำแหน่งอิสระได้ตามใจ)'),
            ),
          ],
          onChanged: (pos) {
            if (pos != null) {
              setState(() {
                _tempSettings = _tempSettings.copyWith(snifferHubPosition: pos);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildNetworkTab() {
    return ListView(
      children: [
        // DNS Presets & Custom DNS
        const Text('DNS over HTTPS (DoH) & DNS Presets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _tempSettings.selectedDnsPreset,
          dropdownColor: AppTheme.darkSurface,
          decoration: const InputDecoration(
            labelText: 'Select DNS Provider',
            isDense: true,
          ),
          items: DnsPreset.presets.map((preset) {
            return DropdownMenuItem(
              value: preset.name,
              child: Text('${preset.name} - ${preset.description}'),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _tempSettings = _tempSettings.copyWith(selectedDnsPreset: val);
              });
            }
          },
        ),
        // If Custom DNS selected, show input
        if (_tempSettings.selectedDnsPreset == 'Custom DNS / DoH') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _dohController,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Custom DoH URL / DNS Server (e.g. https://dns.google/dns-query)',
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        // Proxy Settings
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Proxy Server', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
          subtitle: const Text('Route traffic through HTTP / HTTPS / SOCKS5 proxy', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          value: _tempSettings.proxyEnabled,
          activeThumbColor: AppTheme.accentAmber,
          onChanged: (val) {
            setState(() {
              _tempSettings = _tempSettings.copyWith(proxyEnabled: val);
            });
          },
        ),
        if (_tempSettings.proxyEnabled) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _proxyHostController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Proxy Host / IP', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _proxyPortController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Port', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _proxyUserController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Username (Optional)', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _proxyPassController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Password (Optional)', isDense: true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildShortcutsTab() {
    final s = _tempSettings.shortcuts;

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Keyboard Shortcuts (ปรับแต่งคีย์ลัด)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Customize essential hotkeys for lightning-fast browsing & downloading.',
                  style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.restore, size: 14),
              label: const Text('Reset Defaults', style: TextStyle(fontSize: 11)),
              onPressed: () {
                setState(() {
                  _tempSettings = _tempSettings.copyWith(shortcuts: const AppShortcuts());
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildShortcutRow(
          title: 'Close Active Tab (ปิดแท็บปัจจุบัน)',
          description: 'Closes the current browser tab',
          currentKey: s.closeTab,
          onChanged: (newKey) => setState(() {
            _tempSettings = _tempSettings.copyWith(shortcuts: s.copyWith(closeTab: newKey));
          }),
        ),
        _buildShortcutRow(
          title: 'New Tab (เปิดแท็บใหม่)',
          description: 'Opens a new browser tab with default homepage',
          currentKey: s.newTab,
          onChanged: (newKey) => setState(() {
            _tempSettings = _tempSettings.copyWith(shortcuts: s.copyWith(newTab: newKey));
          }),
        ),
        _buildShortcutRow(
          title: 'Close Other Tabs (ปิดแท็บอื่นๆ ทั้งหมด)',
          description: 'Closes all tabs except the currently active tab',
          currentKey: s.closeOtherTabs,
          onChanged: (newKey) => setState(() {
            _tempSettings = _tempSettings.copyWith(shortcuts: s.copyWith(closeOtherTabs: newKey));
          }),
        ),
        _buildShortcutRow(
          title: 'Detect / Re-detect Media (ตรวจจับสื่อ)',
          description: 'Deep scans page. In Auto mode: Re-detects; in Manual mode: Detects.',
          currentKey: s.detectMedia,
          onChanged: (newKey) => setState(() {
            _tempSettings = _tempSettings.copyWith(shortcuts: s.copyWith(detectMedia: newKey));
          }),
        ),
        _buildShortcutRow(
          title: 'Toggle Sniffer Panel (เปิด/ปิด Media Deck)',
          description: 'Shows or hides the right-side media sniffer deck',
          currentKey: s.toggleMediaDeck,
          onChanged: (newKey) => setState(() {
            _tempSettings = _tempSettings.copyWith(shortcuts: s.copyWith(toggleMediaDeck: newKey));
          }),
        ),
        _buildShortcutRow(
          title: 'Focus Address Bar (โฟกัสแถบ URL)',
          description: 'Selects the URL bar for typing new address or search',
          currentKey: s.focusUrlBar,
          onChanged: (newKey) => setState(() {
            _tempSettings = _tempSettings.copyWith(shortcuts: s.copyWith(focusUrlBar: newKey));
          }),
        ),
        _buildShortcutRow(
          title: 'Hover Media Quick Download (โหลดเมื่อเมาส์ชี้)',
          description: 'Press while hovering video or image to queue download immediately',
          currentKey: s.downloadHoverMedia,
          onChanged: (newKey) => setState(() {
            _tempSettings = _tempSettings.copyWith(shortcuts: s.copyWith(downloadHoverMedia: newKey));
          }),
        ),
      ],
    );
  }

  Widget _buildShortcutRow({
    required String title,
    required String description,
    required String currentKey,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary)),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              final selected = await _showKeyPicker(currentKey);
              if (selected != null && selected.isNotEmpty) {
                onChanged(selected);
              }
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentKey,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 11, color: AppTheme.primaryLight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showKeyPicker(String current) async {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Change Shortcut Key', style: TextStyle(fontSize: 14, color: AppTheme.darkTextPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type shortcut format (e.g. Ctrl+W, Ctrl+Shift+T, F5, Alt+D, Shift+D):',
              style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
              decoration: const InputDecoration(isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    final updated = _tempSettings.copyWith(
      defaultDownloadPath: _downloadPathController.text.trim(),
      speedLimitKBps: double.tryParse(_speedLimitController.text) ?? 0,
      connectionTimeoutSeconds: int.tryParse(_timeoutController.text) ?? 30,
      maxRetries: int.tryParse(_maxRetriesController.text) ?? 3,
      retryDelaySeconds: int.tryParse(_retryDelayController.text) ?? 5,
      interTaskDelayMs: int.tryParse(_interTaskDelayController.text) ?? 500,
      customDohUrl: _dohController.text.trim(),
      proxyHost: _proxyHostController.text.trim(),
      proxyPort: int.tryParse(_proxyPortController.text) ?? 8080,
      proxyUsername: _proxyUserController.text.trim(),
      proxyPassword: _proxyPassController.text.trim(),
    );

    ref.read(settingsProvider.notifier).updateSettings(updated);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully'), duration: Duration(seconds: 2)),
    );
  }
}
