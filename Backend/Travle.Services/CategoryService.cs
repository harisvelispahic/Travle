using System;
using System.Collections.Generic;
using System.Linq;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using FluentValidation;

namespace Travle.Services
{
    public class CategoryService : BaseCRUDService<Category, CategoryResponse, CategorySearchObject, CategoriesInsertRequest, CategoriesUpdateRequest>, ICategoryService
    {
        // dummy in-memory collection with some hierarchical categories
      
        public CategoryService(TravleDbContext dbContext, MapsterMapper.IMapper mapper, IValidator<CategoriesInsertRequest> insertValidator, IValidator<CategoriesUpdateRequest> updateValidator) : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<Category> ApplyFilters(IEnumerable<Category> query, CategorySearchObject? search)
        {
            if (search != null)
            {
                if (!string.IsNullOrWhiteSpace(search.Name))
                {
                    query = query.Where(c => c.Name.Contains(search.Name, StringComparison.OrdinalIgnoreCase));
                }

                if (search.ParentCategoryId.HasValue)
                {
                    query = query.Where(c => c.ParentCategoryId == search.ParentCategoryId.Value);
                }
            }

            return query;
        }

       
    }
}