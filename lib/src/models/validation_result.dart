/// Outcome of validating a [PickedMedia] against [MediaSelectionOptions].
class ValidationResult {
  /// Constructs a successful [ValidationResult].
  const ValidationResult.valid() : isValid = true, violations = const [];

  /// Constructs an invalid [ValidationResult] with one or more [violations].
  const ValidationResult.invalid(this.violations) : isValid = false;

  /// Whether the media satisfied all constraints.
  final bool isValid;

  /// List of constraint violation descriptions, empty when [isValid] is true.
  final List<String> violations;

  @override
  String toString() => isValid
      ? 'ValidationResult(valid)'
      : 'ValidationResult(invalid: ${violations.join(', ')})';
}
