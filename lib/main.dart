import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:developer' as developer;

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static const customSwatch = MaterialColor(
    0xFFFF5252,
    <int, Color>{
      50: Color(0xFFFFEBEE),
      100: Color(0xFFFFCDD2),
      200: Color(0xFFEF9A9A),
      300: Color(0xFFE57373),
      400: Color(0xFFEF5350),
      500: Color(0xFFFF5252),
      600: Color(0xFFE53935),
      700: Color(0xFFD32F2F),
      800: Color(0xFFC62828),
      900: Color(0xFFB71C1C),
    },
  );

  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: customSwatch,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  MobileScannerController cameraController = MobileScannerController();
  bool _screenOpened = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('initstate______initstate');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ticket qr code scanner'), actions: [
        IconButton(
            color: Colors.white,
            iconSize: 32.0,
            onPressed: () => cameraController.toggleTorch(),
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(
                      Icons.flash_off,
                      color: Colors.grey,
                    );
                  case TorchState.on:
                    return const Icon(
                      Icons.flash_on,
                      color: Colors.yellow,
                    );
                }
              },
            )),
        IconButton(
            color: Colors.white,
            iconSize: 32.0,
            onPressed: () => cameraController.switchCamera(),
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ))
      ]),
      body: MobileScanner(
        onDetect: _foundBarCode,
        controller: cameraController,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    switch (state) {
      case AppLifecycleState.paused:
        cameraController.stop();
        break;
      case AppLifecycleState.resumed:
        // debugPrint('resumed____cameracontroller');
        cameraController.start();
        break;
      case AppLifecycleState.inactive:
        // TODO: Handle this case.
        break;
      case AppLifecycleState.detached:
        // TODO: Handle this case.
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    cameraController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _foundBarCode(BarcodeCapture barcode) {
    cameraController.stop();
    final db = FirebaseFirestore.instance;
    final qrRef = db.collection('qr');
    String status = "none";
    String code = "";
    //open screen
    if (!_screenOpened) {
      Iterable<Barcode> barcodes = barcode.barcodes;
      for (Barcode bar_code in barcodes) {
        code = bar_code.rawValue ?? "---";
      }
      debugPrint('barcode found! $code');
      db
          .collection('qr')
          .where('uuid', isEqualTo: code)
          .get()
          .then((querySnapshot) {
        if (querySnapshot.size > 0) {
          var doc = querySnapshot.docs[0];
          var data = doc.data();
          // debugPrint('${data}');
          if (data['status'] == 'initialized') {
            doc.reference.update({'status': 'checked'});
            code = '${doc['type']} ${doc['place']}';
            status = 'success';
          } else {
            code = '${doc['type']} ${doc['place']}';
            status = 'fail';
          }
        } else {
          code = 'inexistant';
          status = 'invalid';
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoundCodeScreen(
                screenClosed: _screenWasClosed, value: code, status: status),
          ),
        );
      });
    }
  }

  void _screenWasClosed() {
    _screenOpened = false;
  }
}

class FoundCodeScreen extends StatefulWidget {
  final String value;
  final String status;
  final Function() screenClosed;

  const FoundCodeScreen(
      {Key? key,
      required this.value,
      required this.status,
      required this.screenClosed})
      : super(key: key);

  @override
  State<FoundCodeScreen> createState() => _FoundCodeScreenState();
}

class _FoundCodeScreenState extends State<FoundCodeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status'),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            widget.screenClosed();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_outlined),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Icon(
                  widget.status == 'success'
                      ? Icons.task_alt
                      : widget.status == 'fail'
                          ? Icons.warning
                          : Icons.cancel,
                  color: widget.status == 'success'
                      ? Colors.green
                      : widget.status == 'fail'
                          ? Colors.deepOrange
                          : Colors.red,
                  size: 300.0,
                ),
              ),
              Text(
                widget.status == 'success'
                    ? "\"${widget.value}\" CHECKED"
                    : widget.status == 'fail'
                        ? "\"${widget.value}\" ALREADY CHECKED"
                        : "NONE",
                style: const TextStyle(
                  fontSize: 25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
