# Întrebări Tehnice Frecvente
### Aplicația Aegis — Ghid tehnic pentru secretariat

---

## 1. Infrastructură & Baze de date

---

### 1. Ce bază de date folosiți?

**Cloud Firestore** — o bază de date NoSQL bazată pe documente, oferită de Google Firebase.

Datele sunt organizate în **colecții** (similar cu folderele) și **documente** (similar cu fișierele JSON). Orice modificare apare automat pe toate dispozitivele conectate, fără ca utilizatorul să fie nevoie să reîmprospăteze manual.

---

### 2. Ce tip de bază de date este Firestore — SQL sau NoSQL?

**NoSQL, orientat pe documente.** Nu există tabele, coloane sau scheme fixe. Fiecare document este un obiect cu câmpuri proprii, de exemplu:

```
users / ion.popescu
  ├── fullName:  "Ion Popescu"
  ├── role:      "student"
  ├── classId:   "10A"
  └── status:    "active"
```

Interogările se fac prin filtre pe câmpuri indexate (ex: `role = "student"` și `classId = "10A"`), nu prin SQL.

---

### 3. Care sunt principalele colecții din baza de date?

| Colecție | Ce conține |
|---|---|
| `users` | Toți utilizatorii: elevi, profesori, părinți, admini, operatori turnichete |
| `classes` | Clasele școlare cu dirigintele asignat și orarul de blocare ieșiri |
| `app_settings/security` | Flag-uri globale: onboarding activat/dezactivat, 2FA activat/dezactivat |

---

### 4. Datele sunt stocate local pe dispozitiv?

**Pe web:** persistența locală este dezactivată intenționat — aplicația citește mereu datele proaspete de pe server.

**Pe Android/iOS:** Firestore menține un cache intern care permite citiri offline, dar toate modificările se sincronizează cu serverul imediat ce conexiunea revine.

Preferințele de sesiune (ex: starea verificării 2FA) sunt salvate separat în memoria locală a dispozitivului (`SharedPreferences`).

---

## 2. Limbaje & Tehnologii

---

### 5. Ce limbaj de programare folosiți pentru aplicația mobilă și web?

**Dart**, folosind framework-ul **Flutter**.

Flutter permite compilarea unui singur cod sursă pentru Android, iOS și web simultan — o singură aplicație scrisă o singură dată, care rulează pe toate platformele.

---

### 6. Ce limbaj folosiți pe server (backend)?

**Node.js (JavaScript)**, prin **Firebase Cloud Functions**.

Funcțiile rulează pe serverele Google și sunt apelate securizat din aplicație. Ele verifică că utilizatorul are permisiunile necesare înainte de a executa orice operațiune sensibilă.

---

### 7. Cum comunică aplicația cu baza de date?

Prin două mecanisme complementare:

**1. Direct via SDK (Firestore SDK)**
Folosit pentru citiri și ascultare în timp real. Regulile de securitate Firestore controlează ce poate citi sau scrie fiecare rol.

**2. Prin Cloud Functions (backend)**
Folosit pentru operațiunile administrative sensibile: creare cont, ștergere utilizator, dezactivare cont, reset parolă. Funcția verifică pe server că apelantul este admin înainte de a modifica datele.

---

### 8. Ce este Firebase și de ce l-ați ales?

Firebase este o platformă **Backend-as-a-Service (BaaS)** de la Google care oferă într-un singur pachet:

- Autentificare utilizatori
- Bază de date în timp real
- Funcții serverless (Cloud Functions)
- Notificări push (FCM)
- Hosting web

A fost ales pentru că elimină necesitatea unui server propriu, scalează automat odată cu numărul de utilizatori și are SDK-uri native pentru Flutter, web și Node.js.

---

## 3. Autentificare & Securitate

---

### 9. Cum sunt stocate parolele utilizatorilor?

Parolele **nu sunt stocate niciodată în text clar.** La crearea contului, parola trece prin algoritmul:

> **PBKDF2-HMAC-SHA256** — 120.000 iterații — salt aleatoriu de 16 octeți

În baza de date se salvează doar trei câmpuri:

| Câmp | Ce este |
|---|---|
| `passwordSalt` | Saltul aleatoriu (Base64) |
| `passwordHash` | Hash-ul derivat (Base64) |
| `passwordAlgo` | Numele algoritmului: `"pbkdf2_sha256"` |

La autentificare, parola introdusă este re-derivată cu același salt și comparată cu hash-ul stocat. Dacă nu se potrivesc, autentificarea eșuează.

---

### 10. Ce este autentificarea în doi pași (2FA) și cum funcționează?

2FA poate fi **activată sau dezactivată global** de admin din setările de securitate.

Când este activă, după introducerea parolei corecte utilizatorul trebuie să confirme identitatea printr-un pas suplimentar. Starea verificată se salvează temporar:

- **Local** — în memoria dispozitivului cu un timestamp de expirare
- **În Firestore** — câmpul `twoFactorVerifiedUntil` cu data expirării sesiunii

Astfel, reîncărcarea paginii nu forțează re-verificarea dacă sesiunea este încă validă.

---

### 11. Ce este procesul de onboarding și când se activează?

Onboarding-ul este un **flux obligatoriu pentru utilizatorii noi**, controlat global de admin (flag `onboardingEnabled`).

Când este activ, utilizatorul nou trebuie să parcurgă trei pași:

1. Adăugarea unei fotografii de profil
2. Verificarea sau adăugarea unui email personal
3. Schimbarea parolei temporare primite de la secretariat

Câmpul `onboardingComplete` din profilul utilizatorului devine `true` doar după finalizarea tuturor pașilor. Până atunci, utilizatorul nu poate accesa restul aplicației.

---

### 12. Cum funcționează controlul accesului pe roluri?

Fiecare utilizator are un câmp `role` în Firestore. La autentificare, aplicația citește rolul și afișează interfața corespunzătoare:

| Rol | Interfață accesibilă |
|---|---|
| `student` | Orar, cereri ieșire, inbox |
| `teacher` | Dashboard diriginte, status elevi |
| `parent` | Cereri și status copil |
| `admin` | Panoul complet de secretariat |
| `gate` | Scanner QR pentru turnichete |

Regulile de securitate Firestore și Cloud Functions verifică rolul pentru fiecare operațiune sensibilă. Un elev nu poate accesa niciodată funcțiile de admin, chiar dacă cunoaște structura bazei de date.

---

### 13. Ce se întâmplă când un cont este dezactivat?

Funcția backend `adminSetDisabled`:

1. Setează câmpul `status` la `"disabled"` în Firestore
2. Blochează contul și în Firebase Auth (nu mai poate face login)

La următoarea încărcare a aplicației, starea este citită din Firestore și utilizatorul este **deconectat automat**, chiar dacă este deja logat. Un cont dezactivat nu poate face login chiar dacă cunoaște parola.

---

## 4. Notificări Push

---

### 14. Cum funcționează notificările push?

Prin **Firebase Cloud Messaging (FCM)**.

La fiecare login, dispozitivul primește un **token FCM unic** care este salvat în Firestore (`fcmToken` în profilul utilizatorului). Când backend-ul trebuie să notifice un utilizator, citește token-ul și trimite mesajul prin API-ul FCM.

- **Pe Android/iOS** — notificarea apare în bara de stare, gestionată de librăria nativă
- **Pe web** — notificările sunt gestionate de un Service Worker Firebase

---

### 15. Ce se întâmplă cu notificările când aplicația este închisă?

**Android/iOS:** FCM livrează notificările direct sistemului de operare, chiar dacă aplicația nu rulează. Notificarea apare în bara de stare și utilizatorul o poate deschide.

**Web:** Service Worker-ul Firebase primește și afișează notificările în fundal, fără ca tab-ul aplicației să fie deschis.

---

## 5. Turnichete & Coduri QR

---

### 16. Cum funcționează sistemul de turnichete cu QR?

```
Elev generează QR  →  Operator scanează  →  Backend validează  →  Acces înregistrat
```

1. Elevul apasă butonul de generare QR în aplicație
2. Se creează un token semnat cu timp de expirare scurt
3. Operatorul de la turnichete (rol `gate`) scanează QR-ul
4. Aplicația verifică semnătura și că token-ul nu a expirat
5. Funcția `redeemQrToken` înregistrează evenimentul de acces în Firestore

---

### 17. Cum este securizat token-ul QR? Nu poate fi falsificat?

Token-ul are formatul:

```
userId . expTimestamp . semnatura
```

Semnătura este generată cu **HMAC-SHA256** pe baza perechii `userId.expTimestamp`, folosind un secret cunoscut doar serverului.

Oricine modifică `userId` sau `expTimestamp` va produce o semnătură diferită — verificarea va eșua automat. În plus, token-ul expiră după câteva minute, deci un screenshot vechi nu poate fi refolosit.

---

### 18. Ce se întâmplă dacă un elev încearcă să iasă în intervalul de blocare?

Fiecare clasă are un **orar de blocare** configurabil de admin:

| Câmp | Exemplu |
|---|---|
| `noExitStart` | `"08:00"` |
| `noExitEnd` | `"13:00"` |
| `noExitDays` | `[1, 2, 3, 4, 5]` (Luni–Vineri) |

Când orarul este activ, aplicația **nu permite generarea unui token QR**, iar backend-ul refuză validarea chiar dacă token-ul ajunge cumva la turnichete.

---

## 6. Operațiuni Administrative

---

### 19. Cum se creează un utilizator nou?

Adminul completează formularul din panoul de secretariat. Aplicația apelează Cloud Function `adminCreateUser` care:

1. Validează câmpurile (username, parolă, rol, clasă)
2. Verifică că username-ul nu există deja
3. Verifică că clasa există (pentru elevi și profesori)
4. Hashează parola cu PBKDF2
5. Creează documentul în colecția `users`
6. Dacă este profesor, îl asignează ca diriginte al clasei în aceeași tranzacție atomică

---

### 20. Ce se întâmplă când șterg un utilizator?

Cloud Function `adminDeleteUser`:

1. Șterge contul din **Firebase Auth** (elimină accesul la autentificare)
2. Șterge documentul din **Firestore**
3. Dacă era profesor, elimină câmpul `teacherUsername` din clasa asociată

Dacă funcția backend eșuează (ex: problemă de rețea), există un **mecanism de fallback** care face curățenia direct din client, pentru a nu bloca fluxul de lucru al adminului.

---

### 21. Cum se resetează parola unui utilizator?

Adminul introduce username-ul și apasă "Reset parolă". Sistemul:

1. Generează o parolă aleatorie de **10 caractere** (fără caractere confuze: `0`, `O`, `1`, `l`, `I`)
2. Hashează parola cu PBKDF2
3. Actualizează câmpurile `passwordHash`, `passwordSalt`, `passwordAlgo` în Firestore
4. Afișează parola generată secretariatului pentru a fi comunicată utilizatorului

---

### 22. Cum funcționează mutarea unui elev în altă clasă?

Operațiunea `moveStudent` rulează într-o **tranzacție Firestore atomică**:

1. Citește documentul utilizatorului și al noii clase
2. Actualizează câmpul `classId` al utilizatorului
3. Dacă e profesor, scoate `teacherUsername` din vechea clasă și îl setează pe cea nouă
4. **Toate operațiunile reușesc împreună sau niciuna nu se aplică**

---

### 23. Ce este o tranzacție Firestore?

O tranzacție garantează că mai multe operațiuni de citire/scriere se execută **atomic**: fie toate reușesc, fie niciuna nu se aplică.

Este esențială pentru situații precum asignarea dirigintelui: dacă doi admini încearcă simultan să pună profesori diferiți pe aceeași clasă, tranzacția detectează conflictul și aruncă o eroare, prevenind o stare inconsistentă.

---

### 24. Ce este un "batch write"?

Un batch write grupează mai multe scrieri Firestore într-o singură cerere rețea, aplicată atomic.

Folosit la **ștergerea cascade a unei clase**: toți elevii clasei + profesorul + documentul clasei sunt șterși simultan printr-un singur batch, nu prin cereri individuale (care ar putea lăsa date orfane dacă o cerere eșuează la mijloc).

---

## 7. Export & Raportare

---

### 25. Cum se exportă lista utilizatorilor?

La crearea fiecărui utilizator, credențialele sunt adăugate automat într-un fișier CSV local (`credentiale_utilizatori.csv`).

- **Android** — salvat în stocarea externă a dispozitivului
- **iOS** — salvat în directorul de documente al aplicației
- **Web** — datele se acumulează în memorie și se descarcă ca fișier la apăsarea butonului de export

---

### 26. Ce date conține exportul CSV?

| Coloană | Descriere |
|---|---|
| `created_at` | Data și ora creării contului |
| `username` | Username-ul de login |
| `password` | Parola temporară **în text clar** |
| `full_name` | Numele complet |
| `role` | Rolul utilizatorului |
| `class_id` | Clasa asociată (dacă există) |

> **Atenție:** Fișierul CSV conține parole în text clar și trebuie protejat corespunzător. Nu îl trimiteți prin email nesecurizat și ștergeți-l după distribuirea credențialelor.

---

## 8. RBAC — Control Acces Bazat pe Roluri

---

### 27. Ce înseamnă RBAC?

**RBAC (Role-Based Access Control)** este un model de securitate în care permisiunile nu sunt acordate direct utilizatorului, ci **rolului** pe care îl deține. Utilizatorul moștenește automat toate permisiunile rolului său.

În Aegis, rolul este stocat ca un simplu câmp text în profilul fiecărui utilizator din Firestore:

```
users / ion.popescu
  └── role: "student"
```

---

### 28. Care sunt rolurile din sistem și ce poate face fiecare?

| Rol | Cine este | Ce poate face |
|---|---|---|
| `student` | Elev | Vede orarul propriu, generează QR, trimite cereri de ieșire, citește inbox |
| `teacher` | Diriginte | Vede statusul elevilor din clasa sa, aprobă/respinge cereri |
| `parent` | Părinte | Vede cerererile și statusul copilului(copiilor) săi |
| `admin` | Secretariat | Acces complet: creare/ștergere utilizatori, clase, orar, mesaje globale |
| `gate` | Operator turnichete | Doar scanare QR — nu are acces la nicio altă secțiune |

---

### 29. Unde sunt aplicate restricțiile de acces? Doar în aplicație?

**Nu** — restricțiile sunt aplicate pe **două niveluri independente**:

**1. Nivelul aplicației (client)**
La autentificare, aplicația citește rolul și navighează spre interfața corespunzătoare. Un elev pur și simplu nu vede butoanele de admin — ele nu există în interfața sa.

**2. Nivelul serverului (Firestore Security Rules + Cloud Functions)**
Chiar dacă cineva ar încerca să apeleze direct API-ul Firestore sau Cloud Functions (ex: prin Postman sau un script), fiecare operațiune sensibilă verifică rolul pe server:

```javascript
// Verificare rol admin în Cloud Functions
async function assertAdmin(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "...");
    const callerDoc = await firestore.collection("users").doc(request.auth.uid).get();
    if (callerDoc.data()?.role !== "admin")
        throw new HttpsError("permission-denied", "...");
}
```

---

### 30. Cum este protejat un părinte să vadă doar copilul lui, nu toți elevii?

Fiecare cont de `parent` are un câmp `children` — o listă cu UID-urile copiilor asociați:

```
users / mihai.popescu  (role: parent)
  └── children: ["ion.popescu", "maria.popescu"]
```

Asocierea se face **exclusiv de admin** prin funcția `adminAssignParentToStudent`. Părintele nu se poate asocia singur unui elev. Cloud Function-urile și regulile Firestore verifică că un părinte poate citi doar datele elevilor din lista sa `children`.

---

### 31. Poate un utilizator să-și schimbe singur rolul?

**Nu.** Câmpul `role` din Firestore este protejat de regulile de securitate — un utilizator autentificat nu poate scrie în propriul document pentru a-și schimba rolul. Doar funcțiile backend cu drepturi de admin (`firebase-admin` SDK) pot modifica acest câmp.

---

### 32. Ce se întâmplă dacă un utilizator încearcă să acceseze o rută de admin direct?

Aplicația Flutter verifică rolul la fiecare autentificare, înainte de a construi interfața. Dacă rolul nu este `admin`, pagina `SecretariatRawPage` nu este niciodată instanțiată. Chiar dacă ar fi, orice apel la Cloud Functions ar fi respins de `assertAdmin()` cu eroarea `permission-denied`.

---

## 9. Email — SMTP & Brevo

---

### 33. Ce este SMTP și cum îl folosiți?

**SMTP (Simple Mail Transfer Protocol)** este protocolul standard pentru trimiterea de emailuri. Funcțiile backend din Aegis folosesc librăria **Nodemailer** (Node.js) pentru a trimite emailuri prin orice server SMTP compatibil.

Configurația SMTP este stocată în variabile de mediu (fișierul `.env` al Cloud Functions) și nu este hardcodată în cod:

| Variabilă | Valoare |
|---|---|
| `SMTP_HOST` | Adresa serverului SMTP |
| `SMTP_PORT` | Portul (587 = TLS, 465 = SSL) |
| `SMTP_USER` | Utilizatorul de autentificare |
| `SMTP_PASS` | Parola / API key |
| `SMTP_FROM` | Adresa expeditorului afișată |

---

### 34. Ce este Brevo și de ce l-ați ales?

**Brevo** (fostul Sendinblue) este un serviciu de email tranzacțional în cloud. Oferă un **relay SMTP** — în loc să trimiteți emailuri direct de pe un server propriu (care ar putea fi marcat ca spam), emailurile trec prin infrastructura Brevo, care are reputație bună la ISP-uri și Gmail.

**De ce Brevo și nu altceva (SendGrid, Mailgun, AWS SES)?**
- Plan gratuit generos: **300 emailuri/zi** fără card de credit
- Relay SMTP standard — nu necesită SDK special, funcționează cu orice librărie SMTP
- Dashboard cu statistici de livrare (bounce rate, open rate)
- Configurare simplă: un singur host (`smtp-relay.brevo.com`, port `587`)

---

### 35. Cum funcționează trimiterea unui email în Aegis?

Există două fluxuri care trimit emailuri:

**1. Verificare email personal (onboarding)**

```
Utilizator introduce email  →  sendVerificationEmail()
  →  Generează cod 6 cifre  →  Salvează cod + expirare în Firestore
  →  Trimite email cu codul prin Brevo SMTP
  →  Utilizatorul introduce codul  →  verifyEmailCode()
  →  emailVerified: true  →  onboardingComplete: true
```

**2. Resetare parolă uitată**

```
Utilizator cere reset  →  authRequestPasswordReset()
  →  Generează cod 6 cifre  →  Salvează cod cu expirare 30 min
  →  Trimite email cu codul prin Brevo SMTP
  →  Utilizatorul introduce codul + parola nouă  →  authConfirmPasswordReset()
```

---

### 36. Ce se întâmplă dacă SMTP-ul nu este configurat?

Dacă oricare din variabilele `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` lipsește, Cloud Function aruncă imediat eroarea:

```
SMTP neconfigurat. Seteaza SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM.
```

Aplicația afișează eroarea utilizatorului și nu mai trimite nimic. Codul de verificare este totuși salvat în Firestore — dacă SMTP-ul se configurează ulterior și utilizatorul reîncearcă, codul anterior expirat nu mai este valid.

---

### 37. Cum arată emailul trimis utilizatorilor?

Emailul este HTML, cu design branded Aegis (fond verde, logo, cod mare centrat). Exemplu pentru resetare parolă:

```
Subiect: Resetare parola · Aegis

[Logo AEGIS]

Resetare parolă
Ai solicitat resetarea parolei contului tău Aegis.

┌─────────────────────┐
│       482 917       │  ← cod 6 cifre, expirare 30 min
└─────────────────────┘

Dacă nu ai solicitat resetarea parolei, ignoră acest email.
```

---

### 38. Cât timp este valid un cod de verificare trimis pe email?

| Tip cod | Valabilitate |
|---|---|
| Verificare email personal (onboarding) | **1 oră** |
| Resetare parolă uitată | **30 de minute** |

După expirare, codul este refuzat automat — utilizatorul trebuie să solicite un cod nou. Există și un **cooldown de 60 de secunde** între două cereri consecutive de cod, pentru a preveni abuzul.

---

### 39. Poate fi schimbat furnizorul de email (ex: de la Brevo la Gmail)?

Da, fără nicio modificare în cod. Este suficient să actualizați variabilele de mediu în `.env` și să redeploy-ați Cloud Functions:

```
# Gmail (mai puțin recomandat pentru producție)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=adresa@gmail.com
SMTP_PASS=app-password-generat

# SendGrid
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=SG.xxxxxxxxxxxx
```

---

## 10. Arhitectură Generală

---

### 40. Cum funcționează actualizarea în timp real a datelor?

Firestore SDK permite **abonarea la stream-uri**. Când un document se modifică pe server, SDK-ul livrează automat noua versiune tuturor clienților abonați, fără cereri repetate.

În Flutter, widgetul `StreamBuilder` ascultă aceste stream-uri și reconstruiește interfața automat la fiecare modificare — de exemplu, lista de elevi se actualizează instant când adminul adaugă un elev nou, fără să fie nevoie de refresh manual.

---

### 41. Aplicația funcționează și pe web, nu doar mobil?

Da. Există câteva diferențe gestionate explicit în cod:

| Funcționalitate | Android/iOS | Web |
|---|---|---|
| Export CSV | Fișier local pe dispozitiv | Descărcare browser |
| Notificări push | Librărie nativă | Firebase Service Worker |
| Cache Firestore | Activ | Dezactivat |
| Partajare fișiere | Disponibilă | Indisponibilă |

---

*Document generat pentru uzul intern al secretariatului — Aegis*
