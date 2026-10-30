import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/clinic_service.dart';
import '../receptionist/add_staff_dialog.dart';
import 'staff_web_shell.dart';

/// Receptionist: add staff, approve doctor applications, see the staff list.
class WebStaffPage extends StatefulWidget {
  const WebStaffPage({super.key});

  @override
  State<WebStaffPage> createState() => _WebStaffPageState();
}

class _WebStaffPageState extends State<WebStaffPage> {
  final ClinicService _service = ClinicService();
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  String? _workingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await _service.pendingDoctorApplications();
      final staff = await _service.staffList();
      if (mounted) {
        setState(() {
          _applications = apps;
          _staff = staff;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the staff.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addStaff() async {
    final msg = await showAddStaffDialog(context);
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    _load();
  }

  Future<void> _review(Map<String, dynamic> app, bool approve) async {
    final id = app['id'] as String;
    setState(() {
      _workingId = id;
      _error = null;
    });
    try {
      if (approve) {
        await _service.approveDoctorApplication(id);
      } else {
        await _service.rejectDoctorApplication(id);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  String _statusLabel(String s) => switch (s) {
    'active' => 'Active',
    'pending' => 'Pending approval',
    'rejected' => 'Rejected',
    _ => s,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WebPageHeader(
          title: 'Staff',
          subtitle:
              'Add receptionists and doctors, and approve doctor applications.',
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _addStaff,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add staff'),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doctor applications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_applications.isEmpty)
                  const Text('No pending doctor applications.')
                else
                  for (final app in _applications) _applicationRow(app),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Staff directory',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Professions')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final s in _staff)
                      DataRow(
                        cells: [
                          DataCell(Text('${s['name'] ?? ''}')),
                          DataCell(
                            Text(
                              s['role'] == 'doctor' ? 'Doctor' : 'Receptionist',
                            ),
                          ),
                          DataCell(Text('${s['email'] ?? ''}')),
                          DataCell(
                            Text(
                              (s['professions'] as List? ?? const [])
                                  .map((e) => e.toString())
                                  .join(', '),
                            ),
                          ),
                          DataCell(Text(_statusLabel('${s['status']}'))),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _applicationRow(Map<String, dynamic> app) {
    final id = app['id'] as String;
    final name = '${app['first_name'] ?? ''} ${app['last_name'] ?? ''}'.trim();
    final professions = (app['professions'] as List? ?? const [])
        .map((e) => e.toString())
        .join(', ');
    final working = _workingId == id;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
      title: Text(name.isEmpty ? 'Doctor application' : name),
      subtitle: Text(
        [
          '${app['email'] ?? ''}',
          if (professions.isNotEmpty) professions,
        ].join('  ·  '),
      ),
      trailing: working
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () => _review(app, true),
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _review(app, false),
                  child: const Text('Reject'),
                ),
              ],
            ),
    );
  }
}
