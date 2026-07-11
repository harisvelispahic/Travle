using System;
using System.Collections.Generic;
using System.Linq;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using FluentValidation;

namespace Travle.Services
{
    public class ProductTypeService : BaseCRUDService<ProductType, ProductTypeResponse, ProductTypeSearch, ProductTypeInsertRequest, ProductTypeUpdateRequest>, IProductTypeService
    {
        public ProductTypeService(TravleDbContext dbContext, MapsterMapper.IMapper mapper, IValidator<ProductTypeInsertRequest> insertValidator, IValidator<ProductTypeUpdateRequest> updateValidator) : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<ProductType> ApplyFilters(IEnumerable<ProductType> query, ProductTypeSearch? search)
        {
            if (search != null)
            {
                if (!string.IsNullOrWhiteSpace(search.Name))
                {
                    query = query.Where(pt => pt.Name.Contains(search.Name, StringComparison.OrdinalIgnoreCase));
                }

                if (search.IsActive.HasValue)
                {
                    query = query.Where(pt => pt.IsActive == search.IsActive.Value);
                }
            }

            return query;
        }
    }
}
