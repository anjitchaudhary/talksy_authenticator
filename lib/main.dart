import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _brandColor = Color(0xFF4995DB);

class Profile {
  const Profile({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.avatarUrl = '',
  });

  factory Profile.fromMap(
    Map<String, dynamic> map, {
    String fallbackEmail = '',
  }) {
    return Profile(
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      email: map['email'] as String? ?? fallbackEmail,
      avatarUrl: map['avatar_url'] as String? ?? '',
    );
  }

  final String firstName;
  final String lastName;
  final String email;
  final String avatarUrl;

  String get fullName => '$firstName $lastName'.trim();
}

class CodeSnapshot {
  const CodeSnapshot({required this.code, required this.secondsLeft});

  final String code;
  final double secondsLeft;
}

class ApiGateway {
  ApiGateway._();

  static final ApiGateway instance = ApiGateway._();

  static const _timeout = Duration(seconds: 8);

  SupabaseClient get _client => Supabase.instance.client;

  bool get hasSession => _client.auth.currentSession != null;

  Stream<bool> get sessionChanges => _client.auth.onAuthStateChange
      .map((state) => state.session != null)
      .distinct();

  Future<bool> isEmailRegistered(String email) async {
    final result = await _client.rpc(
      'check_email_exists',
      params: {'email_input': email.trim().toLowerCase()},
    );
    return result == true;
  }

  Future<void> signInWithGoogle(String idToken) async {
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  Future<Profile?> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('first_name, last_name, email, avatar_url')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(_timeout);
      if (row == null) return null;
      return Profile.fromMap(row, fallbackEmail: user.email ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<CodeSnapshot?> currentCode() => _fetchCode('get_my_code');

  Future<CodeSnapshot?> generateCode() => _fetchCode('generate_my_code');

  Future<CodeSnapshot?> _fetchCode(String function) async {
    final rows = await _client.rpc(function).timeout(_timeout) as List;
    if (rows.isEmpty) return null;

    final row = rows.first as Map<String, dynamic>;
    return CodeSnapshot(
      code: row['code'] as String,
      secondsLeft: (row['seconds_left'] as num).toDouble(),
    );
  }
}

class ProfileStore {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Profile read() {
    return Profile(
      firstName: _prefs.getString('first_name') ?? '',
      lastName: _prefs.getString('last_name') ?? '',
      email: _prefs.getString('email') ?? '',
      avatarUrl: _prefs.getString('avatar_url') ?? '',
    );
  }

  static Future<void> write(Profile profile) async {
    await Future.wait([
      _prefs.setString('first_name', profile.firstName),
      _prefs.setString('last_name', profile.lastName),
      _prefs.setString('email', profile.email),
      _prefs.setString('avatar_url', profile.avatarUrl),
    ]);
  }

  static Future<void> clear() => _prefs.clear();
}

Future<Profile?> syncProfile() async {
  final profile = await ApiGateway.instance.fetchProfile();
  if (profile != null) await ProfileStore.write(profile);
  return profile;
}

Future<void> signOutGoogle() async {
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
}

Future<void> clearSession() async {
  final avatarUrl = ProfileStore.read().avatarUrl;
  await Future.wait([signOutGoogle(), ApiGateway.instance.signOut()]);
  if (avatarUrl.isNotEmpty) {
    await CachedNetworkImage.evictFromCache(avatarUrl);
  }
  await ProfileStore.clear();
}

void replaceWith(BuildContext context, Widget screen) {
  Navigator.pushReplacement(
    context,
    CupertinoPageRoute(builder: (_) => screen),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
    await Future.wait([
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
      ProfileStore.init(),
      Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
      ),
      GoogleSignIn.instance.initialize(
        serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
      ),
    ]);
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
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brandColor,
      brightness: brightness,
    ),
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
      home: ApiGateway.instance.hasSession
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _gateway = ApiGateway.instance;
  bool _busy = false;

  void _showError(String message) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colors.onError)),
        backgroundColor: colors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final account = await GoogleSignIn.instance.authenticate();

      if (!await _gateway.isEmailRegistered(account.email)) {
        await signOutGoogle();
        _showError('This email is not registered with Talksy.');
        return;
      }

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        await signOutGoogle();
        _showError('Google did not return a valid token. Please try again.');
        return;
      }

      await _gateway.signInWithGoogle(idToken);
      await syncProfile();

      if (!mounted) return;
      replaceWith(context, const HomeScreen());
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showError('Google sign in failed. Please try again.');
      }
    } catch (_) {
      await clearSession();
      _showError('Sign in failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 36,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Talksy Authenticator',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sign in with the email you used to create your Talksy account.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _busy ? null : _signIn,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const GoogleLogo(size: 22),
                      const SizedBox(width: 12),
                      Text(
                        _busy ? 'Signing in...' : 'Sign in with Google',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Created your account with an email and password? '
                'Sign in with that same email address to get your code for Talksy app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
    final bounds = Rect.fromCircle(
      center: center,
      radius: (size.width - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    void arc(Color color, double start, double sweep) {
      paint.color = color;
      canvas.drawArc(
        bounds,
        start * math.pi / 180,
        sweep * math.pi / 180,
        false,
        paint,
      );
    }

    arc(_red, -150, 105);
    arc(_yellow, 150, 60);
    arc(_green, 45, 105);
    arc(_blue, 0, 45);

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

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.url, this.radius = 20});

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Icon(
        CupertinoIcons.person_fill,
        size: radius,
        color: colors.onPrimaryContainer,
      ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: url.isEmpty
          ? fallback
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
            ),
    );
  }
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
  static const _retryDelay = Duration(seconds: 5);

  final _gateway = ApiGateway.instance;

  late final AnimationController _clock;
  late final Timer _ticker;
  late final StreamSubscription<bool> _sessionWatch;

  Profile _profile = ProfileStore.read();

  _CodeState _state = _CodeState.loading;
  String _code = '';
  DateTime _expiresAt = DateTime.now();
  DateTime _retryAt = DateTime.now();
  int _ticket = 0;
  bool _generating = false;
  bool _loggingOut = false;

  int get _secondsLeft {
    final millis = _expiresAt.difference(DateTime.now()).inMilliseconds;
    return (millis / 1000).ceil().clamp(0, _lifetime);
  }

  bool get _hasValidCode =>
      _state == _CodeState.active && _expiresAt.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _lifetime),
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _sessionWatch = _gateway.sessionChanges.listen((signedIn) {
      if (!signedIn) _leave();
    });
    _refreshProfile();
    _loadCode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionWatch.cancel();
    _ticker.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _loggingOut) return;
    if (_hasValidCode) _syncClock();
    _loadCode();
  }

  Future<void> _refreshProfile() async {
    final profile = await syncProfile();
    if (profile == null || !mounted) return;
    setState(() => _profile = profile);
  }

  void _onTick() {
    if (!mounted || _loggingOut) return;

    if (_state == _CodeState.active) {
      _secondsLeft == 0 ? _showIdle() : setState(() {});
    } else if (_state == _CodeState.offline &&
        DateTime.now().isAfter(_retryAt)) {
      _retryAt = DateTime.now().add(_retryDelay);
      _loadCode();
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
    _retryAt = DateTime.now().add(_retryDelay);
    setState(() {
      _code = '';
      _state = _CodeState.offline;
    });
  }

  void _showCode(CodeSnapshot snapshot, DateTime askedAt) {
    final remaining = snapshot.secondsLeft.clamp(0.0, _lifetime.toDouble());
    if (remaining == 0) {
      _showIdle();
      return;
    }
    setState(() {
      _code = snapshot.code;
      _expiresAt = askedAt.add(
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

  bool _isCurrent(int ticket) => mounted && !_loggingOut && ticket == _ticket;

  Future<void> _loadCode({bool fresh = false}) async {
    if (_loggingOut) return;
    final ticket = ++_ticket;
    final askedAt = DateTime.now();

    try {
      final snapshot = fresh
          ? await _gateway.generateCode()
          : await _gateway.currentCode();
      if (!_isCurrent(ticket)) return;
      snapshot == null ? _showIdle() : _showCode(snapshot, askedAt);
    } catch (_) {
      if (!_isCurrent(ticket)) return;
      _hasValidCode ? _syncClock() : _showOffline();
    }
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    await _loadCode(fresh: true);
    if (mounted) setState(() => _generating = false);
  }

  Future<bool> _confirmLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
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
    return confirmed == true;
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    if (!await _confirmLogout() || !mounted) return;
    await _leave();
  }

  Future<void> _leave() async {
    if (_loggingOut || !mounted) return;
    setState(() => _loggingOut = true);
    _ticker.cancel();

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
              title: const Text(
                'Talksy Authenticator',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              centerTitle: false,
              scrolledUnderElevation: 0,
              actions: [
                IconButton(
                  tooltip: 'Log out',
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                ),
                const SizedBox(width: 4),
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
                        _SectionCard(child: _ProfileRow(profile: _profile)),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Code',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SectionCard(child: _codeContent(theme)),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'This code is valid for 60 seconds and can be used to log in. '
                            'If it expires before you can use it, generate a new one.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
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
          if (_loggingOut)
            ModalBarrier(
              dismissible: false,
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
            ),
          if (_loggingOut)
            Center(
              child: CupertinoActivityIndicator(
                radius: 16,
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _codeContent(ThemeData theme) {
    final colors = theme.colorScheme;

    switch (_state) {
      case _CodeState.loading:
        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      case _CodeState.offline:
        return SizedBox(
          height: 46,
          child: Row(
            children: [
              Icon(
                CupertinoIcons.wifi_slash,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connect to the internet to get code.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      case _CodeState.idle:
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            onPressed: _generating ? null : _generate,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _generating
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text('Generate code'),
          ),
        );
      case _CodeState.active:
        final spaced = _code.length == 6
            ? '${_code.substring(0, 3)} ${_code.substring(3)}'
            : _code;
        return SizedBox(
          height: 46,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  spaced,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: _secondsLeft <= _warnAt
                        ? colors.error
                        : colors.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(
                  painter: _ClockPainter(_clock, colors.primary),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant, width: 0.6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: child,
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = profile.fullName;

    return Row(
      children: [
        Avatar(url: profile.avatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Talksy User' : name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profile.email.isEmpty ? 'No email provided' : profile.email,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.progress, this.color) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress.value * 2 * math.pi,
      true,
      Paint()..color = color,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) => oldDelegate.color != color;
}
