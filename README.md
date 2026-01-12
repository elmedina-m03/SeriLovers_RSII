# SeriLovers

SeriLovers je platforma za otkrivanje i upravljanje TV serijama.

## Tehnologije

- ASP.NET Core Web API (.NET 8)
- Flutter (Mobile & Desktop)
- SQL Server
- RabbitMQ
- Docker & Docker Compose

## Pokretanje aplikacije

### Preko Docker-a (Preporučeno)

1. Navigirajte do `SeriLovers.API` direktorijuma
2. Pokrenite servise:
   ```bash
   docker-compose up -d --build
   ```
3. Pokrenite migracije:
   ```bash
   docker exec -it serilovers.api dotnet ef database update
   ```

Aplikacija će biti dostupna na:
- **API Swagger:** http://localhost:5149/swagger
- **RabbitMQ Management:** http://localhost:15672 (guest/guest)

### Bez Docker-a

1. **API:**
   ```bash
   cd SeriLovers.API
   dotnet ef database update
   dotnet run
   ```

2. **Flutter:**
   ```bash
   cd serilovers_frontend
   flutter pub get
   # Kopirajte env.template u .env i ažurirajte API_BASE_URL
   flutter run
   ```

## Test korisnički podaci

### Admin
- **Email/Korisničko ime:** `admin@test.com`
- **Lozinka:** `Admin123!`

### User
- **Email/Korisničko ime:** `user1@test.com`
- **Lozinka:** `User123!`

## Docker servisi

Docker Compose pokreće 4 servisa:
- **serilovers.api** - Glavni REST API (port 5149)
- **serilovers.worker** - Pomoćni servis za obradu RabbitMQ poruka
- **serilovers.db** - SQL Server baza podataka (port 1433, baza: IB220036)
- **rabbitmq** - Message broker (portovi 5672, 15672)

## Sistem preporuke

Aplikacija koristi hibridni sistem preporuke (Item-based + User-based filtering). Detaljna dokumentacija u `recommender_dokumentacija.pdf`.

## Struktura projekta

```
SeriLovers_RSII/
├── SeriLovers.API/          # Backend API + Worker servis
│   ├── docker-compose.yml   # Docker konfiguracija
│   └── SeriLovers.Worker/   # Worker mikroservis
└── serilovers_frontend/      # Flutter aplikacija
```
