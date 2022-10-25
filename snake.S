.org $8000

.define Snake_Color $00
.define Fruit_X $01
.define Fruit_Y $02
.define Fruit_Color $03
.define Snake_Length $04
; $60-$7F temp memory used for function stuffs
.define Head_X $80  ; $80-$BF X location of snake parts (max 20, even if max capacity is 64)
.define Head_Y $C0  ; $C0-$FF Y location of snake parts (max 20, even if max capacity is 64)
.define Monitor $0200
.define Game_Started $0300 ; "boolean" variable to see if game has started, 0 if has not started, anything else otherwise
.define Seed $0301
.define Input $4000

start:
    ; clear stack
    LDX #$FF
    TXS
    ; clearing zero page, monitor page and three page
    LDY #0
    LDX #0
    LDA #0
    JSR clear_zero_page_loop
    LDA #2
    STA $01
    LDA #0
    STA $00
    LDY #0
    LDA #0
    JSR clear_any_page_loop
    LDA #3
    STA $01
    LDA #0
    STA $00
    LDY #0
    LDA #0
    JSR clear_any_page_loop

    LDX #8  ; starting x point of the snake
    STX Head_X
    LDX #8  ; starting y point of the snake
    STX Head_Y
    LDX #1  ; initial length of the snake (1)
    STX Snake_Length
    LDX #6  ; color of the snake
    STX Snake_Color
    LDX #2  ; color of the fruit
    STX Fruit_Color
    LDX #0  ; initial 0 value for game not started
    STX Game_Started
    JMP start_loop

clear_zero_page_loop:
    STA $00,X
    INX
    BNE clear_zero_page_loop
    RTS

clear_any_page_loop:
    STA ($00),Y
    INY
    BNE clear_any_page_loop
    RTS

; user need to press up+right to start the game, thus giving a random seed each time for random fruit location
start_loop:
    LDA Input
    CMP #9
    BEQ initiate_game
    JMP start_loop

initiate_game:
    INC Game_Started
    JSR sleep
    JSR spawn_fruit
    JMP game_loop

head_matches_fruit_x:
    LDA Head_Y
    CMP Fruit_Y
    BNE done_checking
    JSR spawn_fruit
    JSR add_snake_part

game_loop:
    ; check if snake head is on fruit position 
    LDA Head_X
    CMP Fruit_X
    BEQ head_matches_fruit_x
done_checking:
    LDA Input
    CMP #1
    BEQ move_up
    LDA Input
    CMP #2
    BEQ move_down
    LDA Input
    CMP #4
    BEQ move_left
    LDA Input
    CMP #8
    BEQ move_right
    JSR sleep
    JMP game_loop

move_up:
    ; move head position up and store the new coordinate in X and Y register
    SEC
    LDX Head_X
    LDA Head_Y
    SBC #1
    JSR clear_leftmost_halfbyte
    TAY
    JSR follow_snake_parts
    JSR sleep
    JMP game_loop

move_down:
    ; move head position down and store the new coordinate in X and Y register
    LDX Head_X
    LDA Head_Y
    CLC
    ADC #1
    JSR clear_leftmost_halfbyte
    TAY
    JSR follow_snake_parts
    JSR sleep
    JMP game_loop

move_left:
    ; move head position left and store the new coordinate in X and Y register
    SEC
    LDA Head_X
    LDY Head_Y
    SBC #1
    JSR clear_leftmost_halfbyte
    TAX
    JSR follow_snake_parts
    JSR sleep
    JMP game_loop

move_right:
    ; move head position right and store the new coordinate in X and Y register
    LDA Head_X
    LDY Head_Y
    CLC
    ADC #1
    JSR clear_leftmost_halfbyte
    TAX
    JSR follow_snake_parts
    JSR sleep
    JMP game_loop

spawn_fruit:
    JSR get_rng ; get random XY value (2 bytes from 0-16, stored in Accumulator)
    STA $77 ; save it for later
    ; save the fruit X and Y to the relative memory address
    LSR A
    LSR A
    LSR A
    LSR A
    STA Fruit_Y
    LDA $77
    ASL A
    ASL A
    ASL A
    ASL A
    LSR A
    LSR A
    LSR A
    LSR A
    STA Fruit_X
    ; draw the fruit
    LDA Fruit_Color
    LDX Fruit_X
    LDY Fruit_Y
    JSR draw_pixel
    RTS

; function where it shifts all the snake parts to the new head position X and Y that are stored in X and Y registers before this function
follow_snake_parts:
    ; save in memory $60-$62 the X and Y of the new head position and the current snake length
    STX $60
    STY $61
    LDA Snake_Length
    STA $62
update_snake_parts_loop:
    JSR update_part
    DEC $62
    BNE update_snake_parts_loop
    JSR check_death
    RTS

update_part:
    ; shift all the snake part 1 place right to the snake "array", making sure for the first one (the tail) to erease it from the monitor
    LDA Snake_Length
    CMP $62
    BNE not_tail
    LDY $62
    DEY
    LDA Head_X,Y
    PHA
    LDA Head_Y,Y
    TAY
    PLA
    TAX
    LDA #0
    JSR draw_pixel ; erease from monitor the old tail position
not_tail:
    ; now copy the next section position to the current one, exepct for the head
    LDY $62
    DEY
    BNE not_head
    RTS
not_head:
    LDY $62
    DEY
    DEY
    ; get next section position and paste it to the current one
    LDA Head_X,Y
    PHA
    LDA Head_Y,Y
    INY
    STA Head_Y,Y
    PLA
    STA Head_X,Y
    RTS

; in $60-61 currently are saved the new head coordinates
check_death:
    LDX $60
    LDY $61
    JSR read_pixel
    CMP Snake_Color
    BNE not_dead
    JMP game_over
not_dead:
    LDX $60
    LDY $61
    LDA Snake_Color
    JSR draw_pixel
    LDX $60
    LDY $61
    STX Head_X
    STY Head_Y
    RTS

clear_leftmost_halfbyte:
    ASL A
    ASL A
    ASL A
    ASL A
    LSR A
    LSR A
    LSR A
    LSR A
    RTS

add_snake_part:
    LDA #20 ; max snake sections, skip part if greater or equal than 20
    CLC
    CMP Snake_Length
    BCS add_part
    RTS
add_part:
    INC Snake_Length
    RTS

game_over:
    JMP game_over

; function to draw pixel in X and Y location stored in X and Y registers, with color stored in Accumulator
draw_pixel:
    PHA
    STX $67
    STY $68
    LDA #0
    CLC
    ADC $68
    ASL A
    ASL A
    ASL A
    ASL A
    ADC $67
    TAX
    PLA
    STA Monitor,X
    RTS

; function to print color (in A) of monitor's pixel at X and Y coordinates in X and Y registers
read_pixel:
    STX $70
    STY $71
    LDA #0
    CLC
    ADC $71
    ASL A
    ASL A
    ASL A
    ASL A
    ADC $70
    TAY
    LDA Monitor,Y
    RTS

sleep:
	LDX #2
outer_loop:
	LDA #220
	SBC $03		; subtract section count from iteration count a few times
	SBC $03		
	SBC $03
	SBC $03
	SBC $03
	SBC $03
	SBC $03
	CLC
inner_loop:
	SBC #1
	BNE inner_loop
	DEX
	BNE outer_loop
	RTS

get_rng:
    LDA Seed
    BEQ doEor
    ASL A
    BEQ noEor
    BCC noEor
doEor:
    EOR #$1D
noEor:
    STA Seed
    RTS 

nmi:
    LDA Game_Started
    CMP #0
    BEQ increase_seed
    RTI
increase_seed:
    INC Seed
    RTI

.goto $FFFA
.dw nmi
.dw start
.dw start