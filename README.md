# 📱 Aplikasi Manajemen Kehadiran
Aplikasi ini dirancang untuk membantu dalam mengelola kehadiran anggota saat ada event tertentu secara mudah.
Aplikasi ini juga terintergrasi dengan ESP32 untuk sistem ID Card nya agar memudahkan proses presensi.

## 🧩 Fitur Utama
- **Registrasi Anggota**: Pengguna dapat menambahkan ID Card anggota melalui console.
- **Manajemen Anggota**: Pengguna dapat mengedit data anggota ketika data yang di inputkan salah.
- **Manajemen Event**: Pengguna dapat menambahkan, mengedit, dan menghapus data event sesuai kebutuhan.
- **Pemantauan Kehadiran**: Pengguna dapat memantau dan mengatur mode kehadiran anggota pada console aplikasi. 
- **Ekspor Rekap Kehadiran**: Pengguna dapat mengekspor rekapan kehadiran pada suatu event secara langsung dan otomatis.

## 🛠️ Teknologi yang Digunakan
- **Flutter**: Framework untuk pengembangan aplikasi mobile.
- **API**: Untuk mengambil dan mengirim data antara aplikasi dan Supabase (Postgress).

## 🚀 Cara Menjalankan Aplikasi
1. Pastikan sudah menginstall [Flutter](https://docs.flutter.dev/install) di komputer.
2. Clone repository ini ke komputer lokal.
3. Buka terminal di direktori proyek, lalu jalankan perintah berikut:
    ```bash
     flutter pub get
     flutter run
     ```
4. Aplikasi akan berjalan di emulator atau perangkat fisik yang terhubung.