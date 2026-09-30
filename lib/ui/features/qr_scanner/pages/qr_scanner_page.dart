import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR scanner with a nicer overlay and torch control.
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.scrim,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_scanned) return;
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final raw = barcodes.first.rawValue ?? '';
                if (raw.isEmpty) return;
                _scanned = true;
                Navigator.of(context).pop(raw);
              },
            ),

            // Darkened overlay with transparent square in center
            Center(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final size = constraints.maxWidth * 0.7;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // full screen semi-transparent layer
                      Container(
                        color: scheme.scrim.withAlpha((0.45 * 255).round()),
                      ),
                      // cutout box
                      ClipPath(
                        clipper: _HoleClipper(size: size),
                        child: Container(color: scheme.scrim.withAlpha(0)),
                      ),
                      // border around scan box
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: scheme.onSurface.withAlpha(
                              (0.9 * 255).round(),
                            ),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Top bar with title
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: scheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Scan invite QR',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: scheme.onSurface,
                    ),
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                  ),
                ],
              ),
            ),

            // Instruction text
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: Center(
                child: Text(
                  'Align the household QR inside the box to scan',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withAlpha((0.9 * 255).round()),
                  ),
                ),
              ),
            ),

            // bottom controls
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                    icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                    label: Text(_torchOn ? 'Torch' : 'Torch'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final double size;
  _HoleClipper({required this.size});

  @override
  Path getClip(Size s) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, s.width, s.height));
    final center = Offset(s.width / 2, s.height / 2);
    final hole = Rect.fromCenter(center: center, width: size, height: size);
    path.addRect(hole);
    return Path.combine(PathOperation.difference, path, Path()..addRect(hole));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
