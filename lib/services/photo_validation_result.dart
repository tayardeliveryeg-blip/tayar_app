/// Result of validating a profile photo. Shared by the mobile (ML Kit) and
/// web (face-api.js) implementations so both return the exact same shape.
class PhotoValidationResult {
  final bool isValid;
  final String? errorMessageAr; // Arabic message to show the user

  const PhotoValidationResult._({required this.isValid, this.errorMessageAr});

  factory PhotoValidationResult.valid() =>
      const PhotoValidationResult._(isValid: true);

  factory PhotoValidationResult.invalid(String ar) =>
      PhotoValidationResult._(isValid: false, errorMessageAr: ar);
}
