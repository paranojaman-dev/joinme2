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

  const CreateEventScreen({super.key, this.eventToEdit});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _typeController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _maxParticipantsController;
  late TextEditingController _dateTimeController;
  late TextEditingController _endTimeController;

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

  @override
  void initState() {
    super.initState();
    final e = widget.eventToEdit;
    
    // Mapowanie wsteczne dla starych (polskich) kategorii w bazie danych
    String initialType = e?.type ?? '';
    initialType = _mapLegacyType(initialType);

    _titleController = TextEditingController(text: e?.title ?? '');
    _typeController = TextEditingController(text: initialType);
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _maxParticipantsController = TextEditingController(text: e?.maxParticipants.toString() ?? '10');
    
    _dateTimeController = TextEditingController(
        text: e != null ? DateFormat('yyyy-MM-dd HH:mm').format(e.dateTime) : '');
    _endTimeController = TextEditingController(
        text: e?.endTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(e!.endTime!) : '');
    
    _existingImageUrl = e?.imageUrl;
    _latitude = e?.latitude;
    _longitude = e?.longitude;

    if (e != null) {
      _selectedDate = e.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(e.dateTime);
      if (e.endTime != null) {
        _selectedEndDate = e.endTime;
        _selectedEndTime = TimeOfDay.fromDateTime(e.endTime!);
      }
    }
  }

  String _mapLegacyType(String type) {
    switch (type) {
      case 'Kino': return 'cinema';
      case 'Spacer': return 'walk';
      case 'Dyskusja': return 'discussion';
      case 'Restauracja': return 'restaurant';
      case 'Bar': return 'bar';
      case 'Dyskoteka': return 'disco';
      case 'Koncert': return 'concert';
      case 'Spotkanie': return 'meeting';
      case 'Planszówka': return 'board_games';
      case 'Wyjazd': return 'trip';
      case 'Mecz': return 'match';
      case 'Grill': return 'grill';
      case 'Galeria': return 'gallery';
      case 'Zakupy': return 'shopping';
      case 'Impreza': return 'party';
      default: return type;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _maxParticipantsController.dispose();
    _dateTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  // ... (reszta metod bez zmian, geocode, pickImage itd.)

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('loc_found')), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('loc_not_found')), backgroundColor: Colors.orange),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _eventImage = File(pickedFile.path));
    }
  }

  Future<void> _pickStartDateTime(BuildContext context) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2101),
    );
    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = date;
      _selectedTime = time;
      final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dateTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    });
  }

  Future<void> _pickEndDateTime(BuildContext context) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? _selectedDate ?? DateTime.now(),
      firstDate: _selectedDate ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? TimeOfDay.now(),
    );
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
        'type': _typeController.text,
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
      };

      final userName = user.displayName ?? loc.translate('someone');

      if (widget.eventToEdit != null) {
        await _databaseService.updateEvent(widget.eventToEdit!.id, eventData);
        await _databaseService.sendNotification(
          user.uid, 
          user.uid, 
          'updated_event', 
          extraData: {'senderName': userName, 'eventTitle': _titleController.text}
        );
      } else {
        final newEvent = Event(
          id: '',
          creatorId: user.uid,
          creatorName: user.displayName ?? 'Organizer',
          title: _titleController.text,
          type: _typeController.text,
          description: _descriptionController.text,
          address: _addressController.text,
          maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 10,
          dateTime: startDateTime,
          endTime: _selectedEndDate != null ? DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day, _selectedEndTime!.hour, _selectedEndTime!.minute) : null,
          participants: [user.uid],
          latitude: _latitude!,
          longitude: _longitude!,
          imageUrl: imageUrl,
        );
        await _databaseService.createEvent(newEvent);
        await _databaseService.sendNotification(
          user.uid, 
          user.uid, 
          'created_new_event', 
          extraData: {'senderName': userName, 'eventTitle': _titleController.text}
        );
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
    
    final List<Map<String, String>> mappedTypes = [
      {'key': 'cinema'},
      {'key': 'walk'},
      {'key': 'discussion'},
      {'key': 'restaurant'},
      {'key': 'bar'},
      {'key': 'disco'},
      {'key': 'concert'},
      {'key': 'meeting'},
      {'key': 'board_games'},
      {'key': 'trip'},
      {'key': 'match'},
      {'key': 'grill'},
      {'key': 'gallery'},
      {'key': 'shopping'},
      {'key': 'party'},
      {'key': 'others'},
    ];

    String? currentType = _typeController.text.isEmpty ? null : _typeController.text;

    return Scaffold(
      appBar: AppBar(title: Text(widget.eventToEdit != null ? loc.translate('save') : loc.translate('create_event'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[700]!),
                      image: _eventImage != null 
                        ? DecorationImage(image: FileImage(_eventImage!), fit: BoxFit.cover)
                        : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                          ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _eventImage == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty)
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 50, color: Colors.white70),
                            SizedBox(height: 8),
                            Text("Dodaj zdjęcie", style: TextStyle(color: Colors.white70)),
                          ],
                        )
                      : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController, 
                  decoration: InputDecoration(labelText: loc.translate('event_title'), border: const OutlineInputBorder()), 
                  validator: (v) => v!.isEmpty ? loc.translate('no_empty_title') : null
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: currentType,
                  decoration: InputDecoration(labelText: loc.translate('category'), border: const OutlineInputBorder()),
                  items: mappedTypes.map((type) => DropdownMenuItem(
                    value: type['key'], 
                    child: Text(loc.translate(type['key']!))
                  )).toList(),
                  onChanged: (val) => setState(() => _typeController.text = val!),
                  validator: (v) => v == null ? loc.translate('select_category') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController, 
                  decoration: InputDecoration(labelText: loc.translate('description'), border: const OutlineInputBorder()), 
                  maxLines: 3
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController, 
                  decoration: InputDecoration(
                    labelText: loc.translate('location_address'), 
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: AppColors.primaryColor),
                      onPressed: _geocodeAddress,
                    ),
                  ),
                  onFieldSubmitted: (_) => _geocodeAddress(),
                  validator: (v) => v!.isEmpty ? loc.translate('provide_address') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maxParticipantsController, 
                  decoration: InputDecoration(labelText: loc.translate('participants_limit'), border: const OutlineInputBorder()), 
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? loc.translate('provide_limit') : null
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateTimeController, 
                        decoration: InputDecoration(labelText: loc.translate('start_time'), border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today)), 
                        readOnly: true, 
                        onTap: () => _pickStartDateTime(context),
                        validator: (v) => v!.isEmpty ? loc.translate('select_start') : null
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _endTimeController, 
                        decoration: InputDecoration(labelText: loc.translate('end_time'), border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.timer_outlined)), 
                        readOnly: true, 
                        onTap: () => _pickEndDateTime(context)
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                if (_isLoading) const CircularProgressIndicator()
                else SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _submitEvent, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: Text(widget.eventToEdit != null ? loc.translate('save').toUpperCase() : loc.translate('create_event').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
