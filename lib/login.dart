import 'dart:convert';
import 'package:blankmap_mobile/main.dart';
import 'package:blankmap_mobile/shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  final storage = const FlutterSecureStorage();

  bool loading = false;
  bool isRegister = false;
  bool checkingAuth = true;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(_fade);

    _anim.forward();

    checkLogin();
  }

  Future<void> checkLogin() async {
    final token = await storage.read(key: "jwt");

    print("CHECKING STORED TOKEN: $token");

    if (token != null) {
      print("JWT FOUND -> AUTO LOGIN");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => const MainNav(username: "User")),
      );
    }

    setState(() => checkingAuth = false);
  }

  @override
  void dispose() {
    _anim.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    final name = nameCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) return;

    setState(() => loading = true);

    try {
      if (isRegister) {
        print("REGISTER REQUEST");

        final res = await http.post(
          Uri.parse("$baseUrl/auth/register"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": email, "name": name, "password": pass}),
        );

        print("REGISTER STATUS: ${res.statusCode}");
        print("REGISTER BODY: ${res.body}");

        if (res.statusCode == 409) {
          showError("Email already exists");
          setState(() => loading = false);
          return;
        }

        if (res.statusCode != 200 && res.statusCode != 201) {
          showError("Registration failed");
          setState(() => loading = false);
          return;
        }
      }

      print("LOGIN REQUEST");

      final res = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": pass}),
      );

      print("LOGIN STATUS: ${res.statusCode}");
      print("LOGIN BODY: ${res.body}");

      if (res.statusCode != 200) {
        showError("Invalid email or password");
        setState(() => loading = false);
        return;
      }

      final data = jsonDecode(res.body);
      final token = data["token"];

      print("JWT RECEIVED: $token");

      await storage.write(key: "jwt", value: token);

      print("JWT SAVED");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => MainNav(username: email)),
      );
    } catch (e, s) {
      print("AUTH ERROR: $e");
      print(s);
      showError("Network error");
    }

    setState(() => loading = false);
  }

  void toggleMode() {
    setState(() {
      isRegister = !isRegister;
    });
  }

  void showError(String msg) {
    print("UI ERROR: $msg");

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checkingAuth) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: BM.bg,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: BM.accentSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: BM.accent.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.layers_alt,
                      color: BM.accent,
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'BlankMap.',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: BM.textPri,
                      letterSpacing: -2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Your city. Uncensored.',
                    style: TextStyle(fontSize: 18, color: BM.textSec),
                  ),

                  const Spacer(flex: 2),

                  if (isRegister) ...[
                    CupertinoTextField(
                      controller: nameCtrl,
                      placeholder: 'Name',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  CupertinoTextField(
                    controller: emailCtrl,
                    placeholder: 'Email',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),

                  const SizedBox(height: 14),

                  CupertinoTextField(
                    controller: passCtrl,
                    placeholder: 'Password',
                    obscureText: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: loading ? null : submit,
                      child: loading
                          ? const CupertinoActivityIndicator()
                          : Text(isRegister ? "Create Account" : "Login"),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: toggleMode,
                      child: Text(
                        isRegister
                            ? "Already have an account? Login"
                            : "Create an account",
                        style: const TextStyle(color: BM.accent),
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
