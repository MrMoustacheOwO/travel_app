import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../config/backend_config.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/trips_provider.dart';
import 'auth_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _backendUrlController = TextEditingController();
  String? _photoPath;
  bool _loaded = false;
  bool _saving = false;
  bool _savingBackendUrl = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _backendUrlController.text = BackendConfig.baseUrl;

      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.load();
      final profile = profileProvider.profile;
      if (!mounted) return;
      if (profile != null) {
        setState(() {
          _nameController.text = profile.name;
          _emailController.text = profile.email;
          _photoPath = profile.photoPath;
          _loaded = true;
        });
      }
      context.read<TripsProvider>().loadTrips();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final savedFile = await File(picked.path).copy(p.join(docsDir.path, fileName));
    setState(() => _photoPath = savedFile.path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<ProfileProvider>().save(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          photoPath: _photoPath,
        );
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Изменения сохранены')),
    );
  }

  Future<void> _saveBackendUrl() async {
    final url = _backendUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите адрес сервера')),
      );
      return;
    }

    setState(() => _savingBackendUrl = true);
    await BackendConfig.setBaseUrl(url);
    setState(() => _savingBackendUrl = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сервер: ${BackendConfig.baseUrl}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripsProvider>().trips;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Настройки профиля'),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage:
                              _photoPath != null ? FileImage(File(_photoPath!)) : null,
                          child: _photoPath == null
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 14,
                            child: Icon(Icons.edit, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя пользователя',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Адрес электронной почты',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Сервер локальной сети',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _backendUrlController,
                  decoration: InputDecoration(
                    labelText: 'URL backend',
                    hintText: 'http://192.168.1.50:8080',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _savingBackendUrl ? null : _saveBackendUrl,
                      icon: const Icon(Icons.save_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Пример: http://192.168.1.50:8080',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Созданные поездки',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (trips.isEmpty)
                  const Text('Поездок пока нет')
                else
                  ...trips.map((t) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.flight_takeoff),
                        title: Text(t.name),
                        subtitle: Text(t.status.name),
                      )),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator())
                      : const Text('Сохранить изменения'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    final navigator = Navigator.of(context);

                    await authProvider.logout();
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Выйти из аккаунта'),
                ),
              ],
            ),
    );
  }
}
