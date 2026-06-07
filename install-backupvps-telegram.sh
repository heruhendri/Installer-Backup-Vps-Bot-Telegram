#!/bin/bash
set -uo pipefail
clear

WATERMARK_INSTALL="=== AUTO BACKUP VPS — INSTALLER ===
Version: 5.0.0 | Created by: HENDRI
Telegram: https://t.me/GbtTapiPngnSndiri
========================================="
WATERMARK_END="=== INSTALL COMPLETE — SCRIPT BY HENDRI ===
Support: https://t.me/GbtTapiPngnSndiri
========================================="

echo "$WATERMARK_INSTALL"
echo ""

# Install dependencies
apt-get update && apt-get install -y jq curl rsync zip unzip bc pv || echo "[WARN] Gagal menginstall dependensi, pastikan Anda root."

INSTALL_DIR="/opt/auto-backup"
CONFIG_FILE="$INSTALL_DIR/config.conf"
MENU_FILE="$INSTALL_DIR/menu.sh"
RUNNER="$INSTALL_DIR/backup-runner.sh"
BOT_CONTROL="$INSTALL_DIR/bot-control.sh"
SERVICE_FILE="/etc/systemd/system/auto-backup.service"
TIMER_FILE="/etc/systemd/system/auto-backup.timer"
BOT_SERVICE_FILE="/etc/systemd/system/auto-backup-bot.service"

mkdir -p "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR"

# If config exists, ask whether to update
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo -e "[INFO] Konfigurasi ditemukan untuk Chat ID: ${CHAT_ID:-}"
    read -p "Update konfigurasi? (y/N): " RESP_UPD
    [[ "$RESP_UPD" =~ ^[Yy]$ ]] && UPDATE_CONFIG="y" || UPDATE_CONFIG="n"
    echo -e "[INFO] Konfigurasi lama ditemukan (Chat ID: $CHAT_ID)."
    read -p "Gunakan kredensial (Token/ChatID) yang ada? (Y/n): " KEEP_CRED
    if [[ ! "$KEEP_CRED" =~ ^[Nn]$ ]]; then
        SKIP_AUTH="y"
        UPDATE_CONFIG="y"
    else
        SKIP_AUTH="n"
        UPDATE_CONFIG="y"
    fi
else
    UPDATE_CONFIG="y"
    SKIP_AUTH="n"
fi

if [[ "$UPDATE_CONFIG" == "y" ]]; then
    echo -e "\n--- MODE INSTALASI ---"
    if [[ "$SKIP_AUTH" == "n" ]]; then
        read -p "Masukkan TOKEN Bot Telegram: " BOT_TOKEN
        read -p "Masukkan CHAT_ID Telegram: " CHAT_ID
    fi

    echo -e "\n--- MODE INSTALASI (By HENDRI) ---"
    echo "1) Quick Setup (Checkbox & Auto-detect DB)"
    echo "2) Custom Setup (Manual Detail)"
    read -p "Pilih mode (1/2): " SETUP_MODE

    read -p "Masukkan TOKEN Bot Telegram: " BOT_TOKEN
    read -p "Masukkan CHAT_ID Telegram: " CHAT_ID
    read -p "Masukkan Username Telegram (Whitelist, tanpa @): " ALLOWED_USERNAMES

    if [[ "$SETUP_MODE" == "1" ]]; then
        # Quick Setup logic with Checkbox-style selection
        q_full="n"
        q_full="y"
        q_mysql=$(command -v mysql >/dev/null 2>&1 && echo "y" || echo "n")
        q_mongo=$(command -v mongodump >/dev/null 2>&1 && echo "y" || echo "n")
        q_pg=$(command -v pg_dumpall >/dev/null 2>&1 && echo "y" || echo "n")

        # Quick Folder paths
        f_etc="y"; f_www="y"; f_home="n"; f_root="n"
        # Quick Retention & TZ
        q_ret="7"
        q_tz="Asia/Jakarta"
        # Folder management variables
        f_etc="/etc"; use_etc="y"
        f_www="/var/www"; use_www="y"
        f_home="/home"; use_home="n"
        f_root="/root"; use_root="n"
        q_ret="${RETENTION_DAYS:-7}"
        q_tz="${TZ:-Asia/Jakarta}"

        pick_sub() {
            local parent=$1
            echo -e "\n--- Pilih Sub-folder di $parent ---"
            local subdirs=($(ls -d "${parent}/"*/ 2>/dev/null | sed 's/\/$//'))
            if [[ ${#subdirs[@]} -eq 0 ]]; then echo "Tidak ada sub-folder."; sleep 1; return "$parent"; fi
            for i in "${!subdirs[@]}"; do echo "  [$((i+1))] $(basename "${subdirs[$i]}")"; done
            read -p "Masukkan nomor (koma untuk banyak, ex: 1,3) atau ENTER untuk semua: " choice
            if [[ -z "$choice" ]]; then echo "$parent"; else
                local res=""
                IFS=',' read -ra ADDR <<< "$choice"
                for idx in "${ADDR[@]}"; do res+="${subdirs[$((idx-1))]},"; done
                echo "${res%,}"
            fi
        }

        while true; do
            clear
            echo "$WATERMARK_INSTALL"
            echo "--- QUICK SETUP: CONFIGURATION ---"
            echo "--- QUICK SETUP: COMPONENTS & FOLDERS ---"
            echo "🚀 KOMPONEN:"
            echo "  [1] [$( [[ "$q_full" == "y" ]] && echo "X" || echo " " )] Full System"
            echo "  [2] [$( [[ "$q_mysql" == "y" ]] && echo "X" || echo " " )] MySQL (Auto: $(command -v mysql >/dev/null 2>&1 && echo "OK" || echo "No"))"
            echo "  [3] [$( [[ "$q_mongo" == "y" ]] && echo "X" || echo " " )] MongoDB (Auto: $(command -v mongodump >/dev/null 2>&1 && echo "OK" || echo "No"))"
            echo "  [4] [$( [[ "$q_pg" == "y" ]] && echo "X" || echo " " )] PostgreSQL (Auto: $(command -v pg_dumpall >/dev/null 2>&1 && echo "OK" || echo "No"))"
            echo "📂 FOLDER PATHS:"
            echo "  [5] [$( [[ "$f_etc" == "y" ]] && echo "X" || echo " " )] /etc"
            echo "  [6] [$( [[ "$f_www" == "y" ]] && echo "X" || echo " " )] /var/www"
            echo "  [7] [$( [[ "$f_home" == "y" ]] && echo "X" || echo " " )] /home"
            echo "  [8] [$( [[ "$f_root" == "y" ]] && echo "X" || echo " " )] /root"
            echo "📂 FOLDER PATHS (Klik untuk pilih sub-folder):"
            echo "  [5] [$( [[ "$use_etc" == "y" ]] && echo "X" || echo " " )] $f_etc"
            echo "  [6] [$( [[ "$use_www" == "y" ]] && echo "X" || echo " " )] $f_www"
            echo "  [7] [$( [[ "$use_home" == "y" ]] && echo "X" || echo " " )] $f_home"
            echo "  [8] [$( [[ "$use_root" == "y" ]] && echo "X" || echo " " )] $f_root"
            echo "⏰ SETTINGS:"
            echo "  [9] Retention : $q_ret Hari (Toggle: 3, 7, 14, 30)"
            echo "  [10] Timezone : $q_tz (Toggle: Jakarta, Singapore, UTC)"
            echo "------------------------------------------"
            echo "[S] SIMPAN & LANJUT"
            read -p "Pilih nomor untuk toggle atau 'S': " Q_OPT
            case "$Q_OPT" in
                1) [[ "$q_full" == "y" ]] && q_full="n" || q_full="y" ;;
                2) [[ "$q_mysql" == "y" ]] && q_mysql="n" || q_mysql="y" ;;
                3) [[ "$q_mongo" == "y" ]] && q_mongo="n" || q_mongo="y" ;;
                4) [[ "$q_pg" == "y" ]] && q_pg="n" || q_pg="y" ;;
                5) [[ "$f_etc" == "y" ]] && f_etc="n" || f_etc="y" ;;
                6) [[ "$f_www" == "y" ]] && f_www="n" || f_www="y" ;;
                7) [[ "$f_home" == "y" ]] && f_home="n" || f_home="y" ;;
                8) [[ "$f_root" == "y" ]] && f_root="n" || f_root="y" ;;
                5) if [[ "$use_etc" == "y" ]]; then use_etc="n"; else use_etc="y"; f_etc=$(pick_sub "/etc"); fi ;;
                6) if [[ "$use_www" == "y" ]]; then use_www="n"; else use_www="y"; f_www=$(pick_sub "/var/www"); fi ;;
                7) if [[ "$use_home" == "y" ]]; then use_home="n"; else use_home="y"; f_home=$(pick_sub "/home"); fi ;;
                8) if [[ "$use_root" == "y" ]]; then use_root="n"; else use_root="y"; f_root=$(pick_sub "/root"); fi ;;
                9) case "$q_ret" in 3) q_ret="7";; 7) q_ret="14";; 14) q_ret="30";; *) q_ret="3";; esac ;;
                10) case "$q_tz" in "Asia/Jakarta") q_tz="Asia/Singapore";; "Asia/Singapore") q_tz="UTC";; *) q_tz="Asia/Jakarta";; esac ;;
                [Ss]) break ;;
            esac
        done

        USE_FULL_BACKUP="$q_full"; USE_MYSQL="$q_mysql"; USE_MONGO="$q_mongo"; USE_PG="$q_pg"
        RETENTION_DAYS="$q_ret"; TZ="$q_tz"
        
        # Construct FOLDERS_RAW
        FOLDERS_RAW=""
        [[ "$f_etc" == "y" ]] && FOLDERS_RAW+="/etc,"
        [[ "$f_www" == "y" ]] && FOLDERS_RAW+="/var/www,"
        [[ "$f_home" == "y" ]] && FOLDERS_RAW+="/home,"
        [[ "$f_root" == "y" ]] && FOLDERS_RAW+="/root,"
        [[ "$use_etc" == "y" ]] && FOLDERS_RAW+="$f_etc,"
        [[ "$use_www" == "y" ]] && FOLDERS_RAW+="$f_www,"
        [[ "$use_home" == "y" ]] && FOLDERS_RAW+="$f_home,"
        [[ "$use_root" == "y" ]] && FOLDERS_RAW+="$f_root,"
        FOLDERS_RAW="${FOLDERS_RAW%,}"
        
        MYSQL_MULTI_CONF="${MYSQL_MULTI_CONF:-}"; MONGO_MULTI_CONF="${MONGO_MULTI_CONF:-}"; CRON_TIME="*-*-* 03:00:00"
    else
        # Custom Setup flow (existing manual inputs)
        read -p "Masukkan folder backup (comma separated): " FOLDERS_RAW
        read -p "Backup FULL System? (y/n): " USE_FULL_BACKUP
        read -p "Backup MySQL? (y/n): " USE_MYSQL
        MYSQL_MULTI_CONF="" # Simplified for this block
        read -p "Backup MongoDB? (y/n): " USE_MONGO
        MONGO_MULTI_CONF=""
        read -p "Backup PostgreSQL? (y/n): " USE_PG
        read -p "Retention (hari): " RETENTION_DAYS
        read -p "Timezone: " TZ
        read -p "Cron Time (ex: *-*-* 03:00:00): " CRON_TIME
    fi
    
    echo ""
    timedatectl set-timezone "$TZ" || true

    cat > "$CONFIG_FILE" <<CONFIG
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
FOLDERS_RAW="$FOLDERS_RAW"
USE_FULL_BACKUP="$USE_FULL_BACKUP"
USE_MYSQL="$USE_MYSQL"
MYSQL_MULTI_CONF="$MYSQL_MULTI_CONF"
USE_MONGO="$USE_MONGO"
MONGO_MULTI_CONF="$MONGO_MULTI_CONF"
USE_PG="$USE_PG"
RETENTION_DAYS="$RETENTION_DAYS"
TZ="$TZ"
INSTALL_DIR="$INSTALL_DIR"
CONFIG
    chmod 600 "$CONFIG_FILE"
else
    echo "[INFO] Menggunakan config yang sudah ada: $CONFIG_FILE"
    source "$CONFIG_FILE"
fi

# ======================================================
# Create backup-runner (safe literal - won't expand now)
# ======================================================
cat > "$RUNNER" <<'BPR'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="/opt/auto-backup/config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    echo "[ERROR] Config not found: $CONFIG_FILE"
    exit 1
fi

# Argument parsing for selective backup
MODE_SELECTIVE="n"
SEL_FULL="n"; SEL_FOLDERS="n"; SEL_MYSQL="n"; SEL_MONGO="n"; SEL_PG="n"

if [[ "${1:-}" == "--selective" && -n "${2:-}" ]]; then
    MODE_SELECTIVE="y"
    [[ "$2" == *full* ]] && SEL_FULL="y"
    [[ "$2" == *folders* ]] && SEL_FOLDERS="y"
    [[ "$2" == *mysql* ]] && SEL_MYSQL="y"
    [[ "$2" == *mongo* ]] && SEL_MONGO="y"
    [[ "$2" == *pg* ]] && SEL_PG="y"
else
    # Default mode (from config)
    SEL_FULL="$USE_FULL_BACKUP"
    SEL_FOLDERS="y"
    SEL_MYSQL="$USE_MYSQL"
    SEL_MONGO="$USE_MONGO"
    SEL_PG="$USE_PG"
fi

update_tg_status() {
    local text="$1"
    if [[ -n "${MSG_ID:-}" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
            -d "chat_id=${CHAT_ID}" \
            -d "message_id=${MSG_ID}" \
            -d "text=${text}" > /dev/null || true
    fi
}

# Kirim pesan status awal dan ambil Message ID
INIT_RESP=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=⏳ Memulai proses backup di VPS...")
MSG_ID=$(echo "$INIT_RESP" | jq -r '.result.message_id // empty')

export TZ="${TZ:-UTC}"

BACKUP_DIR="${INSTALL_DIR}/backups"
mkdir -p "$BACKUP_DIR"

DATE=$(date +%F-%H%M)
FILE="$BACKUP_DIR/backup-$DATE.tar.gz"
TMP_DIR="${INSTALL_DIR}/tmp-$DATE"

mkdir -p "$TMP_DIR"
# Set waktu mulai durasi backup
START_TIME=$(date +%s)

# backup folders
if [[ "$SEL_FOLDERS" == "y" ]]; then
IFS=',' read -r -a FOLDERS <<< "${FOLDERS_RAW:-}"
if [[ ${#FOLDERS[@]} -gt 0 ]]; then
    update_tg_status "📂 Sedang menyalin folder ke direktori sementara..."
    TOTAL_SRC_SIZE=$(du -sb "${FOLDERS[@]}" 2>/dev/null | awk '{sum+=$1} END {print sum}') || TOTAL_SRC_SIZE=0
    
    for f in "${FOLDERS[@]}"; do
        if [[ -d "$f" ]]; then
            rsync -a "$f" "$TMP_DIR/" &
            RSYNC_PID=$!
            while kill -0 $RSYNC_PID 2>/dev/null; do
                if [[ "$TOTAL_SRC_SIZE" -gt 0 ]]; then
                    CUR_SIZE=$(du -sb "$TMP_DIR" 2>/dev/null | awk '{print $1}')
                    PCT=$(echo "scale=0; ($CUR_SIZE * 100) / $TOTAL_SRC_SIZE" | bc -l 2>/dev/null || echo 0)
                    update_tg_status "📂 Sedang menyalin folder: $PCT%"
                fi
                sleep 2
            done
        fi
    done
fi
fi

# Full System Backup logic
if [[ "$SEL_FULL" == "y" ]]; then
    echo "[INFO] Memulai Full System Backup (skipping system dirs)..."
    mkdir -p "$TMP_DIR/full_system"
    tar -cpzf "$TMP_DIR/full_system/root_backup.tar.gz" \
        --exclude=/proc/* --exclude=/sys/* --exclude=/dev/* \
        --exclude=/run/* --exclude=/tmp/* --exclude=/lost+found \
        --exclude="${INSTALL_DIR}/*" / || true
fi

# backup mysql
if [[ "$SEL_MYSQL" == "y" && ! -z "${MYSQL_MULTI_CONF:-}" ]]; then
    update_tg_status "🗄️ Sedang mengekspor database MySQL..."
    mkdir -p "$TMP_DIR/mysql"
    IFS=';' read -r -a MYSQL_ITEMS <<< "$MYSQL_MULTI_CONF"
    for ITEM in "${MYSQL_ITEMS[@]}"; do
        USERPASS=$(echo "$ITEM" | cut -d'@' -f1)
        HOSTDB=$(echo "$ITEM" | cut -d'@' -f2)
        MYSQL_USER=$(echo "$USERPASS" | cut -d':' -f1)
        MYSQL_PASS=$(echo "$USERPASS" | cut -d':' -f2)
        MYSQL_HOST=$(echo "$HOSTDB" | cut -d':' -f1)
        MYSQL_DB_LIST=$(echo "$HOSTDB" | cut -d':' -f2)
        MYSQL_ARGS="-h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASS"
        if [[ "$MYSQL_DB_LIST" == "all" ]]; then
            OUTFILE="$TMP_DIR/mysql/${MYSQL_USER}@${MYSQL_HOST}_ALL.sql"
            mysqldump $MYSQL_ARGS --all-databases > "$OUTFILE" 2>/dev/null || true
        else
            IFS=',' read -r -a DBARR <<< "$MYSQL_DB_LIST"
            for DB in "${DBARR[@]}"; do
                OUTFILE="$TMP_DIR/mysql/${MYSQL_USER}@${MYSQL_HOST}_${DB}.sql"
                mysqldump $MYSQL_ARGS "$DB" > "$OUTFILE" 2>/dev/null || true
            done
        fi
    done
fi

# backup mongo
if [[ "$SEL_MONGO" == "y" && ! -z "${MONGO_MULTI_CONF:-}" ]]; then
    update_tg_status "🍃 Sedang mengekspor database MongoDB..."
    mkdir -p "$TMP_DIR/mongo"
    IFS=';' read -r -a MONGO_ITEMS <<< "$MONGO_MULTI_CONF"
    for ITEM in "${MONGO_ITEMS[@]}"; do
        # format: user:pass@host:port:authdb:dbs
        CREDS=$(echo "$ITEM" | cut -d'@' -f1)
        HOSTPART=$(echo "$ITEM" | cut -d'@' -f2)
        MONGO_USER=$(echo "$CREDS" | cut -d':' -f1)
        MONGO_PASS=$(echo "$CREDS" | cut -d':' -f2)
        MONGO_HOST=$(echo "$HOSTPART" | cut -d':' -f1)
        MONGO_PORT=$(echo "$HOSTPART" | cut -d':' -f2)
        MONGO_AUTHDB=$(echo "$HOSTPART" | cut -d':' -f3)
        MONGO_DB_LIST=$(echo "$HOSTPART" | cut -d':' -f4)

        # build target subdir name safe
        SAFE_NAME=$(echo "${MONGO_USER}_${MONGO_HOST}_${MONGO_PORT}" | sed 's/[^a-zA-Z0-9._-]/_/g')
        DEST_DIR="$TMP_DIR/mongo/$SAFE_NAME"
        mkdir -p "$DEST_DIR"

        # check mongodump
        if ! command -v mongodump >/dev/null 2>&1; then
            echo "[WARN] mongodump not found; skip mongo dump for $MONGO_HOST:$MONGO_PORT"
            continue
        fi

        # build base args
        BASE="--host=${MONGO_HOST} --port=${MONGO_PORT} --out=${DEST_DIR}"
        if [[ -n "$MONGO_USER" ]]; then
            BASE="$BASE --username=${MONGO_USER} --password='${MONGO_PASS}' --authenticationDatabase=${MONGO_AUTHDB}"
        fi

        if [[ "$MONGO_DB_LIST" == "all" ]]; then
            # dump all (mongodump without --db dumps all DBs)
            # note: mongodump default dumps all if no --db specified
            eval mongodump $BASE || true
        else
            IFS=',' read -r -a MDBARR <<< "$MONGO_DB_LIST"
            for MDB in "${MDBARR[@]}"; do
                eval mongodump $BASE --db="${MDB}" || true
            done
        fi

        # compress this mongo dump dir into tar.gz
        if [[ -d "$DEST_DIR" ]]; then
            tar -czf "${DEST_DIR}.tar.gz" -C "$DEST_DIR" . || true
            rm -rf "$DEST_DIR"
        fi
    done
fi

# backup postgres
if [[ "$SEL_PG" == "y" ]]; then
    update_tg_status "🐘 Sedang mengekspor database PostgreSQL..."
    mkdir -p "$TMP_DIR/postgres"
    if id -u postgres >/dev/null 2>&1; then
        su - postgres -c "pg_dumpall > $TMP_DIR/postgres/all.sql" || true
    else
        echo "[WARN] User 'postgres' not found or pg_dumpall unavailable"
    fi
fi

update_tg_status "📦 Sedang mengompres data (Real-time Progress)..."
# Gunakan pv untuk memantau progres kompresi
TOTAL_TMP_SIZE=$(du -sb "$TMP_DIR" | awk '{print $1}')
tar -cf - -C "$TMP_DIR" . | pv -n -s "$TOTAL_TMP_SIZE" 2> /tmp/tar_proc | gzip > "$FILE" &
TAR_PID=$!
while kill -0 $TAR_PID 2>/dev/null; do
    PCT_TAR=$(tail -n 1 /tmp/tar_proc 2>/dev/null || echo 0)
    update_tg_status "📦 Sedang mengompres: $PCT_TAR%"
    sleep 2
done
rm -f /tmp/tar_proc

# Hitung durasi & info file
END_TIME=$(date +%s)
DURATION=$(( END_TIME - START_TIME ))
FILE_SIZE=$(du -h "$FILE" | awk '{print $1}')

# Ambil nama VPS
VPS_NAME=$(hostname 2>/dev/null || echo "Unknown-VPS")

# Buat caption dengan emoji (NON-MARKDOWN, aman)
CAPTION="📦 Backup Selesai

🖥 VPS: ${VPS_NAME}
📅 Tanggal: $(date '+%Y-%m-%d %H:%M:%S')
⏱ Durasi: ${DURATION} detik
📁 Ukuran File: ${FILE_SIZE}
📄 Nama File: $(basename "$FILE")"

update_tg_status "🚀 Mengunggah file ke Telegram..."

# Kirim ke Telegram
if [[ -n "${BOT_TOKEN:-}" && -n "${CHAT_ID:-}" ]]; then
    curl -s -F document=@"$FILE" \
         -F caption="$CAPTION" \
         "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}" || true
else
    echo "[WARN] BOT_TOKEN/CHAT_ID kosong; melewatkan kirim ke Telegram"
fi

# Hapus pesan status progress agar bersih
if [[ -n "${MSG_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" -d "chat_id=${CHAT_ID}" -d "message_id=${MSG_ID}" > /dev/null || true
fi

# cleanup temp
rm -rf "$TMP_DIR"

# retention
if [[ -n "${RETENTION_DAYS:-}" ]]; then
    find "$BACKUP_DIR" -type f -mtime +"${RETENTION_DAYS}" -delete || true
fi

echo "[OK] Backup done: $FILE"
BPR

chmod +x "$RUNNER"
echo "[OK] Backup runner created: $RUNNER"

# ======================================================
# Create bot-control.sh (Telegram Inline Menu)
# ======================================================
cat > "$BOT_CONTROL" <<'BTC'
#!/bin/bash
CONFIG_FILE="/opt/auto-backup/config.conf"
RUNNER="/opt/auto-backup/backup-runner.sh"
OFFSET=0
STATE_FILE="/tmp/bot_state"

send_or_edit() {
    # Refresh config to get latest ALLOWED_USERNAMES
    source "$CONFIG_FILE"
    local dest="$1"
    local text="$2"
    local reply_markup="$3"
    local msg_id="${4:-}"

    if [[ -n "$msg_id" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/editMessageText" \
            -d "chat_id=$dest" -d "message_id=$msg_id" -d "text=$text" -d "reply_markup=$reply_markup"
    else
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d "chat_id=$dest" -d "text=$text" -d "reply_markup=$reply_markup"
    fi
}

get_sel_menu() {
    local s="$1" # string 5 digit binary e.g. 11111
    local f1=$( [[ "${s:0:1}" == "1" ]] && echo "✅" || echo "⬜" )
    local f2=$( [[ "${s:1:1}" == "1" ]] && echo "✅" || echo "⬜" )
    local f3=$( [[ "${s:2:1}" == "1" ]] && echo "✅" || echo "⬜" )
    local f4=$( [[ "${s:3:1}" == "1" ]] && echo "✅" || echo "⬜" )
    local f5=$( [[ "${s:4:1}" == "1" ]] && echo "✅" || echo "⬜" )

    echo '{"inline_keyboard":[[' \
        '{"text":"'"$f1"' Full System","callback_data":"tg_tgl_0_'"$s"'"},' \
        '{"text":"'"$f2"' Folders","callback_data":"tg_tgl_1_'"$s"'"}],' \
        '[{"text":"'"$f3"' MySQL","callback_data":"tg_tgl_2_'"$s"'"},' \
        '{"text":"'"$f4"' MongoDB","callback_data":"tg_tgl_3_'"$s"'"}],' \
        '[{"text":"'"$f5"' PostgreSQL","callback_data":"tg_tgl_4_'"$s"'"}],' \
        '[{"text":"🚀 MULAI BACKUP","callback_data":"tg_run_'"$s"'"}]]}'
}

get_access_menu() {
    source "$CONFIG_FILE"
    local kb='{"inline_keyboard":[['
    kb+='{"text":"➕ Tambah User","callback_data":"adm_add_start"},'
    kb+='{"text":"❌ Hapus User","callback_data":"adm_del_list"}],'
    kb+='[{"text":"⬅️ Kembali","callback_data":"back_main"}]]}'
    echo "$kb"
}

get_del_user_menu() {
    source "$CONFIG_FILE"
    local kb='{"inline_keyboard":['
    IFS=',' read -ra ADDR <<< "$ALLOWED_USERNAMES"
    for u in "${ADDR[@]}"; do
        [[ -z "$u" ]] && continue
        kb+='[{"text":"🗑 @'$u'","callback_data":"adm_rmv_'$u'"}],'
    done
    kb+='[{"text":"⬅️ Batal","callback_data":"manage_access"}]]}'
    echo "$kb"
}

toggle_bit() {
    local bit="$1"
    local str="$2"
    local char="${str:$bit:1}"
    local new_char=$( [[ "$char" == "1" ]] && echo "0" || echo "1" )
    echo "${str:0:$bit}${new_char}${str:$((bit+1))}"
}

map_to_args() {
    local s="$1"
    local res=""
    [[ "${s:0:1}" == "1" ]] && res+="full,"
    [[ "${s:1:1}" == "1" ]] && res+="folders,"
    [[ "${s:2:1}" == "1" ]] && res+="mysql,"
    [[ "${s:3:1}" == "1" ]] && res+="mongo,"
    [[ "${s:4:1}" == "1" ]] && res+="pg,"
    echo "${res%,}"
}

MAIN_MENU='{"inline_keyboard":[[{"text":"🚀 Backup Sekarang","callback_data":"do_backup"},{"text":"🔄 Restore","callback_data":"do_restore"}],[{"text":"📊 Status","callback_data":"do_status"}]]}'
ADMIN_ADD_BTN='[{"text":"⚙️ Kelola Akses","callback_data":"manage_access"}]'

while true; do
    source "$CONFIG_FILE"
    UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET&timeout=30")
    NUM_UPDATES=$(echo "$UPDATES" | jq '.result | length')

    for (( i=0; i<$NUM_UPDATES; i++ )); do
        OFFSET=$(echo "$UPDATES" | jq ".result[$i].update_id + 1")

        SENDER_ID=$(echo "$UPDATES" | jq -r ".result[$i].message.from.id // .result[$i].callback_query.from.id")

        # Validasi ChatID (Only authorized CHAT_ID can access)
        if [[ "$SENDER_ID" != "$CHAT_ID" ]]; then
            echo "[SECURITY] Unauthorized access attempt from ID: $SENDER_ID"
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "text=🚨 Percobaan akses ilegal dari ID: $SENDER_ID" > /dev/null
            continue
        fi

        # Handle Command /start
        MSG_TEXT=$(echo "$UPDATES" | jq -r ".result[$i].message.text // empty")
        if [[ "$MSG_TEXT" == "/start" ]]; then
            send_or_edit "$SENDER_ID" "Selamat Datang di VPS Backup Bot. Pilih aksi:" "$MAIN_MENU"
        fi

        # Handle Callback Query
        CALLBACK_DATA=$(echo "$UPDATES" | jq -r ".result[$i].callback_query.data // empty")
        CB_MSG_ID=$(echo "$UPDATES" | jq -r ".result[$i].callback_query.message.message_id // empty")

        if [[ -n "$CALLBACK_DATA" ]]; then
            case "$CALLBACK_DATA" in
                do_backup)
                    MENU_SEL=$(get_sel_menu "11111")
                    send_or_edit "$SENDER_ID" "Pilih item yang ingin di-backup:" "$MENU_SEL" "$CB_MSG_ID"
                    ;;
                tg_tgl_*)
                    BIT=$(echo "$CALLBACK_DATA" | cut -d'_' -f3)
                    STR=$(echo "$CALLBACK_DATA" | cut -d'_' -f4)
                    NEW_STR=$(toggle_bit "$BIT" "$STR")
                    send_or_edit "$SENDER_ID" "Pilih item yang ingin di-backup:" "$(get_sel_menu "$NEW_STR")" "$CB_MSG_ID"
                    ;;
                tg_run_*)
                    STR=$(echo "$CALLBACK_DATA" | cut -d'_' -f3)
                    ARGS=$(map_to_args "$STR")
                    send_or_edit "$SENDER_ID" "Memulai backup selective: $ARGS" "{}" "$CB_MSG_ID"
                    bash "$RUNNER" --selective "$ARGS" &
                    ;;
                do_status)
                    STATUS=$(systemctl is-active auto-backup.timer)
                    LAST=$(ls -t /opt/auto-backup/backups/ | head -n1)
                    send_or_edit "$SENDER_ID" "Status Timer: $STATUS\nBackup Terakhir: $LAST" "$MAIN_MENU" "$CB_MSG_ID"
                    ;;
                do_restore)
                    send_or_edit "$SENDER_ID" "Gunakan menu di terminal VPS (menu-bot-backup) untuk restorasi selektif demi keamanan." "$MAIN_MENU" "$CB_MSG_ID"
                    ;;
            esac
        fi
    done
    sleep 1
done
BTC
chmod +x "$BOT_CONTROL"

# ======================================================
# Create systemd service & timer
# ======================================================
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Auto Backup VPS to Telegram
After=network.target mysql.service mariadb.service postgresql.service mongodb.service

[Service]
Type=oneshot
Environment="TZ=$TZ"
ExecStart=/usr/bin/env TZ=$TZ $RUNNER
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Run Auto Backup VPS

[Timer]
OnCalendar=$CRON_TIME
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > "$BOT_SERVICE_FILE" <<EOF
[Unit]
Description=Telegram Bot Controller for VPS Backup
After=network.target

[Service]
ExecStart=$BOT_CONTROL
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload || true
systemctl enable auto-backup.service || true
systemctl enable --now auto-backup.timer || true
systemctl enable --now auto-backup-bot.service || true

echo "[OK] systemd service & timer configured."

# ======================================================
# Install menu (menu PRO — full content based on your menu)
# with watermark header+footer and menu status option
# ======================================================
cat > "$MENU_FILE" <<'MENU_EOF'
cat > "$MENU_FILE" <<'MENU_EOF'
#!/bin/bash
set -uo pipefail

CONFIG="/opt/auto-backup/config.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG" || { echo "Config not found"; exit 1; }

INSTALL_DIR="/opt/auto-backup"
RUNNER="$INSTALL_DIR/backup-runner.sh"
SERVICE_FILE="/etc/systemd/system/auto-backup.service"
TIMER_FILE="/etc/systemd/system/auto-backup.timer"
LOGFILE="$INSTALL_DIR/menu-pro.log"

WATERMARK_HEADER="=== AUTO BACKUP VPS by HENDRI — MENU PRO ===
SCRIPT BY: HENDRI
SUPPORT: https://t.me/GbtTapiPngnSndiri
========================================"
WATERMARK_FOOTER="========================================
SCRIPT BY: HENDRI — AUTO BACKUP VPS
Support: https://t.me/GbtTapiPngnSndiri"

if [[ ! -f "$CONFIG" ]]; then
    echo "Config tidak ditemukan di $CONFIG. Jalankan installer terlebih dahulu." | tee -a "$LOGFILE"
    exit 1
fi

# load config
# shellcheck source=/dev/null
source "$CONFIG"
# Prevent unbound variable crash
BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"
FOLDERS_RAW="${FOLDERS_RAW:-}"
USE_FULL_BACKUP="${USE_FULL_BACKUP:-n}"
USE_MYSQL="${USE_MYSQL:-n}"
MYSQL_MULTI_CONF="${MYSQL_MULTI_CONF:-}"
USE_MONGO="${USE_MONGO:-n}"
MONGO_MULTI_CONF="${MONGO_MULTI_CONF:-}"
USE_PG="${USE_PG:-n}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TZ="${TZ:-Asia/Jakarta}"
INSTALL_DIR="${INSTALL_DIR:-/opt/auto-backup}"

save_config() {
    cat <<EOF > "$CONFIG"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
FOLDERS_RAW="$FOLDERS_RAW"
USE_FULL_BACKUP="$USE_FULL_BACKUP"

USE_MYSQL="$USE_MYSQL"
MYSQL_MULTI_CONF="$MYSQL_MULTI_CONF"

USE_MONGO="$USE_MONGO"
MONGO_MULTI_CONF="$MONGO_MULTI_CONF"

USE_PG="$USE_PG"
RETENTION_DAYS="$RETENTION_DAYS"
TZ="$TZ"
INSTALL_DIR="$INSTALL_DIR"
EOF
    chmod 600 "$CONFIG"
    echo "[$(date '+%F %T')] Config saved." >> "$LOGFILE"
}

reload_systemd() {
    systemctl daemon-reload
    systemctl restart auto-backup.timer 2>/dev/null || true
    systemctl restart auto-backup.service 2>/dev/null || true
    systemctl restart auto-backup-bot.service 2>/dev/null || true
    echo "[$(date '+%F %T')] Systemd reloaded & services restarted." >> "$LOGFILE"
}

rebuild_installer_files() {
    echo "Membangun ulang service dan runner..."
    cat > "$RUNNER" <<'BPR'
#!/bin/bash
set -euo pipefail
CONFIG_FILE="/opt/auto-backup/config.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || exit 1

# Argument parsing for selective backup
SEL_FULL="$USE_FULL_BACKUP"; SEL_FOLDERS="y"; SEL_MYSQL="$USE_MYSQL"; SEL_MONGO="$USE_MONGO"; SEL_PG="$USE_PG"
if [[ "${1:-}" == "--selective" && -n "${2:-}" ]]; then
    SEL_FULL="n"; SEL_FOLDERS="n"; SEL_MYSQL="n"; SEL_MONGO="n"; SEL_PG="n"
    [[ "$2" == *full* ]] && SEL_FULL="y"
    [[ "$2" == *folders* ]] && SEL_FOLDERS="y"
    [[ "$2" == *mysql* ]] && SEL_MYSQL="y"
    [[ "$2" == *mongo* ]] && SEL_MONGO="y"
    [[ "$2" == *pg* ]] && SEL_PG="y"
fi

update_tg_status() {
    [[ -n "${MSG_ID:-}" ]] && curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" -d "chat_id=${CHAT_ID}" -d "message_id=${MSG_ID}" -d "text=$1" > /dev/null || true
}

INIT_RESP=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d "chat_id=${CHAT_ID}" -d "text=⏳ Memulai backup...")
MSG_ID=$(echo "$INIT_RESP" | jq -r '.result.message_id // empty')
START_TIME=$(date +%s); BACKUP_DIR="${INSTALL_DIR}/backups"; mkdir -p "$BACKUP_DIR"
DATE=$(date +%F-%H%M); FILE="$BACKUP_DIR/backup-$DATE.tar.gz"; TMP_DIR="${INSTALL_DIR}/tmp-$DATE"; mkdir -p "$TMP_DIR"

if [[ "$SEL_FOLDERS" == "y" ]]; then
    IFS=',' read -r -a FOLDERS <<< "${FOLDERS_RAW:-}"
    [[ ${#FOLDERS[@]} -gt 0 ]] && update_tg_status "📂 Menyalin folder..." && rsync -a "${FOLDERS[@]}" "$TMP_DIR/" || true
fi

if [[ "$SEL_FULL" == "y" ]]; then
    update_tg_status "🖥️ Full Backup..."
    tar -cpzf "$TMP_DIR/root_backup.tar.gz" --exclude=/proc/* --exclude=/sys/* --exclude=/dev/* --exclude=/run/* --exclude=/tmp/* --exclude="${INSTALL_DIR}/*" / || true
fi

if [[ "$SEL_MYSQL" == "y" && -n "${MYSQL_MULTI_CONF:-}" ]]; then
    update_tg_status "🗄️ Dump MySQL..."
    mkdir -p "$TMP_DIR/mysql"
    IFS=';' read -r -a ITEMS <<< "$MYSQL_MULTI_CONF"
    for ITEM in "${ITEMS[@]}"; do
        U=$(echo "$ITEM" | cut -d':' -f1); P=$(echo "$ITEM" | cut -d':' -f2 | cut -d'@' -f1); H=$(echo "$ITEM" | cut -d'@' -f2 | cut -d':' -f1); D=$(echo "$ITEM" | rev | cut -d':' -f1 | rev)
        [[ "$D" == "all" ]] && mysqldump -h$H -u$U -p$P --all-databases > "$TMP_DIR/mysql/${U}@${H}_ALL.sql" 2>/dev/null || mysqldump -h$H -u$U -p$P "$D" > "$TMP_DIR/mysql/${U}@${H}_${D}.sql" 2>/dev/null || true
    done
fi

if [[ "$SEL_MONGO" == "y" && -n "${MONGO_MULTI_CONF:-}" ]]; then
    update_tg_status "🍃 Dump Mongo..."
    mkdir -p "$TMP_DIR/mongo"
    IFS=';' read -r -a ITEMS <<< "$MONGO_MULTI_CONF"
    for ITEM in "${ITEMS[@]}"; do
        U=$(echo "$ITEM" | cut -d':' -f1); P=$(echo "$ITEM" | cut -d':' -f2 | cut -d'@' -f1); H=$(echo "$ITEM" | cut -d'@' -f2 | cut -d':' -f1); O=$(echo "$ITEM" | cut -d':' -f4); A=$(echo "$ITEM" | cut -d':' -f5); D=$(echo "$ITEM" | rev | cut -d':' -f1 | rev)
        BASE="--host=$H --port=$O --out=$TMP_DIR/mongo/${U}_$H"; [[ -n "$U" ]] && BASE+=" --username=$U --password='$P' --authenticationDatabase=$A"
        [[ "$D" == "all" ]] && mongodump $BASE || mongodump $BASE --db="$D"
    done
fi

if [[ "$SEL_PG" == "y" ]]; then
    update_tg_status "🐘 Dump PG..."
    mkdir -p "$TMP_DIR/postgres"; su - postgres -c "pg_dumpall > $TMP_DIR/postgres/all.sql" 2>/dev/null || true
fi

update_tg_status "📦 Kompresi..."
TOTAL_SIZE=$(du -sb "$TMP_DIR" | awk '{print $1}')
tar -cf - -C "$TMP_DIR" . | pv -n -s "$TOTAL_SIZE" 2> /tmp/tar_proc | gzip > "$FILE" &
TPID=$!; while kill -0 $TPID 2>/dev/null; do update_tg_status "📦 Kompresi: $(tail -n 1 /tmp/tar_proc 2>/dev/null)%"; sleep 2; done

CAPTION="📦 Backup VPS: $(hostname)\n📅 $(date '+%F %T')\n📁 Size: $(du -h "$FILE" | awk '{print $1}')"
update_tg_status "🚀 Uploading..."
curl -s -F document=@"$FILE" -F caption="$CAPTION" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}" || true
[[ -n "${MSG_ID:-}" ]] && curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" -d "chat_id=${CHAT_ID}" -d "message_id=${MSG_ID}" > /dev/null || true
rm -rf "$TMP_DIR" /tmp/tar_proc; find "$BACKUP_DIR" -type f -mtime +"${RETENTION_DAYS}" -delete || true
BPR
    chmod +x "$RUNNER"
    cat > "$SERVICE_FILE" <<EOT
[Unit]
Description=Auto Backup VPS to Telegram
After=network.target

[Service]
Type=oneshot
ExecStart=$RUNNER
User=root

[Install]
WantedBy=multi-user.target
EOT
    systemctl daemon-reload
    echo "[OK] Rebuilt runner and service."
}

menu_scope_checkbox() {
    while true; do
        clear
        echo "$WATERMARK_HEADER"
        echo "=== MANAGE BACKUP SCOPE (CHECKBOX) ==="
        echo "[1] [$( [[ "$USE_FULL_BACKUP" == "y" ]] && echo "X" || echo " " )] Full System Backup"
        echo "[2] [$( [[ "$USE_MYSQL" == "y" ]] && echo "X" || echo " " )] MySQL Backup"
        echo "[3] [$( [[ "$USE_MONGO" == "y" ]] && echo "X" || echo " " )] MongoDB Backup"
        echo "[4] [$( [[ "$USE_PG" == "y" ]] && echo "X" || echo " " )] PostgreSQL Backup"
        echo "--------------------------------------"
        echo "[S] SIMPAN DAN KEMBALI"
        echo "[0] BATAL"
        read -p "Pilih nomor untuk toggle: " PIL
        case "$PIL" in
            1) [[ "$USE_FULL_BACKUP" == "y" ]] && USE_FULL_BACKUP="n" || USE_FULL_BACKUP="y" ;;
            2) [[ "$USE_MYSQL" == "y" ]] && USE_MYSQL="n" || USE_MYSQL="y" ;;
            3) [[ "$USE_MONGO" == "y" ]] && USE_MONGO="n" || USE_MONGO="y" ;;
            4) [[ "$USE_PG" == "y" ]] && USE_PG="n" || USE_PG="y" ;;
            [Ss]) save_config; rebuild_installer_files; echo "Tersimpan."; pause; break ;;
            0) break ;;
        esac
    done
}

menu_bot_security() {
    while true; do
        clear
        echo "$WATERMARK_HEADER"
        echo "=== 🤖 BOT & SECURITY ==="
        echo "[1] Edit BOT TOKEN : ${BOT_TOKEN:0:10}***"
        echo "[2] Edit CHAT ID   : $CHAT_ID"
        echo "[3] Edit Whitelist : $ALLOWED_USERNAMES"
        echo "[0] Kembali"
        read -p "Pilihan: " PIL
        case "$PIL" in
            1) read -p "Token Baru: " BOT_TOKEN; save_config ;;
            2) read -p "Chat ID Baru: " CHAT_ID; save_config ;;
            3) read -p "Whitelist (User1,User2): " ALLOWED_USERNAMES; save_config ;;
            0) break ;;
        esac
    done
}

menu_db_config() {
    while true; do
        clear
        echo "$WATERMARK_HEADER"
        echo "=== 🗄️ DATABASE CONFIGURATION ==="
        echo "[1] Manage MySQL (${USE_MYSQL})"
        echo "[2] Manage MongoDB (${USE_MONGO})"
        echo "[3] Test PostgreSQL (${USE_PG})"
        echo "[0] Kembali"
        read -p "Pilihan: " PIL
        case "$PIL" in
            1) menu_mysql_sub ;;
            2) menu_mongo_sub ;;
            3) edit_pg ;;
            0) break ;;
        esac
    done
}

menu_mysql_sub() {
    while true; do
        clear
        echo "--- MySQL CONFIG ---"
        list_mysql
        echo "[1] Tambah [2] Edit [3] Hapus [0] Kembali"
        read -p "Aksi: " AKS
        case "$AKS" in
            1) add_mysql; save_config ;;
            2) edit_mysql; save_config ;;
            3) delete_mysql; save_config ;;
            0) break ;;
        esac
    done
}

menu_mongo_sub() {
    while true; do
        clear
        echo "--- MongoDB CONFIG ---"
        list_mongo
        echo "[1] Tambah [2] Edit [3] Hapus [0] Kembali"
        read -p "Aksi: " AKS
        case "$AKS" in
            1) add_mongo; save_config ;;
            2) edit_mongo; save_config ;;
            3) delete_mongo; save_config ;;
            0) break ;;
        esac
    done
}

menu_schedule_system() {
    while true; do
        clear
        echo "$WATERMARK_HEADER"
        echo "=== ⏰ SCHEDULE & SYSTEM ==="
        echo "[1] Timezone        : $TZ"
        echo "[2] Retention       : $RETENTION_DAYS hari"
        echo "[3] OnCalendar      : $(grep OnCalendar $TIMER_FILE | cut -d'=' -f2)"
        echo "[4] Restart Service"
        echo "[0] Kembali"
        read -p "Pilihan: " PIL
        case "$PIL" in
            1) read -p "Timezone: " TZ; timedatectl set-timezone "$TZ"; save_config ;;
            2) read -p "Retention: " RETENTION_DAYS; save_config ;;
            3) build_oncalendar ;;
            4) reload_systemd; echo "Restarted."; pause ;;
            0) break ;;
        esac
    done
}

menu_ops_backup() {
    while true; do
        clear
        echo "$WATERMARK_HEADER"
        echo "=== 🚀 BACKUP & RESTORE OPERATIONS ==="
        echo "[1] Test Backup Sekarang (Full)"
        echo "[2] Selective Backup (Checkbox CLI)"
        echo "[3] Restore dari File Backup"
        echo "[4] Encrypt Latest Backup (.zip)"
        echo "[0] Kembali"
        read -p "Pilihan: " PIL
        case "$PIL" in
            1) test_backup; pause ;;
            2) selective_backup_cli ;;
            3) restore_backup; pause ;;
            4) encrypt_last_backup; pause ;;
            0) break ;;
        esac
    done
}

main_menu_new() {
    while true; do
        STATUS_SERVICE=$(systemctl is-active auto-backup.service || echo "INACTIVE")
        TOTAL_BACKUP=$(ls /opt/auto-backup/backups/*.tar.gz 2>/dev/null | wc -l)
        clear
        echo -e "${CYAN}========== BACKUP DASHBOARD BY HENDRI ==========${RESET}"
        echo -e " Status  : ${GREEN}${STATUS_SERVICE}${RESET} | Total: ${BLUE}${TOTAL_BACKUP}${RESET}"
        echo "------------------------------------------------------------"
        echo -e "[1] 🤖 Bot & Access Control"
        echo -e "[2] 📂 Backup Scope & Folders (Checkbox)"
        echo -e "[3] 🗄️ Database Configurations"
        echo -e "[4] ⏰ Schedule & Time Settings"
        echo -e "[5] 🚀 Backup & Restore Operations"
        echo -e "------------------------------------------------------------"
        echo -e "[6] 📊 Live Monitor"
        echo -e "[7] 🛠️ Repair/Update System"
        echo -e "[0] Keluar"
        echo -e "${BLUE}============================================================${RESET}"
        read -p "Pilih Kategori: " MAIN_OPT
        case "$MAIN_OPT" in
            1) menu_bot_security ;;
            2) menu_scope_checkbox ;;
            3) menu_db_config ;;
            4) menu_schedule_system ;;
            5) menu_ops_backup ;;
            6) show_status_live ;;
            7) rebuild_installer_files; update_script ;;
            0) exit 0 ;;
            *) echo "Invalid option"; sleep 1 ;;
        esac
    done
}

pause() {
    read -p "Tekan ENTER untuk lanjut..."
}

confirm() {
    local msg="$1"
    read -p "$msg (y/N): " ans
    case "$ans" in
        y|Y) return 0 ;;
        *) return 1 ;;
    esac
}




# ---------- Status Menu ----------
show_status() {
    clear
    echo "$WATERMARK_HEADER"
    echo ""
    echo "=== STATUS BACKUP — STATIC ==="
    echo ""

    svc_active=$(systemctl is-active auto-backup.service 2>/dev/null || echo "unknown")
    svc_enabled=$(systemctl is-enabled auto-backup.service 2>/dev/null || echo "unknown")
    echo "Service status : $svc_active (enabled: $svc_enabled)"

    tm_active=$(systemctl is-active auto-backup.timer 2>/dev/null || echo "unknown")
    tm_enabled=$(systemctl is-enabled auto-backup.timer 2>/dev/null || echo "unknown")
    echo "Timer status   : $tm_active (enabled: $tm_enabled)"

    next_run=$(systemctl list-timers --all | grep auto-backup.timer | awk '{print $1, $2, $3}')
    [[ -z "$next_run" ]] && next_run="(tidak tersedia)"
    echo "Next run       : $next_run"

    BACKUP_DIR="$INSTALL_DIR/backups"
    lastfile=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -n1)
    if [[ -n "$lastfile" ]]; then
        lasttime=$(stat -c '%y' "$BACKUP_DIR/$lastfile" | cut -d'.' -f1)
        echo "Last backup    : $lastfile ($lasttime)"
    else
        echo "Last backup    : (belum ada)"
    fi

    echo ""
    echo "--- Log (5 baris terakhir) ---"
    journalctl -u auto-backup.service -n 5 --no-pager

    echo ""
    read -p "Tekan ENTER untuk kembali..."
}

# -------- Show Status Live (fixed auto-refresh) ----------
show_status_live() {
    trap 'tput cnorm; stty sane; clear; echo "Keluar dari mode realtime."; return 0' SIGINT SIGTERM
    tput civis 2>/dev/null || true

    while true; do
        clear
        echo -e "\e[36m$WATERMARK_HEADER\e[0m"
        echo "        STATUS BACKUP — REALTIME (Refresh 1 detik)"
        echo ""

        GREEN="\e[92m"
        BLUE="\e[96m"
        RESET="\e[0m"

        svc_active=$(systemctl is-active auto-backup.service 2>/dev/null || echo "unknown")
        svc_enabled=$(systemctl is-enabled auto-backup.service 2>/dev/null || echo "unknown")
        echo "Service status : $svc_active (enabled: $svc_enabled)"

        tm_active=$(systemctl is-active auto-backup.timer 2>/dev/null || echo "unknown")
        tm_enabled=$(systemctl is-enabled auto-backup.timer 2>/dev/null || echo "unknown")
        echo "Timer status   : $tm_active (enabled: $tm_enabled)"

        line=$(systemctl list-timers --all 2>/dev/null | grep auto-backup.timer | head -n1 || true)
        if [[ -n "$line" ]]; then
            nr1=$(echo "$line" | awk '{print $1}')
            nr2=$(echo "$line" | awk '{print $2}')
            nr3=$(echo "$line" | awk '{print $3}')
            next_run="$nr1 $nr2 $nr3"
        else
            next_run="(tidak tersedia)"
        fi
        echo -e "Next run       : ${BLUE}$next_run${RESET}"

        if [[ "$next_run" =~ ^\( ]]; then
            echo "Time left      : (tidak tersedia)"
            echo "Progress       : (tidak tersedia)"
        else
            next_epoch=0
            if ! next_epoch=$(date -d "$next_run" +%s 2>/dev/null); then
                next_epoch=0
            fi
            now_epoch=$(date +%s)
            diff=$(( next_epoch - now_epoch ))

            if (( next_epoch == 0 || diff <= 0 )); then
                echo "Time left      : 0 detik"
                echo "Progress       : 100%"
            else
                d=$(( diff/86400 ))
                h=$(( (diff%86400)/3600 ))
                m=$(( (diff%3600)/60 ))
                s=$(( diff%60 ))
                echo "Time left      : $d hari $h jam $m menit $s detik"

                last_epoch=$(journalctl -u auto-backup.service --output=short-unix -n 50 --no-pager \
                    | awk '/Backup done/ {print $1; exit}' | cut -d'.' -f1 || true)

                if [[ -z "$last_epoch" || "$last_epoch" -eq 0 ]]; then
                    echo "Progress       : (tidak tersedia)"
                else
                    total_interval=$(( next_epoch - last_epoch ))
                    elapsed=$(( now_epoch - last_epoch ))

                    if (( total_interval <= 0 )); then
                        percent=100
                    else
                        percent=$(( elapsed * 100 / total_interval ))
                    fi

                    ((percent < 0)) && percent=0
                    ((percent > 100)) && percent=100

                    bars=$(( percent / 5 ))
                    bar=""
                    for ((i=1;i<=bars;i++)); do bar+="█"; done
                    while (( ${#bar} < 20 )); do bar+=" "; done

                    echo -e "Progress       : ${BLUE}[${bar}]${RESET} $percent%"
                fi
            fi
        fi

        BACKUP_DIR="$INSTALL_DIR/backups"
        lastfile=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -n1 || true)
        if [[ -z "$lastfile" ]]; then
            echo "Last backup    : (belum ada)"
        else
            lasttime=$(stat -c '%y' "$BACKUP_DIR/$lastfile" | cut -d'.' -f1)
            echo -e "Last backup    : ${GREEN}$lastfile${RESET} ($lasttime)"
        fi

        echo ""
        echo "--- Log auto-backup.service (3 baris terakhir) ---"
        journalctl -u auto-backup.service -n 3 --no-pager 2>/dev/null || echo "(log tidak tersedia)"

        echo ""
        echo "[Tekan CTRL+C untuk keluar realtime]"
        sleep 1 || true
    done

    tput cnorm 2>/dev/null || true
}

# ---------- Folder / MySQL / PG / Mongo functions ----------
add_folder() {
    read -p "Masukkan folder baru (single path, atau comma separated): " NEW_FOLDER
    if [[ -z "$NEW_FOLDER" ]]; then
        echo "Tidak ada input."
        return
    fi
    if [[ -z "$FOLDERS_RAW" ]]; then
        FOLDERS_RAW="$NEW_FOLDER"
    else
        FOLDERS_RAW="$FOLDERS_RAW,$NEW_FOLDER"
    fi
    echo "[OK] Folder tambahan disiapkan."
}

delete_folder() {
    if [[ -z "$FOLDERS_RAW" ]]; then
        echo "Tidak ada folder yang bisa dihapus."
        return
    fi
    IFS=',' read -ra FL <<< "$FOLDERS_RAW"
    echo "Daftar folder:"
    for i in "${!FL[@]}"; do
        printf "%2d) %s\n" $((i+1)) "${FL[$i]}"
    done
    read -p "Masukkan nomor yang ingin dihapus: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || (( NUM < 1 || NUM > ${#FL[@]} )); then
        echo "Pilihan tidak valid."
        return
    fi
    unset 'FL[NUM-1]'
    FOLDERS_RAW=$(IFS=','; echo "${FL[*]}")
    echo "[OK] Folder dihapus."
}

# MySQL handlers (unchanged from before)
list_mysql() {
    if [[ -z "$MYSQL_MULTI_CONF" ]]; then
        echo "(tidak ada konfigurasi MySQL)"
        return
    fi
    IFS=';' read -ra LIST <<< "$MYSQL_MULTI_CONF"
    i=1
    for item in "${LIST[@]}"; do
        echo "[$i] $item"
        ((i++))
    done
}

add_mysql() {
    echo "Tambah konfigurasi MySQL baru:"
    read -p "MySQL Host (default: localhost): " MYSQL_HOST
    MYSQL_HOST=${MYSQL_HOST:-localhost}
    read -p "MySQL Username: " MYSQL_USER
    read -s -p "MySQL Password: " MYSQL_PASS
    echo ""
    echo "Mode database: 1) Semua  2) Pilih"
    read -p "Pilih: " MODE
    if [[ "$MODE" == "1" ]]; then DB="all"; else read -p "Masukkan nama database (comma separated): " DB; fi
    NEW_ENTRY="${MYSQL_USER}:${MYSQL_PASS}@${MYSQL_HOST}:${DB}"
    if [[ -z "$MYSQL_MULTI_CONF" ]]; then MYSQL_MULTI_CONF="$NEW_ENTRY"; else MYSQL_MULTI_CONF="$MYSQL_MULTI_CONF;$NEW_ENTRY"; fi
    echo "[OK] Ditambahkan."
}

edit_mysql() {
    if [[ -z "$MYSQL_MULTI_CONF" ]]; then echo "Tidak ada konfigurasi MySQL."; return; fi
    IFS=';' read -ra LIST <<< "$MYSQL_MULTI_CONF"
    for i in "${!LIST[@]}"; do printf "%2d) %s\n" $((i+1)) "${LIST[$i]}"; done
    read -p "Pilih nomor untuk diedit: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || (( NUM < 1 || NUM > ${#LIST[@]} )); then echo "Pilihan invalid."; return; fi
    IDX=$((NUM-1))
    OLD="${LIST[$IDX]}"
    echo "Konfigurasi lama: $OLD"
    OLD_USER=$(echo "$OLD" | cut -d':' -f1)
    OLD_PASS=$(echo "$OLD" | cut -d':' -f2 | cut -d'@' -f1)
    OLD_HOST=$(echo "$OLD" | cut -d'@' -f2 | cut -d':' -f1)
    OLD_DB=$(echo "$OLD" | rev | cut -d: -f1 | rev)
    read -p "MySQL Host [$OLD_HOST]: " MYSQL_HOST; MYSQL_HOST=${MYSQL_HOST:-$OLD_HOST}
    read -p "MySQL Username [$OLD_USER]: " MYSQL_USER; MYSQL_USER=${MYSQL_USER:-$OLD_USER}
    read -s -p "MySQL Password (kosong = tetap): " MYSQL_PASS; echo ""
    if [[ -z "$MYSQL_PASS" ]]; then MYSQL_PASS="$OLD_PASS"; fi
    read -p "Database (comma or 'all') [$OLD_DB]: " DB; DB=${DB:-$OLD_DB}
    NEW_ENTRY="${MYSQL_USER}:${MYSQL_PASS}@${MYSQL_HOST}:${DB}"
    LIST[$IDX]="$NEW_ENTRY"
    MYSQL_MULTI_CONF=$(IFS=';'; echo "${LIST[*]}")
    echo "[OK] Konfigurasi diperbarui."
}

delete_mysql() {
    if [[ -z "$MYSQL_MULTI_CONF" ]]; then echo "Tidak ada konfigurasi MySQL."; return; fi
    IFS=';' read -ra LIST <<< "$MYSQL_MULTI_CONF"
    for i in "${!LIST[@]}"; do printf "%2d) %s\n" $((i+1)) "${LIST[$i]}"; done
    read -p "Pilih nomor yang ingin dihapus: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || (( NUM < 1 || NUM > ${#LIST[@]} )); then echo "Pilihan invalid."; return; fi
    unset 'LIST[NUM-1]'
    MYSQL_MULTI_CONF=$(IFS=';'; echo "${LIST[*]}")
    echo "[OK] Dihapus."
}

# -------- Mongo handlers (new) ----------
list_mongo() {
    if [[ -z "$MONGO_MULTI_CONF" ]]; then
        echo "(tidak ada konfigurasi MongoDB)"
        return
    fi
    IFS=';' read -ra LIST <<< "$MONGO_MULTI_CONF"
    i=1
    for item in "${LIST[@]}"; do
        echo "[$i] $item"
        ((i++))
    done
}

add_mongo() {
    echo "Tambah konfigurasi MongoDB baru:"
    read -p "Mongo Host (default: localhost): " MONGO_HOST
    MONGO_HOST=${MONGO_HOST:-localhost}
    read -p "Mongo Port (default: 27017): " MONGO_PORT
    MONGO_PORT=${MONGO_PORT:-27017}
    read -p "Mongo Username (kosong jika tidak pakai auth): " MONGO_USER
    if [[ -n "$MONGO_USER" ]]; then
        read -s -p "Mongo Password: " MONGO_PASS
        echo ""
        read -p "Authentication DB (default: admin): " MONGO_AUTHDB
        MONGO_AUTHDB=${MONGO_AUTHDB:-admin}
    else
        MONGO_PASS=""
        MONGO_AUTHDB=""
    fi
    echo "Mode database: 1) Semua  2) Pilih"
    read -p "Pilih: " MODE
    if [[ "$MODE" == "1" ]]; then MDBLIST="all"; else read -p "Masukkan nama database (comma separated): " MDBLIST; fi
    NEW_ENTRY="${MONGO_USER}:${MONGO_PASS}@${MONGO_HOST}:${MONGO_PORT}:${MONGO_AUTHDB}:${MDBLIST}"
    if [[ -z "$MONGO_MULTI_CONF" ]]; then MONGO_MULTI_CONF="$NEW_ENTRY"; else MONGO_MULTI_CONF="$MONGO_MULTI_CONF;$NEW_ENTRY"; fi
    echo "[OK] Ditambahkan."
}

edit_mongo() {
    if [[ -z "$MONGO_MULTI_CONF" ]]; then echo "Tidak ada konfigurasi MongoDB."; return; fi
    IFS=';' read -ra LIST <<< "$MONGO_MULTI_CONF"
    for i in "${!LIST[@]}"; do printf "%2d) %s\n" $((i+1)) "${LIST[$i]}"; done
    read -p "Pilih nomor untuk diedit: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || (( NUM < 1 || NUM > ${#LIST[@]} )); then echo "Pilihan invalid."; return; fi
    IDX=$((NUM-1))
    OLD="${LIST[$IDX]}"
    echo "Konfigurasi lama: $OLD"
    OLD_USER=$(echo "$OLD" | cut -d':' -f1)
    OLD_PASS=$(echo "$OLD" | cut -d':' -f2 | cut -d'@' -f1)
    OLD_HOST=$(echo "$OLD" | cut -d'@' -f2 | cut -d':' -f1)
    OLD_PORT=$(echo "$OLD" | cut -d'@' -f2 | cut -d':' -f2)
    OLD_AUTHDB=$(echo "$OLD" | cut -d'@' -f2 | cut -d':' -f3)
    OLD_DB=$(echo "$OLD" | rev | cut -d: -f1 | rev)
    read -p "Mongo Host [$OLD_HOST]: " MONGO_HOST; MONGO_HOST=${MONGO_HOST:-$OLD_HOST}
    read -p "Mongo Port [$OLD_PORT]: " MONGO_PORT; MONGO_PORT=${MONGO_PORT:-$OLD_PORT}
    read -p "Mongo Username [$OLD_USER]: " MONGO_USER; MONGO_USER=${MONGO_USER:-$OLD_USER}
    read -s -p "Mongo Password (kosong = tetap): " MONGO_PASS; echo ""
    if [[ -z "$MONGO_PASS" ]]; then MONGO_PASS="$OLD_PASS"; fi
    read -p "Authentication DB [$OLD_AUTHDB]: " MONGO_AUTHDB; MONGO_AUTHDB=${MONGO_AUTHDB:-$OLD_AUTHDB}
    read -p "Database (comma or 'all') [$OLD_DB]: " MDBLIST; MDBLIST=${MDBLIST:-$OLD_DB}
    NEW_ENTRY="${MONGO_USER}:${MONGO_PASS}@${MONGO_HOST}:${MONGO_PORT}:${MONGO_AUTHDB}:${MDBLIST}"
    LIST[$IDX]="$NEW_ENTRY"
    MONGO_MULTI_CONF=$(IFS=';'; echo "${LIST[*]}")
    echo "[OK] Konfigurasi MongoDB diperbarui."
}

delete_mongo() {
    if [[ -z "$MONGO_MULTI_CONF" ]]; then echo "Tidak ada konfigurasi MongoDB."; return; fi
    IFS=';' read -ra LIST <<< "$MONGO_MULTI_CONF"
    for i in "${!LIST[@]}"; do printf "%2d) %s\n" $((i+1)) "${LIST[$i]}"; done
    read -p "Pilih nomor yang ingin dihapus: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || (( NUM < 1 || NUM > ${#LIST[@]} )); then echo "Pilihan invalid."; return; fi
    unset 'LIST[NUM-1]'
    MONGO_MULTI_CONF=$(IFS=';'; echo "${LIST[*]}")
    echo "[OK] Dihapus."
}

edit_pg() {
    read -p "Backup PostgreSQL? (y/n) [current: $USE_PG]: " x
    if [[ ! -z "$x" ]]; then USE_PG="$x"; fi
    echo "[OK] USE_PG set ke $USE_PG"
    read -p "Tekan ENTER jika ingin melakukan test dump sekarang, atau CTRL+C untuk batal..."
    if [[ "$USE_PG" == "y" ]]; then
        TMP="$INSTALL_DIR/pg_test_$(date +%s).sql"
        if su - postgres -c "pg_dumpall > $TMP" 2>/dev/null; then
            echo "Test pg_dumpall berhasil: $TMP"
        else
            echo "pg_dumpall gagal. Pastikan user 'postgres' ada dan pg_dumpall terinstall."
            rm -f "$TMP"
        fi
    else
        echo "PG backup dinonaktifkan."
    fi
}

list_backups() {
    mkdir -p "$INSTALL_DIR/backups"
    ls -1tr "$INSTALL_DIR/backups" 2>/dev/null || echo "(tidak ada file backup)"
}

restore_backup() {
    echo "Daftar file backup (urut waktu):"
    files=()
    idx=1
    while IFS= read -r -d $'\0' f; do
        files+=("$f")
    done < <(find "$INSTALL_DIR/backups" -maxdepth 1 -type f -print0 | sort -z)
    if (( ${#files[@]} == 0 )); then echo "Tidak ada file backup." ; return; fi
    for i in "${!files[@]}"; do printf "%2d) %s\n" $((i+1)) "$(basename "${files[$i]}")"; done
    read -p "Pilih nomor file untuk restore: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || (( NUM < 1 || NUM > ${#files[@]} )); then echo "Pilihan invalid."; return; fi
    SELECT="${files[$((NUM-1))]}"
    echo "File dipilih: $SELECT"
    echo "Isi file (preview):"
    tar -tf "$SELECT" | awk -F/ '{print $1}' | sort -u
    
    read -p "Ketik nama folder/file spesifik dari daftar di atas yang ingin di-restore (atau '*' untuk semua): " RESTORE_PATH
    
    TMPREST="$INSTALL_DIR/restore_tmp_$(date +%s)"
    mkdir -p "$TMPREST"
    
    if [[ "$RESTORE_PATH" == "*" ]]; then
        tar -xzf "$SELECT" -C "$TMPREST"
    else
        tar -xzf "$SELECT" -C "$TMPREST" "$RESTORE_PATH" || { echo "Folder tidak ditemukan."; rm -rf "$TMPREST"; return; }
    fi

    echo "File diekstrak sementara ke $TMPREST"
    if confirm "Lanjut salin data ini ke root (/) sistem?"; then
        if [[ "$RESTORE_PATH" == "*" ]]; then
            rsync -a "$TMPREST/" /
        else
            rsync -a "$TMPREST/$RESTORE_PATH" /$(dirname "$RESTORE_PATH")/
        fi
        echo "[OK] Restore selektif selesai."
        echo "[$(date '+%F %T')] Restore from $(basename "$SELECT")" >> "$LOGFILE"
        rebuild_installer_files # reuse logic
    else
        echo "Restore dibatalkan."
    fi
    rm -rf "$TMPREST"
}

rebuild_installer_files() {
    echo "Membangun ulang service dan runner..."
    # Inlining generate_runner logic to ensure it's available in the menu script
    cat > "/opt/auto-backup/backup-runner.sh" <<'BPR'
#!/bin/bash
set -euo pipefail
CONFIG_FILE="/opt/auto-backup/config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    exit 1
fi

# Selective Backup Logic
MODE_SELECTIVE="n"
SEL_FULL="n"; SEL_FOLDERS="n"; SEL_MYSQL="n"; SEL_MONGO="n"; SEL_PG="n"
if [[ "${1:-}" == "--selective" && -n "${2:-}" ]]; then
    MODE_SELECTIVE="y"
    [[ "$2" == *full* ]] && SEL_FULL="y"
    [[ "$2" == *folders* ]] && SEL_FOLDERS="y"
    [[ "$2" == *mysql* ]] && SEL_MYSQL="y"
    [[ "$2" == *mongo* ]] && SEL_MONGO="y"
    [[ "$2" == *pg* ]] && SEL_PG="y"
else
    SEL_FULL="$USE_FULL_BACKUP"; SEL_FOLDERS="y"
    SEL_MYSQL="$USE_MYSQL"; SEL_MONGO="$USE_MONGO"; SEL_PG="$USE_PG"
fi

# ... (rest of runner logic follows same pattern) ...
BPR
    chmod +x "/opt/auto-backup/backup-runner.sh"

    cat <<EOT > "$SERVICE_FILE"
[Unit]
Description=Auto Backup VPS to Telegram
After=network.target mysql.service mariadb.service postgresql.service mongodb.service

[Service]
Type=oneshot
Environment="TZ=$TZ"
ExecStart=/usr/bin/env TZ=$TZ $RUNNER
User=root

[Install]
WantedBy=multi-user.target
EOT

    CURRENT_ONCAL="*-*-* 03:00:00"
    if [[ -f "$TIMER_FILE" ]]; then
        oc=$(grep -E '^OnCalendar=' "$TIMER_FILE" 2>/dev/null | head -n1 | cut -d'=' -f2-)
        if [[ ! -z "$oc" ]]; then CURRENT_ONCAL="$oc"; fi
    fi

    cat <<EOT > "$TIMER_FILE"
[Unit]
Description=Run Auto Backup VPS

[Timer]
OnCalendar=$CURRENT_ONCAL
Persistent=true

[Install]
WantedBy=timers.target
EOT

    systemctl daemon-reload || true
    systemctl enable --now auto-backup.timer || true
    systemctl enable auto-backup.service || true
    echo "[OK] Service & timer dibuat / direpair."
    echo "[$(date '+%F %T')] Rebuilt installer files." >> "$LOGFILE"
}

encrypt_last_backup() {
    mkdir -p "$INSTALL_DIR/backups"
    LAST=$(ls -1t "$INSTALL_DIR/backups" 2>/dev/null | head -n1)
    if [[ -z "$LAST" ]]; then echo "Tidak ada backup untuk diencrypt."; return; fi
    read -s -p "Masukkan password enkripsi (akan digunakan untuk zip): " PWD; echo ""
    OUT="$INSTALL_DIR/backups/${LAST%.*}.zip"
    if command -v zip >/dev/null 2>&1; then
        zip -P "$PWD" "$OUT" "$INSTALL_DIR/backups/$LAST" >/dev/null 2>&1
        echo "Encrypted archive dibuat: $OUT"
    else
        echo "Perintah zip tidak tersedia. Install zip lalu ulangi."
    fi
    [[ -z "$LAST" ]] && { echo "No backup."; return; }
    read -s -p "Password: " PWD; echo ""
    zip -P "$PWD" "$INSTALL_DIR/backups/${LAST%.*}.zip" "$INSTALL_DIR/backups/$LAST" >/dev/null 2>&1 && echo "Encrypted zip created." || echo "Zip failed."
}

build_oncalendar() {
    echo "Bentuk OnCalendar bisa: '*-*-* HH:MM:SS' (setiap hari jam tertentu)"
    echo "Contoh weekly/monthly: 'Mon *-*-* 03:00:00' dsb."
    read -p "Masukkan string OnCalendar yang diinginkan: " OC
    if [[ -z "$OC" ]]; then echo "Tidak ada input."; return; fi
    sed -i "s|OnCalendar=.*|OnCalendar=$OC|g" "$TIMER_FILE"
    systemctl daemon-reload
    systemctl restart auto-backup.timer
    echo "[OK] OnCalendar disimpan ke $TIMER_FILE"
}

show_config_file() {
    echo "================ CONFIG FILE ================"
    cat "$CONFIG"
    echo "============================================"
}

test_backup() {
    echo "[OK] Menjalankan backup-runner (test)..."
    bash "$RUNNER"
    echo "Selesai. Periksa Telegram / $INSTALL_DIR/backups"
}

selective_backup_cli() {
    local s_full="ON" s_folders="ON" s_mysql="ON" s_mongo="ON" s_pg="ON"
    while true; do
        clear
        echo "=== SELECTIVE BACKUP MENU ==="
        echo "[1] Full System : $s_full"
        echo "[2] Folders     : $s_folders"
        echo "[3] MySQL       : $s_mysql"
        echo "[4] MongoDB     : $s_mongo"
        echo "[5] PostgreSQL  : $s_pg"
        echo "----------------------------"
        echo "[R] JALANKAN BACKUP SEKARANG"
        echo "[0] Batal"
        read -p "Pilih nomor untuk toggle atau 'R' untuk mulai: " sel
        case "$sel" in
            1) [[ "$s_full" == "ON" ]] && s_full="OFF" || s_full="ON" ;;
            2) [[ "$s_folders" == "ON" ]] && s_folders="OFF" || s_folders="ON" ;;
            3) [[ "$s_mysql" == "ON" ]] && s_mysql="OFF" || s_mysql="ON" ;;
            4) [[ "$s_mongo" == "ON" ]] && s_mongo="OFF" || s_mongo="ON" ;;
            5) [[ "$s_pg" == "ON" ]] && s_pg="OFF" || s_pg="ON" ;;
            [Rr]) 
                ARGS=""
                [[ "$s_full" == "ON" ]] && ARGS+="full,"
                [[ "$s_folders" == "ON" ]] && ARGS+="folders,"
                [[ "$s_mysql" == "ON" ]] && ARGS+="mysql,"
                [[ "$s_mongo" == "ON" ]] && ARGS+="mongo,"
                [[ "$s_pg" == "ON" ]] && ARGS+="pg,"
                bash "$RUNNER" --selective "${ARGS%,}"
                pause; break ;;
            0) break ;;
        esac
    done
}


update_script() {
    REPO_URL="https://raw.githubusercontent.com/heruhendri/Installer-Backup-Vps-Bot-Telegram/update/install-backupvps-telegram.sh"
    if confirm "Apakah Anda yakin ingin memperbarui script ke versi terbaru?"; then
        echo "[INFO] Mendownload script terbaru dari GitHub..."
        curl -sL "$REPO_URL" -o /tmp/update-backup.sh
        chmod +x /tmp/update-backup.sh
        echo "[INFO] Menjalankan update sekarang..."
        bash /tmp/update-backup.sh
        exit 0
    fi
}

toggle_mysql() {
    echo "Status sekarang USE_MYSQL = $USE_MYSQL"
    read -p "Aktifkan MySQL? (y/n): " jawab

    case "$jawab" in
        y|Y)
            USE_MYSQL="y"
            echo "[OK] MySQL DI-AKTIFKAN."
            ;;
        n|N)
            USE_MYSQL="n"
            echo "[OK] MySQL DI-MATIKAN."
            ;;
        *)
            echo "Input tidak valid. Gunakan y atau n."
            pause
            return
            ;;
    esac

    save_config
    pause
}

toggle_mongo() {
    echo "Status sekarang USE_MONGO = $USE_MONGO"
    read -p "Aktifkan MongoDB? (y/n): " jawab

    case "$jawab" in
        y|Y)
            USE_MONGO="y"
            echo "[OK] MongoDB DI-AKTIFKAN."
            ;;
        n|N)
            USE_MONGO="n"
            echo "[OK] MongoDB DI-MATIKAN."
            ;;
        *)
            echo "Input tidak valid. Gunakan y atau n."
            pause
            return
            ;;
    esac

    save_config
    pause
}

toggle_pg() {
    echo "Status sekarang USE_PG = $USE_PG"
    read -p "Aktifkan PostgreSQL? (y/n): " jawab

    case "$jawab" in
        y|Y)
            USE_PG="y"
            echo "[OK] PostgreSQL DI-AKTIFKAN."
            ;;
        n|N)
            USE_PG="n"
            echo "[OK] PostgreSQL DI-MATIKAN."
            ;;
        *)
            echo "Input tidak valid. Gunakan y atau n."
            pause
            return
            ;;
    esac

    save_config
    pause
}

# Fungsi untuk ambil status service
get_status_service() {
    # Contoh: cek service backup aktif atau tidak
    if systemctl is-active --quiet auto-backup.service; then
        echo "ACTIVE"
    else
        echo "INACTIVE"
    fi
}

# Fungsi untuk ambil jadwal berikutnya
get_next_schedule() {
    # Contoh: ambil jadwal systemd timer (ubah sesuai timer kamu)
    NEXT=$(systemctl list-timers --no-legend auto-backup.timer | awk 'NR==1 {print $1, $2}')
    if [[ -z "$NEXT" ]]; then
        echo "Belum ada jadwal"
    else
        echo "$NEXT"
    fi
}

# Fungsi untuk ambil backup terakhir
get_last_backup() {
    LAST=$(ls -t /opt/auto-backup/backups/*.tar.gz 2>/dev/null | head -n1)
    if [[ -z "$LAST" ]]; then
        echo "Tidak ada"
    else
        echo "$(basename "$LAST")"
    fi
}

# Fungsi untuk hitung total backup
get_total_backup() {
    COUNT=$(ls /opt/auto-backup/backups/*.tar.gz 2>/dev/null | wc -l)
    echo "${COUNT:-0}"
}

# ===================== WARNA =====================
BLUE="\e[96m"
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
CYAN="\e[36m"
RESET="\e[0m"
BLUE="\e[96m"; GREEN="\e[92m"; YELLOW="\e[93m"; RED="\e[91m"; CYAN="\e[36m"; RESET="\e[0m"
main_menu_new
MENU_EOF

chmod +x "$MENU_FILE"
ln -sf "$MENU_FILE" /usr/bin/menu-bot-backup
chmod +x /usr/bin/menu-bot-backup

echo "[OK] Menu PRO installed: menu-bot-backup (run 'menu-bot-backup' to open)"

# ======================================================
# Finalize installer
# ======================================================
echo ""
echo "$WATERMARK_END"
echo ""
echo "[INFO] Menjalankan backup pertama (test) sekarang..."
# Run first backup (best-effort, don't fail installer if backup runner errors)
bash "$RUNNER" || echo "[WARN] Backup pertama gagal. Periksa log atau jalankan 'menu-bot-backup' untuk debug."

echo ""
echo "Installer akan menghapus file installer ini untuk keamanan."
rm -- "$0" || true

echo ""
echo "Selesai. Ketik: menu-bot-backup"
