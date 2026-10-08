# Smart Presensi — Supabase Cloud Backend

Backend Node.js untuk aplikasi Flutter Smart Presensi. Backend menyimpan data
ke Supabase PostgreSQL dan foto selfie ke Supabase Storage, sehingga anggota
kelompok dapat memakai satu API dan database bersama melalui internet.

## Siapkan Supabase

1. Buat satu project di [Supabase](https://supabase.com/).
2. Buka **SQL Editor**, jalankan seluruh isi [`database/schema.sql`](./database/schema.sql).
3. Buka **Storage → New bucket**, buat bucket bernama `attendance-photos`,
   dan biarkan sebagai **Private**. Backend membuat signed URL yang berlaku
   24 jam untuk menampilkan foto histori.
4. Dari **Project Settings → API**, salin Project URL dan secret service-role key.
   Service-role key adalah rahasia server: jangan masukkan ke Flutter atau GitHub.

## Jalankan backend lokal

```bash
cd backend
npm install
cp .env.example .env
```

Backend memerlukan Node.js 22 atau lebih baru.

Isi `.env` dengan Project URL dan service-role key Supabase. File `.env` jangan
di-commit atau dibagikan ke grup:

```env
PORT=3000
SUPABASE_URL=https://PROJECT_REF.supabase.co
SUPABASE_SERVICE_ROLE_KEY=SERVICE_ROLE_SECRET
SUPABASE_STORAGE_BUCKET=attendance-photos
```

Jalankan API:

```bash
npm run dev
```

## Pakai satu API dari mana saja

Deploy folder `backend/` ke hosting Node.js yang dapat diakses publik dan
menyediakan HTTPS (misalnya Render atau Railway). Masukkan variabel Supabase di
bagian Environment Variables layanan hosting—jangan mengunggah `.env`.
Setelah deploy, tes `https://ALAMAT-API/`; respons seharusnya berisi
`{"status":"ok","service":"smart-presensi-backend"}`.

Semua anggota menjalankan Flutter dengan URL backend yang sama:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://ALAMAT-API
```

Untuk build web yang dibagikan:

```bash
flutter build web --dart-define=API_BASE_URL=https://ALAMAT-API
```

Deploy folder `build/web/` ke web hosting statis. Endpoint API tetap dilindungi
dari kebocoran service-role key karena key hanya berada di hosting backend.

## API

- `POST /api/absen`: kirim NRP, mata kuliah, catatan, koordinat, dan foto.
- `GET /api/absen?nrp=<NRP>`: ambil riwayat NRP.
- `GET /`: status layanan.

Server membatasi absensi di kotak GPS 30 × 30 meter Tower 2 ITS dan menolak
absensi mata kuliah yang sama lebih dari sekali per hari (waktu Asia/Jakarta).
Foto diunggah ke bucket Supabase Storage.

## Migrasi dari MySQL lokal

Schema Supabase membuat database cloud yang baru. Data MySQL lokal tidak
berpindah otomatis. Jika data lama perlu dipertahankan, ekspor tabel MySQL,
sesuaikan tanggal dan kolom, lalu impor ke `public.tbl_kehadiran` di Supabase.
Foto lama yang tersimpan di `backend/public/uploads` juga perlu diunggah ke
bucket cloud dan nilai `foto_path` diperbarui ke lokasi objek bucket masing-masing.

## Catatan operasional

- Gunakan satu project Supabase dan satu backend cloud untuk seluruh kelompok.
- Tetapkan `CORS_ORIGIN` ke origin web aplikasi setelah URL hosting tersedia;
  nilai `*` pada contoh hanya untuk memudahkan pengujian awal.
- Jangan expose port/database PostgreSQL ke umum; Flutter hanya berkomunikasi
  dengan API Node.js.
- Login aplikasi saat ini masih validasi lokal/dummy. Sebelum dipakai untuk
  data presensi nyata lintas internet, tambahkan autentikasi akun pada backend;
  saat ini siapa pun yang mengetahui NRP dapat mencoba membaca riwayat NRP itu.
