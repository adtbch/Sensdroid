import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';

class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorViewModel>(
      builder: (context, viewModel, child) {
        final colorScheme = Theme.of(context).colorScheme;
        
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(viewModel, colorScheme),
                    const SizedBox(height: 24),
                    _buildSensorGrid(viewModel, colorScheme),
                    const SizedBox(height: 20),
                    _buildSamplingRateInfo(viewModel, colorScheme),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(SensorViewModel viewModel, ColorScheme colorScheme) {
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
                  'Sensors',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select sensors to stream',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${viewModel.enabledSensors.values.where((e) => e).length}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!viewModel.isSensorDetectionComplete)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Detecting available sensors...',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => viewModel.redetectSensors(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Redetect Sensors'),
          ),
      ],
    );
  }

  Widget _buildSensorGrid(SensorViewModel viewModel, ColorScheme colorScheme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: viewModel.enabledSensors.entries.map((entry) {
        final isAvailable = viewModel.availableSensors[entry.key] ?? false;
        return _buildSensorCard(
          viewModel,
          entry.key,
          entry.value,
          isAvailable,
          colorScheme,
        );
      }).toList(),
    );
  }

  Widget _buildSensorCard(
    SensorViewModel viewModel,
    String sensorKey,
    bool isEnabled,
    bool isAvailable,
    ColorScheme colorScheme,
  ) {
    final isDisabled = !isAvailable && viewModel.isSensorDetectionComplete;
    
    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : () => viewModel.toggleSensor(sensorKey, !isEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isEnabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer.withOpacity(0.5),
                    ],
                  )
                : null,
            color: isEnabled ? null : colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isEnabled ? colorScheme.primary : colorScheme.outlineVariant,
              width: isEnabled ? 2.5 : 1,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? colorScheme.primary.withOpacity(0.2)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getSensorIcon(sensorKey),
                      color: isEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                  if (isEnabled)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getSensorDisplayName(sensorKey),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isEnabled ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green : colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAvailable ? 'Available' : 'Not Found',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isAvailable
                              ? (isEnabled
                                  ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                                  : Colors.green)
                              : colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSamplingRateInfo(SensorViewModel viewModel, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Sampling Configuration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sampling Rate',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${viewModel.samplingRate} ms',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Frequency',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    viewModel.samplingRate > 0
                        ? '${(1000 / viewModel.samplingRate).toStringAsFixed(0)} Hz'
                        : '∞ Hz',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSensorIcon(String sensorType) {
    switch (sensorType) {
      case AppConstants.sensorAccelerometer:
        return Icons.open_with_rounded;
      case AppConstants.sensorGyroscope:
        return Icons.threesixty_rounded;
      case AppConstants.sensorMagnetometer:
        return Icons.explore_rounded;
      case AppConstants.sensorGPS:
        return Icons.pin_drop_rounded;
      default:
        return Icons.sensors;
    }
  }

  String _getSensorDisplayName(String sensorType) {
    switch (sensorType) {
      case AppConstants.sensorAccelerometer:
        return 'Accelerometer';
      case AppConstants.sensorGyroscope:
        return 'Gyroscope';
      case AppConstants.sensorMagnetometer:
        return 'Magnetometer';
      case AppConstants.sensorGPS:
        return 'GPS Location';
      default:
        return sensorType;
    }
  }
}
