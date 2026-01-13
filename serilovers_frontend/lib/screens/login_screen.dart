import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // Add password visibility toggle

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
        platform: 'desktop', // Desktop application
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Check if user is admin (desktop only)
        final screenWidth = MediaQuery.of(context).size.width;
        if (screenWidth >= 900) {
          // Desktop layout - check admin role
          final token = authProvider.token;
          if (token != null && token.isNotEmpty) {
            try {
              final decodedToken = JwtDecoder.decode(token);
                  
                  // Debug: Print all token claims
                  print('🔑 All token claims: ${decodedToken.keys.toList()}');
                  
                  // Check for Admin role in token
                  bool isAdmin = false;
                  
                  // Method 1: Check "roles" claim (JSON array string)
                  final rolesJson = decodedToken['roles'];
                  if (rolesJson != null && rolesJson is String) {
                    print('🔍 Found roles JSON: $rolesJson');
                    try {
                      final rolesList = (jsonDecode(rolesJson) as List).map((e) => e.toString()).toList();
                      print('🔍 Parsed roles list: $rolesList');
                      if (rolesList.contains('Admin')) {
                        isAdmin = true;
                        print('✅ Found Admin in roles JSON array');
                      }
                    } catch (e) {
                      print('❌ Error parsing roles JSON: $e');
                    }
                  }
                  
                  // Method 2: Check "role" claim (first role for backward compatibility)
                  if (!isAdmin) {
                    final roleClaim = decodedToken['role'];
                    print('🔍 Standard role claim: $roleClaim');
                    if (roleClaim is String && roleClaim == 'Admin') {
                      isAdmin = true;
                      print('✅ Found Admin in standard role claim');
                    }
                  }
                  
                  // Method 3: Check all keys that might contain role information
                  if (!isAdmin) {
                    for (var key in decodedToken.keys) {
                      final keyStr = key.toString().toLowerCase();
                      if (keyStr.contains('role') && keyStr != 'roles') {
                        final roleValue = decodedToken[key];
                        print('🔍 Found role key: $key = $roleValue');
                        if (roleValue is String && roleValue == 'Admin') {
                          isAdmin = true;
                          print('✅ Found Admin role as String');
                          break;
                        } else if (roleValue is List && roleValue.contains('Admin')) {
                          isAdmin = true;
                          print('✅ Found Admin role in List');
                          break;
                        }
                      }
                    }
                  }
                  
                  // Method 4: Check all values in the token for "Admin" string
                  if (!isAdmin) {
                    for (var value in decodedToken.values) {
                      if (value is String && value == 'Admin') {
                        isAdmin = true;
                        print('✅ Found Admin in token values');
                        break;
                      } else if (value is List && value.contains('Admin')) {
                        isAdmin = true;
                        print('✅ Found Admin in token list values');
                        break;
                      }
                    }
                  }
                  
                  print('👤 Final isAdmin check: $isAdmin');
              
                  if (!isAdmin) {
                // Non-admin user - deny access
                    print('❌ User is not Admin, denying access');
                await authProvider.logout();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Access Forbidden – Admins only'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
                return;
              }
              
              // Admin user - navigate to admin panel
                  print('✅ User is Admin, navigating to admin panel');
                  if (mounted) {
              Navigator.pushReplacementNamed(context, '/admin');
                  }
            } catch (e) {
              // Error decoding token - deny access
              await authProvider.logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error decoding token: $e'),
                    backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                  ),
                );
              }
              return;
            }
          } else {
            // No token - deny access
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access Forbidden – Admins only'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        } else {
          // Mobile layout - navigate to mobile screen
          Navigator.pushReplacementNamed(context, '/mobile');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please check your credentials.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false, // No back button on login screen
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 400 : double.infinity,
            ),
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Admin welcome message for desktop
                  if (isDesktop) ...[
                    const Text(
                      'Welcome, Admin. Please log in to manage the SeriLovers platform.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

