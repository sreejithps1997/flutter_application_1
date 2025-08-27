import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SelfieCameraScreen extends StatefulWidget {
  const SelfieCameraScreen({super.key});

  @override
  State<SelfieCameraScreen> createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends State<SelfieCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _init();
  }

  Future<void> _init() async {
    final cams = await availableCameras();
    // Prefer front camera
    CameraDescription cam = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );

    final controller = CameraController(
      cam,
      ResolutionPreset.low, // ↓ small to avoid buffer pressure
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // stable on most OEMs
    );

    _controller = controller;
    await controller.initialize();
    // lock exposure/white-balance auto—leave defaults, avoids extra work
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initFuture = _init();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_taking) return;
    _taking = true;
    setState(() {});
    try {
      final c = _controller!;
      if (!c.value.isInitialized) return;

      final XFile file = await c.takePicture(); // already jpeg
      if (!mounted) return;
      Navigator.of(context).pop(File(file.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    } finally {
      _taking = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!(_controller?.value.isInitialized ?? false)) {
            return const Center(
              child: Text(
                'Camera failed to initialize',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return Stack(
            children: [
              Center(child: CameraPreview(_controller!)),
              Positioned(
                left: 16,
                top: 48,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton(
                    onPressed: _taking ? null : _capture,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                    ),
                    child: const Icon(Icons.camera_alt, size: 28),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
