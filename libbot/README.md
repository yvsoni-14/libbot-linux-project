# L04 – Library Late-Fee Bot

**Student:** YATREE SONI | **Roll:** D60 | **Division:** G | **Enrollment:** 24004501210436

## Problem
Create a library issue/return system that calculates late fees automatically.

## Who will use it
The college library desk that issues books and collects late fees.

## Folder structure
| Path | What it is for |
|---|---|
| `main.sh` | The program you run. Reads command-line options (`--help`, `--backup`, `--cron`) and shows the menu. |
| `lib/functions.sh` | All the functions (log, check_data, the 5 features, backup, cron task). `main.sh` loads it with `source`. |
| `data/books.csv` | The data file: one line per book (30 records). |
| `reports/` | Defaulters reports made by option 5 (`defaulters_YYYY-MM-DD.txt`). |
| `backups/` | `.tar.gz` backups of the `data/` folder made by option 7 or `--backup`. |
| `logs/activity.log` | One line with date and time for every action. |
| `logs/defaulters.log` | Daily overdue list added by the cron job. |
| `logs/cron.log` | Anything the cron job prints (output and errors). |

## Data file columns (`data/books.csv`)
| Column | Meaning | Example |
|---|---|---|
| book_id | Unique ID of the book | B101 |
| title | Book title (no commas) | Unix Concepts |
| issued_to | Roll number of the student | H30 |
| issue_date | Date the book was issued (YYYY-MM-DD) | 2026-10-01 |
| return_date | Date returned; empty = still with the student | 2026-10-20 |

Rules: a book must be returned within **14 days**; the fine is **Rs 2 per late day**.

## Features
1. Issue a book (append record) – asks for the details, checks them, adds one line with `>>`.
2. Return a book and update the record with sed – fills the empty return_date with `sed -i`.
3. Calculate fine per late day using date arithmetic – `date -d "issue +14 days"` gives the due date; late days = (end − due) / 86400.
4. Search books by title (grep -i) – case-insensitive search inside the title column.
5. Generate a defaulters report – late books sorted by fine, saved in `reports/`.

## How to run
```bash
cd ~/linux_project/libbot
chmod +x main.sh
./main.sh            # menu
./main.sh --help     # help
./main.sh --backup   # backup only
./main.sh --cron     # what crontab runs every day
```

## My crontab line and what it means
```
0 10 * * * /bin/bash $HOME/linux_project/libbot/main.sh --cron >> $HOME/linux_project/libbot/logs/cron.log 2>&1
```
| Field | Value | Meaning |
|---|---|---|
| minute | 0 | at minute 0 |
| hour | 10 | of 10 AM |
| day of month | * | every day |
| month | * | every month |
| day of week | * | every day of the week |

`>> logs/cron.log 2>&1` adds normal output and errors to cron.log.

## Commands I used and why
| Command | Where | Why |
|---|---|---|
| `date -d`, `date +%F`, `date +%s` | late_days, feature_1/2, file names | due date, today's date, converting dates to seconds for subtraction |
| `awk -F,` | feature_3, feature_5, cron_task | split CSV columns, print a neat table, add up the fines |
| `sed -i.bak` | feature_2 | write the return date into the right line (keeps a .bak copy) |
| `grep -i`, `grep -q` | feature_4, feature_1/2 | case-insensitive title search; check if an ID exists |
| `sort -t, -k7 -nr` | feature_5 | highest fine first |
| `cut`, `tail -n +2`, `wc -l` | many | pick a column, skip the header, count lines |
| `tar -czf`, `du -h` | do_backup | compressed backup and its size |
| `cat -n`, `tail -n 15` | view_data, view_log | show data with line numbers, last log lines |
| `crontab -e`, `crontab -l` | scheduling | run the cron task every day at 10 AM |

## What I learned
(write 3-5 lines in your own words)
