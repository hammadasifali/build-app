import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bonanza Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  List<String> portraitGames = [];

  @override
  void initState() {
    super.initState();
    _preloadDataAndNavigateToHome();
  }

  Future<void> _preloadDataAndNavigateToHome() async {
    await _fetchPortraitGames();
    await Future.delayed(
      const Duration(
        seconds: 3,
      ),
    );
    Navigator.pushReplacement(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(
        builder: (context) => const PreviewWebpage(),
      ),
    );
  }

  Future<void> _fetchPortraitGames() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    portraitGames = prefs.getStringList('portraitGames') ?? [];

    if (portraitGames.isEmpty) {
      final response =
          await http.get(Uri.parse('https://vegasmania.app/portrait'));
      if (response.statusCode == 200) {
        setState(() {
          portraitGames = List<String>.from(jsonDecode(response.body)['games']);
          prefs.setStringList('portraitGames', portraitGames);
        });
      } else {
        throw Exception('Failed to fetch portrait games');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.purpleAccent,
          ),
        ),
      ),
    );
  }
}

class PreviewWebpage extends StatefulWidget {
  const PreviewWebpage({super.key});

  @override
  State<PreviewWebpage> createState() => _PreviewWebpageState();
}

class _PreviewWebpageState extends State<PreviewWebpage>
    with WidgetsBindingObserver {
  late WebViewController _controller;
  final String initialUrl = 'https://bonanzagames.app';
  List<String> portraitGames = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Only set the platform for Android
    if (Platform.isAndroid) {
      WebView.platform = SurfaceAndroidWebView();
    }

    WidgetsBinding.instance.addObserver(this);
    _lockOrientationBasedOnUrl(initialUrl);
    _fetchPortraitGames();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _allowScreenSleep();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _pauseWebView();
        break;
      case AppLifecycleState.resumed:
        _resumeWebView();
        _preventScreenSleep();
        break;
      default:
        break;
    }
  }

  Future<void> _lockOrientationBasedOnUrl(String url) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedOrientation = prefs.getString('orientation');

    if (cachedOrientation == null || !_isPortraitGame(url)) {
      if (_isPortraitGame(url)) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        prefs.setString('orientation', 'portrait');
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        prefs.setString('orientation', 'landscape');
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  bool _isPortraitGame(String url) {
    return portraitGames.any((game) => url.contains(game));
  }

  void _preventScreenSleep() {
    WakelockPlus.enable();
  }

  void _allowScreenSleep() {
    WakelockPlus.disable();
  }

  void _pauseWebView() {
    if (_controller != null) {
      _controller.runJavascript("document.querySelector('video').pause();");
    }
  }

  void _resumeWebView() {
    if (_controller != null) {
      _controller.runJavascript("document.querySelector('video').play();");
    }
  }

  void _onPageFinished(String url) {
    setState(() {
      _isLoading = false;
    });
    _lockOrientationBasedOnUrl(url);
  }

  void _onPageStarted(String url) {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });
  }

  void _onWebResourceError(WebResourceError error) {
    setState(() {
      _isError = true;
      _isLoading = false;

      if (error.errorType == WebResourceErrorType.connect) {
        _errorMessage = 'No internet connection. Please check your connection.';
      } else if (error.errorType == WebResourceErrorType.hostLookup) {
        _errorMessage = 'The website is currently under maintenance.';
      } else {
        _errorMessage = 'We are working on it. Please wait.';
      }

      Future.delayed(const Duration(seconds: 3), () {
        _controller.reload();
      });
    });
  }

  Future<void> _fetchPortraitGames() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    portraitGames = prefs.getStringList('portraitGames') ?? [];

    if (portraitGames.isEmpty) {
      final response =
          await http.get(Uri.parse('https://vegasmania.app/portrait'));
      if (response.statusCode == 200) {
        setState(() {
          portraitGames = List<String>.from(jsonDecode(response.body)['games']);
          prefs.setStringList('portraitGames', portraitGames);
        });
      } else {
        throw Exception('Failed to fetch portrait games');
      }
    }
  }

  Future<void> _showExitConfirmation() async {
    bool shouldExit = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      SystemNavigator.pop(); // Close the app
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        await _showExitConfirmation();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            _isError
                ? _buildErrorPage()
                : WebView(
                    initialUrl: initialUrl,
                    javascriptMode: JavascriptMode.unrestricted,
                    onWebViewCreated: (WebViewController webViewController) {
                      _controller = webViewController;
                      _controller.loadUrl(initialUrl);
                    },
                    onPageStarted: _onPageStarted,
                    onPageFinished: _onPageFinished,
                    onWebResourceError: _onWebResourceError,
                    gestureNavigationEnabled: !_isLoading,
                    allowsInlineMediaPlayback: true,
                  ),
            if (_isLoading && !_isError)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (_isLoading && !_isError)
              const Positioned.fill(
                child: AbsorbPointer(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 100),
          const SizedBox(height: 20),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.redAccent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _isError = false;
                _controller.reload();
              });
            },
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 18,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
