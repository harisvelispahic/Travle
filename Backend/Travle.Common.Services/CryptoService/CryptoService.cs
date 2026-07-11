using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace Travle.Common.Services.CryptoService
{
    public class CryptoService : ICryptoService
    {
        public string GenerateHash(string password, string salt)
        {
            using (var pbkdf2 = new Rfc2898DeriveBytes(password, Encoding.UTF8.GetBytes(salt), 10000, HashAlgorithmName.SHA256))
            {
                byte[] hash = pbkdf2.GetBytes(20);
                return Convert.ToBase64String(hash);
            }
        }

        public string GenerateSlat()
        {
            using (var rng = new RNGCryptoServiceProvider())
            {
                byte[] saltBytes = new byte[16];
                rng.GetBytes(saltBytes);
                return Convert.ToBase64String(saltBytes);
            }
        }

        public bool Verify(string hash, string salt, string password)
        {
            var generatedHash = GenerateHash(password, salt);
             return hash == generatedHash;
        }
    }
}
