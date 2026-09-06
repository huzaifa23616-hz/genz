import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_screen.dart';
import 'api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool isLoading = false;
  bool obscurePassword = true;

  String? errorMessage;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _handleLogin() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    // ------------------------------------------------------------
    // VALIDATION
    // ------------------------------------------------------------

    if (email.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your email.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your password.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // ==========================================================
      // STEP 1: LOGIN
      // ==========================================================
      //
      // ApiService.login() handles:
      // - Sending email/password
      // - Receiving access token
      // - Receiving refresh token
      // - Saving both tokens
      //

      await ApiService.login(
        email,
        password,
      );

      // ==========================================================
      // STEP 2: GET ACCESS TOKEN
      // ==========================================================

      final String? token = await ApiService.getToken();

      if (token == null || token.trim().isEmpty) {
        throw Exception(
          'Login successful, but no access token was returned.',
        );
      }

      final String cleanToken = token.trim();

      debugPrint('================================');
      debugPrint('LOGIN SUCCESS');
      debugPrint('ACCESS TOKEN FOUND: YES');
      debugPrint('TOKEN LENGTH: ${cleanToken.length}');
      debugPrint('================================');

      // ==========================================================
      // STEP 3: SAVE USER EMAIL
      // ==========================================================

      final SharedPreferences prefs =
      await SharedPreferences.getInstance();

      final bool emailSaved = await prefs.setString(
        'user_email',
        email,
      );

      if (!emailSaved) {
        debugPrint(
          'WARNING: Email could not be saved.',
        );
      }

      // ==========================================================
      // STEP 4: VERIFY ACCESS TOKEN FROM STORAGE
      // ==========================================================
      //
      // IMPORTANT:
      // Your ApiService uses:
      //
      // static const String accessTokenKey = 'access_token';
      //
      // So we use ApiService.accessTokenKey here.
      //

      final String? savedToken =
      prefs.getString(ApiService.accessTokenKey);

      if (savedToken == null ||
          savedToken.trim().isEmpty) {
        throw Exception(
          'Access token was not saved correctly.',
        );
      }

      debugPrint('================================');
      debugPrint('AUTHENTICATION READY');
      debugPrint('ACCESS TOKEN SAVED: YES');
      debugPrint('REFRESH TOKEN HANDLED BY APISERVICE');
      debugPrint('================================');

      // ==========================================================
      // STEP 5: OPEN DASHBOARD
      // ==========================================================

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    } catch (e) {
      debugPrint('================================');
      debugPrint('LOGIN ERROR');
      debugPrint(e.toString());
      debugPrint('================================');

      if (!mounted) return;

      setState(() {
        errorMessage = e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: Column(
              children: [
                // ==================================================
                // LOGO
                // ==================================================

                Container(
                  width: 110,
                  height: 110,

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(25),

                    boxShadow: [
                      BoxShadow(
                        color:
                        Colors.black.withOpacity(.08),
                        blurRadius: 20,
                        offset:
                        const Offset(0, 8),
                      ),
                    ],
                  ),

                  padding:
                  const EdgeInsets.all(15),

                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,

                    errorBuilder: (
                        context,
                        error,
                        stackTrace,
                        ) {
                      return const Icon(
                        Icons.business_rounded,
                        size: 55,
                        color: Color(0xFF087A72),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // TITLE
                // ==================================================

                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF142B2A),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Login to Employee Monitoring',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 35),

                // ==================================================
                // LOGIN CARD
                // ==================================================

                Container(
                  padding:
                  const EdgeInsets.all(22),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius:
                    BorderRadius.circular(24),

                    boxShadow: [
                      BoxShadow(
                        color:
                        Colors.black.withOpacity(.05),
                        blurRadius: 25,
                        offset:
                        const Offset(0, 10),
                      ),
                    ],
                  ),

                  child: Column(
                    children: [
                      // ==========================================
                      // EMAIL
                      // ==========================================

                      TextField(
                        controller:
                        emailController,

                        keyboardType:
                        TextInputType.emailAddress,

                        textInputAction:
                        TextInputAction.next,

                        decoration:
                        InputDecoration(
                          labelText: 'Email',
                          hintText:
                          'Enter your email',

                          prefixIcon:
                          const Icon(
                            Icons.email_outlined,
                          ),

                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),

                          focusedBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),

                            borderSide:
                            const BorderSide(
                              color:
                              Color(0xFF087A72),
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ==========================================
                      // PASSWORD
                      // ==========================================

                      TextField(
                        controller:
                        passwordController,

                        obscureText:
                        obscurePassword,

                        textInputAction:
                        TextInputAction.done,

                        onSubmitted: (_) {
                          if (!isLoading) {
                            _handleLogin();
                          }
                        },

                        decoration:
                        InputDecoration(
                          labelText: 'Password',
                          hintText:
                          'Enter your password',

                          prefixIcon:
                          const Icon(
                            Icons.lock_outline,
                          ),

                          suffixIcon:
                          IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons
                                  .visibility_off
                                  : Icons
                                  .visibility,
                            ),

                            onPressed: () {
                              setState(() {
                                obscurePassword =
                                !obscurePassword;
                              });
                            },
                          ),

                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),

                          focusedBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),

                            borderSide:
                            const BorderSide(
                              color:
                              Color(0xFF087A72),
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      // ==========================================
                      // ERROR MESSAGE
                      // ==========================================

                      if (errorMessage != null) ...[
                        const SizedBox(height: 15),

                        Container(
                          width: double.infinity,

                          padding:
                          const EdgeInsets.all(12),

                          decoration:
                          BoxDecoration(
                            color:
                            Colors.red
                                .withOpacity(.08),

                            borderRadius:
                            BorderRadius.circular(
                              12,
                            ),

                            border:
                            Border.all(
                              color:
                              Colors.red
                                  .withOpacity(.2),
                            ),
                          ),

                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [
                              const Icon(
                                Icons
                                    .error_outline,
                                color: Colors.red,
                                size: 20,
                              ),

                              const SizedBox(width: 8),

                              Expanded(
                                child: Text(
                                  errorMessage!,

                                  style:
                                  const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 25),

                      // ==========================================
                      // LOGIN BUTTON
                      // ==========================================

                      SizedBox(
                        width: double.infinity,
                        height: 52,

                        child:
                        ElevatedButton(
                          onPressed:
                          isLoading
                              ? null
                              : _handleLogin,

                          style:
                          ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(
                              0xFF087A72,
                            ),

                            foregroundColor:
                            Colors.white,

                            disabledBackgroundColor:
                            const Color(
                              0xFF087A72,
                            ).withOpacity(.6),

                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                14,
                              ),
                            ),
                          ),

                          child: isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,

                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                              Colors.white,
                            ),
                          )
                              : const Row(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .center,

                            children: [
                              Icon(
                                Icons
                                    .login_rounded,
                              ),

                              SizedBox(width: 8),

                              Text(
                                'LOGIN',

                                style:
                                TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight
                                      .w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // FOOTER
                // ==================================================

                Text(
                  'Secure Workforce Management',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
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