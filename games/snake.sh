#!/bin/bash
# Snake game for claude-arcade
# Simple terminal snake using bash

# Game settings
WIDTH=30
HEIGHT=15
INITIAL_LENGTH=3
FRAME_DELAY=0.12

# Initialize
declare -a SNAKE_X SNAKE_Y
FOOD_X=0
FOOD_Y=0
DIRECTION="RIGHT"
SCORE=0
GAME_OVER=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Hide cursor and setup terminal
setup() {
    tput civis
    stty -echo -icanon time 0 min 0
    clear
}

# Restore terminal
cleanup() {
    tput cnorm
    stty echo icanon
    clear
    echo -e "${YELLOW}Game Over!${NC}"
    echo -e "Final Score: ${GREEN}$SCORE${NC}"
    echo ""
    echo "Press any key to exit..."
    stty -echo -icanon
    read -n1
    stty echo icanon
    exit 0
}

trap cleanup EXIT INT TERM

# Initialize snake in center
init_snake() {
    local start_x=$((WIDTH / 2))
    local start_y=$((HEIGHT / 2))

    for ((i=0; i<INITIAL_LENGTH; i++)); do
        SNAKE_X[$i]=$((start_x - i))
        SNAKE_Y[$i]=$start_y
    done
}

# Place food randomly
place_food() {
    while true; do
        FOOD_X=$((RANDOM % (WIDTH - 2) + 1))
        FOOD_Y=$((RANDOM % (HEIGHT - 2) + 1))

        # Check if food is on snake
        local on_snake=false
        for ((i=0; i<${#SNAKE_X[@]}; i++)); do
            if [[ ${SNAKE_X[$i]} -eq $FOOD_X && ${SNAKE_Y[$i]} -eq $FOOD_Y ]]; then
                on_snake=true
                break
            fi
        done

        if [[ $on_snake == false ]]; then
            break
        fi
    done
}

# Draw the game
draw() {
    tput cup 0 0

    # Title
    echo -e "${CYAN}╔══════ SNAKE ══════╗${NC}"
    echo -e "${CYAN}║${NC}  Score: $(printf '%4d' $SCORE)       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════╝${NC}"

    # Game board
    for ((y=0; y<HEIGHT; y++)); do
        for ((x=0; x<WIDTH; x++)); do
            # Border
            if [[ $y -eq 0 || $y -eq $((HEIGHT-1)) ]]; then
                echo -n "═"
                continue
            fi
            if [[ $x -eq 0 || $x -eq $((WIDTH-1)) ]]; then
                echo -n "║"
                continue
            fi

            # Check if this position has something
            local char=" "

            # Food
            if [[ $x -eq $FOOD_X && $y -eq $FOOD_Y ]]; then
                char="${RED}●${NC}"
            fi

            # Snake
            for ((i=0; i<${#SNAKE_X[@]}; i++)); do
                if [[ ${SNAKE_X[$i]} -eq $x && ${SNAKE_Y[$i]} -eq $y ]]; then
                    if [[ $i -eq 0 ]]; then
                        char="${GREEN}█${NC}"  # Head
                    else
                        char="${GREEN}▓${NC}"  # Body
                    fi
                    break
                fi
            done

            echo -ne "$char"
        done
        echo ""
    done

    echo -e "${YELLOW}← ↑ ↓ → to move | q to quit${NC}"
}

# Read input
read_input() {
    local key
    read -rsn1 key 2>/dev/null

    case "$key" in
        $'\x1b')
            read -rsn2 key 2>/dev/null
            case "$key" in
                '[A') [[ $DIRECTION != "DOWN" ]] && DIRECTION="UP" ;;
                '[B') [[ $DIRECTION != "UP" ]] && DIRECTION="DOWN" ;;
                '[C') [[ $DIRECTION != "LEFT" ]] && DIRECTION="RIGHT" ;;
                '[D') [[ $DIRECTION != "RIGHT" ]] && DIRECTION="LEFT" ;;
            esac
            ;;
        'w'|'W') [[ $DIRECTION != "DOWN" ]] && DIRECTION="UP" ;;
        's'|'S') [[ $DIRECTION != "UP" ]] && DIRECTION="DOWN" ;;
        'd'|'D') [[ $DIRECTION != "LEFT" ]] && DIRECTION="RIGHT" ;;
        'a'|'A') [[ $DIRECTION != "RIGHT" ]] && DIRECTION="LEFT" ;;
        'q'|'Q') GAME_OVER=true ;;
    esac
}

# Move snake
move_snake() {
    # Calculate new head position
    local new_x=${SNAKE_X[0]}
    local new_y=${SNAKE_Y[0]}

    case $DIRECTION in
        UP)    ((new_y--)) ;;
        DOWN)  ((new_y++)) ;;
        LEFT)  ((new_x--)) ;;
        RIGHT) ((new_x++)) ;;
    esac

    # Check wall collision
    if [[ $new_x -le 0 || $new_x -ge $((WIDTH-1)) || $new_y -le 0 || $new_y -ge $((HEIGHT-1)) ]]; then
        GAME_OVER=true
        return
    fi

    # Check self collision
    for ((i=0; i<${#SNAKE_X[@]}-1; i++)); do
        if [[ ${SNAKE_X[$i]} -eq $new_x && ${SNAKE_Y[$i]} -eq $new_y ]]; then
            GAME_OVER=true
            return
        fi
    done

    # Check food
    local ate_food=false
    if [[ $new_x -eq $FOOD_X && $new_y -eq $FOOD_Y ]]; then
        ate_food=true
        ((SCORE += 10))
        place_food
    fi

    # Move body
    if [[ $ate_food == false ]]; then
        unset 'SNAKE_X[-1]'
        unset 'SNAKE_Y[-1]'
    fi

    # Add new head
    SNAKE_X=("$new_x" "${SNAKE_X[@]}")
    SNAKE_Y=("$new_y" "${SNAKE_Y[@]}")
}

# Main game loop
main() {
    setup
    init_snake
    place_food

    while [[ $GAME_OVER == false ]]; do
        draw
        read_input
        move_snake
        sleep $FRAME_DELAY
    done
}

main
