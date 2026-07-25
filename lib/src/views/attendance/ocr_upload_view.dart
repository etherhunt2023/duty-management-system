import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/ocr_service.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../data/models/attendance_model.dart';
import '../../core/theme/app_theme.dart';

class OcrUploadView extends ConsumerStatefulWidget {
  const OcrUploadView({super.key});

  @override
  ConsumerState<OcrUploadView> createState() => _OcrUploadViewState();
}

class _OcrUploadViewState extends ConsumerState<OcrUploadView> {
  final _ocrService = OcrService();
  bool _isLoading = false;
  File? _selectedFile;
  List<ParsedAttendanceRecord> _parsedRecords = [];

  // Controllers for editing OCR results before saving
  final List<TextEditingController> _empIdCtrls = [];
  final List<TextEditingController> _inCtrls = [];
  final List<TextEditingController> _outCtrls = [];
  final List<String> _shiftVals = [];

  @override
  void dispose() {
    _ocrService.dispose();
    for (final c in _empIdCtrls) {
      c.dispose();
    }
    for (final c in _inCtrls) {
      c.dispose();
    }
    for (final c in _outCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // Handle document uploading
  Future<void> _pickDocument({required bool fromCamera}) async {
    File? file;
    if (fromCamera) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        file = File(picked.path);
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
      );
      if (result != null && result.files.single.path != null) {
        file = File(result.files.single.path!);
      }
    }

    if (file != null) {
      setState(() {
        _selectedFile = file;
        _isLoading = true;
        _parsedRecords = [];
        _clearControllers();
      });

      // Execute OCR Parser
      final results = await _ocrService.processAttendanceDocument(file);
      
      setState(() {
        _parsedRecords = results;
        _isLoading = false;
        
        // Initialize editing controllers
        for (final rec in results) {
          _empIdCtrls.add(TextEditingController(text: rec.employeeId));
          _inCtrls.add(TextEditingController(text: rec.checkIn));
          _outCtrls.add(TextEditingController(text: rec.checkOut));
          _shiftVals.add(rec.shiftCode ?? 'A');
        }
      });
    }
  }

  void _clearControllers() {
    _empIdCtrls.clear();
    _inCtrls.clear();
    _outCtrls.clear();
    _shiftVals.clear();
  }

  // Save the verified entries
  Future<void> _saveRecords() async {
    setState(() {
      _isLoading = true;
    });

    final List<Attendance> verified = [];
    final today = DateTime.now().toIso8601String().split('T').first;

    for (int i = 0; i < _parsedRecords.length; i++) {
      verified.add(
        Attendance(
          id: '',
          employeeId: _empIdCtrls[i].text.trim().toUpperCase(),
          employeeName: _parsedRecords[i].employeeName ?? 'Staff',
          date: today,
          shiftName: _shiftVals[i] == 'A'
              ? 'Shift A (Morning)'
              : _shiftVals[i] == 'B'
                  ? 'Shift B (Evening)'
                  : _shiftVals[i] == 'C'
                      ? 'Shift C (Night)'
                      : 'Custom Duty',
          checkIn: _inCtrls[i].text.trim(),
          checkOut: _outCtrls[i].text.trim(),
          dutyMinutes: 0, // recomputed in VM
          otMinutes: 0,
          remainingOtMinutes: 0,
          coGenerated: 0,
          remarks: 'Uploaded from Scan Register',
        ),
      );
    }

    await ref.read(attendanceViewModelProvider.notifier).saveOcrScannedRecords(verified);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully processed ${_parsedRecords.length} scanned logs.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Attendance Scanner'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing register layout. Aligning coordinate cells...', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File Select Panel
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Center(
                            child: Icon(Icons.document_scanner, size: 64, color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Scan Attendance Register',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload a photo of the physical register sheet, a scanned PDF, or take a picture using the device camera.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                            textAlign: Center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Camera'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  minimumSize: const Size(130, 48),
                                ),
                                onPressed: () => _pickDocument(fromCamera: true),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.file_upload),
                                label: const Text('Upload File'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(130, 48),
                                ),
                                onPressed: () => _pickDocument(fromCamera: false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_parsedRecords.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.between,
                      children: [
                        Text(
                          'Parsed Logs: ${_parsedRecords.length} rows',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Verify & Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(140, 40),
                          ),
                          onPressed: _saveRecords,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Parsed records grid review
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _parsedRecords.length,
                      itemBuilder: (context, idx) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Employee Name: ${_parsedRecords[idx].employeeName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _empIdCtrls[idx],
                                        decoration: const InputDecoration(labelText: 'Employee ID', isDense: true),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _shiftVals[idx],
                                        decoration: const InputDecoration(labelText: 'Shift', isDense: true),
                                        items: const [
                                          DropdownMenuItem(value: 'A', child: Text('Shift A')),
                                          DropdownMenuItem(value: 'B', child: Text('Shift B')),
                                          DropdownMenuItem(value: 'C', child: Text('Shift C')),
                                          DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _shiftVals[idx] = v;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _inCtrls[idx],
                                        decoration: const InputDecoration(labelText: 'Check-In', isDense: true),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _outCtrls[idx],
                                        decoration: const InputDecoration(labelText: 'Check-Out', isDense: true),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
