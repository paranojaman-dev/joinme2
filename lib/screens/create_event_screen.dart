import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/services/storage_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/constants.dart';
import 'package:geocoding/geocoding.dart';

class CreateEventScreen extends StatefulWidget {
  final Event? eventToEdit;
  final double? initialLat;
  final double? initialLng;

  const CreateEventScreen({super.key, this.eventToEdit, this.initialLat, this.initialLng});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _maxParticipantsController;
  late TextEditingController _dateTimeController;
  late TextEditingController _endTimeController;
  final _spotifyController = TextEditingController();
  
  String _selectedType = 'others';
  IconData _selectedIcon = Icons.event;

  File? _eventImage;
  String? _existingImageUrl;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  bool _isLoading = false;
  
  double? _latitude;
  double? _longitude;

  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();

  final List<IconData> _availableIcons = [
    Icons.favorite, Icons.star, Icons.music_note, Icons.restaurant, 
    Icons.directions_run, Icons.local_bar, Icons.camera_alt, Icons.sports_esports,
    Icons.movie, Icons.casino, Icons.coffee, Icons.pets
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.eventToEdit;
    _selectedType = e?.type ?? 'others';
    if (e?.iconCodePoint != null) {
      _selectedIcon = IconData(e!.iconCodePoint!, fontFamily: 'MaterialIcons');
    }

    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _maxParticipantsController = TextEditingController(text: e?.maxParticipants.toString() ?? '10');
    _spotifyController.text = e?.spotifyTrackId ?? '';
    
    _dateTimeController = TextEditingController(
        text: e != null ? DateFormat('yyyy-MM-dd HH:mm').format(e.dateTime) : '');
    _endTimeController = TextEditingController(
        text: e?.endTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(e!.endTime!) : '');
    
    _existingImageUrl = e?.imageUrl;
    _latitude = e?.latitude ?? widget.initialLat;
    _longitude = e?.longitude ?? widget.initialLng;

    if (e != null) {
      _selectedDate = e.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(e.dateTime);
      if (e.endTime != null) {
        _selectedEndDate = e.endTime;
        _selectedEndTime = TimeOfDay.fromDateTime(e.endTime!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _maxParticipantsController.dispose();
    _dateTimeController.dispose();
    _endTimeController.dispose();
    _spotifyController.dispose();
    super.dispose();
  }

  Future<void> _geocodeAddress() async {
    if (_addressController.text.isEmpty) return;
    final loc = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      List<Location> locations = await locationFromAddress(_addressController.text);
      if (locations.isNotEmpty) {
        setState(() {
          _latitude = locations.first.latitude;
          _longitude = locations.first.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('loc_found')), backgroundColor: Colors.blue));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('loc_not_found')), backgroundColor: Colors.orange));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) setState(() => _eventImage = File(pickedFile.path));
  }

  Future<void> _pickStartDateTime(BuildContext context) async {
    final DateTime? date = await showDatePicker(context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2101));
    if (date == null) return;
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _selectedDate = date;
      _selectedTime = time;
      final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dateTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    });
  }

  Future<void> _pickEndDateTime(BuildContext context) async {
    final DateTime? date = await showDatePicker(context: context, initialDate: _selectedEndDate ?? _selectedDate ?? DateTime.now(), firstDate: _selectedDate ?? DateTime.now(), lastDate: DateTime(2101));
    if (date == null) return;
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: _selectedEndTime ?? TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _selectedEndDate = date;
      _selectedEndTime = time;
      final endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _endTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(endTime);
    });
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('select_start'))));
      return;
    }

    if (_latitude == null || _longitude == null) {
      await _geocodeAddress();
      if (_latitude == null) return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Session error");

      String imageUrl = _existingImageUrl ?? '';
      if (_eventImage != null) {
        imageUrl = await _storageService.uploadEventImage("event_${DateTime.now().millisecondsSinceEpoch}", _eventImage!);
      }

      final startDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      
      final Map<String, dynamic> eventData = {
        'title': _titleController.text,
        'type': _selectedType,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'maxParticipants': int.tryParse(_maxParticipantsController.text) ?? 10,
        'dateTime': Timestamp.fromDate(startDateTime),
        'endTime': _selectedEndDate != null && _selectedEndTime != null 
            ? Timestamp.fromDate(DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day, _selectedEndTime!.hour, _selectedEndTime!.minute)) 
            : null,
        'imageUrl': imageUrl,
        'latitude': _latitude,
        'longitude': _longitude,
        'spotifyTrackId': _spotifyController.text.isNotEmpty ? _spotifyController.text : null,
        'iconCodePoint': _selectedIcon.codePoint,
      };

      if (widget.eventToEdit != null) {
        await _databaseService.updateEvent(widget.eventToEdit!.id, eventData);
      } else {
        await FirebaseFirestore.instance.collection('events').add({
          ...eventData,
          'creatorId': user.uid,
          'creatorName': user.displayName ?? 'Organizer',
          'participants': [user.uid],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.eventToEdit != null ? loc.translate('event_updated') : loc.translate('event_created')), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.eventToEdit != null ? loc.translate('save') : loc.translate('create_event'))),
      body: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.10, child: Center(child: Icon(Icons.chair, size: 300, color: Colors.green.shade400)))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 180, width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[850], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[700]!),
                          image: _eventImage != null ? DecorationImage(image: FileImage(_eventImage!), fit: BoxFit.cover) : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover) : null,
                        ),
                        child: _eventImage == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty) ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_photo_alternate_outlined, size: 50, color: Colors.white70), const SizedBox(height: 8), Text(loc.translate('add_photo'), style: const TextStyle(color: Colors.white70))]) : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(controller: _titleController, decoration: InputDecoration(labelText: loc.translate('event_title'), border: const OutlineInputBorder()), validator: (v) => v!.isEmpty ? loc.translate('no_empty_title') : null),
                    const SizedBox(height: 16),
                    // WYBÓR SYMBOLU
                    const Align(alignment: Alignment.centerLeft, child: Text("Wybierz symbol na mapie:", style: TextStyle(color: Colors.grey))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade800), borderRadius: BorderRadius.circular(8)),
                      child: Wrap(
                        spacing: 8,
                        children: _availableIcons.map((icon) => IconButton(
                          icon: Icon(icon, color: _selectedIcon == icon ? Colors.green : Colors.white54),
                          onPressed: () => setState(() => _selectedIcon = icon),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: _spotifyController, decoration: const InputDecoration(labelText: "Spotify Track ID", border: OutlineInputBorder(), hintText: "Wklej ID utworu ze Spotify")),
                    const SizedBox(height: 16),
                    TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: loc.translate('description'), border: const OutlineInputBorder()), maxLines: 3),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController, decoration: InputDecoration(labelText: loc.translate('location_address'), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.green), onPressed: _geocodeAddress)),
                      onFieldSubmitted: (_) => _geocodeAddress(),
                      validator: (v) => v!.isEmpty ? loc.translate('provide_address') : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(controller: _maxParticipantsController, decoration: InputDecoration(labelText: loc.translate('participants_limit'), border: const OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? loc.translate('provide_limit') : null),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _dateTimeController, decoration: InputDecoration(labelText: loc.translate('start_time'), border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today)), readOnly: true, onTap: () => _pickStartDateTime(context), validator: (v) => v!.isEmpty ? loc.translate('select_start') : null)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: _endTimeController, decoration: InputDecoration(labelText: loc.translate('end_time'), border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.timer_outlined)), readOnly: true, onTap: () => _pickEndDateTime(context))),
                      ],
                    ),
                    const SizedBox(height: 30),
                    if (_isLoading) const CircularProgressIndicator()
                    else SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _submitEvent, style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(widget.eventToEdit != null ? loc.translate('save').toUpperCase() : loc.translate('create_event').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
