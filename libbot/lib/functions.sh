#!/bin/bash
# lib/functions.sh – Library Late-Fee Bot
# All functions live here. main.sh loads this file with: source lib/functions.sh
DATA="data/books.csv"
LOG="logs/activity.log"
LOAN_DAYS=14        # a book must be returned within 14 days
FINE_PER_DAY=2      # fine in Rupees for every late day

# log -> write one line "date time | message" into $LOG
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"
}

# check_data -> if $DATA does not exist, print a message and return 1
check_data() {
    if [ ! -f "$DATA" ]; then
        echo "Error: data file $DATA not found!"
        return 1
    fi
}

# valid_date -> success only if $1 looks like YYYY-MM-DD and is a real date
valid_date() {
    [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$1" >/dev/null 2>&1
}

# late_days -> how many days late is a book?  args: issue_date return_date
# If return_date is empty the book is still out, so we count until today.
late_days() {
    local issue="$1" ret="$2"
    local due_s end_s days
    due_s=$(date -d "$issue +$LOAN_DAYS days" +%s)     # due date in seconds
    if [ -z "$ret" ]; then
        end_s=$(date -d "$(date +%F)" +%s)              # today in seconds
    else
        end_s=$(date -d "$ret" +%s)                     # return date in seconds
    fi
    days=$(( (end_s - due_s) / 86400 ))                 # 86400 seconds = 1 day
    [ "$days" -lt 0 ] && days=0
    echo "$days"
}

# fine_table -> prints one CSV line per book:
#   book_id,title,issued_to,due_date,status,late_days,fine
fine_table() {
    local id title to issue ret due status days
    tail -n +2 "$DATA" | while IFS=, read -r id title to issue ret; do
        [ -z "$id" ] && continue
        due=$(date -d "$issue +$LOAN_DAYS days" +%F)
        if [ -z "$ret" ]; then status="NOT RETURNED"; else status="Returned"; fi
        days=$(late_days "$issue" "$ret")
        echo "$id,$title,$to,$due,$status,$days,$(( days * FINE_PER_DAY ))"
    done
}

# show_help -> print how to use the script
show_help() {
    echo "Library Late-Fee Bot - usage:"
    echo "  ./main.sh            open the menu"
    echo "  ./main.sh --help     show this help"
    echo "  ./main.sh --backup   back up the data/ folder and exit"
    echo "  ./main.sh --cron     add today's overdue list to logs/defaulters.log (used by crontab)"
    echo "Rules: loan period $LOAN_DAYS days, fine Rs $FINE_PER_DAY per late day."
}

# view_data -> show the data file with line numbers
view_data() {
    check_data || return
    cat -n "$DATA"
    echo "Total books: $(( $(wc -l < "$DATA") - 1 ))"
    log "Viewed data"
}

# do_backup -> create backups/data_<date_time>.tar.gz of the data/ folder
do_backup() {
    local file="backups/data_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$file" data/
    echo "Backup saved: $file ($(du -h "$file" | cut -f1))"
    log "Backup created $file"
}

# view_log -> show the last 15 lines of $LOG
view_log() {
    if [ ! -f "$LOG" ]; then echo "No activity yet."; return; fi
    tail -n 15 "$LOG"
}

# ------------------------------------------------------------
# FEATURE 1: Issue a book (append record)
# ------------------------------------------------------------
feature_1() {
    check_data || return
    local id title to issue
    read -p "Book ID (e.g. B131): " id
    read -p "Title: " title
    read -p "Issued to (roll no, e.g. G24): " to
    read -p "Issue date YYYY-MM-DD (Enter = today): " issue
    [ -z "$issue" ] && issue=$(date +%F)

    if [ -z "$id" ] || [ -z "$title" ] || [ -z "$to" ]; then
        echo "Error: no field can be empty."; return
    fi
    if [[ ! "$id" =~ ^B[0-9]+$ ]]; then
        echo "Error: Book ID must look like B131."; return
    fi
    if grep -q "^$id," "$DATA"; then
        echo "Error: $id already exists."; return
    fi
    if [[ "$title" == *,* ]]; then
        echo "Error: title cannot contain a comma."; return
    fi
    if ! valid_date "$issue"; then
        echo "Error: date must be YYYY-MM-DD."; return
    fi

    echo "$id,$title,$to,$issue," >> "$DATA"
    echo "Saved! Due date: $(date -d "$issue +$LOAN_DAYS days" +%F)"
    log "Issued $id ($title) to $to on $issue"
}

# ------------------------------------------------------------
# FEATURE 2: Return a book and update the record with sed
# ------------------------------------------------------------
feature_2() {
    check_data || return
    local id ret line issue days
    read -p "Book ID to return: " id
    if [ -z "$id" ]; then echo "Error: Book ID cannot be empty."; return; fi

    line=$(grep "^$id," "$DATA")
    if [ -z "$line" ]; then echo "Error: $id not found."; return; fi
    if [[ "$line" != *, ]]; then echo "Error: $id is already returned."; return; fi

    read -p "Return date YYYY-MM-DD (Enter = today): " ret
    [ -z "$ret" ] && ret=$(date +%F)
    if ! valid_date "$ret"; then echo "Error: date must be YYYY-MM-DD."; return; fi

    issue=$(echo "$line" | cut -d, -f4)
    # On the line that starts with the ID, replace the comma at the end with ",date".
    # -i.bak edits the file in place and keeps the old version as books.csv.bak
    sed -i.bak "/^$id,/ s/,\$/,$ret/" "$DATA"

    days=$(late_days "$issue" "$ret")
    echo "Saved! $id returned on $ret. Late days: $days, Fine: Rs $(( days * FINE_PER_DAY ))"
    log "Returned $id on $ret (late $days days)"
}

# ------------------------------------------------------------
# FEATURE 3: Calculate fine per late day using date arithmetic
# ------------------------------------------------------------
feature_3() {
    check_data || return
    printf "%-6s %-30s %-6s %-11s %-13s %5s %6s\n" ID TITLE ROLL DUE STATUS LATE FINE
    fine_table | awk -F, '
        { printf "%-6s %-30s %-6s %-11s %-13s %5d %6d\n", $1, substr($2,1,30), $3, $4, $5, $6, $7
          total += $7; if ($7 > 0) late++ }
        END { printf "\nLate books: %d   Total fine: Rs %d\n", late, total }'
    log "Calculated fines"
}

# ------------------------------------------------------------
# FEATURE 4: Search books by title (grep -i)
# ------------------------------------------------------------
feature_4() {
    check_data || return
    local word result
    read -p "Word to search in title: " word
    if [ -z "$word" ]; then echo "Error: search word cannot be empty."; return; fi

    # ^[^,]*,  = skip column 1 (book_id);  [^,]*$word = the word somewhere in column 2 (title)
    result=$(grep -i "^[^,]*,[^,]*$word" "$DATA")
    if [ $? -ne 0 ]; then
        echo "No book found with '$word' in the title."
    else
        echo "$result" | sort -t, -k2 | awk -F, '{ printf "%-6s %-35s issued to %s\n", $1, $2, $3 }'
    fi
    log "Searched title for '$word'"
}

# ------------------------------------------------------------
# FEATURE 5: Generate a defaulters report
# ------------------------------------------------------------
feature_5() {
    check_data || return
    local report="reports/defaulters_$(date +%F).txt"
    {
        echo "DEFAULTERS REPORT - $(date '+%d %b %Y %H:%M')"
        echo "Loan period: $LOAN_DAYS days | Fine: Rs $FINE_PER_DAY per day"
        echo "--------------------------------------------------------------"
        fine_table | awk -F, '$6 > 0' | sort -t, -k7 -nr | \
            awk -F, '{ printf "%-6s %-28s %-5s %-13s %3d days  Rs %d\n", $1, substr($2,1,28), $3, $5, $6, $7; t += $7 }
                     END { print "--------------------------------------------------------------"
                           printf "Defaulters: %d   Total fine: Rs %d\n", NR, t }'
    } > "$report"
    cat "$report"
    echo
    echo "Report saved: $report"
    log "Defaulters report saved $report"
}

# ------------------------------------------------------------
# CRON TASK: Every day at 10 AM, append the list of overdue books with fines to defaulters.log
# This runs when crontab calls:  ./main.sh --cron
# ------------------------------------------------------------
cron_task() {
    check_data || return
    {
        echo "===== $(date '+%Y-%m-%d %H:%M') overdue books ====="
        fine_table | awk -F, '$5 == "NOT RETURNED" && $6 > 0 { printf "%s, %s, %s, %d days late, Rs %d\n", $1, $2, $3, $6, $7 }'
    } >> logs/defaulters.log
    log "Cron: overdue list added to logs/defaulters.log"
}
