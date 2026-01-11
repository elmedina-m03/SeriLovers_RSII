# SeriLovers

SeriLovers is a TV series discovery and management platform that allows users to browse series, manage watchlists, rate episodes, and receive personalized recommendations. Administrators can curate content and access detailed statistics.

## Technologies

- ASP.NET Core Web API
- Flutter (Mobile & Desktop)
- SQL Server
- RabbitMQ
- Docker

## How to Run

### Prerequisites

- .NET 8 SDK
- Flutter SDK
- Docker and Docker Compose (for RabbitMQ and database)
- SQL Server (if not using Docker)

### API Setup

1. Navigate to `SeriLovers.API` directory
2. Update `appsettings.json` with your database connection string
3. Run migrations:
   ```bash
   dotnet ef database update
   ```
4. Start the API:
   ```bash
   dotnet run
   ```
   The API will be available at `http://localhost:5149`

### Database, RabbitMQ and Worker (Docker)

1. Navigate to `SeriLovers.API` directory
2. Start services:
   ```bash
   docker-compose up -d
   ```
   This starts:
   - SQL Server on port 1433
   - RabbitMQ on ports 5672 (AMQP) and 15672 (Management UI)
   - Worker service (processes RabbitMQ messages)

3. Run migrations inside the container:
   ```bash
   docker exec -it serilovers.api dotnet ef database update
   ```

### Flutter App Setup

1. Navigate to `serilovers_frontend` directory
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Copy `env.template` to `.env` and update `API_BASE_URL`:
   - Android Emulator: `http://10.0.2.2:5149/api`
   - Windows: `http://localhost:5149/api`
   - iOS Simulator: `http://localhost:5149/api`
4. Run the app:
   ```bash
   flutter run
   ```

## Test Credentials

### Desktop Application
- **Username:** `desktop`
- **Password:** `test`

### Mobile Application
- **Username:** `mobile`
- **Password:** `test`

### By Role

**Admin Role:**
- **Username:** `Admin`
- **Password:** `test`

**User Role:**
- **Username:** `User`
- **Password:** `test`

### Alternative Test Users

**Admin (Email-based):**
- **Email/Username:** `admin@test.com`
- **Password:** `Admin123!`

**Regular Users (Email-based):**
- **Email/Username:** `user1@test.com`
- **Password:** `User123!`

- **Email/Username:** `user2@test.com`
- **Password:** `User123!`

## Notes

- HTTPS is intentionally not used.
- Configuration files are part of the repository.
- RabbitMQ subscriptions are disabled in Development environment by default.

