import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database.dart';
import 'models.dart';
import 'sync_service.dart';
import 'widgets/date_picker_sheet.dart';
import 'widgets/breed_picker.dart';

class AddPetPage extends StatefulWidget {
  final Pet? pet;
  final VoidCallback onSaved;
  const AddPetPage({super.key, this.pet, required this.onSaved});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _note = TextEditingController();
  String _species = 'cat';
  String _gender = 'unknown';
  String _neuter = 'unknown';
  String? _birthday;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    final p = widget.pet;
    if (p != null) {
      _name.text = p.name;
      _breed.text = p.breed ?? '';
      _note.text = p.note ?? '';
      _species = p.species;
      _gender = p.gender ?? 'unknown';
      _neuter = p.neuter ?? 'unknown';
      _birthday = p.birthday;
      _avatarPath = p.avatarPath;
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: Text('拍照'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: Text('从相册选择'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 85);
    if (picked == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${appDir.path}/avatars');
    if (!avatarsDir.existsSync()) avatarsDir.createSync(recursive: true);
    final ext = p.extension(picked.path);
    final dest = File('${avatarsDir.path}/${genId()}$ext');
    await File(picked.path).copy(dest.path);
    setState(() => _avatarPath = dest.path);
  }

  Future<void> _pickDate() async {
    final d = await showScrollDatePicker(
      context,
      initialDate: _birthday,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _birthday = d);
  }

  Future<void> _pickBreed() async {
    final b = await showBreedPicker(context, _species, _breed.text.trim());
    if (b != null) setState(() => _breed.text = b);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写宠物昵称')));
      return;
    }
    final pet = Pet(
      id: widget.pet?.id ?? genId(),
      name: name,
      species: _species,
      breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
      birthday: _birthday,
      gender: _gender,
      neuter: _neuter,
      avatarPath: _avatarPath,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: widget.pet?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    if (widget.pet == null) {
      await DatabaseHelper.instance.insertPet(pet);
    } else {
      await DatabaseHelper.instance.updatePet(pet);
    }
    widget.onSaved();
    SyncService.syncIfAuto();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pet == null ? '添加宠物' : '编辑宠物')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _avatarPreview(),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFF5A623), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(controller: _name, decoration: const InputDecoration(labelText: '昵称 *')),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Text('🐱', style: TextStyle(fontSize: 20, color: _species == 'cat' ? Colors.orange : Colors.grey)),
                Radio<String>(value: 'cat', groupValue: _species, onChanged: (v) => setState(() => _species = v!), activeColor: const Color(0xFFF5A623)),
                Text('猫咪'),
                const SizedBox(width: 16),
                Text('🐶', style: TextStyle(fontSize: 20, color: _species == 'dog' ? Colors.orange : Colors.grey)),
                Radio<String>(value: 'dog', groupValue: _species, onChanged: (v) => setState(() => _species = v!), activeColor: const Color(0xFFF5A623)),
                Text('狗狗'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickBreed,
            child: AbsorbPointer(
              child: TextField(
                controller: _breed,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '品种',
                  hintText: '点击选择品种或自定义',
                  suffixIcon: Icon(Icons.keyboard_arrow_down, color: Colors.orange.shade300),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextField(
                controller: TextEditingController(text: _birthday ?? ''),
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '出生日期',
                  hintText: '选择日期',
                  suffixIcon: Icon(Icons.calendar_today, color: Colors.orange.shade300),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: '性别'),
            items: const [
              DropdownMenuItem(value: 'unknown', child: Text('未知')),
              DropdownMenuItem(value: 'male', child: Text('公')),
              DropdownMenuItem(value: 'female', child: Text('母')),
            ],
            onChanged: (v) => setState(() => _gender = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _neuter,
            decoration: const InputDecoration(labelText: '绝育状态'),
            items: const [
              DropdownMenuItem(value: 'unknown', child: Text('未知')),
              DropdownMenuItem(value: 'neutered', child: Text('已绝育')),
              DropdownMenuItem(value: 'intact', child: Text('未绝育')),
            ],
            onChanged: (v) => setState(() => _neuter = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: '备注')),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: Text('保存'))),
        ],
      ),
    );
  }

  Widget _avatarPreview() {
    if (_avatarPath != null && File(_avatarPath!).existsSync()) {
      return ClipOval(
        child: Image.file(File(_avatarPath!), width: 110, height: 110, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
      child: Center(child: Text(speciesEmoji(_species), style: const TextStyle(fontSize: 56))),
    );
  }
}
