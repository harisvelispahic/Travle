

namespace Travle.Common.Services.CryptoService
{
    public interface ICryptoService
    {
        string GenerateHash(string password, string salt);
        string GenerateSlat();
        bool Verify(string hash, string salt, string password);
    }
}
