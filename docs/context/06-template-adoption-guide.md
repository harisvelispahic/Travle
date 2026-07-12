# 06 — Template Adoption Guide (eCommerce → Travle)

Step-by-step, verified against the actual `rsII_exam_template_2025_26` contents. Goal: a compiling `Travle` solution with zero eCommerce leftovers (course §8.1 rejects template remains — `WeatherForecastController` is named explicitly).

## Step 1 — Copy and re-init

```bash
git clone https://github.com/Adil-Eminagic/rsII_exam_template_2025_26 travle
cd travle && rm -rf .git "Ispitni zadaci" && git init
```

## Step 2 — Rename directories and files

Target layout (decided): repo root `travle/` with **`Backend/`** and **`UI/`** as siblings; `docker-compose.yml` + `.env` + `README.md` + `recommender-dokumentacija.md` at the root.

```
eCommerce/                       → Backend/   (UI/ moves OUT of it, one level up to the repo root)
eCommerce/UI/                    → UI/        (sibling of Backend/)
eCommerce/docker-compose.yml     → docker-compose.yml (repo root; fix build contexts to ./Backend/...)
eCommerce.sln                    → Backend/Travle.sln
eCommerce.Model/                 → Travle.Model/        (+ eCommerce.Model.csproj → Travle.Model.csproj)
eCommerce.Services/              → Travle.Services/     (+ csproj)
eCommerce.WebAPI/                → Travle.WebAPI/       (+ csproj)
eCommerce.Common.Services/       → Travle.Common.Services/ (+ csproj) — or fold its CryptoService into Travle.Services and drop the project
fit/ (fit.sqlproj)               → delete (SQL DB project, not needed with Code First)
UI/ecommerce_desktop, _mobile    → replaced by your own Flutter templates as travle_desktop / travle_mobile
```

Renaming `.csproj` files does not touch the project GUIDs — those live in the `.sln`, which you fix next.

## Step 3 — Fix the solution file

Open `Travle.sln` in a text editor and find/replace `eCommerce` → `Travle` (project display names **and** relative paths). GUIDs stay as they are. Alternative if anything misbehaves: create a fresh sln and re-add:

```bash
dotnet new sln -n Travle
dotnet sln add Travle.Model Travle.Services Travle.WebAPI Travle.Common.Services
```

## Step 3b — Retarget to .NET 10 (LTS)

The template targets `net9.0` (out of support since May 2026). In all five `.csproj` files (Model, Services, WebAPI, Common.Services, new Worker): `<TargetFramework>net10.0</TargetFramework>`. Bump `Microsoft.*` packages to their 10.x lines (EF Core, JwtBearer, AspNetCore.OpenApi) and third-party packages (Mapster, FluentValidation, Scalar, System.Linq.Dynamic.Core) to latest. Keep **both** OpenAPI pipelines as the template ships them (Swashbuckle and Microsoft.AspNetCore.OpenApi + Scalar), bumped to latest stable; consolidation to a single pipeline is deferred and optional. Dockerfiles use `mcr.microsoft.com/dotnet/sdk:10.0` / `mcr.microsoft.com/dotnet/aspnet:10.0`.

## Step 4 — Fix project references + namespaces

`.csproj` `<ProjectReference Include="..\eCommerce.X\...">` paths → `Travle.X`. Then the namespace sweep — the template uses three casings, handle all of them **in this order** (longest/most specific first):

```bash
# from the solution root; review with git diff afterwards
grep -rl "ECommerceDbContext" --include="*.cs" . | xargs sed -i 's/ECommerceDbContext/TravleDbContext/g'
grep -rl "eCommerce"          --include="*.cs" --include="*.csproj" . | xargs sed -i 's/eCommerce/Travle/g'
grep -rl "ECommerce"          --include="*.cs" . | xargs sed -i 's/ECommerce/Travle/g'
grep -rl "ecommerce"          --include="*.cs" --include="*.yml" --include="*.json" . | xargs sed -i 's/ecommerce/travle/g'
```

(On Windows, Visual Studio's solution-wide Replace with "Match case" three times does the same job; or rename the `ECommerceDbContext` class via the IDE refactor first, then bulk-replace.) Also rename the files themselves: `eCommerceDbContext.cs → TravleDbContext.cs`, `eCommerceConfiguration.cs` (delete — replaced by `Configurations/` classes), `eCommerceSeed.cs → Seed/TravleSeeder.cs`.

## Step 5 — Purge list (delete, never comment out)

| Delete | Why |
|---|---|
| `WebAPI/Controllers/WeatherForecastController.cs`, `WebAPI/WeatherForecast.cs` | named rejection reason (§8.1) |
| `Model/Class1.cs`, `Services/Class1.cs` | placeholders |
| `Model/Exceptions/ClinetException.cs` | typo'd name; replaced by the new exception hierarchy (02 §3) |
| `WebAPI/Filters/ExceptionFilter.cs` (after middleware exists) | replaced by `ExceptionMiddleware` |
| `Services/QueryOptimization/*`, `WebAPI/Controllers/QueryOptimizationController.cs` | lecture demo artifact |
| `.vscode/` (contains `tasks.json` building fit.sqlproj via a path hardcoded to the author's machine: `/Users/amel/...`) | copy-paste leftover; useless outside the professor's Mac |
| `eCommerce.WebAPI/eCommerce.WebAPI.http` | endpoint-test file whose only request targets `/weatherforecast/` — a template leftover; recreate later with real Travle requests if you like the editor-based testing workflow |
| eCommerce domain — entities: Product, ProductCategory, ProductType, ProductReview, Category, Cart, CartItem, Order, OrderItem, UnitOfMeasure, Asset; their services/interfaces, controllers, validators, requests/responses/search objects; `ProductStateMachine/*` (after you've mirrored the pattern into `BookingStateMachine`) | not our domain |
| `Services/Migrations/*` (all) | fresh `InitialCreate` after Travle entities exist |
| Mapster `TypeAdapterConfig<...>` lines and DI registrations in `Program.cs` referencing deleted types | must compile clean |

## Step 6 — Keep list (the actual value of the template)

`BaseReadService`/`BaseCRUDService` + `IBase*`, `BaseReadController`/`BaseCRUDController`, `BaseSearchObject` + `PageResult`, `AccessController` + `AccessManager` + `ClaimNames` + `HttpAuthenticatedUserAccessor`/`IAuthenticatedUserAccessor`, `RefreshToken` entity + `IRefreshTokenService`/`RefreshTokenService`, `User`/`Role`/`UserRole` (extend per 03), `CryptoService` (verify: must be PBKDF2/bcrypt-class + `RandomNumberGenerator` — fix if not), user requests/responses/validators, `Program.cs` skeleton (dedupe registrations while there — course forbids double `UseCors`/`AddHttpContextAccessor`/`AddSwaggerGen`), `Properties/launchSettings.json` (dev launch profiles — ports + `ASPNETCORE_ENVIRONMENT`; no secrets; optionally trim to the http profile since the course recommends plain HTTP), root `.gitignore` (keep at repo root — it already ignores `*.user` and `*.env`; Flutter apps keep their own per-project .gitignore files, which move with them into `UI/`).

## Step 7 — Additions

`Travle.Worker` project (console/host + Dockerfile), `Travle.WebAPI/Dockerfile`, full `docker-compose.yml` (api, worker, rabbitmq, sqlserver — pinned tags; container/DB names travle-flavored; DB name **230172**), `.env` + `.env.example`, `ExceptionMiddleware` + exception hierarchy, `BaseEntity`/`BaseEntityConfiguration`, `Database/Configurations/` folder, **`POST /Access/Logout`** on `AccessController` calling the existing `DeleteAllUserRefreshTokensAsync` with the JWT userId.

## Step 8 — Flutter side

You're starting from your own mobile/desktop templates, so no eCommerce rename needed there. Port from the template UI only what's useful: `base_provider.dart` (paged fetch + auth header + error mapping), `auth_provider.dart`, `master_screen.dart`, `utils/`. Name packages `travle_mobile` / `travle_desktop` (pubspec `name:`, Android `applicationId`/namespace, Windows app title) from day one — renaming Flutter packages later is miserable.

## Step 9 — Verify (Phase 0 DoD gate)

```bash
dotnet build Travle.sln
grep -rniE "ecommerce|clinet|weatherforecast|productstate|unitofmeasure|cartitem" \
  --include="*.cs" --include="*.csproj" --include="*.sln" --include="*.yml" . && echo "LEFTOVERS FOUND" || echo "CLEAN"
docker compose up -d && docker compose ps
dotnet ef migrations add InitialCreate -p Travle.Services -s Travle.WebAPI
```

All four containers healthy, build clean, grep CLEAN → template adoption done.
