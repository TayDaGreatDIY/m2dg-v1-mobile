import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/services/checkin_service.dart';

final supabase = Supabase.instance.client;

class CheckInPage extends StatefulWidget {
  final String courtId;
  final double courtLat;
  final double courtLng;
  final int radiusMeters;
  final String courtName;

  const CheckInPage({
    super.key,
    required this.courtId,
    required this.courtLat,
    required this.courtLng,
    required this.radiusMeters,
    required this.courtName,
  });

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final _svc = CheckInService(supabase);
  
  bool _isLoading = false;
  bool _showQrCode = false;
  bool _showLocation = false;
  bool _showSelfie = false;
  
  Position? _currentPosition;
  int? _distanceMeters;
  double? _accuracy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          setState(() => _error = 'Location permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      
      if (!mounted) return;
      
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.courtLat,
        widget.courtLng,
      ).round();

      setState(() {
        _currentPosition = position;
        _distanceMeters = distance;
        _accuracy = position.accuracy;
        _showLocation = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error getting location: $e');
      }
    }
  }

  Future<void> _submitCheckIn() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final result = await _svc.checkIn(
        courtId: widget.courtId,
        courtLat: widget.courtLat,
        courtLng: widget.courtLng,
        radiusMeters: widget.radiusMeters,
        debugPinToCourtCoords: false,
      );

      if (!mounted) return;

      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Check-in successful! 🎉'),
            backgroundColor: const Color(0xFF32D74B),
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFFFF2D55),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Check In',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Court name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.courtName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Steps indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStepIndicator(1, 'QR Code', _showQrCode),
                  const SizedBox(width: 12),
                  _buildStepIndicator(2, 'Location', _showLocation),
                  const SizedBox(width: 12),
                  _buildStepIndicator(3, 'Selfie', _showSelfie),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // QR Code section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCheckInSection(
                title: 'Court QR Code',
                subtitle: 'Scan to verify you\'re at the court',
                icon: Icons.qr_code_2,
                isComplete: _showQrCode,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 80,
                          color: const Color(0xFFC7C7CC),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'QR Code Placeholder',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFC7C7CC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Location section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCheckInSection(
                title: 'GPS Location',
                subtitle: 'Verify your physical location',
                icon: Icons.location_on,
                isComplete: _showLocation && _distanceMeters != null && _distanceMeters! <= widget.radiusMeters,
                child: _error != null
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF2D55),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFF2D55)),
                        ),
                      )
                    : _currentPosition == null
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF2D55),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Distance',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFFC7C7CC),
                                      ),
                                    ),
                                    Text(
                                      '$_distanceMeters m',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: _distanceMeters! <= widget.radiusMeters
                                            ? const Color(0xFF32D74B)
                                            : const Color(0xFFFF2D55),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Court Radius',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFFC7C7CC),
                                      ),
                                    ),
                                    Text(
                                      '${widget.radiusMeters} m',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'GPS Accuracy',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFFC7C7CC),
                                      ),
                                    ),
                                    Text(
                                      '${_accuracy?.toStringAsFixed(1)} m',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: _accuracy != null && _accuracy! <= 75
                                            ? const Color(0xFF32D74B)
                                            : const Color(0xFFFF2D55),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
              ),
            ),

            const SizedBox(height: 24),

            // Selfie section (placeholder)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCheckInSection(
                title: 'Selfie Verification',
                subtitle: 'Take a selfie for anti-cheat',
                icon: Icons.camera_alt,
                isComplete: _showSelfie,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 80,
                          color: const Color(0xFFC7C7CC),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Camera Feature Coming Soon',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFC7C7CC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submitCheckIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF3A3A3C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Complete Check-In',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isComplete) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF32D74B)
                  : const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isComplete
                    ? const Color(0xFF32D74B)
                    : const Color(0xFFC7C7CC),
                width: 2,
              ),
            ),
            child: Center(
              child: isComplete
                  ? const Icon(Icons.check, color: Colors.white)
                  : Text(
                      step.toString(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFC7C7CC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFFC7C7CC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isComplete,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFC7C7CC),
                  ),
                ),
              ],
            ),
            if (isComplete)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF32D74B),
                size: 28,
              ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
