import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/sos_request.dart';
import '../providers/sos_provider.dart';
import '../theme/theme.dart';
import '../utils/battery_helper.dart';
import '../utils/device_helper.dart';
import '../utils/location_helper.dart';

class CreateSosDialog extends StatefulWidget {
  const CreateSosDialog({super.key});

  @override
  State<CreateSosDialog> createState() => _CreateSosDialogState();
}

class _CreateSosDialogState extends State<CreateSosDialog> {
  final _victimNameController = TextEditingController();
  final _victimCountController = TextEditingController();

  String _emergencyLevel = "HIGH";
  InjuryType _injuryType = InjuryType.critical;
  bool _isSending = false;

  @override
  void dispose() {
    _victimNameController.dispose();
    _victimCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create SOS"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _victimNameController,
              decoration: const InputDecoration(
                labelText: "Victim Name",
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<InjuryType>(
  initialValue: _injuryType,
  decoration: const InputDecoration(
    labelText: "Injury Type",
  ),
  items: InjuryType.values.map((type) {
    return DropdownMenuItem(
      value: type,
      child: Text(type.apiValue),
    );
  }).toList(),
  onChanged: (value) {
    if (value != null) {
      setState(() {
        _injuryType = value;
      });
    }
  },
),            const SizedBox(height: 12),
            TextField(
              controller: _victimCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Victim Count",
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
             initialValue: _emergencyLevel,
              decoration: const InputDecoration(
                labelText: "Emergency Level",
              ),
              items: const [
                DropdownMenuItem(
                  value: "LOW",
                  child: Text("LOW"),
                ),
                DropdownMenuItem(
                  value: "MEDIUM",
                  child: Text("MEDIUM"),
                ),
                DropdownMenuItem(
                  value: "HIGH",
                  child: Text("HIGH"),
                ),
                             ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _emergencyLevel = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isSending
              ? null
              : () async {
                  setState(() {
                    _isSending = true;
                  });

                  try {
                    final provider = context.read<SosProvider>();
                    final position = await LocationHelper.getCurrentLocation();
                    final battery = await BatteryHelper.getBatteryPercentage();
                    final deviceId = await DeviceHelper.getDeviceId();

                    final payload = SosRequestCreate(
                      victimName: _victimNameController.text.trim().isEmpty
                          ? "Anonymous Victim"
                          : _victimNameController.text.trim(),
                      injuryType: _injuryType,
                      victimCount: int.tryParse(_victimCountController.text) ?? 1,
                      emergencyLevel: EmergencyLevel.values.firstWhere(
                        (level) => level.apiValue == _emergencyLevel,
                        orElse: () => EmergencyLevel.high,
                      ),
                      latitude: position.latitude,
                      longitude: position.longitude,
                      batteryPercentage: battery,
                      deviceId: deviceId,
                    );

                    final result = await provider.createSos(payload);
                    if (!context.mounted) return;

                    if (result == SosCreationResult.onlineSuccess) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("SOS sent successfully!"),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (result == SosCreationResult.offlineQueued) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("SOS saved locally. Waiting for connection."),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    } else {
                      final errorMsg =
                          provider.errorMessage ?? "Failed to process SOS.";
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: $error"),
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isSending = false;
                      });
                    }
                  }
                },
          child: _isSending
    ? const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 10),
          Text("Sending..."),
        ],
      )
    : const Text("Send SOS"),
        ),
      ],
    );
  }
}