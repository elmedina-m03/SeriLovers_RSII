# SeriLovers

SeriLovers je platforma za otkrivanje i upravljanje TV serijama.

## Tehnologije

- ASP.NET Core Web API (.NET 8)
- Flutter (Mobile & Desktop)
- SQL Server
- RabbitMQ (EasyNetQ)
- Docker & Docker Compose

## Preuzimanje projekta

**Važno:** Ako Windows Defender prikaže "Virus detected" prilikom preuzimanja ZIP arhive, to je **false positive** (lažno pozitivno). Flutter Windows build fajlovi često pokreću ovo upozorenje, ali su potpuno sigurni.

**Preporučeni način preuzimanja:**
```bash
git clone https://github.com/elmedina-m03/SeriLovers_RSII.git
```

Alternativno, možete ignorirati upozorenje ili dodati iznimku u Windows Defender.

## Pokretanje aplikacije

### ⚡ Brzo pokretanje (Za evaluaciju)

**VAŽNO:** Backend **MORA** biti pokrenut prije nego što pokrenete aplikaciju!

1. **Pokrenite backend:**
   ```bash
   cd SeriLovers.API
   docker-compose up -d --build
   ```
   Sačekajte 30-60 sekundi da se svi servisi pokrenu.

2. **Pokrenite Windows aplikaciju:**
   - Otvorite File Explorer
   - Navigirajte do: `folder-desktop-app/build/windows/x64/runner/Release/`
   - Duplim klikom pokrenite: `serilovers_frontend.exe`
   - Prijavite se sa: `desktop` / `test`

**Napomena:** Ako se aplikacija ne otvori ili login ne radi, provjerite da je backend pokrenut (`docker-compose ps` u `SeriLovers.API` folderu).

### Pokretanje buildanih aplikacija (Za evaluaciju)

**Važno:** Buildane aplikacije već imaju ispravno konfigurisane `.env` fajlove:
- **Windows aplikacija** koristi `http://localhost:5149/api`
- **Android APK** koristi `http://10.0.2.2:5149/api` (za Android emulator)

#### Windows aplikacija

1. Pokrenite backend servise (vidi "Preko Docker-a" ispod)
2. Navigirajte do `folder-desktop-app/build/windows/x64/runner/Release/`
3. Pokrenite `serilovers_frontend.exe`

**Napomena:** Ako pokrećete direktno iz File Explorera, provjerite da je backend pokrenut na `http://localhost:5149`

#### Android aplikacija

1. Pokrenite backend servise (vidi "Preko Docker-a" ispod)
2. Pokrenite Android emulator (AVD)
3. Instalirajte APK fajl iz `folder-mobilne-app/build/app/outputs/flutter-apk/app-release.apk`
   - Možete prevući APK fajl u emulator ili koristiti `adb install app-release.apk`

**Napomena:** Android emulator automatski mapira `10.0.2.2` na `localhost` računara, tako da aplikacija može pristupiti backend-u.

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
