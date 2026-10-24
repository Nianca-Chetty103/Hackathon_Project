# Eduvos app

## App and backend

Flutter is the frontend. The PHP REST API currently owns signup, login, and
profile retrieval, and connects to MySQL through PDO. On Android, Java sends
Flutter authentication requests to that PHP API through a platform channel.
Java is the Android-side API client; it does not replace PHP authentication or
connect directly to MySQL. Flutter/Dart continues to display forms, validate
input, and navigate between screens.

The app currently targets Android. Android uses Java platform-channel clients
for PHP API requests; the Kotlin Gradle files are build configuration.

## XAMPP and MySQL setup

1. Put this `eduvos_app` folder at
   `C:\xampp\htdocs\Hackathon_Project\eduvos_app` (or adjust the URL below to
   match where you placed it). Apache currently serves `C:\xampp\htdocs`; a
   project that remains in Documents will return 404 and the API cannot save
   accounts. On the current development machine, XAMPP's API folder is linked
   to this workspace, so the Flutter app can use its existing API URL without
   copying the whole project.
2. In XAMPP, start Apache and MySQL. Confirm PHP has the PDO MySQL extension.
3. Open phpMyAdmin, import [`api/schema.sql`](api/schema.sql), and fill in
   `DB_HOST`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD` in
   [`api/db_config.php`](api/db_config.php). For a default local XAMPP install,
   the database user is `root` with a blank password. The starter config uses
   those defaults; change them only if your MySQL setup uses different
   credentials.
4. If you already created accounts with the old `users` schema, back up the
   database, import the new schema, then run
   `C:\xampp\php\php.exe api\migrate_split_users.php` from this project folder
   to copy existing accounts and tokens into the role tables. The old tables
   are left in place.
   If you already imported the earlier split schema, first run
   `C:\xampp\php\php.exe api\migrate_admin_table.php` to convert the old admin
   columns to the name/email/password layout. These migration scripts only run
   from the command line, not through Apache.
5. Start Flutter with `flutter run`. The normal app entry point is
   `lib/main.dart`. The Android emulator's default API address is
   `http://10.0.2.2/Hackathon_Project/eduvos_app/api/auth.php`.
   For a different server folder, pass the matching URL using
   `--dart-define=API_BASE_URL=http://10.0.2.2/Hackathon_Project/eduvos_app/api/auth.php`.

The signup screen creates student or lecturer accounts and asks for a role,
first name, surname, email, phone number, and password. Students also enter a
student number; lecturers enter a lecturer number. Admins cannot sign themselves
up: their accounts must be created by an authorized administrator. Sign-in
includes the admin role for these provisioned accounts.

The database has separate `students`, `lecturers`, and `admins` tables, plus
`auth_tokens` for sessions and `account_settings` for each account's dark-mode
and notification preferences. The admin table stores only a name, email, and
password hash, in addition to its database ID and creation timestamp. To add an
admin in phpMyAdmin, first generate a password hash with XAMPP PHP:
`php -r "echo password_hash('ReplaceWithYourPassword', PASSWORD_DEFAULT), PHP_EOL;"`.
Insert the admin's name, email, and generated hash into `admins`. Each role table
enforces unique emails within that role; email addresses may be repeated across
different roles. The API accepts
JSON `POST` requests with `action=signup` or `action=login`. Authenticated
profile retrieval uses `GET /api/auth.php` with the session token in the
`Authorization` header. Tokens expire after 30 days and only their SHA-256
hashes are stored. Passwords use PHP's `password_hash` and are never returned
by the API. The profile & settings screen uses `GET` and `POST /api/profile.php`
to view or edit account details, save preferences, and revoke the current
session when signing out.

For development, the Android debug build allows HTTP so it can connect to
XAMPP on the host. Use HTTPS and restrict CORS origins before deploying.

The login screen now sends valid account details to the API. After signup or
login succeeds, students and lecturers open the home screen, while admins open
the admin dashboard. API or database errors are shown on the login screen
instead. Check the email and role table in phpMyAdmin after signup to confirm
the account was saved.

The student home screen includes Marketplace, The Tank, and Communities
features backed by PHP endpoints and MySQL. Products and services are stored in
separate tables; students can create, edit, and delete their own listings.
Product listings support up to five JPEG, PNG, or WebP photos (up to 5 MB each),
which are uploaded through the authenticated Marketplace API and shown with
their listing.
Admins can delete listings for moderation but cannot edit another account's
listing. Students can post and delete their own business ideas in
`business_ideas`. Communities
and their updates are stored separately from `community_memberships`, which
records each account's membership. Members can join or leave communities and
see their updates. Admins can review and delete any marketplace listing or
business idea from the admin dashboard; ownership is checked by the PHP API.
The Home page links to Bursaries, where all signed-in users can view bursary
details and open the provider's application website. Administrators can post
bursaries from the Admin Dashboard; the PHP API checks the admin role before
accepting a post.
Each bursary records its company name, bursary name, details, and application
website. For an existing database, run
`C:\xampp\php\php.exe api\migrate_bursary_company_name.php` from the project
folder to add the company-name column without losing existing bursary records.

To add these tables to an existing installation, re-import
[`api/schema.sql`](api/schema.sql) in phpMyAdmin. The feature tables and sample
communities, account settings, product-image metadata, and bursaries tables are
created idempotently, and existing account tables are left unchanged. Ensure
the PHP process can create files in `api/uploads/product_images` for
product-photo uploads. The notification setting stores a user's opt-in
preference; push-notification delivery is not configured yet.
