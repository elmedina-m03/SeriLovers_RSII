# SeriLovers

SeriLovers je platforma za otkrivanje i upravljanje TV serijama.

## Tehnologije

- ASP.NET Core Web API (.NET 8)
- Flutter (Mobile & Desktop)
- SQL Server
- RabbitMQ (EasyNetQ)
- Docker & Docker Compose

## Pokretanje aplikacije

### Preko Docker-a (Preporučeno)

1. Navigirajte do `SeriLovers.API` direktorijuma:
   ```bash
   cd SeriLovers.API
   ```

2. Pokrenite sve servise:
   ```bash
   docker-compose up -d --build
   ```

3. Sačekajte da se svi servisi pokrenu (oko 30-60 sekundi). Migracije se primenjuju automatski prilikom pokretanja API servisa.

4. Proverite status servisa:
   ```bash
   docker-compose ps
   ```

Aplikacija će biti dostupna na:
- **API Swagger:** http://localhost:5149/swagger
- **RabbitMQ Management:** http://localhost:15672 (guest/guest)
- **SQL Server:** localhost:1433 (sa/YourStrong!Pass)

**Napomena:** Prilikom prvog pokretanja, migracije se primenjuju automatski. Ako dođe do greške, sačekajte nekoliko sekundi i pokrenite ponovo:
```bash
docker-compose restart serilovers.api
```

### Bez Docker-a

1. **API:**
   ```bash
   cd SeriLovers.API
   dotnet ef database update
   dotnet run
   ```

2. **Flutter Desktop:**
   ```bash
   cd serilovers_frontend
   flutter pub get
   # Kopirajte env.template u .env i ažurirajte API_BASE_URL na localhost
   flutter run -d windows
   ```

3. **Flutter Mobile:**
   ```bash
   cd serilovers_frontend
   flutter pub get
   # Kopirajte env.template u .env i ažurirajte API_BASE_URL na 10.0.2.2 (za Android emulator)
   flutter run -d android
   ```

## Korisnički podaci za pristup aplikaciji

**Obavezno:** Koristite sledeće podatke za pristup aplikaciji seminarskog rada:

### Desktop verzija
- **Korisničko ime:** `desktop`
- **Lozinka:** `test`

### Mobilna verzija
- **Korisničko ime:** `mobile`
- **Lozinka:** `test`

## Docker servisi

Docker Compose pokreće 4 servisa:

- **serilovers.api** - Glavni REST API servis (port 5149)
  - Automatski primenjuje migracije prilikom pokretanja
  - Seeding podataka se izvršava automatski
  
- **serilovers.worker** - Pomoćni mikroservis za obradu RabbitMQ poruka
  - Prima poruke sa RabbitMQ
  - Izvršava asinhrone zadatke (slanje emaila, logiranje, notifikacije)
  
- **serilovers.db** - SQL Server baza podataka
  - Port: 1433
  - Baza: IB220036
  - Korisničko ime: sa
  - Lozinka: YourStrong!Pass
  
- **rabbitmq** - Message broker
  - Portovi: 5672 (AMQP), 15672 (Management UI)
  - Korisničko ime: guest
  - Lozinka: guest

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
