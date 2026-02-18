#!/bin/bash
# Tetris for claude-arcade
# Terminal tetris in bash

WIDTH=12
HEIGHT=20
FRAME_DELAY=0.05
DROP_INTERVAL=15

# Colors
RED='\033[41m  \033[0m'
GREEN='\033[42m  \033[0m'
YELLOW='\033[43m  \033[0m'
BLUE='\033[44m  \033[0m'
MAGENTA='\033[45m  \033[0m'
CYAN='\033[46m  \033[0m'
WHITE='\033[47m  \033[0m'
EMPTY='  '

# Pieces (each piece has 4 rotations)
declare -a PIECES COLORS

# I piece
PIECES[0]="0,1,2,3:0,0,0,0 1,1,1,1:0,1,2,3 0,1,2,3:0,0,0,0 1,1,1,1:0,1,2,3"
COLORS[0]=$CYAN

# O piece
PIECES[1]="0,1,0,1:0,0,1,1 0,1,0,1:0,0,1,1 0,1,0,1:0,0,1,1 0,1,0,1:0,0,1,1"
COLORS[1]=$YELLOW

# T piece
PIECES[2]="0,1,2,1:0,0,0,1 1,0,1,1:0,1,1,2 0,1,2,1:1,1,1,0 0,0,1,0:0,1,1,2"
COLORS[2]=$MAGENTA

# S piece
PIECES[3]="1,2,0,1:0,0,1,1 0,0,1,1:0,1,1,2 1,2,0,1:0,0,1,1 0,0,1,1:0,1,1,2"
COLORS[3]=$GREEN

# Z piece
PIECES[4]="0,1,1,2:0,0,1,1 1,1,0,0:0,1,1,2 0,1,1,2:0,0,1,1 1,1,0,0:0,1,1,2"
COLORS[4]=$RED

# J piece
PIECES[5]="0,0,1,2:0,1,1,1 0,1,0,0:0,0,1,2 0,1,2,2:0,0,0,1 1,1,0,1:0,2,2,2"
COLORS[5]=$BLUE

# L piece
PIECES[6]="2,0,1,2:0,1,1,1 0,0,0,1:0,1,2,2 0,1,2,0:0,0,0,1 0,1,1,1:0,0,1,2"
COLORS[6]=$WHITE

# Game state
declare -a BOARD
CURRENT_PIECE=0
CURRENT_ROTATION=0
PIECE_X=0
PIECE_Y=0
SCORE=0
LINES=0
LEVEL=1
GAME_OVER=false
FRAME_COUNT=0

setup() {
    tput civis
    stty -echo -icanon time 0 min 0
    clear
}

cleanup() {
    tput cnorm
    stty echo icanon
    clear
    echo "Game Over!"
    echo "Score: $SCORE"
    echo "Lines: $LINES"
    echo "Level: $LEVEL"
    echo ""
    echo "Press any key..."
    read -n1
    exit 0
}

trap cleanup EXIT INT TERM

init_board() {
    for ((i=0; i<HEIGHT*WIDTH; i++)); do
        BOARD[$i]=0
    done
}

get_board() {
    local x=$1 y=$2
    if [[ $x -lt 0 || $x -ge $WIDTH || $y -lt 0 || $y -ge $HEIGHT ]]; then
        echo 1
    else
        echo ${BOARD[$((y * WIDTH + x))]}
    fi
}

set_board() {
    local x=$1 y=$2 val=$3
    BOARD[$((y * WIDTH + x))]=$val
}

spawn_piece() {
    CURRENT_PIECE=$((RANDOM % 7))
    CURRENT_ROTATION=0
    PIECE_X=$((WIDTH / 2 - 1))
    PIECE_Y=0

    if ! check_collision 0 0 0; then
        GAME_OVER=true
    fi
}

get_piece_coords() {
    local piece=$1 rotation=$2
    local rotations="${PIECES[$piece]}"
    local rot_data=$(echo "$rotations" | tr ' ' '\n' | sed -n "$((rotation + 1))p")
    echo "$rot_data"
}

check_collision() {
    local dx=$1 dy=$2 dr=$3
    local new_x=$((PIECE_X + dx))
    local new_y=$((PIECE_Y + dy))
    local new_r=$(((CURRENT_ROTATION + dr) % 4))

    local coords=$(get_piece_coords $CURRENT_PIECE $new_r)
    local xs=$(echo "$coords" | cut -d: -f1 | tr ',' ' ')
    local ys=$(echo "$coords" | cut -d: -f2 | tr ',' ' ')

    local x_arr=($xs)
    local y_arr=($ys)

    for ((i=0; i<4; i++)); do
        local px=$((new_x + x_arr[i]))
        local py=$((new_y + y_arr[i]))

        if [[ $px -lt 0 || $px -ge $WIDTH || $py -ge $HEIGHT ]]; then
            return 1
        fi

        if [[ $py -ge 0 ]] && [[ $(get_board $px $py) -ne 0 ]]; then
            return 1
        fi
    done

    return 0
}

lock_piece() {
    local coords=$(get_piece_coords $CURRENT_PIECE $CURRENT_ROTATION)
    local xs=$(echo "$coords" | cut -d: -f1 | tr ',' ' ')
    local ys=$(echo "$coords" | cut -d: -f2 | tr ',' ' ')

    local x_arr=($xs)
    local y_arr=($ys)

    for ((i=0; i<4; i++)); do
        local px=$((PIECE_X + x_arr[i]))
        local py=$((PIECE_Y + y_arr[i]))
        if [[ $py -ge 0 ]]; then
            set_board $px $py $((CURRENT_PIECE + 1))
        fi
    done

    clear_lines
    spawn_piece
}

clear_lines() {
    local cleared=0

    for ((y=HEIGHT-1; y>=0; y--)); do
        local full=true
        for ((x=0; x<WIDTH; x++)); do
            if [[ $(get_board $x $y) -eq 0 ]]; then
                full=false
                break
            fi
        done

        if $full; then
            ((cleared++))
            for ((yy=y; yy>0; yy--)); do
                for ((x=0; x<WIDTH; x++)); do
                    set_board $x $yy $(get_board $x $((yy-1)))
                done
            done
            for ((x=0; x<WIDTH; x++)); do
                set_board $x 0 0
            done
            ((y++))
        fi
    done

    if [[ $cleared -gt 0 ]]; then
        ((LINES += cleared))
        case $cleared in
            1) ((SCORE += 100 * LEVEL)) ;;
            2) ((SCORE += 300 * LEVEL)) ;;
            3) ((SCORE += 500 * LEVEL)) ;;
            4) ((SCORE += 800 * LEVEL)) ;;
        esac
        LEVEL=$((LINES / 10 + 1))
    fi
}

draw() {
    tput cup 0 0

    echo "╔══════════════════════════╗"
    echo "║   TETRIS   Score: $(printf '%5d' $SCORE) ║"
    echo "║   Level $LEVEL   Lines: $(printf '%3d' $LINES)  ║"
    echo "╠════════════════════════╦═╣"

    local coords=$(get_piece_coords $CURRENT_PIECE $CURRENT_ROTATION)
    local xs=$(echo "$coords" | cut -d: -f1 | tr ',' ' ')
    local ys=$(echo "$coords" | cut -d: -f2 | tr ',' ' ')
    local x_arr=($xs)
    local y_arr=($ys)

    for ((y=0; y<HEIGHT; y++)); do
        echo -n "║"
        for ((x=0; x<WIDTH; x++)); do
            local val=$(get_board $x $y)
            local is_piece=false

            for ((i=0; i<4; i++)); do
                if [[ $((PIECE_X + x_arr[i])) -eq $x && $((PIECE_Y + y_arr[i])) -eq $y ]]; then
                    is_piece=true
                    break
                fi
            done

            if $is_piece; then
                echo -ne "${COLORS[$CURRENT_PIECE]}"
            elif [[ $val -gt 0 ]]; then
                echo -ne "${COLORS[$((val-1))]}"
            else
                echo -n "$EMPTY"
            fi
        done
        echo "║"
    done

    echo "╚════════════════════════╩═╝"
    echo "← → move | ↑ rotate | ↓ drop | q quit"
}

read_input() {
    local key
    read -rsn1 key 2>/dev/null

    case "$key" in
        $'\x1b')
            read -rsn2 key 2>/dev/null
            case "$key" in
                '[A') check_collision 0 0 1 && ((CURRENT_ROTATION = (CURRENT_ROTATION + 1) % 4)) ;;
                '[B') if check_collision 0 1 0; then ((PIECE_Y++)); else lock_piece; fi ;;
                '[C') check_collision 1 0 0 && ((PIECE_X++)) ;;
                '[D') check_collision -1 0 0 && ((PIECE_X--)) ;;
            esac
            ;;
        ' ')
            while check_collision 0 1 0; do ((PIECE_Y++)); done
            lock_piece
            ;;
        'q'|'Q') GAME_OVER=true ;;
    esac
}

main() {
    setup
    init_board
    spawn_piece

    local drop_speed=$DROP_INTERVAL

    while [[ $GAME_OVER == false ]]; do
        draw
        read_input

        ((FRAME_COUNT++))
        drop_speed=$((DROP_INTERVAL - LEVEL + 1))
        [[ $drop_speed -lt 3 ]] && drop_speed=3

        if [[ $((FRAME_COUNT % drop_speed)) -eq 0 ]]; then
            if check_collision 0 1 0; then
                ((PIECE_Y++))
            else
                lock_piece
            fi
        fi

        sleep $FRAME_DELAY
    done
}

main
