import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ====== حالة الموافقة على الشروط والأحكام ======
  // الزرار (Switch) لازم يكون شغال عشان نفعّل زرار "إنشاء حساب"
  bool _agreedToTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // ====== نتأكد إن كل الحقول سليمة الأول ======
    if (!_formKey.currentState!.validate()) return;

    // ====== حماية إضافية: حتى لو حد لعب في الكود وفعّل الزرار، ما ينفعش يكمل من غير موافقة ======
    if (!_agreedToTerms) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // ====== نحفظ اسم المستخدم على الحساب مباشرة بعد الإنشاء ======
      await credential.user?.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PassengerHomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = AppLocalizations.of(context)!.emailAlreadyInUseError;
          break;
        case 'invalid-email':
          message = AppLocalizations.of(context)!.invalidEmailError;
          break;
        case 'weak-password':
          message = AppLocalizations.of(context)!.weakPasswordError;
          break;
        default:
          message = AppLocalizations.of(
            context,
          )!.registrationFailedError(e.message ?? e.code);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.registrationFailedError(e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Text(
                  loc.createAccountTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: 30),

                // ====== حقل الاسم ======
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    labelText: loc.nameLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return loc.requiredFieldError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ====== حقل الإيميل ======
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    labelText: loc.emailLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return loc.requiredFieldError;
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return loc.invalidEmailError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ====== حقل كلمة السر ======
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    labelText: loc.passwordLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc.requiredFieldError;
                    }
                    if (value.length < 6) {
                      return loc.weakPasswordError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ====== حقل تأكيد كلمة السر ======
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    labelText: loc.confirmPasswordLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return loc.passwordsDoNotMatchError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ====== زرار الموافقة على الشروط والأحكام ======
                // ده هو الجزء المطلوب: Switch بيتحكم في تفعيل زرار "إنشاء حساب"
                Row(
                  children: [
                    Switch(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() => _agreedToTerms = value);
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        // ====== نخلي الضغط على النص نفسه يبدّل حالة الـ Switch كمان ======
                        onTap: () {
                          setState(() => _agreedToTerms = !_agreedToTerms);
                        },
                        child: Text(
                          loc.agreeToTermsText,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textGreyColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ====== زرار إنشاء الحساب ======
                // معطل تماماً (onPressed: null) لحد ما المستخدم يوافق على الشروط
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      disabledBackgroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: (_agreedToTerms && !_isLoading)
                        ? _register
                        : null,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            loc.createAccountButton,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // ====== رابط الرجوع لتسجيل الدخول لو عنده حساب بالفعل ======
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      loc.alreadyHaveAccountLink,
                      style: TextStyle(color: context.textGreyColor),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
