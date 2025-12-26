# SeriLovers.API

SeriLovers.API is a TV series discovery platform that powers authentication, role-based administration, personalized recommendations, and reporting capabilities for the SeriLovers ecosystem. Users can browse series, manage watchlists, rate episodes, and receive tailored suggestions while administrators curate content and export reports.

## Tech Stack

- **Runtime:** .NET 8
- **Web Framework:** ASP.NET Core Web API
- **Data Access:** Entity Framework Core (SQL Server)
- **Authentication:** JWT Bearer tokens, ASP.NET Core Identity
- **External Login:** OAuth 2.0 Google sign-in
- **Documentation:** Swagger / OpenAPI (Swashbuckle)
- **PDF Generation:** QuestPDF
- **Message Queue:** RabbitMQ (EasyNetQ) for event-driven architecture

## Getting Started

### Prerequisites

- .NET 8 SDK or newer
- SQL Server (localdb or full instance)
- Google OAuth 2.0 client credentials (for external login)
- RabbitMQ server (optional, for event messaging)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd SeriLovers.API
   ```

2. **Restore dependencies**
   ```bash
   dotnet restore
   ```

3. **Apply migrations**
   Make sure the database connection string in `appsettings.json` is correct, then run:
   ```bash
   dotnet ef database update
   ```

4. **Run the API**
   ```bash
   dotnet run
   ```

5. **Open Swagger UI**
   Navigate to `https://localhost:5001/swagger` (or the configured URL) to explore and test endpoints.

### Docker

#### Build & Run

```bash
docker-compose up --build
```

The API will be reachable at `http://localhost:5149/swagger`.

#### Run EF Core Migrations inside container

```bash
docker exec -it serilovers.api dotnet ef database update
```

Ensure the database container is running and the connection string matches the docker-compose configuration.

## Default Accounts

| Role  | Email             | Password   |
|-------|-------------------|------------|
| Admin | admin@test.com    | Admin123!  |
| User  | user@test.com     | User123!   |

> These accounts are seeded during initial setup. Use them for quick testing.

## Authentication Flow

### JWT Login

1. Call `POST /api/auth/login` with email and password.
2. Copy the `token` value from the response.
3. In Swagger, click **Authorize**, choose the `Bearer` scheme, and enter `Bearer <token>`.
4. Authenticated requests will now include the JWT.

### Google OAuth 2.0 Login

1. Obtain a Google OAuth access token on the client side (implicit or authorization-code flow).
2. Call `POST /api/auth/external/google` with `{ "accessToken": "<google-token>" }`.
3. The API will create or update the local user and return a JWT for subsequent calls.

## Key API Endpoints

- **Authentication**
  - `POST /api/auth/register` – create a new account
  - `POST /api/auth/login` – standard login (JWT)
  - `POST /api/auth/external/google` – Google OAuth exchange

- **Series Management**
  - `GET /api/series` – list with pagination/filtering
  - `GET /api/series/{id}` – detailed series view
  - `GET /api/series/recommendations` – personalized suggestions
  - `POST /api/series` – create (Admin)
  - `PUT /api/series/{id}` – update (Admin)
  - `DELETE /api/series/{id}` – remove (Admin)

- **Genres & Actors**
  - `GET /api/genre`, `GET /api/actor` – lists with search and series lookups
  - `POST/PUT/DELETE` endpoints protected by Admin role

- **Ratings & Watchlists**
  - `POST /api/rating` – add or update rating
  - `POST /api/watchlist` – add to watchlist
  - `DELETE /api/watchlist/{seriesId}` – remove from watchlist

- **Favorites & Recommendations Logs**
  - `GET /api/favoritecharacter`, `POST /api/favoritecharacter`
  - `GET /api/recommendationlog`, `POST /api/recommendationlog`

- **Reports**
  - `GET /api/reports/series-summary` – CSV export
  - `GET /api/reports/series-summary/pdf` – PDF export

## RabbitMQ Configuration

The API uses RabbitMQ for event-driven messaging. Events are published when:
- A review is created (`ReviewCreatedEvent`)
- An episode is marked as watched (`EpisodeWatchedEvent`)
- A user is created (`UserCreatedEvent`)
- A user profile is updated (`UserUpdatedEvent`)

### Configuration

RabbitMQ connection can be configured via:
1. **Environment Variable:** `RABBITMQ_CONNECTION`
2. **appsettings.json:** `RabbitMq:Connection`
3. **Connection String:** `ConnectionStrings:RabbitMQ`

Example connection string:
```
host=localhost;username=guest;password=guest
```

If RabbitMQ is not configured, the application will continue to function without message bus functionality (graceful degradation).

### Background Workers

Background workers automatically consume and log all published events. Check application logs for `[RabbitMQ]` prefixed messages.

### Testing RabbitMQ

**1. Check Connection Status:**
   - GET `/api/admin/MessageBusTest/status` - Returns whether RabbitMQ is connected

**2. Test Event Publishing:**
   - POST `/api/admin/MessageBusTest/test/review-created` - Test ReviewCreatedEvent
   - POST `/api/admin/MessageBusTest/test/episode-watched` - Test EpisodeWatchedEvent
   - POST `/api/admin/MessageBusTest/test/user-created` - Test UserCreatedEvent
   - POST `/api/admin/MessageBusTest/test/user-updated` - Test UserUpdatedEvent

**3. Verify Events Are Consumed:**
   After publishing a test event, check your application logs for messages like:
   ```
   [RabbitMQ] ReviewCreatedEvent received - RatingId: 999, User: TestUser (1), Series: Test Series (1), Score: 5, Comment: "This is a test review event"
   ```

**4. Check Application Startup Logs:**
   When the application starts, you should see:
   - `"Successfully connected to RabbitMQ."` - if connected
   - `"RabbitMQ connection string is not configured..."` - if not configured
   - `"Successfully subscribed to ReviewCreatedEvent."` - for each event type

**5. Real-World Testing:**
   - Create a review with a comment → Should publish `ReviewCreatedEvent`
   - Mark an episode as watched → Should publish `EpisodeWatchedEvent`
   - Register a new user → Should publish `UserCreatedEvent`
   - Update user profile → Should publish `UserUpdatedEvent`

## Development Tips

- Update OAuth credentials in `appsettings.json` / `appsettings.Development.json` under `Authentication:Google`.
- Seed data includes series, actors, genres, favorite characters, and recommendation logs. Rerun `dotnet ef database update` after changing the seed.
- Swagger UI highlights which endpoints require authentication. Use the Bearer authorize button to test protected routes.
- RabbitMQ events are published asynchronously and decoupled from the main request flow - failures won't affect API responses.

## Credits & License

- Developed by the SeriLovers team.
- Uses open source libraries including AutoMapper, QuestPDF, Swashbuckle, and Entity Framework Core.
- Licensed under the MIT License. See the `LICENSE` file (or add one) for details.
