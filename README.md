# Admin Seller Center

Aplikasi mobile (Flutter) dan backend REST API (Flask) untuk memprediksi risiko pembatalan pesanan e-commerce menggunakan model **XGBoost 3-Class** serta memberikan rekomendasi perubahan metode pembayaran menggunakan pendekatan **Bounded Counterfactual**.

## Fitur Utama
- **Autentikasi Admin**: Login berbasis Email & Password terhubung ke database (`users`).
- **Dashboard Ringkasan Risiko**: Menampilkan total pesanan, jumlah pesanan berisiko tinggi (≥ 50%), pesanan aman (< 50%), dan rasio keamanan transaksi.
- **Riwayat Pesanan**: Pencarian, filter berdasarkan status risiko & metode pembayaran (`COD`, `Online`, `Internal Credit`), detail transaksi, serta hapus riwayat.
- **Prediksi Risiko & Rekomendasi Bounded Counterfactual**: Menghitung probabilitas pembatalan pesanan secara dinamis dan menyimulasikan alternatif metode pembayaran untuk menurunkan risiko di bawah ambang batas 50%.

## Struktur Folder
- `lib/main.dart` — Kode utama aplikasi Flutter (Android / Web).
- `backend/` — Server Flask API (`app_api.py`), model XGBoost & preprocessor (`.pkl`), serta `requirements.txt`.

## Cara Menjalankan Lokal
### 1. Backend (Flask API)
```bash
cd backend
pip install -r requirements.txt
python app_api.py
```
Server berjalan di `http://127.0.0.1:5000`.

### 2. Frontend (Flutter)
```bash
flutter pub get
flutter run
```
Akun demo default:
- **Email:** `admin@seller.com`
- **Password:** `admin`

## Catatan Penelitian
Aplikasi ini merupakan demonstrasi penelitian. Model dilatih dan diuji menggunakan dataset transaksi e-commerce Pakistan dan belum divalidasi untuk transaksi e-commerce Indonesia.
