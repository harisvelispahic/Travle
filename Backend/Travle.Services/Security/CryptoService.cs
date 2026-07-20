using System.Security.Cryptography;
using System.Text;

namespace Travle.Services.Security
{
    /// <summary>
    /// PBKDF2-HMAC-SHA256 password hashing (course §A.3: bcrypt/Argon2/PBKDF2 only, salt from
    /// <see cref="RandomNumberGenerator"/>). Parameters are hardened relative to the template
    /// (600k iterations, 256-bit derived key). The salt is stored as its own Base64 column and fed
    /// to the KDF as UTF-8 bytes; the seed hashes are produced with these exact parameters so
    /// <c>HasData</c> accounts and runtime-created accounts share one format.
    /// </summary>
    public class CryptoService : ICryptoService
    {
        private const int Iterations = 600_000;
        private const int SaltBytes = 16;
        private const int HashBytes = 32;
        private static readonly HashAlgorithmName Algorithm = HashAlgorithmName.SHA256;

        public string GenerateHash(string password, string salt)
        {
            var saltBytes = Encoding.UTF8.GetBytes(salt);
            var hash = Rfc2898DeriveBytes.Pbkdf2(
                Encoding.UTF8.GetBytes(password),
                saltBytes,
                Iterations,
                Algorithm,
                HashBytes);

            return Convert.ToBase64String(hash);
        }

        public string GenerateSalt()
        {
            var saltBytes = RandomNumberGenerator.GetBytes(SaltBytes);
            return Convert.ToBase64String(saltBytes);
        }

        public bool Verify(string hash, string salt, string password)
        {
            var computed = GenerateHash(password, salt);

            // Fixed-time comparison so verification does not leak how many leading bytes matched.
            return CryptographicOperations.FixedTimeEquals(
                Convert.FromBase64String(computed),
                Convert.FromBase64String(hash));
        }
    }
}
