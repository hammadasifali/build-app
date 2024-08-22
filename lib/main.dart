import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:ui'; // Required for ImageFilter.blur

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vegas Mania',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(Duration(seconds: 3), () {});
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PreviewWebpage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
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

class _PreviewWebpageState extends State<PreviewWebpage> with WidgetsBindingObserver {
  late WebViewController _controller;
  final String initialUrl = 'https://bonanza777.app';
  List<String> portraitGames = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockOrientationBasedOnUrl(initialUrl);
    _fetchPortraitGames();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _allowScreenSleep();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState: $state');

    switch (state) {
      case AppLifecycleState.paused:
        print('App is paused');
        _pauseWebView();
        break;
      case AppLifecycleState.resumed:
        print('App is resumed');
        _resumeWebView();
        _preventScreenSleep();
        break;
      case AppLifecycleState.detached:
        print('App is detached');
        break;
      case AppLifecycleState.inactive:
        print('App is inactive');
        break;
      default:
        print('AppLifecycleState: $state');
        break;
    }
  }

  void _lockOrientationBasedOnUrl(String url) {
    if (_isPortraitGame(url)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
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

  Future<void> _showExitConfirmation() async {
    bool shouldExit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exit App'),
        content: Text('Are you sure you want to exit the app?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Yes'),
          ),
        ],
      ),
    ) ?? false;

    if (shouldExit) {
      SystemNavigator.pop();
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
      _isError = false; // Reset error state on page load
      _errorMessage = ''; // Clear any previous error message
    });
  }

  void _onWebResourceError(WebResourceError error) {
    setState(() {
      _isError = true; // Set error state to true on error
      _isLoading = false; // Stop the loader if an error occurs

      // Determine the type of error and set an appropriate message
      if (error.errorType == WebResourceErrorType.connect) {
        _errorMessage = 'No internet connection. Please check your connection.';
      } else if (error.errorType == WebResourceErrorType.hostLookup) {
        _errorMessage = 'The website is currently under maintenance.';
      } else {
        _errorMessage = 'We are working on it. Please wait.';
      }
    });
  }

  Future<void> _fetchPortraitGames() async {
    final response = await http.get(Uri.parse('https://vegasmania.app/portrait'));
    if (response.statusCode == 200) {
      setState(() {
        portraitGames = List<String>.from(jsonDecode(response.body)['games']);
        print("this is ");
        print(portraitGames);
      });
    } else {
      throw Exception('Failed to fetch portrait games');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _showExitConfirmation();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            _isError
                ? _buildErrorPage() // Display error page if there's an error
                : WebView(
              initialUrl: initialUrl,
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController webViewController) {
                _controller = webViewController;
              },
              onPageStarted: _onPageStarted,
              onPageFinished: _onPageFinished,
              onWebResourceError: _onWebResourceError, // Handle errors
              gestureNavigationEnabled: !_isLoading, // Disable gestures when loading
              allowsInlineMediaPlayback: true,
            ),
            if (_isLoading && !_isError)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Center(
                  child: CustomPreloader(), // Custom Preloader Widget
                ),
              ),
            if (_isLoading && !_isError)
              Positioned.fill(
                child: AbsorbPointer(), // Disable all interactions
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
          Icon(Icons.error, color: Colors.red, size: 100),
          SizedBox(height: 20),
          Text(
            _errorMessage, // Display the specific error message
            style: TextStyle(
              fontSize: 24,
              color: Colors.redAccent,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _isError = false;
                _controller.reload(); // Retry loading the page
              });
            },
            child: Text(
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

class CustomPreloader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/loader.gif', // Example of a custom loader image (GIF, PNG, etc.)
            width: 100,
            height: 100,
          ),
          SizedBox(height: 20), // Adjust the height as needed
        ],
      ),
    );
  }
}
