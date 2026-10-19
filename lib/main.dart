import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

const _lightBlue = Color.fromARGB(255, 73, 149, 219);

void replaceWith(BuildContext context, Widget screen) {
  Navigator.pushReplacement(
    context,
    CupertinoPageRoute(builder: (_) => screen),
  );
}

Future<Map<String, dynamic>?> fetchProfile() async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('first_name', profile['first_name'] ?? '');
    await prefs.setString('last_name', profile['last_name'] ?? '');
    await prefs.setString('email', profile['email'] ?? user.email ?? '');
    await prefs.setString('avatar_url', profile['avatar_url'] ?? '');
    return profile;
  } catch (_) {
    return null;
  }
}

Future<void> signOutGoogle() async {
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
}

Future<void> clearSession() async {
  await signOutGoogle();
  try {
    await supabase.auth.signOut();
  } catch (_) {}
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
    );
    await GoogleSignIn.instance.initialize(
      serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    );
    runApp(const MainApp());
  } catch (e, st) {
    debugPrint('Startup error: $e\n$st');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Startup error:\n$e'),
            ),
          ),
        ),
      ),
    );
  }
}

SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
  final iconBrightness = brightness == Brightness.light
      ? Brightness.dark
      : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarContrastEnforced: false,
  );
}

ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    ),
    useMaterial3: true,
    appBarTheme: AppBarTheme(systemOverlayStyle: overlayStyleFor(brightness)),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Talksy Authenticator',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyleFor(Theme.of(context).brightness),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 0.92,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

  late final Animation<double> _fadeAnimation = Tween<double>(
    begin: 0.75,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    try {
      final session = supabase.auth.currentSession;
      if (!mounted) return;
      replaceWith(
        context,
        session != null ? const HomeScreen() : const LoginScreen(),
      );
    } catch (_) {
      if (!mounted) return;
      replaceWith(context, const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 52,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Talksy Authenticator',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      color: colors.primary,
                      backgroundColor: colors.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final googleUser = await GoogleSignIn.instance.authenticate();

      final response = await supabase.rpc(
        'check_email_exists',
        params: {'email_input': googleUser.email.trim().toLowerCase()},
      );

      if (response != true) {
        await signOutGoogle();
        _showError('This email is not registered.');
        return;
      }

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('Missing Google ID token');
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      await fetchProfile();

      if (!mounted) return;
      replaceWith(context, const HomeScreen());
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showError('Google sign in failed. Please try again.');
      }
    } catch (_) {
      await signOutGoogle();
      _showError('Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: 0.35,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              size: 60,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Welcome to Talksy Authenticator',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sign in with your registered particular email which you have used to create your Talksy account.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: colors.surface,
                                side: BorderSide(
                                  color: colors.outlineVariant,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _isLoading
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: colors.primary,
                                          ),
                                        )
                                      : const GoogleLogo(size: 22),
                                  const SizedBox(width: 14),
                                  Text(
                                    _isLoading
                                        ? 'Signing in...'
                                        : 'Sign in with Google',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: colors.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'If you have already created your account with a email address and password, '
                            'sign in with that same email address to access your code.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.85,
                              ),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final center = size.center(Offset.zero);
    final arcBounds = Rect.fromCircle(
      center: center,
      radius: (size.width - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    void drawArc(Color color, double startDegrees, double sweepDegrees) {
      paint.color = color;
      canvas.drawArc(
        arcBounds,
        startDegrees * math.pi / 180,
        sweepDegrees * math.pi / 180,
        false,
        paint,
      );
    }

    drawArc(_red, -150, 105);
    drawArc(_yellow, 150, 60);
    drawArc(_green, 45, 105);
    drawArc(_blue, 0, 45);

    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - stroke / 2,
        size.width,
        center.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _CodeState { loading, offline, idle, active }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _lifetime = 60;
  static const _warnAt = 10;
  static const _getCodeRpc = 'get_my_code';
  static const _generateCodeRpc = 'generate_my_code';

  late final AnimationController _clock;
  Timer? _ticker;

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _avatarUrl = '';
  bool _profileLoading = true;

  _CodeState _state = _CodeState.loading;
  String _code = '';
  DateTime _expiresAt = DateTime.now();
  DateTime _retryAt = DateTime.now();
  bool _requesting = false;
  bool _generating = false;
  bool _loggingOut = false;

  String get _name => '$_firstName $_lastName'.trim();

  int get _secondsLeft {
    final millis = _expiresAt.difference(DateTime.now()).inMilliseconds;
    return (millis / 1000).ceil().clamp(0, _lifetime);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _lifetime),
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _loadProfile();
    _requestCode(_getCodeRpc);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_hasValidCode) _syncClock();
    _requestCode(_getCodeRpc);
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _firstName = prefs.getString('first_name') ?? '';
      _lastName = prefs.getString('last_name') ?? '';
      _email =
          prefs.getString('email') ?? supabase.auth.currentUser?.email ?? '';
      _avatarUrl = prefs.getString('avatar_url') ?? '';
      _profileLoading = false;
    });

    final profile = await fetchProfile();
    if (!mounted || profile == null) return;
    setState(() {
      _firstName = profile['first_name'] ?? _firstName;
      _lastName = profile['last_name'] ?? _lastName;
      _email = profile['email'] ?? _email;
      _avatarUrl = profile['avatar_url'] ?? _avatarUrl;
    });
  }

  void _onTick() {
    if (!mounted) return;

    if (_state == _CodeState.active) {
      if (_secondsLeft == 0) {
        _showIdle();
      } else {
        setState(() {});
      }
    } else if (_state == _CodeState.offline &&
        DateTime.now().isAfter(_retryAt)) {
      _requestCode(_getCodeRpc);
    }
  }

  void _showIdle() {
    _clock.reset();
    setState(() {
      _code = '';
      _state = _CodeState.idle;
    });
  }

  void _showOffline() {
    _clock.reset();
    _retryAt = DateTime.now().add(const Duration(seconds: 5));
    setState(() {
      _code = '';
      _state = _CodeState.offline;
    });
  }

  void _showCode(String code, double secondsLeft, DateTime requestedAt) {
    final remaining = secondsLeft.clamp(0.0, _lifetime.toDouble());
    if (remaining == 0) {
      _showIdle();
      return;
    }
    setState(() {
      _code = code;
      _expiresAt = requestedAt.add(
        Duration(milliseconds: (remaining * 1000).round()),
      );
      _state = _CodeState.active;
    });
    _syncClock();
  }

  void _syncClock() {
    final millisLeft = _expiresAt.difference(DateTime.now()).inMilliseconds;
    final elapsed = (_lifetime * 1000 - millisLeft) / (_lifetime * 1000);
    _clock.forward(from: elapsed.clamp(0.0, 1.0));
  }

  bool get _hasValidCode =>
      _state == _CodeState.active && _expiresAt.isAfter(DateTime.now());

  Future<void> _requestCode(String function) async {
    if (_requesting || _loggingOut) return;
    _requesting = true;

    try {
      final requestedAt = DateTime.now();
      final rows =
          await supabase.rpc(function).timeout(const Duration(seconds: 8))
              as List;
      if (!mounted || _loggingOut) return;

      if (rows.isEmpty) {
        _showIdle();
        return;
      }

      final row = rows.first as Map<String, dynamic>;
      _showCode(
        row['code'] as String,
        (row['seconds_left'] as num).toDouble(),
        requestedAt,
      );
    } catch (_) {
      if (mounted && !_loggingOut) {
        if (_hasValidCode) {
          _syncClock();
        } else {
          _showOffline();
        }
      }
    } finally {
      _requesting = false;
    }
  }

  Future<void> _generateCode() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      await _requestCode(_generateCodeRpc);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<bool?> _confirmLogout() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await _confirmLogout();
    if (confirmed != true || !mounted) return;

    _ticker?.cancel();
    setState(() => _loggingOut = true);

    await clearSession();

    if (!mounted) return;
    replaceWith(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: !_loggingOut,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            appBar: AppBar(
              toolbarHeight: 44,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: const Text(
                'Talksy Authenticator',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton.filledTonal(
                    tooltip: 'Log out',
                    onPressed: _logout,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.errorContainer.withValues(
                        alpha: 0.6,
                      ),
                      foregroundColor: colors.onErrorContainer,
                      fixedSize: const Size(36, 36),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _card(
                          theme,
                          _profileLoading
                              ? _profileSkeleton(theme)
                              : _profile(theme),
                        ),
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _card(theme, _codeContent(theme)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              'This code will only be valid for 60 seconds and can be used for login. If you are unable to use the code within this time frame, you can generate a new one.',
                              textAlign: TextAlign.justify,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: theme.hintColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loggingOut) _logoutOverlay(theme),
        ],
      ),
    );
  }

  Widget _logoutOverlay(ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          dismissible: false,
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
        ),
        Center(
          child: CupertinoActivityIndicator(
            radius: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _card(ThemeData theme, Widget child) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: child,
        ),
      ),
    );
  }

  Widget _profile(ThemeData theme) {
    final hasAvatar = _avatarUrl.isNotEmpty;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: hasAvatar ? NetworkImage(_avatarUrl) : null,
          onBackgroundImageError: hasAvatar ? (_, _) {} : null,
          child: hasAvatar
              ? null
              : Icon(
                  CupertinoIcons.person_fill,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name.isEmpty ? 'Talksy User' : _name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _email.isEmpty ? 'No email provided' : _email,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileSkeleton(ThemeData theme) {
    final color = theme.dividerColor.withValues(alpha: 0.15);

    Widget bar(double width, double height) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [bar(120, 14), const SizedBox(height: 6), bar(180, 11)],
        ),
      ],
    );
  }

  Widget _codeContent(ThemeData theme) {
    switch (_state) {
      case _CodeState.loading:
        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: theme.dividerColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      case _CodeState.offline:
        return SizedBox(
          height: 46,
          child: Row(
            children: [
              Icon(CupertinoIcons.wifi_slash, size: 18, color: theme.hintColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connect to internet to see code',
                  style: TextStyle(fontSize: 14, color: theme.hintColor),
                ),
              ),
            ],
          ),
        );
      case _CodeState.idle:
        return _generateButton();
      case _CodeState.active:
        return _activeCode(theme);
    }
  }

  Widget _generateButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton(
        onPressed: _generating ? null : _generateCode,
        style: FilledButton.styleFrom(
          backgroundColor: _lightBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _lightBlue.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: _generating
            ? const CupertinoActivityIndicator(color: Colors.white)
            : const Text('Generate code'),
      ),
    );
  }

  Widget _activeCode(ThemeData theme) {
    final expiring = _secondsLeft <= _warnAt;
    final text = _code.length == 6
        ? '${_code.substring(0, 3)} ${_code.substring(3)}'
        : _code;

    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: expiring
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(painter: _ClockPainter(_clock)),
          ),
        ],
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;

    final fill = Paint()..color = _lightBlue;
    final border = Paint()
      ..color = _lightBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress.value * 2 * math.pi,
      true,
      fill,
    );
    canvas.drawCircle(center, radius, border);
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) => false;
}
