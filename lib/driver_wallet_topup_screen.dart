import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart' show TayarColors, TayarThemeColors;
import 'wallet_service.dart';

// ====================================================
// ====== شاشة شحن رصيد محفظة الطيار ======
// الطيار بيحوّل المبلغ إنستاباي بنفسه (خارج التطبيق)، وبيرفع صورة
// إيصال التحويل هنا كإثبات. الطلب بيتحفظ بحالة "pending" وبيتراجع
// يدويًا من Firebase Console لحد ما تتعمل شاشة الأدمن ======
// ====================================================
class DriverWalletTopupScreen extends StatefulWidget {
  const DriverWalletTopupScreen({super.key});

  @override
  State<DriverWalletTopupScreen> createState() =>
      _DriverWalletTopupScreenState();
}

class _DriverWalletTopupScreenState extends State<DriverWalletTopupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  Uint8List? _proofBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _proofBytes = bytes);
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_proofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.topUpProofRequiredError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);
    try {
      final amount = double.parse(_amountController.text.trim());
      await submitWalletTopupRequest(
        driverId: uid,
        amount: amount,
        proofBase64: base64Encode(_proofBytes!),
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: context.cardColor,
          title: Text(
            loc.topUpSubmittedTitle,
            style: TextStyle(color: context.textColor),
          ),
          content: Text(
            loc.topUpSubmittedBody,
            style: TextStyle(color: context.textGreyColor),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // يقفل الـ dialog
                Navigator.of(context).pop(); // يرجع لشاشة المحفظة
              },
              child: Text(loc.confirmButton),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        title: Text(
          loc.topUpWalletTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Text(
                  loc.topUpWalletSubtitle,
                  style: TextStyle(color: context.textGreyColor, height: 1.5),
                ),
                const SizedBox(height: 24),

                // ====== حقل المبلغ ======
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    labelText: loc.topUpAmountLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    final amount = double.tryParse((value ?? '').trim());
                    if (amount == null || amount <= 0) {
                      return loc.invalidAmountError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ====== رفع صورة الإيصال ======
                Text(
                  loc.topUpProofLabel,
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickProof,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.dividerColor2),
                    ),
                    child: _proofBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: context.textGreyColor,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                loc.topUpProofLabel,
                                style: TextStyle(
                                  color: context.textGreyColor,
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              _proofBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 180,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),

                // ====== زرار الإرسال ======
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TayarColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: context.onPrimaryColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            loc.topUpSubmitButton,
                            style: TextStyle(
                              color: context.onPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
