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
   accounts. Ensure Apache serves the same API files that you edit. If its
   `htdocs` folder contains a separate copy rather than a link to this
   workspace, copy changed files from `api/` into that served copy too;
   otherwise, the app may receive HTTP 404 for endpoints that exist only in
   the workspace.
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

The signup screen creates student or investor accounts and asks for a role,
first name, surname, email, phone number, and password. Students also enter a
student number. Lecturer accounts remain in the backend but are not available
in the sign-in or signup forms. Admins cannot sign themselves up: their
accounts must be created by an authorized administrator. Sign-in includes the
admin role for these provisioned accounts. Investor company names are optional.

The database has separate `students`, `lecturers`, `investors`, and `admins`
tables, plus `auth_tokens` for sessions and `account_settings` for each
account's dark-mode and notification preferences. Investor accounts can
optionally save a company name. The admin table stores only a name, email, and
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
their listing. Services can include one JPEG, PNG, or WebP image of their fees
or price list, and the owner can replace it when editing the service. The
Marketplace tab shows other users' listings; students also have a My Listings
tab to manage their own. Investors can privately message sellers and purchase
priced products or services through PayFast. Only the seller and the user who
started a listing conversation can read its messages.
Admins can delete listings for moderation but cannot edit another account's
listing. Students can post and delete their own business ideas in
`business_ideas`. Communities
and their updates are stored separately from `community_memberships`, which
records each account's membership. Members can join or leave communities and
see their updates. Admins can review and delete any marketplace listing or
business idea from the admin dashboard; ownership is checked by the PHP API.
Lecturers, admins, and investors can publish entrepreneurial advice; authors can
edit their own posts, and students can ask questions and like posts. Investors
can register and sign in separately.
Students can post ideas with an industry and a date deadline for investor
interest. The Tank and My Posts tabs separate public ideas from the student's
own posts. Expired ideas are hidden from other users, remain visible to their
owner, and cannot start new investor chats. Investors can tap Interested on an
unexpired student idea to notify the student in a private chat and pay the R200
admin fee. Users can continue both idea and marketplace conversations from
Chats; messages are visible only to the conversation participants and refresh
while a conversation is open.
The `entrepreneurial_posts`, `entrepreneurial_post_comments`, and
`entrepreneurial_post_reactions` tables store the advice feed and student
engagement. `investor_chats` and `investor_chat_messages` store private idea
conversations.
Students and other non-investor roles can open Bursaries from the Home page and
view bursary details or the provider's application website. Investors cannot
view bursaries; the PHP API enforces this restriction as well as hiding the
Home-page entry point. The bottom-navigation Bursaries button is replaced by
Auction. Administrators can post bursaries from the Admin Dashboard; the PHP
API checks the admin role before accepting a post.
Each bursary records its company name, bursary name, details, and application
website. For an existing database, run
`C:\xampp\php\php.exe api\migrate_bursary_company_name.php` from the project
folder to add the company-name column without losing existing bursary records.
For investor registration, entrepreneurial advice, and private chats on an
existing database, run
`C:\xampp\php\php.exe api\migrate_investor_blog_chats.php` from the project
folder. This creates the investor, blog, and chat tables and updates the account
role columns to include investors.
For service price-list images, idea industries and expiry deadlines, and
marketplace chats, run
`C:\xampp\php\php.exe api\migrate_marketplace_ideas.php` from the project
folder after the investor/blog/chat migration. Existing ideas receive a
deadline 30 days after their original creation date.
For investor interest notifications and R200 (ZAR) idea fees, run
`C:\xampp\php\php.exe api\migrate_idea_interest_payments.php` after those
migrations. Investors can tap **Interested** to notify the student in a
private chat; chat is available immediately. The investor can then pay through
PayFast, while administrators can verify manually received payments from
**Review Tank admin fees**.
For investor purchases of priced marketplace listings on an existing database,
run `C:\xampp\php\php.exe api\migrate_marketplace_purchases.php` after the
investor migration. Marketplace purchases use the configured Eduvos PayFast
merchant; automatic seller payouts are not configured.
The bottom navigation links to **Auction** for students and investors. Investors
must pay the existing R200 admin fee for an idea before submitting an offer;
students can review offers on their own ideas and accept one. Offer amounts are
visible only to the investor who made the offer and the student who owns the
idea. Accepting an offer closes other pending offers and opens the existing
one-to-one student/investor chat. Investors can see the number of offers on an
auction and whether it has closed, but offer amounts and messages remain private
to the investor who made the offer and the student who owns the idea. Once an
offer is accepted, the server prevents further offers. For an existing
database, run
`C:\xampp\php\php.exe api\migrate_auction_investor_advice.php` after the
investor, idea, and fee migrations to enable investor advice posts and auction
offers.
For community creation and member-only group chats on an existing database, run
`C:\xampp\php\php.exe api\migrate_community_chat.php`. Community creators are
automatically joined. Only current members see a community conversation in
**Chats** or can read and send its shared messages; leaving the community
removes that access.

To configure PayFast, copy
`api\payfast_config.example.php` to `api\payfast_config.local.php`, then enter
the merchant ID, key, and passphrase from your PayFast account. The local
configuration file is ignored by Git. Keep sandbox mode enabled while testing,
and change it only for a real PayFast merchant account. The return, cancel,
notify, and checkout URLs must use the public HTTPS address of the deployed API.
PayFast cannot send payment notifications to an Android emulator or a private
localhost URL. The API verifies the PayFast IPN signature, validates the
notification directly with PayFast, and checks the transaction reference and
amount before marking a purchase or fee as paid. Never treat the browser return
page as proof of payment.

To add these tables to an existing installation, re-import
[`api/schema.sql`](api/schema.sql) in phpMyAdmin. The feature tables and sample
communities, account settings, product-image metadata, and bursaries tables are
created idempotently, and existing account tables are left unchanged. Ensure
the PHP process can create files in `api/uploads/product_images` and
`api/uploads/service_images` for listing image uploads. The notification setting stores a user's opt-in
preference; push-notification delivery is not configured yet.
