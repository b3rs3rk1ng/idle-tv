#!/bin/bash
# Pipes animation for claude-arcade
# Relaxing pipes that draw themselves - no interaction needed

# Pipe characters
declare -a PIPES=("│" "─" "┐" "┌" "┘" "└" "┼" "├" "┤" "┬" "┴")

# Colors
declare -a COLORS=(
    "\033[31m"  # Red
    "\033[32m"  # Green
    "\033[33m"  # Yellow
    "\033[34m"  # Blue
    "\033[35m"  # Magenta
    "\033[36m"  # Cyan
    "\033[91m"  # Bright Red
    "\033[92m"  # Bright Green
    "\033[93m"  # Bright Yellow
    "\033[94m"  # Bright Blue
    "\033[95m"  # Bright Magenta
    "\033[96m"  # Bright Cyan
)
NC="\033[0m"

# Get terminal size
COLS=$(tput cols)
ROWS=$(tput lines)

# Current position and direction
X=0
Y=0
DIR=0  # 0=right, 1=down, 2=left, 3=up
COLOR_IDX=0

setup() {
    tput civis
    stty -echo -icanon time 0 min 0
    clear

    # Start from random position
    X=$((RANDOM % COLS))
    Y=$((RANDOM % (ROWS - 2) + 1))
    DIR=$((RANDOM % 4))
    COLOR_IDX=$((RANDOM % ${#COLORS[@]}))
}

cleanup() {
    tput cnorm
    stty echo icanon
    clear
    exit 0
}

trap cleanup EXIT INT TERM

# Get pipe character based on direction change
get_pipe() {
    local old_dir=$1
    local new_dir=$2

    # Same direction - straight pipe
    if [[ $old_dir -eq $new_dir ]]; then
        case $new_dir in
            0|2) echo "─" ;;  # Horizontal
            1|3) echo "│" ;;  # Vertical
        esac
        return
    fi

    # Direction change - corner
    case "$old_dir,$new_dir" in
        "0,1"|"3,2") echo "┐" ;;  # right->down or up->left
        "0,3"|"1,2") echo "┘" ;;  # right->up or down->left
        "2,1"|"3,0") echo "┌" ;;  # left->down or up->right
        "2,3"|"1,0") echo "└" ;;  # left->up or down->right
        *) echo "┼" ;;
    esac
}

# Move in current direction
move() {
    case $DIR in
        0) ((X++)) ;;  # Right
        1) ((Y++)) ;;  # Down
        2) ((X--)) ;;  # Left
        3) ((Y--)) ;;  # Up
    esac
}

# Check if position is valid
is_valid() {
    [[ $X -ge 0 && $X -lt $COLS && $Y -ge 1 && $Y -lt $((ROWS-1)) ]]
}

# Maybe change direction
maybe_turn() {
    # 20% chance to turn
    if [[ $((RANDOM % 5)) -eq 0 ]]; then
        # Turn left or right (not reverse)
        if [[ $((RANDOM % 2)) -eq 0 ]]; then
            DIR=$(((DIR + 1) % 4))
        else
            DIR=$(((DIR + 3) % 4))
        fi
    fi
}

# Check for input (non-blocking)
check_input() {
    local key
    read -rsn1 -t 0.01 key 2>/dev/null
    if [[ "$key" == "q" || "$key" == "Q" ]]; then
        exit 0
    fi
}

# Draw status line
draw_status() {
    tput cup $((ROWS-1)) 0
    echo -ne "\033[7m Pipes - Press 'q' to quit \033[0m"
}

# Start a new pipe from random location
new_pipe() {
    X=$((RANDOM % COLS))
    Y=$((RANDOM % (ROWS - 2) + 1))
    DIR=$((RANDOM % 4))
    COLOR_IDX=$(((COLOR_IDX + 1) % ${#COLORS[@]}))
}

main() {
    setup
    draw_status

    local old_dir=$DIR
    local steps=0
    local max_steps=$((COLS * ROWS / 4))

    while true; do
        check_input

        # Draw current position
        local pipe=$(get_pipe $old_dir $DIR)
        tput cup $Y $X
        echo -ne "${COLORS[$COLOR_IDX]}${pipe}${NC}"

        old_dir=$DIR
        maybe_turn
        move
        ((steps++))

        # If out of bounds or too many steps, start new pipe
        if ! is_valid || [[ $steps -gt $max_steps ]]; then
            new_pipe
            steps=0
            old_dir=$DIR

            # Occasionally clear screen for fresh start
            if [[ $((RANDOM % 10)) -eq 0 ]]; then
                clear
                draw_status
            fi
        fi

        # Refresh status occasionally
        if [[ $((steps % 50)) -eq 0 ]]; then
            draw_status
        fi

        sleep 0.05
    done
}

main
