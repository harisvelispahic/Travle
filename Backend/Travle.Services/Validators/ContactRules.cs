namespace Travle.Services.Validators
{
    /// <summary>
    /// Shared contact-field rules, so every place a phone number is accepted (self-registration, profile
    /// edit, admin account creation) enforces the same format and shows the same message. Course §4
    /// requires a format check on phone/email fields <i>and</i> an error message that states the expected
    /// format rather than just "invalid". The Flutter mirror lives in
    /// <c>travle_core/lib/src/utils/validators.dart</c> (<c>Validators.phone</c>) and must stay in step.
    /// </summary>
    public static class ContactRules
    {
        /// <summary>
        /// An optional leading <c>+</c>, then digits, optionally grouped with spaces, dashes, slashes or
        /// parentheses; 6–20 characters overall. Deliberately permissive about grouping (BiH numbers are
        /// written "+387 61 234 567", "061/234-567", "061 234 567") but strict about the character set,
        /// so letters and free text are rejected.
        /// </summary>
        public const string PhonePattern = @"^\+?[0-9][0-9 \-()/]{5,19}$";

        /// <summary>The message shown under the control when <see cref="PhonePattern"/> fails.</summary>
        public const string PhoneMessage =
            "Digits only, optionally starting with '+' — e.g. +387 61 234 567 or 061/234-567.";
    }
}
