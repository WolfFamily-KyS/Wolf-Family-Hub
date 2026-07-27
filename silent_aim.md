# Silent Aim - Cara Kerjanya

## Apa itu Silent Aim?

Silent Aim adalah fitur yang secara otomatis menyesuaikan arah peluru untuk mengenai target tanpa perlu aim manual. Dari perspektif target, peluru terlihat datang dari arah yang tidak terduga.

Di game seperti Violence District, dimana kamu bermain sebagai Survivor dengan pistol (Twist of Fate), Silent Aim memungkinkan kamu menembak Killer tanpa harus aim langsung ke arah mereka.

---

## Bagaimana Cara Kerjanya?

Silent Aim bekerja dengan cara mengintersepsi request tembakan dari pistol dan memodifikasi **vektor arah** sebelum dikirim ke server game.

### Menembak Normal (Biasa)
```
1. Player aim ke target
2. Klik tombol tembak
3. Game menghitung arah berdasarkan kemana kamu aim
4. Kirim arah ke server
5. Server spawn peluru dengan arah tersebut
```

### Menembak Silent Aim (Dimodifikasi)
```
1. Player klik tembak (tidak perlu aim)
2. Script deteksi posisi target
3. Script hitung arah ke target
4. Script kirim arah yang SUDAH DIMODIFIKASI ke server
5. Server spawn peluru menuju target (meskipun kamu aim ke arah lain)
```

---

## Komponen Inti

### 1. Deteksi Target
Script melakukan scan semua player di game untuk menemukan Killer:

```lua
for each player in game:
    if player.Team == "Killer":
        return player as target
```

**Hasil:** Script tahu player mana yang harus ditembak.

---

### 2. Deteksi Senjata
Script mengecek apakah kamu sudah equipped pistol:

```lua
Cek character untuk tool "Twist of Fate"
Cek model pistol di dalam tool berdasarkan skin yang dipilih:
    - Default: RightArm/gun
    - EmperorGun: RightArm/EmperorGun
    - AWP: Tool itu sendiri
```

**Hasil:** Script tahu dari mana harus menembak.

---

### 3. Pelacakan Kecepatan
Script melacak kecepatan dan arah gerakan target:

```lua
Setiap frame:
    Catat posisi killer saat ini
    Bandingkan dengan posisi sebelumnya
    Hitung: velocity = (posisi sekarang - posisi lalu) / waktu
```

**Contoh:**
- Killer ada di posisi (100, 0, 50) pada waktu 1.0
- Killer ada di posisi (116, 0, 50) pada waktu 2.0
- Velocity = (116-100, 0, 0) / (2.0-1.0) = (16, 0, 0) studs/detik
- **Kesimpulan:** Killer bergerak ke kanan dengan kecepatan 16 studs/detik (sprint)

---

### 4. Kalkulasi Prediksi
Karena peluru butuh waktu untuk sampai, script memprediksi dimana Killer akan berada:

```lua
jarak = jarak dari kamu ke killer (misal: 100 studs)
kecepatan_peluru = 500 studs/detik
waktu_ke_target = jarak / kecepatan_peluru = 100 / 500 = 0.2 detik

Jika killer bergerak:
    prediksi = velocity × waktu_ke_target
    posisi_prediksi = posisi_sekarang + prediksi
```

**Contoh:**
- Killer ada di (100, 0, 50)
- Killer bergerak ke kanan 16 studs/detik
- Peluru butuh 0.2 detik untuk sampai
- Prediksi = 16 × 0.2 = 3.2 studs
- **Aim ke:** (103.2, 0, 50) bukan ke (100, 0, 50)

**Visual:**
```
Killer bergerak ke kanan →→→
    [K]---------> (akan ada disini dalam 0.2 detik)
           ↑
     AIM KESINI (bukan ke posisi sekarang)
```

---

### 5. Penyesuaian Offset
Fine-tune aim dengan offset manual:

```lua
posisi_akhir = posisi_prediksi + offset

offset = (X, Y, Z) dalam studs
    X: Penyesuaian kiri/kanan (positif = kanan)
    Y: Penyesuaian atas/bawah (negatif = bawah)
    Z: Penyesuaian depan/belakang
```

**Contoh:**
- Offset X = 5.0 (aim 5 studs ke kanan)
- Offset Y = -2.5 (aim 2.5 studs ke bawah, targeting dada)
- Offset Z = 0.0 (tidak ada penyesuaian depan/belakang)

---

### 6. Kalkulasi Arah
Hitung vektor arah final:

```lua
posisi_target_akhir = posisi_prediksi + offset
arah = (posisi_target_akhir - posisi_kamu).Unit

Unit = normalisasi vektor ke panjang 1.0
```

**Contoh:**
- Kamu ada di (0, 0, 0)
- Target akhir di (100, 10, 0)
- Arah = (100, 10, 0) / panjang = (0.995, 0.099, 0)

---

### 7. Fire Remote
Kirim arah yang sudah dimodifikasi ke server:

```lua
game.ReplicatedStorage.Remotes.Items["Twist of Fate"].Fire:FireServer(gun, direction)
```

**Yang terjadi:**
- Server menerima vektor arah
- Server tidak tahu kamu tidak aim manual
- Server spawn peluru dengan arah custom kamu
- Peluru meluncur otomatis menuju killer
- ✅ Killer kena tembak meskipun kamu tidak aim ke mereka

---

## Formula Matematika

### Rantai Kalkulasi Lengkap

```
1. Deteksi Posisi Killer:
   posisi_killer = Killer.HumanoidRootPart.Position

2. Hitung Velocity:
   velocity = (posisi_sekarang - posisi_lalu) / delta_waktu

3. Hitung Waktu ke Target:
   jarak = |posisi_killer - posisi_player|
   waktu_ke_target = jarak / 500

4. Hitung Prediksi:
   JIKA velocity.magnitude > 2.0:
       prediksi = velocity × waktu_ke_target
       
       JIKA jarak > 100:
           skala = 100 / jarak
           prediksi = prediksi × skala
   SELAIN ITU:
       prediksi = (0, 0, 0)

5. Terapkan Offset:
   target = posisi_killer + prediksi + offset

6. Hitung Arah:
   arah = (target - posisi_player).Unit

7. Tembak:
   FireServer(gun, arah)
```

---

## Kenapa Ini Bisa Bekerja (Penjelasan Teknis)

### Arsitektur Client-Server
Kebanyakan game online menggunakan model client-server:

1. **Client** (game kamu) mengirim input ke server
2. **Server** validasi dan proses input tersebut
3. **Server** broadcast hasil ke semua client

### Kelemahannya
Saat kamu menembak:
- Client kirim: `FireServer(gun, direction)`
- Server percaya dengan vektor arah tersebut
- Server tidak verifikasi apakah kamu benar-benar aim kesana

**Silent Aim mengeksploitasi ini** dengan mengirim arah yang dikalkulasi, bukan arah aim asli kamu.

---

## Analogi Dunia Nyata

Bayangkan kamu main dart:

**Dart Normal:**
- Kamu lihat ke papan target
- Kamu aim lengan kamu
- Kamu lempar
- Dart pergi kemana kamu aim

**Dart Silent Aim:**
- Kamu lihat ke lantai (aim palsu)
- Robot menghitung dimana target berada
- Robot sesuaikan arah lengan kamu secara tidak terlihat
- Dart kena target meskipun kamu "aim" ke lantai
- Penonton melihat kamu lempar tanpa aim, tapi tetap kena target

---

## Faktor Akurasi

### Kenapa Prediksi Diperlukan
Tanpa prediksi, kamu akan miss target yang bergerak:

```
Skenario: Killer lari 16 studs/detik
Jarak: 100 studs
Waktu tempuh peluru: 0.2 detik

Tanpa prediksi:
    Peluru sampai di (100, 0, 50)
    Killer sekarang di (103.2, 0, 50)
    ❌ MISS sebesar 3.2 studs

Dengan prediksi:
    Peluru ditembakkan ke (103.2, 0, 50)
    Killer sampai di (103.2, 0, 50)
    ✅ KENA
```

### Skalasi Jarak
Untuk target yang sangat jauh, prediksi dikurangi:

```
JIKA jarak > 100 studs:
    skala = 100 / jarak
    prediksi = prediksi × skala
```

**Alasan:** Network latency dan server tick rate membuat prediksi jarak jauh kurang akurat.

---

## Tujuan Offset

Offset memungkinkan fine-tuning untuk akurasi maksimal:

### Kasus Penggunaan Umum

**Offset X (Horizontal):**
- Kompensasi network lag
- Sesuaikan untuk tepi hitbox

**Offset Y (Vertikal):**
- Target bagian tubuh spesifik (kepala, dada, kaki)
- Kompensasi perbedaan ketinggian

**Offset Z (Kedalaman):**
- Jarang digunakan
- Bisa kompensasi gerakan mendekat/menjauh

### Contoh Konfigurasi
```
Offset X = 5.0   → Target sedikit ke kanan
Offset Y = -2.5  → Target area dada (dibawah kepala)
Offset Z = 0.0   → Tidak ada penyesuaian kedalaman

Hasil: Tembakan dada yang konsisten
```

---

## Indikator Visual (Line Tracer)

Line tracer menampilkan kemana kamu sebenarnya aim:

```lua
Setiap frame:
    1. Ambil posisi pistol (barrel)
    2. Ambil posisi target yang diprediksi
    3. Gambar beam dari pistol ke target
    4. Update warna dan transparansi beam
```

**Tujuan:**
- Visual feedback untuk debugging
- Konfirmasi prediksi bekerja dengan benar
- Sesuaikan offset dengan melihat kemana garis menunjuk

---

## Keterbatasan

### 1. Pistol Harus Equipped
- Silent Aim hanya bekerja jika "Twist of Fate" sudah equipped
- Skin pistol berbeda punya struktur model berbeda

### 2. Target Harus Ada
- Hanya bekerja jika ada Killer di game
- Tidak akan bekerja terhadap Survivor lain

### 3. Bergantung Network
- Ping tinggi mengurangi akurasi
- Server lag bisa menyebabkan miss
- Prediksi kompensasi tapi tidak sempurna

### 4. Terlihat oleh Penonton
- Player lain bisa melihat peluru datang dari arah yang salah
- Line tracer hanya terlihat oleh kamu (visual client-side)

---

## Perbandingan dengan Aim Assist Lain

### Aimbot
- Menggerakkan kamera ke target
- **Terlihat** oleh semua orang (kamera snap ke target)
- Mudah dideteksi

### Silent Aim
- Tidak menggerakkan kamera
- **Tidak terlihat** oleh penonton (aim terlihat normal)
- Lebih sulit dideteksi

### Triggerbot
- Auto-klik saat crosshair mengenai target
- Memerlukan aim manual
- Hanya otomatis klik

### Keuntungan Silent Aim
- Tidak ada gerakan kamera
- Tidak perlu aim
- Bekerja dengan posisi crosshair apapun

---

## Deteksi & Anti-Cheat

### Cara Game Mendeteksinya

**Validasi Server-Side:**
```lua
if sudut_antara(arah_kamera, arah_tembakan) > threshold:
    flag_as_suspicious()
```

**Contoh:**
- Kamera kamu lihat ke tanah (0, -1, 0)
- Peluru kamu pergi ke depan (0, 0, 1)
- Perbedaan sudut = 90 derajat
- ⚠️ Tidak mungkin tanpa cheat

**Analisis Statistik:**
- Lacak hit rate (misal: 100% headshot)
- Lacak deviasi aim dari arah kamera
- Flag akun dengan akurasi tidak manusiawi

### Cara Mengurangi Risiko Deteksi

1. **Jangan pakai line tracer di publik** (bukti visual)
2. **Sesuaikan offset** untuk miss sesekali
3. **Jangan tembak saat melihat menjauh** (mismatch yang jelas)
4. **Gunakan hemat** (hit rate tinggi = mencurigakan)

---

## Educational Purpose

This documentation is for **educational purposes only** to understand:
- Client-server communication in online games
- Vector mathematics in 3D game engines
- Prediction algorithms for moving targets
- Network programming concepts

**Not intended for:**
- Gaining unfair advantage in competitive games
- Disrupting other players' experience
- Violating game terms of service

---

## Tujuan Edukasi

Dokumentasi ini dibuat untuk **tujuan edukasi** agar memahami:
- Komunikasi client-server di game online
- Matematika vektor dalam game engine 3D
- Algoritma prediksi untuk target bergerak
- Konsep network programming

**Tidak dimaksudkan untuk:**
- Mendapatkan keuntungan tidak adil di game kompetitif
- Mengganggu pengalaman player lain
- Melanggar terms of service game

---

## Glosarium Istilah Teknis

| Istilah | Definisi |
|---------|----------|
| **Vektor Arah** | Vektor 3D (x, y, z) yang menunjukkan arah, dinormalisasi ke panjang 1.0 |
| **Velocity** | Kecepatan dan arah gerakan (studs/detik) |
| **Prediksi** | Estimasi posisi masa depan berdasarkan gerakan saat ini |
| **Offset** | Penyesuaian manual untuk kompensasi error |
| **Unit Vector** | Vektor dengan magnitude (panjang) 1.0 |
| **Studs** | Unit pengukuran Roblox (1 stud ≈ 28cm di dunia nyata) |
| **Remote** | Objek networking Roblox untuk komunikasi client-server |
| **FireServer** | Fungsi untuk mengirim data dari client ke server |
| **Magnitude** | Panjang vektor (misal: kecepatan dalam studs/detik) |
| **Delta Time** | Waktu yang berlalu antara dua frame |

---

## Ringkasan

Silent Aim bekerja dengan:
1. **Mendeteksi** target (Killer)
2. **Melacak** velocity gerakan mereka
3. **Memprediksi** dimana mereka akan berada saat peluru sampai
4. **Menghitung** arah presisi dengan offset
5. **Mengintersepsi** request tembakan
6. **Memodifikasi** vektor arah
7. **Mengirim** ke server seolah-olah itu aim asli kamu

Hasilnya: peluru mengenai target tanpa aim manual, terlihat seolah kamu punya akurasi sempurna tanpa menggerakkan kamera.

---

*Terakhir Diupdate: 2026*  
*Untuk Tujuan Edukasi*
