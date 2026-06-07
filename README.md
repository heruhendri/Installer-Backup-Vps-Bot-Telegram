

# 📦 **bot-backup-vps-script**

![License](https://img.shields.io/github/license/heruhendri/Installer-Backup-Vps-Bot-Telegram)
![Stars](https://img.shields.io/github/stars/heruhendri/Installer-Backup-Vps-Bot-Telegram?style=social)
![Forks](https://img.shields.io/github/forks/heruhendri/Installer-Backup-Vps-Bot-Telegram?style=social)
![Issues](https://img.shields.io/github/issues/heruhendri/Installer-Backup-Vps-Bot-Telegram)
![Version](https://img.shields.io/badge/version-5.0.0-blue)

---

# 🛡 **Bot Backup VPS — Telegram Auto Backup by HENDRI (Installer + Menu PRO)**

Script ini membuat sistem **backup otomatis VPS** dengan fitur lengkap:

* Backup folder
* Backup MySQL (multi-host, multi-user, multi-database)
* Backup PostgreSQL
* Backup MongoDB (multi-account, multi-host, multi-database)
* **Telegram Bot Controller** (Akses Menu via Tombol Inline) — **NEW**
* **Real-time Progress** (Persentase penyalinan & kompresi) — **NEW**
* **Security Whitelist** (Hanya username terdaftar yang bisa akses) — **NEW**
* **Full & Selective Restore** (Restore folder tertentu saja) — **NEW**
* systemd service + timer (OnCalendar)
* Menu PRO untuk edit konfigurasi
* Status real-time (auto refresh setiap 1 detik)
* Restore backup → langsung ke root `/`
* Rebuild sistem service/timer/runner
* Encrypt backup (ZIP + password)
* Auto delete file lama (retention)
* **Toggle database (use_mysql / use_pg / use_mongo) — NEW**
* **Dashboard status baru — NEW**

---

# ✨ **FITUR UTAMA**

### 🔥 Backup Lengkap dan Fleksibel

* Backup banyak folder sekaligus (comma separated)

* **MySQL multi config:**

  * multi user
  * multi host
  * database ALL atau list DB
  * format: `user:pass@host:db1,db2`

* **MongoDB multi config — NEW**

  * multi database
  * multi host
  * format:

    ```
    user:pass@host:27017/db1,db2
    ```
  * atau mode ALL:

    ```
    mongodb://user:pass@host:27017/all
    ```

* PostgreSQL full backup (`pg_dumpall`)

* Dapat mengaktifkan/nonaktifkan setiap database lewat menu:

  * use_mysql
  * use_mongo
  * use_pg

---

# 🔔 Notifikasi Telegram

* Backup dikirim ke Telegram sebagai file
* Nama file + ukuran + waktu otomatis
* Mendukung caption lengkap

---

# ⚙️ Otomatis dan Stabil

* Menggunakan systemd service + timer
* Jadwal OnCalendar lengkap
* Timezone otomatis disesuaikan saat instalasi
* Rebuild otomatis jika ada file rusak

---

# 🛠 Menu PRO (Dashboard Baru)

Saat menjalankan:

```
menu-bot-backup
```

[Tampilan dashboard baru:](https://github.com/heruhendri/Installer-Backup-Vps-Bot-Telegram/blob/master/dash.png)

```
========== BACKUP DASHBOARD BY HENDRI ==========

 Status Service   : INACTIVE
 Next Schedule    : Sat 2025-12-06
 Last Backup File : backup-2025-12-06-0110.tar.gz
 Total Backup     : 10
```

---

# 📋 **MENU AKSI LENGKAP (VERSI BARU)**

```
---------------------- MENU AKSI ---------------------------
[1]  Lihat konfigurasi
[2]  Edit BOT TOKEN
[3]  Edit CHAT ID
[4]  Tambah folder backup
[5]  Hapus folder backup
[6]  Tambah konfigurasi MySQL
[7]  Edit konfigurasi MySQL
[8]  Hapus konfigurasi MySQL
[9]  Tambah konfigurasi MongoDB
[10] Edit konfigurasi MongoDB
[11] Hapus konfigurasi MongoDB
[12] Edit PostgreSQL settings & test dump
[13] Ubah timezone
[14] Ubah retention days
[15] Ubah jadwal backup (OnCalendar helper)
[16] Test backup sekarang
[17] Restore dari backup
[18] Rebuild / Repair installer files (service/timer/runner)
[19] Encrypt latest backup (zip with password)
[20] Restart service & timer
[21] Simpan config
[22] Status (service / last backup / next run)
[23] Status Realtime (live monitor)
[24] Gunakan MySQL (use_mysql)
[25] Gunakan MongoDB (use_mongo)
[26] Gunakan PostgreSQL (use_pg)
[0]  Keluar (tanpa simpan)
```

---

# 🔒 **Keamanan**

* Config disimpan di:
  `/opt/auto-backup/config.conf`
* Permission otomatis `chmod 600`
* Password MySQL, PostgreSQL, MongoDB tidak ditampilkan

---

# 🚀 **INSTALASI CEPAT**

Jalankan installer:

```bash
bash <(curl -s https://raw.githubusercontent.com/heruhendri/Installer-Backup-Vps-Bot-Telegram/update/install-backupvps-telegram.sh)
```
<!--
Atau versi branch terbaru:

```bash
bash <(curl -s https://raw.githubusercontent.com/heruhendri/Installer-Backup-Vps-Bot-Telegram/menu-bot/install-backupvps-telegram.sh)
```
```bash
bash <(curl -s https://raw.githubusercontent.com/heruhendri/Installer-Backup-Vps-Bot-Telegram/menu-bot/fixx.sh)
``` -->

---

# 🛠 **UPDATE KONFIGURASI (MENU PRO)**

Akses menu:

```
menu-bot-backup
```

Menu berisi:

* Edit token/chat id
* Manajemen folder
* Manajemen MySQL
* Manajemen PostgreSQL
* **Manajemen MongoDB (baru)**
* Test backup
* Restore
* Encrypt ZIP
* Rebuild runner/service/timer
* Status & status realtime
* Toggle database
* Save config

---

# 🧠 **ARSITEKTUR BACKUP SYSTEM**

```mermaid
flowchart TD
    A[VPS Server] --> B[Backup Runner]

    A --> C[MySQL Dump]
    A --> D[PostgreSQL Dump]
    A --> E[MongoDB Dump]

    B --> F[Create Archive]
    F --> G[Backup Folder]
    G --> H[Send to Telegram]

    I[Systemd Timer] --> B
    J[Systemd Service] --> B

    K[Menu PRO] --> L[Edit config.conf]
    K --> M[Rebuild System]

    L --> B
    M --> B
```

---

# 🚲 **ALUR BACKUP SYSTEM**

```mermaid
flowchart TD
    Start([Start]) --> Load[Load Config]
    Load --> Auth{Username Allowed?}
    Auth -- No --> Alert[Send Security Alert]
    Auth -- Yes --> Tmp[Create Temp Dir]

    Tmp --> Copy[Copy Folders with Progress]

    Copy --> MySQL{Use MySQL?}
    MySQL -->|Yes| DumpMySQL[Dump MySQL]
    MySQL -->|No| SkipMySQL[Skip]

    DumpMySQL --> Mongo{Use MongoDB?}
    SkipMySQL --> Mongo

    Mongo -->|Yes| DumpMongo[Dump MongoDB]
    Mongo -->|No| SkipMongo[Skip]

    DumpMongo --> PG{Use PostgreSQL?}
    SkipMongo --> PG

    PG -->|Yes| DumpPG[Dump PostgreSQL]
    PG -->|No| SkipPG[Skip]

    DumpPG --> Tar[Create TAR.GZ]
    SkipPG --> Tar

    Tar --> Send{Send to Telegram?}

    Send -->|Yes| Upload[Upload File]
    Send -->|No| SkipSend[Skip]

    Upload --> Clean[Cleanup Temp]
    SkipSend --> Clean

    Clean --> Retention[Delete Old Backups]

    Retention --> End([Done])
```
---

# 📂 **STRUKTUR DIREKTORI**

| Path                                      | Deskripsi               |
| ----------------------------------------- | ----------------------- |
| `/opt/auto-backup/config.conf`            | File konfigurasi utama  |
| `/opt/auto-backup/backup-runner.sh`       | Script backup inti      |
| `/opt/auto-backup/bot-control.sh`         | Service kontroler Bot Telegram |
| `/opt/auto-backup/menu.sh`                | Menu PRO                |
| `/usr/bin/menu-bot-backup`                | Symlink global          |
| `/opt/auto-backup/backups/`               | Folder backup           |
| `/etc/systemd/system/auto-backup.service` | Service backup          |
| `/etc/systemd/system/auto-backup.timer`   | Timer OnCalendar        |
| `/etc/systemd/system/auto-backup-bot.service` | Service Bot Telegram |
| `install-backupvps-telegram.sh`           | Installer (auto delete) |


# 📝 **PENJELASAN SCRIPT UTAMA**

## 1️⃣ **Installer**

Fungsi:

* Input parameter
* Generate semua file
* Setup config
* Setup runner
* Setup service & timer
* Backup pertama langsung berjalan
* Hapus dirinya sendiri

---

## 2️⃣ **Menu PRO (Lengkap)**

### 👍 Management Folder

* tambah
* hapus

### 👍 Management MySQL

* multi konfigurasi
* edit
* delete

Format:

```
user:password@host:DB1,DB2
```

### 👍 Management MongoDB — NEW

* tambah konfigurasi
* edit
* delete
* test dump
* support ALL DB

Format:

```
user:pass@host:27017/db1,db2
```

### 👍 PostgreSQL

* enable/disable
* test dump `pg_dumpall`

### 👍 Sistem

* timezone
* retention
* jadwal OnCalendar
* restart service/timer
* rebuild file corrupt

### 👍 Backup & Restore

* test backup
* restore ke `/`
* preview isi archive

### 👍 Status

* status lengkap
* status realtime (refresh 1 detik)

### 👍 Toggle Database — NEW

* use_mysql on/off
* use_mongo on/off
* use_pg on/off

---

## 3️⃣ **Backup Runner**

Melakukan:

* copy folder
* dump MySQL
* dump PostgreSQL
* dump MongoDB — NEW
* compress tar.gz
* kirim Telegram
* hapus temp
* hapus file lama sesuai retention

---

# 🔐 **ENCRYPT BACKUP**

Tersedia di menu:

```
Encrypt latest backup
```

---

# 🧪 **TEST SERVICE**

```
systemctl status auto-backup
systemctl start auto-backup
systemctl list-timers | grep auto-backup
```

---

# 🧹 **RETENTION AUTO CLEAN**

```
find /opt/auto-backup/backups -type f -mtime +RETENTION_DAYS -delete
```

---

# 🩹 **RESTORE BACKUP**

* pilih file
* preview isi (list folder)
* **Restore Selektif**: Pilih folder spesifik yang ingin di-restore.
* extract temp
* rsync ke root `/`
* konfirmasi 2 tahap

---

# 🙌 **KONTRIBUSI**

Pull Request dan Issue sangat diterima.

Repo:
👉 [https://github.com/heruhendri/bot-backup-vps-script](https://github.com/heruhendri/bot-backup-vps-script)

---

# 📜 **LISENSI**

MIT License.
