#!/bin/bash
# main.sh – L04 Library Late-Fee Bot
cd "$(dirname "$0")" || exit 1
source lib/functions.sh

# TODO 1: command-line arguments ($1 = first word typed after ./main.sh)
case "$1" in
    --help)   show_help; exit 0 ;;
    --backup) do_backup; exit 0 ;;
    --cron)   cron_task; exit 0 ;;
    "")       ;;                       # no argument -> go to the menu
    *)        echo "Unknown option: $1"; show_help; exit 1 ;;
esac

# TODO 2: menu
while true; do
    echo
    echo "======= LIBRARY LATE-FEE BOT ======="
    echo " 1) Issue a book"
    echo " 2) Return a book"
    echo " 3) Calculate fines"
    echo " 4) Search books by title"
    echo " 5) Generate defaulters report"
    echo " 6) View data"
    echo " 7) Backup data"
    echo " 8) View activity log"
    echo " 0) Exit"
    read -p "Enter choice: " choice || { echo; echo "No more input. Bye!"; break; }
    case "$choice" in
        1) feature_1 ;;
        2) feature_2 ;;
        3) feature_3 ;;
        4) feature_4 ;;
        5) feature_5 ;;
        6) view_data ;;
        7) do_backup ;;
        8) view_log ;;
        0) echo "Bye!"; break ;;
        *) echo "Invalid choice" ;;
    esac
done
