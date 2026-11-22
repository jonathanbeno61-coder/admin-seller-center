from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, date
import sqlite3
import json
import math
import os

try:
    import mysql.connector
except ImportError:
    mysql = None

app = Flask(__name__)
CORS(app)

# ==========================================
# 1. PEMUATAN MODEL XGBOOST (JSON RINGAN & AKURAT)
# ==========================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

PAYMENT_CLASSES = ["COD", "Online", "Internal Credit"]
THRESHOLD = 0.50

trees = []
model_meta = None
base_margin = 0.0

try:
    with open(os.path.join(BASE_DIR, "model_xgb.json"), "r", encoding="utf-8") as f:
        _mj = json.load(f)
    with open(os.path.join(BASE_DIR, "model_meta.json"), "r", encoding="utf-8") as f:
        model_meta = json.load(f)

    trees = _mj["learner"]["gradient_booster"]["model"]["trees"]
    _bs = float(model_meta["base_score"])
    base_margin = math.log(_bs / (1.0 - _bs))
    print(f"MODEL XGBOOST BERHASIL DIMUAT! ({len(trees)} trees | Threshold = {THRESHOLD})")
except Exception as e:
    print(f"GAGAL MEMUAT MODEL: {e}")

CATEGORY_MAP_ID_TO_PK = {
    "Komputer & IT": "Computing",
    "Pakaian Pria": "Men's Fashion",
    "Pakaian Wanita": "Women's Fashion",
    "Kecantikan & Perawatan": "Beauty & Grooming",
    "Oleh-oleh & Camilan": "Soghaat",
    "HP & Tablet": "Mobiles & Tablets",
    "Peralatan Rumah Tangga": "Appliances",
    "Hiburan": "Entertainment",
    "Kesehatan & Olahraga": "Health & Sports",
    "Rumah & Dekorasi": "Home & Living",
    "Anak & Bayi": "Kids & Baby",
    "Buku": "Books",
    "Sekolah & Edukasi": "School & Education",
    "Superstore": "Superstore",
    "Lainnya": "Others",
}

def sesuaikan_kategori_preprocessor(kategori_input):
    return CATEGORY_MAP_ID_TO_PK.get(kategori_input, kategori_input)

def normalisasi_metode_pembayaran(metode_input):
    m = str(metode_input).strip().lower()
    if m == "cod":
        return "COD"
    elif m == "online":
        return "Online"
    elif m == "internal credit":
        return "Internal Credit"
    return str(metode_input).strip()

def hitung_probabilitas_batal(feature_dict):
    vec = [float(feature_dict[k]) for k in model_meta["numeric_features"]]
    for val, cats in zip(
        [feature_dict["category_name_1"], feature_dict["payment_method_class"]],
        model_meta["cat_categories"],
    ):
        for c in cats:
            vec.append(1.0 if val == c else 0.0)

    total = base_margin
    for t in trees:
        node = 0
        lc = t["left_children"]
        rc = t["right_children"]
        si = t["split_indices"]
        sc = t["split_conditions"]
        bw = t["base_weights"]
        while lc[node] != -1:
            node = lc[node] if vec[si[node]] < sc[node] else rc[node]
        total += bw[node]

    return 1.0 / (1.0 + math.exp(-total))

# ==========================================
# 2. DATABASE: MySQL (Lokal) + SQLite (Online)
# ==========================================
SQLITE_PATH = os.path.join(BASE_DIR, "seller_center.db")
USE_MYSQL = False

def get_mysql_connection():
    return mysql.connector.connect(
        host=os.environ.get("MYSQL_HOST", "localhost"),
        port=int(os.environ.get("MYSQL_PORT", 3306)),
        user=os.environ.get("MYSQL_USER", "root"),
        password=os.environ.get("MYSQL_PASSWORD", ""),
        database=os.environ.get("MYSQL_DATABASE", "seller_center_db"),
        connection_timeout=3,
    )

def get_sqlite_connection():
    conn = sqlite3.connect(SQLITE_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def inisialisasi_database():
    global USE_MYSQL
    if mysql is not None and os.environ.get("FORCE_SQLITE") != "1":
        try:
            conn = get_mysql_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(50) NOT NULL,
                    password VARCHAR(255) NOT NULL
                )
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS orders (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    tanggal_pesanan DATE,
                    kategori VARCHAR(50),
                    harga_satuan INT DEFAULT 0,
                    jumlah INT DEFAULT 0,
                    total_harga INT DEFAULT 0,
                    metode_pembayaran VARCHAR(50),
                    prediksi_risiko FLOAT DEFAULT 0
                )
            """)
            cursor.execute("SELECT id FROM users WHERE LOWER(username) = %s", ("admin@seller.com",))
            if cursor.fetchone() is None:
                cursor.execute(
                    "INSERT INTO users (username, password) VALUES (%s, %s)",
                    ("admin@seller.com", generate_password_hash("admin")),
                )
            conn.commit()
            cursor.close()
            conn.close()
            USE_MYSQL = True
            print("DATABASE: Terhubung ke MySQL!")
            return
        except Exception as e:
            print(f"INFO: MySQL tidak tersedia ({e}), menggunakan SQLite.")

    USE_MYSQL = False
    conn = get_sqlite_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            password TEXT NOT NULL
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tanggal_pesanan TEXT,
            kategori TEXT,
            harga_satuan INTEGER DEFAULT 0,
            jumlah INTEGER DEFAULT 0,
            total_harga INTEGER DEFAULT 0,
            metode_pembayaran TEXT,
            prediksi_risiko REAL DEFAULT 0
        )
    """)
    cursor.execute("SELECT id FROM users WHERE LOWER(username) = ?", ("admin@seller.com",))
    if cursor.fetchone() is None:
        cursor.execute(
            "INSERT INTO users (username, password) VALUES (?, ?)",
            ("admin@seller.com", generate_password_hash("admin")),
        )
    conn.commit()
    conn.close()
    print("DATABASE: Menggunakan SQLite (online ready)!")

inisialisasi_database()

def simpan_ke_database(tanggal, kategori, harga, jumlah, total, metode, prediksi_persen):
    try:
        if USE_MYSQL:
            conn = get_mysql_connection()
            cursor = conn.cursor()
            cursor.execute(
                """INSERT INTO orders
                (tanggal_pesanan, kategori, harga_satuan, jumlah, total_harga, metode_pembayaran, prediksi_risiko)
                VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (tanggal, kategori, harga, jumlah, total, metode, prediksi_persen),
            )
            conn.commit()
            cursor.close()
            conn.close()
        else:
            conn = get_sqlite_connection()
            cursor = conn.cursor()
            cursor.execute(
                """INSERT INTO orders
                (tanggal_pesanan, kategori, harga_satuan, jumlah, total_harga, metode_pembayaran, prediksi_risiko)
                VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (tanggal, kategori, harga, jumlah, total, metode, prediksi_persen),
            )
            conn.commit()
            conn.close()
    except Exception as e:
        print(f"INFO DATABASE: Gagal simpan ({e})")

# ==========================================
# 3. ENDPOINTS API
# ==========================================
@app.route('/', methods=['GET'])
def health_check():
    return jsonify({
        "status": "online",
        "aplikasi": "Admin Seller Center API",
        "database": "MySQL" if USE_MYSQL else "SQLite",
        "model_loaded": len(trees) > 0,
    }), 200

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json() or {}
        email = str(data.get("email", "")).strip().lower()
        password = str(data.get("password", "")).strip()

        if not email or not password:
            return jsonify({"status": "gagal", "pesan_error": "Email dan password wajib diisi!"}), 400

        if USE_MYSQL:
            conn = get_mysql_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM users WHERE LOWER(username) = %s LIMIT 1", (email,))
            user = cursor.fetchone()
            cursor.close()
            conn.close()
        else:
            conn = get_sqlite_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE LOWER(username) = ? LIMIT 1", (email,))
            row = cursor.fetchone()
            user = dict(row) if row else None
            conn.close()

        if not user:
            return jsonify({"status": "gagal", "pesan_error": "Email tidak terdaftar!"}), 401

        saved_pw = str(user.get("password", ""))
        password_cocok = (saved_pw == password) or (
            saved_pw.startswith(("scrypt:", "pbkdf2:")) and check_password_hash(saved_pw, password)
        )

        if not password_cocok:
            return jsonify({"status": "gagal", "pesan_error": "Password salah!"}), 401

        return jsonify({"status": "sukses", "email": user["username"]}), 200
    except Exception as e:
        return jsonify({"status": "gagal", "pesan_error": f"Gagal cek database: {e}"}), 500

@app.route('/orders', methods=['GET'])
def get_orders():
    try:
        if USE_MYSQL:
            conn = get_mysql_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM orders ORDER BY id DESC")
            rows = cursor.fetchall()
            cursor.close()
            conn.close()
        else:
            conn = get_sqlite_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM orders ORDER BY id DESC")
            rows = [dict(r) for r in cursor.fetchall()]
            conn.close()

        for r in rows:
            for k, v in r.items():
                if isinstance(v, (datetime, date)):
                    r[k] = v.strftime('%Y-%m-%d')
                elif isinstance(v, float):
                    r[k] = round(v, 2)

        return jsonify({"status": "sukses", "total": len(rows), "data": rows}), 200
    except Exception as e:
        return jsonify({"status": "gagal", "pesan_error": str(e), "data": []}), 500

@app.route('/orders/<int:order_id>', methods=['DELETE'])
def delete_order(order_id):
    try:
        if USE_MYSQL:
            conn = get_mysql_connection()
            cursor = conn.cursor()
            cursor.execute("DELETE FROM orders WHERE id = %s", (order_id,))
            conn.commit()
            terhapus = cursor.rowcount
            cursor.close()
            conn.close()
        else:
            conn = get_sqlite_connection()
            cursor = conn.cursor()
            cursor.execute("DELETE FROM orders WHERE id = ?", (order_id,))
            conn.commit()
            terhapus = cursor.rowcount
            conn.close()

        if terhapus == 0:
            return jsonify({"status": "gagal", "pesan_error": "Data tidak ditemukan"}), 404

        return jsonify({"status": "sukses", "pesan": f"Pesanan #{order_id} berhasil dihapus"}), 200
    except Exception as e:
        return jsonify({"status": "gagal", "pesan_error": str(e)}), 500

@app.route('/predict', methods=['POST'])
def predict():
    try:
        if not trees or model_meta is None:
            return jsonify({
                "status": "gagal",
                "pesan_error": "Model prediksi belum berhasil dimuat di backend.",
            }), 500

        data = request.get_json()
        tanggal_str = data.get("tanggal_pesanan")
        if all(k in data for k in ("order_year", "order_month", "order_day", "order_dayofweek")):
            order_year = int(data["order_year"])
            order_month = int(data["order_month"])
            order_day = int(data["order_day"])
            order_dayofweek = int(data["order_dayofweek"])
            if not tanggal_str:
                tanggal_str = f"{order_year:04d}-{order_month:02d}-{order_day:02d}"
        else:
            dt = datetime.strptime(tanggal_str, "%Y-%m-%d")
            order_year = dt.year
            order_month = dt.month
            order_day = dt.day
            order_dayofweek = dt.weekday()

        price = float(data.get("price", data.get("harga_satuan", 0)))
        qty_ordered = int(data.get("qty_ordered", data.get("jumlah", 1)))
        grand_total = float(data.get("grand_total", data.get("total_harga", 0)))

        kategori_ui = str(data.get("category_name_1", data.get("kategori", "")))
        category_name_1 = sesuaikan_kategori_preprocessor(kategori_ui)

        metode_raw = data.get("payment_method_class", data.get("metode_pembayaran", "COD"))
        payment_method_class = normalisasi_metode_pembayaran(metode_raw)

        fitur_pesanan = {
            "price": price,
            "qty_ordered": qty_ordered,
            "grand_total": grand_total,
            "order_year": order_year,
            "order_month": order_month,
            "order_day": order_day,
            "order_dayofweek": order_dayofweek,
            "category_name_1": category_name_1,
            "payment_method_class": payment_method_class,
        }

        prob_awal = hitung_probabilitas_batal(fitur_pesanan)
        risiko_awal_persen = round(prob_awal * 100, 2)
        is_high_risk = prob_awal >= THRESHOLD

        simpan_ke_database(
            tanggal_str,
            category_name_1,
            int(price),
            qty_ordered,
            int(grand_total),
            payment_method_class,
            float(risiko_awal_persen),
        )

        hasil_respons = {
            "status": "sukses",
            "threshold": THRESHOLD,
            "metode_awal": payment_method_class,
            "probabilitas_awal": round(prob_awal, 4),
            "risiko_awal_persen": risiko_awal_persen,
            "status_risiko": "Risiko Tinggi" if is_high_risk else "Di bawah ambang risiko tinggi",
            "perlu_rekomendasi": is_high_risk,
            "rekomendasi_valid": False,
            "metode_rekomendasi": None,
            "probabilitas_akhir": None,
            "risiko_akhir_persen": None,
            "pesan_rekomendasi": None,
            "evaluasi_alternatif": [],
        }

        if is_high_risk:
            alternatif_metode = [m for m in PAYMENT_CLASSES if m != payment_method_class]
            metode_terbaik = None
            prob_terendah = None

            for alt in alternatif_metode:
                fitur_simulasi = fitur_pesanan.copy()
                fitur_simulasi["payment_method_class"] = alt
                prob_alt = hitung_probabilitas_batal(fitur_simulasi)

                hasil_respons["evaluasi_alternatif"].append({
                    "metode": alt,
                    "probabilitas": round(prob_alt, 4),
                    "risiko_persen": round(prob_alt * 100, 2),
                })

                if prob_terendah is None or prob_alt < prob_terendah:
                    prob_terendah = prob_alt
                    metode_terbaik = alt

            if prob_terendah is not None and prob_terendah < THRESHOLD:
                hasil_respons["rekomendasi_valid"] = True
                hasil_respons["metode_rekomendasi"] = metode_terbaik
                hasil_respons["probabilitas_akhir"] = round(prob_terendah, 4)
                hasil_respons["risiko_akhir_persen"] = round(prob_terendah * 100, 2)
                hasil_respons["pesan_rekomendasi"] = (
                    f"Rekomendasi: Ubah pembayaran ke {metode_terbaik} "
                    f"(Risiko turun menjadi {hasil_respons['risiko_akhir_persen']}%)"
                )
            else:
                hasil_respons["rekomendasi_valid"] = False
                hasil_respons["pesan_rekomendasi"] = "Tidak ditemukan alternatif yang memenuhi ambang"

        return jsonify(hasil_respons), 200

    except Exception as e:
        return jsonify({"status": "gagal", "pesan_error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    print(f"API SERVER MENYALA di port {port}!")
    app.run(host='0.0.0.0', port=port, debug=False)
