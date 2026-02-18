#!/bin/bash
# 2048 for claude-arcade
# Terminal 2048 puzzle game

SIZE=4
declare -a BOARD
SCORE=0
GAME_OVER=false
WON=false

# Colors for tiles
declare -A TILE_COLORS
TILE_COLORS[0]="\033[48;5;250m"
TILE_COLORS[2]="\033[48;5;230m\033[38;5;236m"
TILE_COLORS[4]="\033[48;5;223m\033[38;5;236m"
TILE_COLORS[8]="\033[48;5;215m\033[38;5;255m"
TILE_COLORS[16]="\033[48;5;208m\033[38;5;255m"
TILE_COLORS[32]="\033[48;5;203m\033[38;5;255m"
TILE_COLORS[64]="\033[48;5;196m\033[38;5;255m"
TILE_COLORS[128]="\033[48;5;226m\033[38;5;236m"
TILE_COLORS[256]="\033[48;5;220m\033[38;5;236m"
TILE_COLORS[512]="\033[48;5;214m\033[38;5;255m"
TILE_COLORS[1024]="\033[48;5;208m\033[38;5;255m"
TILE_COLORS[2048]="\033[48;5;202m\033[38;5;255m"
NC="\033[0m"

setup() {
    tput civis
    stty -echo -icanon
    clear
}

cleanup() {
    tput cnorm
    stty echo icanon
    clear
    if $WON; then
        echo "Congratulations! You reached 2048!"
    else
        echo "Game Over!"
    fi
    echo "Final Score: $SCORE"
    echo ""
    echo "Press any key..."
    read -n1
    exit 0
}

trap cleanup EXIT INT TERM

init_board() {
    for ((i=0; i<SIZE*SIZE; i++)); do
        BOARD[$i]=0
    done
    add_random_tile
    add_random_tile
}

get_cell() {
    local x=$1 y=$2
    echo ${BOARD[$((y * SIZE + x))]}
}

set_cell() {
    local x=$1 y=$2 val=$3
    BOARD[$((y * SIZE + x))]=$val
}

add_random_tile() {
    local empty=()
    for ((i=0; i<SIZE*SIZE; i++)); do
        if [[ ${BOARD[$i]} -eq 0 ]]; then
            empty+=($i)
        fi
    done

    if [[ ${#empty[@]} -gt 0 ]]; then
        local idx=${empty[$((RANDOM % ${#empty[@]}))]}
        if [[ $((RANDOM % 10)) -lt 9 ]]; then
            BOARD[$idx]=2
        else
            BOARD[$idx]=4
        fi
    fi
}

draw() {
    tput cup 0 0

    echo "╔═══════════════════════════╗"
    echo "║         2 0 4 8           ║"
    echo "╠═══════════════════════════╣"
    printf "║     Score: %-10d    ║\n" $SCORE
    echo "╠═══════════════════════════╣"

    echo "║  ┌──────┬──────┬──────┬──────┐  ║"

    for ((y=0; y<SIZE; y++)); do
        echo -n "║  │"
        for ((x=0; x<SIZE; x++)); do
            local val=$(get_cell $x $y)
            local color="${TILE_COLORS[$val]:-${TILE_COLORS[2048]}}"
            if [[ $val -eq 0 ]]; then
                echo -ne "${color}      ${NC}│"
            else
                printf "${color}%6d${NC}│" $val
            fi
        done
        echo "  ║"

        if [[ $y -lt $((SIZE-1)) ]]; then
            echo "║  ├──────┼──────┼──────┼──────┤  ║"
        fi
    done

    echo "║  └──────┴──────┴──────┴──────┘  ║"
    echo "╠═══════════════════════════╣"
    echo "║  ← ↑ ↓ → to move | q quit ║"
    echo "╚═══════════════════════════╝"
}

slide_row() {
    local -a row=("$@")
    local -a result=()
    local -a filtered=()

    # Filter out zeros
    for val in "${row[@]}"; do
        if [[ $val -ne 0 ]]; then
            filtered+=($val)
        fi
    done

    # Merge adjacent same values
    local i=0
    while [[ $i -lt ${#filtered[@]} ]]; do
        if [[ $((i+1)) -lt ${#filtered[@]} && ${filtered[$i]} -eq ${filtered[$((i+1))]} ]]; then
            local merged=$((filtered[i] * 2))
            result+=($merged)
            ((SCORE += merged))
            if [[ $merged -eq 2048 ]]; then
                WON=true
            fi
            ((i += 2))
        else
            result+=(${filtered[$i]})
            ((i++))
        fi
    done

    # Pad with zeros
    while [[ ${#result[@]} -lt $SIZE ]]; do
        result+=(0)
    done

    echo "${result[@]}"
}

move_left() {
    local moved=false

    for ((y=0; y<SIZE; y++)); do
        local row=()
        for ((x=0; x<SIZE; x++)); do
            row+=($(get_cell $x $y))
        done

        local new_row=($(slide_row "${row[@]}"))

        for ((x=0; x<SIZE; x++)); do
            if [[ $(get_cell $x $y) -ne ${new_row[$x]} ]]; then
                moved=true
            fi
            set_cell $x $y ${new_row[$x]}
        done
    done

    $moved && add_random_tile
}

move_right() {
    local moved=false

    for ((y=0; y<SIZE; y++)); do
        local row=()
        for ((x=$((SIZE-1)); x>=0; x--)); do
            row+=($(get_cell $x $y))
        done

        local new_row=($(slide_row "${row[@]}"))

        for ((x=0; x<SIZE; x++)); do
            local idx=$((SIZE - 1 - x))
            if [[ $(get_cell $idx $y) -ne ${new_row[$x]} ]]; then
                moved=true
            fi
            set_cell $idx $y ${new_row[$x]}
        done
    done

    $moved && add_random_tile
}

move_up() {
    local moved=false

    for ((x=0; x<SIZE; x++)); do
        local col=()
        for ((y=0; y<SIZE; y++)); do
            col+=($(get_cell $x $y))
        done

        local new_col=($(slide_row "${col[@]}"))

        for ((y=0; y<SIZE; y++)); do
            if [[ $(get_cell $x $y) -ne ${new_col[$y]} ]]; then
                moved=true
            fi
            set_cell $x $y ${new_col[$y]}
        done
    done

    $moved && add_random_tile
}

move_down() {
    local moved=false

    for ((x=0; x<SIZE; x++)); do
        local col=()
        for ((y=$((SIZE-1)); y>=0; y--)); do
            col+=($(get_cell $x $y))
        done

        local new_col=($(slide_row "${col[@]}"))

        for ((y=0; y<SIZE; y++)); do
            local idx=$((SIZE - 1 - y))
            if [[ $(get_cell $x $idx) -ne ${new_col[$y]} ]]; then
                moved=true
            fi
            set_cell $x $idx ${new_col[$y]}
        done
    done

    $moved && add_random_tile
}

can_move() {
    # Check for empty cells
    for ((i=0; i<SIZE*SIZE; i++)); do
        if [[ ${BOARD[$i]} -eq 0 ]]; then
            return 0
        fi
    done

    # Check for adjacent same values
    for ((y=0; y<SIZE; y++)); do
        for ((x=0; x<SIZE; x++)); do
            local val=$(get_cell $x $y)
            if [[ $x -lt $((SIZE-1)) && $val -eq $(get_cell $((x+1)) $y) ]]; then
                return 0
            fi
            if [[ $y -lt $((SIZE-1)) && $val -eq $(get_cell $x $((y+1))) ]]; then
                return 0
            fi
        done
    done

    return 1
}

read_input() {
    local key
    read -rsn1 key

    case "$key" in
        $'\x1b')
            read -rsn2 key
            case "$key" in
                '[A') move_up ;;
                '[B') move_down ;;
                '[C') move_right ;;
                '[D') move_left ;;
            esac
            ;;
        'w'|'W') move_up ;;
        's'|'S') move_down ;;
        'd'|'D') move_right ;;
        'a'|'A') move_left ;;
        'q'|'Q') GAME_OVER=true ;;
    esac
}

main() {
    setup
    init_board

    while ! $GAME_OVER; do
        draw

        if ! can_move; then
            GAME_OVER=true
            break
        fi

        read_input
    done
}

main
