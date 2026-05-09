#!/bin/bash

#0. Tạo đường dẫn mặc định
DIR_APK="/sdcard/Download/AutoDroid/apk"
DIR_OTHER="/sdcard/Download/AutoDroid/other"
TEMP_DIR="/sdcard/Download/AutoDroid/temp_dl"
EXTRACT_DIR="$HOME/apks_tmp_$$"
TMP_DIR="/data/local/tmp"
mkdir -p "$DIR_APK"
mkdir -p "$DIR_OTHER"
mkdir -p "$TEMP_DIR"
#1. Ghi lại nhật ký
LOG="/sdcard/Download/AutoDroid/program.log"
exec > >(tee -a "$LOG") 2>&1
echo -e "\e[34mProvided by Khoaa\e[0m"
#2. Cài đặt megatools nếu chưa có trên hệ thống
if ! command -v megatools &> /dev/null; then
    read -p "[?] megatools -> Cài tự động[y/Y] || Cài từ file backup[n/N]: " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        echo "[+] Đang cài đặt tự động..."
        pkg update -y && pkg install megatools -y
    elif [[ "$choice" == "n" || "$choice" == "N" ]]; then
        curl -L -O "https://github.com/vxah-ka/setup-droid/releases/download/v1.0.0/termux-backup.tar.gz"
        mv termux-backup.tar.gz /sdcard/Download/
        echo "[+] Đang cài đặt từ file backup..."
        tar -zxf /sdcard/Download/termux-backup.tar.gz -C /data/data/com.termux/files --recursive-unlink --preserve-permissions
        echo "[+] Cài đặt thành công..."
    else
        echo "[-] Lựa chọn không hợp lệ, thoát chương trình."
        exit 1
    fi
fi
#3. Nhập link Mega
echo "[+] Đang đọc link Mega..."
read MEGA_LINK <<< "https://mega.nz/folder/L7YSVQBK#iaLQ1dNjyTDp8YCW3Tr72Q"
#4. Tải xuống
echo "[+] Đang tải xuống file từ link Mega..."
megatools dl "$MEGA_LINK" --path "$TEMP_DIR"
if [ "$(ls -A "$TEMP_DIR" 2>/dev/null | wc -l)" -eq 0 ]; then
    echo "[!] Không có file nào được tải xuống, thoát chương trình."
    rm -rf "$TEMP_DIR" && exit 1
fi
echo "[+] Đã tải thành công! Số lượng file là: $(ls "$TEMP_DIR" | wc -l)."
#5. Phân loại file
echo "[+] Đang phân loại file đã tải xuống..."
find "$TEMP_DIR" -type f \( -iname "*.apk" -o -iname "*.apks" \) -exec mv {} "$DIR_APK/" \;
find "$TEMP_DIR" -type f -not -iname "*.apk" -not -iname "*.apks" -exec mv {} "$DIR_OTHER/" \;
rm -rf "$TEMP_DIR"
#6. Tự động cài đặt TẤT CẢ file .apk và .apks
echo "[+] Đang cài đặt các file .apk..."
shopt -s nullglob
for apk_file in "$DIR_APK"/*.apk; do
    if [ -f "$apk_file" ]; then
        filename=$(basename "$apk_file")
        echo "  -> Cài đặt: $filename"
        su -c "cp \"$apk_file\" \"$TMP_DIR/$filename\""
        su -c "pm install -r \"$TMP_DIR/$filename\""
        su -c "rm \"$TMP_DIR/$filename\""
    fi
done
echo "[+] Đang cài đặt các file .apks..."
for apks in "$DIR_APK"/*.apks; do
  if [ -f "$apks" ]; then
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    unzip -q -o "$apks" -d "$EXTRACT_DIR"
    echo "  -> Cài đặt: $(basename "$apks")"
    SESSION_OUTPUT=$(su -c "pm install-create -r")
    SESSION_ID=$(echo "$SESSION_OUTPUT" | tr -dc '0-9')   
    if [ -n "$SESSION_ID" ]; then
        INDEX=0
        for apk_part in "$EXTRACT_DIR"/*.apk; do
            if [ -f "$apk_part" ]; then
                su -c "pm install-write $SESSION_ID split_$INDEX \"$apk_part\""
                INDEX=$((INDEX + 1))
            fi
        done
        su -c "pm install-commit $SESSION_ID"
    else
        echo "[!] Không thể tạo Install Session. ($SESSION_OUTPUT)"
    fi
    rm -rf "$EXTRACT_DIR"
  fi
done
shopt -u nullglob
#7. Tự động hóa cài đặt hệ thống (Developer)
echo "[+] Bật Tùy chọn nhà phát triển..."
su -c "settings put global development_settings_enabled 1"
su -c "settings put global window_animation_scale 0"
su -c "settings put global transition_animation_scale 0"
su -c "settings put global animator_duration_scale 0"
echo "[+] Bật Hiển thị số lần nhấn (Show touches)..."
su -c "settings put system show_touches 1"
echo "[+] Thiết lập DPI về mức 521..."
su -c "wm density 221"
echo "[+] Thay đổi Launcher mặc định thành [Android Launcher]..."
su -c "cmd package set-home-activity amirz.rootless.nexuslauncher/com.google.android.apps.nexuslauncher.NexusLauncherActivity"
echo "[+] Đặt Cốc Cốc làm trình duyệt mặc định..."
su -c "cmd role add-role-holder android.app.role.BROWSER com.coccoc.trinhduyet"
echo "[+] Đổi ngôn ngữ máy sang Vietnames..."
su -c "settings put system system_locales vi-VN"
echo "[+] Chuyển giao diện sang darkmode..."
su -c "settings put secure ui_night_mode 2"
echo -e "\e[34mProvided by Khoaa\e[0m"
echo -e "\e[31m[!]Chuẩn bị khởi động lại[!]\e[0m"
for i in 5 4 3 2 1; do
    echo -e "Khởi động lại sau \e[31m$i\e[0m giây..."
    sleep 1
done
su -c "killall system_server"
