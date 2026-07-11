using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using FluentValidation;
using MapsterMapper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Travle.Services
{
    public class AssetService : BaseCRUDService<Asset, AssetResponse, AssetSearch, AssetInsertRequest, AssetUpdateRequest>, IAssetService
    {
        public AssetService(TravleDbContext dbContext, IMapper mapper, IValidator<AssetInsertRequest> insertValidator, IValidator<AssetUpdateRequest> updateValidator)
           : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<Asset> ApplyFilters(IEnumerable<Asset> query, AssetSearch? search)
        {
            if (search != null)
            {
                if (!string.IsNullOrWhiteSpace(search.FileName))
                {
                    query = query.Where(a => a.FileName.Contains(search.FileName, StringComparison.OrdinalIgnoreCase));
                }

                if (!string.IsNullOrWhiteSpace(search.ContentType))
                {
                    query = query.Where(a => a.ContentType.Contains(search.ContentType, StringComparison.OrdinalIgnoreCase));
                }

                if (search.ProductId.HasValue)
                {
                    query = query.Where(a => a.ProductId == search.ProductId.Value);
                }
            }

            return query;
        }
    }
}
