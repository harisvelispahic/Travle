namespace Travle.Services.Security
{
    /// <summary>
    /// Password hashing primitives. Implemented with PBKDF2 + a cryptographic RNG (course §A.3).
    /// The same instance is used by the runtime (registration, password change) and matches the
    /// format of the hashes baked into the seed, so seeded and live accounts verify identically.
    /// </summary>
    public interface ICryptoService
    {
        /// <summary>Derives a Base64 password hash from the plaintext and its (Base64) salt.</summary>
        string GenerateHash(string password, string salt);

        /// <summary>Generates a fresh, cryptographically random Base64 salt.</summary>
        string GenerateSalt();

        /// <summary>Constant-time-ish verification that <paramref name="password"/> matches the stored hash/salt.</summary>
        bool Verify(string hash, string salt, string password);
    }
}
