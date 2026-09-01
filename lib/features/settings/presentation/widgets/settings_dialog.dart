import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/app_settings.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        width: 640,
        height: 560,
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
                Tab(icon: Icon(Icons.download, size: 16), text: 'Download & Queue'),
                Tab(icon: Icon(Icons.transform, size: 16), text: 'Format & Sniffer'),
                Tab(icon: Icon(Icons.public, size: 16), text: 'Network & DNS'),
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
        // Concurrency Slider
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Max Concurrent Downloads', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
          subtitle: Text(
            'Current: ${_tempSettings.maxConcurrentDownloads} tasks simultaneously',
            style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
          ),
          trailing: SizedBox(
            width: 180,
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
