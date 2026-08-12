import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/screens/passenger/select_destination_screen.dart'
    show SelectDestinationScreen, PlaceResult;
import 'package:tayay_app/widgets/pin_marker.dart' show PinType;
import 'package:tayay_app/services/vendor_service.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

/// ====== شاشة فورم "عايز تبقى شريك تجاري معانا؟" ======
/// فورم خفيف بخمس حقول: اسم المحل، نوع النشاط (Dropdown)، رقم موبايل/واتساب،
/// الموقع (اختيار من البحث أو من الخريطة عبر SelectDestinationScreen اللي
/// بيستخدم PickOnMapScreen جواه)، وملاحظة اختيارية. بترسل عبر
/// submitVendorApplication في vendor_service.dart، والحالة دايمًا 'pending'
/// لحد ما الأدمن يراجعها من تاب "Vendor Requests".
class BecomeVendorScreen extends StatefulWidget {
  const BecomeVendorScreen({super.key});

  @override
  State<BecomeVendorScreen> createState() => _BecomeVendorScreenState();
}

class _BecomeVendorScreenState extends State<BecomeVendorScreen> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _businessType = kVendorBusinessTypes.first;
  LatLng? _location;
  String? _locationAddress;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _storeNameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _location != null &&
      !_isSubmitting;

  Future<void> _pickLocation() async {
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDestinationScreen(
          initialLocation: _location,
          title: AppLocalizations.of(context)!.vendorLocationPickTitle,
          pinType: PinType.destination,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _location = result.location;
        _locationAddress = result.title;
      });
    }
  }

  Future<void> _showBusinessTypeSheet() async {
    final loc = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sheetContext.handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            for (final type in kVendorBusinessTypes)
              ListTile(
                title: Text(
                  vendorBusinessTypeDisplay(loc, type),
                  style: TextStyle(color: sheetContext.textColor),
                ),
                trailing: type == _businessType
                    ? const Icon(Icons.check, color: TayarColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, type),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _businessType = selected);
    }
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.vendorFillRequiredFieldsError)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await submitVendorApplication(
        storeName: _storeNameController.text,
        businessType: _businessType,
        contactPhone: _phoneController.text,
        location: _location!,
        note: _noteController.text,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: dialogContext.cardColor,
          title: Text(
            loc.vendorApplicationSentTitle,
            style: TextStyle(color: dialogContext.textColor),
          ),
          content: Text(
            loc.vendorApplicationSentMessage,
            style: TextStyle(color: dialogContext.textGreyColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                loc.okButton,
                style: const TextStyle(color: TayarColors.primary),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في إرسال طلب انضمام التاجر: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.vendorSubmitFailedError)),
      );
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
        title: Text(
          loc.becomeVendorTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.becomeVendorIntro,
              style: TextStyle(color: context.textGreyColor, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // ====== اسم المحل ======
            // maxLength مطابق لحد d.storeName.size() <= 100 في isValidVendorApplication()
            // بملف firestore.rules، عشان الفورم ميحاولش يبعت قيمة السيرفر هيرفضها
            _VendorLabeledTextField(
              label: loc.vendorStoreNameLabel,
              hint: loc.vendorStoreNameHint,
              controller: _storeNameController,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // ====== نوع النشاط (Dropdown) ======
            AppCard(
              onTap: _showBusinessTypeSheet,
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: TayarColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.vendorBusinessTypeLabel,
                      style: TextStyle(
                        color: context.textGreyColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    vendorBusinessTypeDisplay(loc, _businessType),
                    style: TextStyle(
                      color: context.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_left, color: context.textGreyColor),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ====== رقم موبايل/واتساب ======
            // maxLength و inputFormatters مطابقين لحقل الموبايل في
            // create_delivery_order_screen.dart، وللحد الأقصى 20 حرف في
            // isValidVendorApplication() بملف firestore.rules
            _VendorLabeledTextField(
              label: loc.vendorPhoneLabel,
              hint: loc.phoneNumberHint,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 20,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // ====== الموقع ======
            AppCard(
              onTap: _pickLocation,
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: TayarColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.vendorLocationLabel,
                          style: TextStyle(
                            color: context.textGreyColor,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _locationAddress ?? loc.tapToSelectLocationLabel,
                          style: TextStyle(
                            color: _locationAddress != null
                                ? context.textColor
                                : context.textGreyColor,
                            fontWeight: _locationAddress != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left, color: context.textGreyColor),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ====== ملاحظة اختيارية ======
            // maxLength مطابق لحد d.note.size() <= 300 في isValidVendorApplication()
            _VendorLabeledTextField(
              label: loc.vendorNoteLabel,
              hint: loc.vendorNoteHint,
              controller: _noteController,
              maxLines: 3,
              maxLength: 300,
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: AppPrimaryButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  disabledBackgroundColor: TayarColors.primary.withValues(
                    alpha: 0.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
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
                        loc.vendorSubmitButton,
                        style: TextStyle(
                          color: context.onPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ====== بترجع النص المترجم (عربي/إنجليزي) لقيمة نوع النشاط المخزّنة
/// بالعربي في قاعدة البيانات - نفس فكرة paymentMethodDisplay() الموجودة
/// أصلًا لطرق الدفع في passenger_home.dart ======
String vendorBusinessTypeDisplay(AppLocalizations loc, String value) {
  switch (value) {
    case 'مطعم':
      return loc.vendorTypeRestaurant;
    case 'سوبر ماركت':
      return loc.vendorTypeSupermarket;
    case 'صيدلية':
      return loc.vendorTypePharmacy;
    default:
      return loc.vendorTypeOther;
  }
}

/// ====== خانة نص بعنوان فوقها - نفس شكل LabeledTextField في
/// create_delivery_order_widgets/labeled_text_field.dart بس بإضافة maxLines للملاحظة ======
class _VendorLabeledTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? maxLength;

  const _VendorLabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              label,
              style: TextStyle(color: context.textGreyColor, fontSize: 12),
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            maxLines: maxLines,
            maxLength: maxLength,
            style: TextStyle(color: context.textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: context.textGreyColor),
              border: InputBorder.none,
              isDense: true,
              // ====== نخفي عداد الحروف الافتراضي بتاع maxLength عشان الشكل
              // البصري يفضل مطابق لباقي الحقول في التطبيق (زي
              // create_delivery_order_screen.dart) - الحد الأقصى بيتفرض
              // برمجيًا برضه حتى من غير ما يبان للمستخدم ======
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
