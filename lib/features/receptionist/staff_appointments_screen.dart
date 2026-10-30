import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../services/clinic_service.dart';
import 'add_staff_dialog.dart';

/// Shared by the receptionist (Fig 9, isReception: true) and the doctor
/// (Fig 10, isReception: false).
class StaffAppointmentsScreen extends StatefulWidget {
  const StaffAppointmentsScreen({super.key, required this.isReception});

  final bool isReception;

  @override
  State<StaffAppointmentsScreen> createState() =>
      _StaffAppointmentsScreenState();
}

class _StaffAppointmentsScreenState extends State<StaffAppointmentsScreen> {
  final ClinicService _service = ClinicService();
  List<ClinicAppointment> _appointments = [];
  List<Map<String, dynamic>> _doctorApplications = [];
  bool _loading = true;
  bool _loadingDoctors = false;
  int _selectedTab = 0;
  String? _workingId;
  String? _workingDoctorId;
  String? _error;
  String? _doctorError;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.isReception) {
      _loadDoctorApplications();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appointments = await _service.staffAppointments(
        state: widget.isReception ? 'pending' : null,
      );
      if (mounted) setState(() => _appointments = appointments);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(ClinicAppointment appointment, bool approve) async {
    setState(() {
      _workingId = appointment.id;
      _error = null;
    });
    try {
      await _service.reviewAppointment(appointment.id, approve: approve);
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<void> _loadDoctorApplications() async {
    setState(() {
      _loadingDoctors = true;
      _doctorError = null;
    });
    try {
      final applications = await _service.pendingDoctorApplications();
      if (mounted) setState(() => _doctorApplications = applications);
    } on ApiException catch (error) {
      if (mounted) setState(() => _doctorError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _doctorError = 'Unable to load doctor applications.');
      }
    } finally {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  Future<void> _reviewDoctorApplication(
    Map<String, dynamic> application,
    bool approve,
  ) async {
    final staffId = application['id'] as String;
    setState(() {
      _workingDoctorId = staffId;
      _doctorError = null;
    });
    try {
      if (approve) {
        await _service.approveDoctorApplication(staffId);
      } else {
        await _service.rejectDoctorApplication(staffId);
      }
      await _loadDoctorApplications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'Doctor application approved.'
                  : 'Doctor application rejected.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _doctorError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _doctorError = 'Unable to review this doctor application.';
        });
      }
    } finally {
      if (mounted) setState(() => _workingDoctorId = null);
    }
  }

  Future<void> _addStaff() async {
    final msg = await showAddStaffDialog(context);
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _loadDoctorApplications();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.isReception
            ? 'Clinic appointment requests'
            : 'Clinic appointments',
      ),
      actions: [
        if (widget.isReception)
          IconButton(
            tooltip: 'Clinic location',
            onPressed: () => context.push('/reception/clinic-location'),
            icon: const Icon(Icons.place_outlined),
          ),
        if (widget.isReception)
          IconButton(
            tooltip: 'Add staff',
            onPressed: _addStaff,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        if (widget.isReception)
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.push('/reception/inbox'),
            icon: const Icon(Icons.inbox_outlined),
          ),
        IconButton(
          tooltip: 'My profile',
          onPressed: () => context.push('/profile'),
          icon: const Icon(Icons.person_outline),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            if (widget.isReception)
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Appointment Requests'),
                      icon: Icon(Icons.calendar_month),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Doctor Applications'),
                      icon: Icon(Icons.medical_services_outlined),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (selection) {
                    final tab = selection.first;
                    setState(() => _selectedTab = tab);
                    if (tab == 1 && _doctorApplications.isEmpty) {
                      _loadDoctorApplications();
                    }
                  },
                ),
              ),
            if (_selectedTab == 0 || !widget.isReception)
              ..._appointmentsTab()
            else
              ..._doctorsTab(),
          ],
        ),
      ),
    ),
  );

  List<Widget> _appointmentsTab() => [
    if (_loading) const LinearProgressIndicator(),
    if (_error != null)
      MaterialBanner(
        content: Text(_error!),
        actions: [TextButton(onPressed: _load, child: const Text('Retry'))],
      ),
    Expanded(
      child: _loading && _appointments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
          ? Center(
              child: Text(
                widget.isReception
                    ? 'There are no pending appointment requests.'
                    : 'There are no clinic appointments.',
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _appointments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _appointmentCard(context, _appointments[index]),
              ),
            ),
    ),
  ];

  Widget _appointmentCard(BuildContext context, ClinicAppointment appointment) {
    final working = _workingId == appointment.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointment.clinicName ?? 'Clinic information unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Patient: ${appointment.patientName ?? appointment.userId}'),
            if (appointment.doctorName != null)
              Text('Doctor: ${appointment.doctorName}'),
            if (appointment.scheduledAt != null)
              Text('Time: ${appointment.scheduledAt!.toLocal()}'),
            Text(
              'Type: ${appointment.mode == 'online' ? 'Online' : 'In person'}',
            ),
            Text('Reference: ${appointment.reference ?? 'Unavailable'}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (widget.isReception && appointment.status == 'pending') ...[
                  FilledButton.icon(
                    onPressed: working
                        ? null
                        : () => _review(appointment, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                  OutlinedButton.icon(
                    onPressed: working
                        ? null
                        : () => _review(appointment, false),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ] else
                  Chip(label: Text(appointmentStatusLabel(appointment.status))),
                if (working)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _doctorsTab() => [
    Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Review pending doctor registrations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Refresh applications',
            onPressed: _loadingDoctors ? null : _loadDoctorApplications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    ),
    if (_doctorError != null)
      MaterialBanner(
        content: Text(_doctorError!),
        actions: [
          TextButton(
            onPressed: _loadDoctorApplications,
            child: const Text('Retry'),
          ),
        ],
      ),
    Expanded(
      child: _loadingDoctors && _doctorApplications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _doctorApplications.isEmpty
          ? const Center(child: Text('No pending doctor applications.'))
          : RefreshIndicator(
              onRefresh: _loadDoctorApplications,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _doctorApplications.length,
                itemBuilder: (context, index) =>
                    _doctorCard(context, _doctorApplications[index]),
              ),
            ),
    ),
  ];

  Widget _doctorCard(BuildContext context, Map<String, dynamic> application) {
    final id = application['id'] as String;
    final name =
        '${application['first_name'] ?? ''} ${application['last_name'] ?? ''}'
            .trim();
    final professions = (application['professions'] as List? ?? const [])
        .map((item) => item.toString())
        .join(', ');
    final working = _workingDoctorId == id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? 'Doctor application #$id' : name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('Email: ${application['email'] ?? 'Not provided'}'),
            Text(
              'Professions: ${professions.isEmpty ? 'Not provided' : professions}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: working
                      ? null
                      : () => _reviewDoctorApplication(application, true),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: working
                      ? null
                      : () => _reviewDoctorApplication(application, false),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
                if (working)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
