    ;;    game state memory location
    .equ CURR_STATE, 0x1000              ; current game state
    .equ GSA_ID, 0x1004                     ; gsa currently in use for drawing
    .equ PAUSE, 0x1008                     ; is the game paused or running
    .equ SPEED, 0x100C                      ; game speed
    .equ CURR_STEP,  0x1010              ; game current step
    .equ SEED, 0x1014              ; game seed
    .equ GSA0, 0x1018              ; GSA0 starting address
    .equ GSA1, 0x1038              ; GSA1 starting address
    .equ SEVEN_SEGS, 0x1198             ; 7-segment display addresses
    .equ CUSTOM_VAR_START, 0x1200 ; Free range of addresses for custom variable definition
    .equ CUSTOM_VAR_END, 0x1300
    .equ LEDS, 0x2000                       ; LED address
    .equ RANDOM_NUM, 0x2010          ; Random number generator address
    .equ BUTTONS, 0x2030                 ; Buttons addresses

    ;; states
    .equ INIT, 0
    .equ RAND, 1
    .equ RUN, 2

    ;; constants
    .equ N_SEEDS, 4
    .equ N_GSA_LINES, 8
    .equ N_GSA_COLUMNS, 12
    .equ MAX_SPEED, 10
    .equ MIN_SPEED, 1
    .equ PAUSED, 0x00
    .equ RUNNING, 0x01

main:
	addi sp, zero, 0x2000
	call push_temps_on_stack
	call reset_game
	call pull_temps_from_stack

	call push_temps_on_stack
	call get_input
	call pull_temps_from_stack
	add t0, zero, zero ; done signal
	while_not_done:
		add a0, zero, v0 ; edge capture register 
		call push_temps_on_stack
		call select_action
		call pull_temps_from_stack

		call push_temps_on_stack
		call update_state
		call pull_temps_from_stack
	
		call push_temps_on_stack
		call update_gsa
		call pull_temps_from_stack
	
		call push_temps_on_stack
		call mask
		call pull_temps_from_stack

		call push_temps_on_stack
		call draw_gsa
		call pull_temps_from_stack

		call push_temps_on_stack
		call wait
		call pull_temps_from_stack

		call push_temps_on_stack
		call decrement_step
		call pull_temps_from_stack
	
		add t0, zero, v0 ; done signal
	
		call push_temps_on_stack
		call get_input
		call pull_temps_from_stack

		add a0, zero, v0 ; edge capture register 
		beq t0, zero, while_not_done
    br main


; BEGIN:helper
push_temps_on_stack:
    addi sp, sp, -4
	stw t0, 0(sp)
	addi sp, sp, -4
	stw t1, 0(sp)
	addi sp, sp, -4
	stw t2, 0(sp)
	addi sp, sp, -4
	stw t3, 0(sp)
	addi sp, sp, -4
	stw t4, 0(sp)
	addi sp, sp, -4
	stw t5, 0(sp)
	addi sp, sp, -4
	stw t6, 0(sp)
	addi sp, sp, -4
	stw t7, 0(sp)
	addi sp, sp, -4
	stw a0, 0(sp)
	addi sp, sp, -4
	stw a1, 0(sp)
	ret
pull_temps_from_stack:
	ldw a1, 0(sp)
	addi sp, sp, 4
	ldw a0, 0(sp)
	addi sp, sp, 4
    ldw t7, 0(sp)
	addi sp, sp, 4
	ldw t6, 0(sp)
	addi sp, sp, 4
	ldw t5, 0(sp)
	addi sp, sp, 4
	ldw t4, 0(sp)
	addi sp, sp, 4
	ldw t3, 0(sp)
	addi sp, sp, 4
	ldw t2, 0(sp)
	addi sp, sp, 4
	ldw t1, 0(sp)
	addi sp, sp, 4
	ldw t0, 0(sp)
	addi sp, sp, 4
	ret
store_step_in_7_segs:
	ldw t0, CURR_STEP(zero) ; curr_step
	andi t1, t0, 15 ; lsd
	slli t1, t1, 2 ; digit*4
	ldw t1, font_data(t1) ; 7seg of lsd
	addi t2, zero, 12 ; value 12
	stw t1, SEVEN_SEGS(t2) ; store 7seg of lsd
	
	srli t1, t0, 4 ; remove lsd
	andi t1, t1, 15 ; digit 
	slli t1, t1, 2 ; digit*4
	ldw t1, font_data(t1) ; 7seg of digit 1
	addi t2, zero, 8 ; value 8
	stw t1, SEVEN_SEGS(t2) ; store 7seg of digit 1

	srli t1, t0, 8 ; remove 2 least significant digits
	andi t1, t1, 15 ; digit 2
	slli t1, t1, 2 ; digit*4
	ldw t1, font_data(t1) ; 7seg of digit 2
	addi t2, zero, 4 ; value 4
	stw t1, SEVEN_SEGS(t2) ; store 7seg of digit 2

	ret
copy_seed_in_gsa:
	addi sp, sp, -4		
	stw ra, 0(sp)
	
	ldw t2, SEED(zero) ; load seed
	slli t2, t2, 2 ; seed * 4
	ldw t2, SEEDS(t2) ; get seed address

	add a1, zero, zero ; line index (y-coordinate)
	loop_copy_seed:
		ldw a0, 0(t2) ; get seed value
		
		call push_temps_on_stack
		call set_gsa
		call pull_temps_from_stack
			
		addi a1, a1, 1
		addi t2, t2, 4
		addi t3, zero, N_GSA_LINES
		blt a1, t3, loop_copy_seed ; while (a1 < 8) repeat

	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:helper

; BEGIN:clear_leds
clear_leds:	
	addi t0, zero, 4 ; value 4
	addi t1, t0, 4 ; value 8
	stw zero, LEDS (zero) ; LEDS[0]
	stw zero, LEDS (t0) ; LEDS[1]
	stw zero, LEDS (t1) ; LEDS[2]
	ret
; END:clear_leds

; BEGIN:set_pixel
set_pixel:
	srli t0, a0, 2 ; a0/4
	slli t1, t0, 2 ; a0/4 * 4
	ldw t2, LEDS(t1) ; current word in LEDS[0], LEDS[1] or LEDS[2]

	andi t0, a0, 3 ; a0 mod 4
	slli t5, t0, 3 ; (a0 mod 4) * 8
	add t6, t5, a1 ; exact bit position in the section of LEDS

	addi t3, zero, 1 ; value 1
	sll t5, t3, t6 ; word with only that bit selected

	or t7, t2, t5 ; current word with only the selected pixel modified
	stw t7, LEDS(t1) ; stores word
	ret
; END:set_pixel

; BEGIN:wait
wait:
	addi t0, zero, 1 ; value 1
	slli t1, t0, 19 ; 2^19
	ldw t2, SPEED (zero)
	loop_wait:
		sub t1, t1, t2 ; decrement time to wait by speed
		bge t1, t0, loop_wait ; check if time to wait >= 1
	ret
; END:wait

; BEGIN:get_gsa
get_gsa:
   	ldw t0, GSA_ID(zero) ; id of the gsa
	andi t0, t0, 1 ; specific bit with the id
	slli t1, a0, 2 ; multiply by 4 the line to get index
	beq zero, t0, get_gsa0 ; go to gsa0 if id is 0
	ldw v0, GSA1(t1)
	jmpi end_of_jump_get_gsa	
	get_gsa0: ldw v0, GSA0(t1)
	end_of_jump_get_gsa:	
	ret
; END:get_gsa

; BEGIN:set_gsa
set_gsa:
	ldw t0, GSA_ID(zero) ; id of the gsa
	andi t0, t0, 1 ; specific bit with the id
	slli t1, a1, 2 ; multiply by 4 the line to get index
	beq zero, t0, set_gsa0 ; go to gsa0 if id is 0
	stw a0, GSA1(t1)
	jmpi end_of_jump_set_gsa
	set_gsa0: stw a0, GSA0(t1)
	end_of_jump_set_gsa:
	ret
; END:set_gsa

; BEGIN:draw_gsa
draw_gsa:
		addi sp, sp, -4
		stw ra, 0(sp)

		call push_temps_on_stack
		call clear_leds ; clear leds before drawing
		call pull_temps_from_stack

		add t6, zero, zero ; current column index in gsa
		add t5, zero, zero ; leds to print
		loop_lines0_draw_gsa:
			addi t4, zero, N_GSA_LINES ; max line index in GSA
			add a0, zero, zero ; a0 : current line index in gsa
			add t2, zero, zero ; t2 : current column in leds
			addi t7, zero, 1 ; value 1
			sll t7, t7, t6 ; mask for current gsa line 
			loop_column0_draw_gsa:

				call push_temps_on_stack
				call get_gsa
				call pull_temps_from_stack
				

				and t3, v0, t7 ; correct position of current gsa line
				srl t3, t3, t6 ; puts it back at lsb
				sll t3, t3, a0 ; put it at the correct bit
				or t2, t2, t3 ; concatenate it with the current column in leds
				addi a0, a0, 1 ; increment the line index
				blt a0, t4, loop_column0_draw_gsa ; while (a0 < 8) repeat
			slli t7, t6, 3 ; current column index multiplied by 8
			sll t2, t2, t7 ; place the column at the right position
			or t5, t5, t2 ; concatenate the column to the rest of columns
			addi t6, t6, 1 ; increment column index
			addi t2, zero, 4 ; value 4
			blt t6, t2, loop_lines0_draw_gsa ; while (t6 < 4) repeat
		stw t5, LEDS(zero)

		add t5, zero, zero ; leds to print
		loop_lines1_draw_gsa:
			addi t4, zero, N_GSA_LINES ; max line index in GSA
			add a0, zero, zero ; a0 : current line index in gsa
			add t2, zero, zero ; t2 : current column in leds
			addi t7, zero, 1 ; value 1
			sll t7, t7, t6 ; mask for current gsa line 
			loop_column1_draw_gsa:

				call push_temps_on_stack
				call get_gsa
				call pull_temps_from_stack

				and t3, v0, t7 ; correct position of current gsa line
				srl t3, t3, t6 ; puts it back at lsb
				sll t3, t3, a0 ; put it at the correct bit
				or t2, t2, t3 ; concatenate it with the current column in leds
				addi a0, a0, 1 ; increment the line index
				blt a0, t4, loop_column1_draw_gsa ; while (a0 < 8) repeat
			srli t0, t6, 2 ; a0/4			
			slli t0, t0, 2 ; a0/4 * 4
			sub t0, t6, t0 ; a0 mod 4
			slli t7, t0, 3 ; current column index multiplied by 8
			sll t2, t2, t7 ; place the column at the right position
			or t5, t5, t2 ; concatenate the column to the rest of columns
			addi t6, t6, 1 ; increment column index
			addi t2, zero, 8 ; value 8
			blt t6, t2, loop_lines1_draw_gsa ; while (t6 < 8) repeat
		addi t2, zero, 4 ; value 4
		stw t5, LEDS(t2)

		add t5, zero, zero ; leds to print
		loop_lines2_draw_gsa:
			addi t4, zero, N_GSA_LINES ; max line index in GSA
			add a0, zero, zero ; a0 : current line index in gsa
			add t2, zero, zero ; t2 : current column in leds
			addi t7, zero, 1 ; value 1
			sll t7, t7, t6 ; mask for current gsa line 
			loop_column2_draw_gsa:

				call push_temps_on_stack
				call get_gsa
				call pull_temps_from_stack

				and t3, v0, t7 ; correct position of current gsa line
				srl t3, t3, t6 ; puts it back at lsb
				sll t3, t3, a0 ; put it at the correct bit
				or t2, t2, t3 ; concatenate it with the current column in leds
				addi a0, a0, 1 ; increment the line index
				blt a0, t4, loop_column2_draw_gsa ; while (a0 < 8) repeat
			srli t0, t6, 2 ; a0/4			
			slli t0, t0, 2 ; a0/4 * 4
			sub t0, t6, t0 ; a0 mod 4
			slli t7, t0, 3 ; current column index multiplied by 8
			sll t2, t2, t7 ; place the column at the right position
			or t5, t5, t2 ; concatenate the column to the rest of columns
			addi t6, t6, 1 ; increment column index
			addi t2, zero, N_GSA_COLUMNS ; value 12
			blt t6, t2, loop_lines2_draw_gsa ; while (t6 < 12) repeat
		addi t2, zero, 8 ; value 8
		stw t5, LEDS(t2)
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:draw_gsa


; BEGIN:random_gsa
random_gsa:
	addi sp, sp, -4
	stw ra, 0(sp)

	add a1, zero, zero ; current y index
	loop_y_random_gsa:
		add a0, zero, zero ; current line
		add t5, zero, zero ; current x index
		loop_x_random_gsa:
			ldw t2, RANDOM_NUM(zero) ; random 32-bit num
			andi t2, t2, 1 ; random num modulo 2
			sll t2, t2, t5 ; place modulo at the correct position
			or a0, a0, t2 ; concatenate the value with the rest
			addi t5, t5, 1 ; increment the column index
			addi t3, zero, N_GSA_COLUMNS ; number of columns
			blt t5, t3, loop_x_random_gsa ; while (t5 < 12) repeat

		call push_temps_on_stack
		call set_gsa
		call pull_temps_from_stack
	
		addi a1, a1, 1 ; increment the line index
		addi t4, zero, N_GSA_LINES ; number of lines
		blt a1, t4, loop_y_random_gsa ; while (a1 < 8) repeat
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:random_gsa

; BEGIN:change_speed
change_speed:
    ldw t0, SPEED(zero) ; load current speed
	beq a0, zero, increment_speed ; if a0 is 0 we increment, else we decrement
	addi t1, zero, 1 ; value 1
	beq t1, t0, end_of_decrement_speed
	sub t0, t0, t1 ; decrement
	jmpi end_of_decrement_speed ; skip the incrementation
	increment_speed:
		addi t2, zero, 10
		beq t0, t2, end_of_decrement_speed
		addi t0, t0, 1 ; increment
	end_of_decrement_speed:
	stw t0, SPEED(zero) ; store the new speed
	ret
; END:change_speed


; BEGIN:pause_game
pause_game:
    ldw t0, PAUSE(zero) ; load current pause setting
	xori t0, t0, 1 ; invert value
	stw t0, PAUSE(zero) ; store new value
	ret
; END:pause_game

; BEGIN:change_steps
change_steps:
	addi sp, sp, -4
	stw ra, 0(sp)

	ldw t0, CURR_STEP(zero) ; load current step
	add t0, t0, a0 ; increment or not units

	slli a1, a1, 4 ; tens
	add t0, t0, a1 ; increment or not tens

	slli a2, a2, 8 ; hundreds
	add t0, t0, a2 ; increment or not tens

	andi t0, t0, 0xFFF ; keep only the 3 lsd
	stw t0, CURR_STEP(zero) ; store new step

	call push_temps_on_stack
	call store_step_in_7_segs
	call pull_temps_from_stack

	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:change_steps

; BEGIN:increment_seed
increment_seed:
	addi sp, sp, -4
	stw ra, 0(sp)

	addi t3, zero, N_GSA_LINES

	ldw t0, CURR_STATE(zero) ; load state
	addi t1, zero, INIT
	beq t0, t1, increment_by_one_seed ; if INIT, go to increment by 1
	addi t1, zero, RAND
	beq t0, t1, generate_random_gsa_seed ; if RAND, go to generate random gsa
	jmpi skip_rand_seed


	increment_by_one_seed:
		ldw t2, SEED(zero) ; load seed
		addi t4, zero, N_SEEDS ; value 4
		bge t2, t4, generate_random_gsa_seed ; if the seed is superior or equal to 4, genreates a random_gsa
		addi t2, t2, 1 ; increment seed
		stw t2, SEED(zero) ; store new seed
		beq t2, t4, generate_random_gsa_seed ; if the new seed is superior or equal to 4, genreates a random_gsa
		
		call push_temps_on_stack
		call copy_seed_in_gsa
		call pull_temps_from_stack
			
		jmpi skip_rand_seed ; skip generation of random gsa
	generate_random_gsa_seed:

		call push_temps_on_stack
		call random_gsa ; generates random gsa
		call pull_temps_from_stack

	skip_rand_seed:
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:increment_seed

; BEGIN:update_state
update_state:
	addi sp, sp, -4
	stw ra, 0(sp)

	ldw t0, CURR_STATE(zero) ; curr_state
	addi t1, zero, INIT ; INIT state
	addi t2, zero, RAND ; RAND state
	addi t3, zero, RUN ; RUN state

	beq t0, t1, update_state_from_init
	beq t0, t2, update_state_from_rand
	beq t0, t3, update_state_from_run
	jmpi skip_update_state

	update_state_from_init:
		ldw t0, SEED(zero) ; load seed
		addi t4, zero, N_SEEDS ; value 4
		bge t0, t4, change_to_rand_from_init ; if the new seed is superior or equal to 4, that means button 0 has been pressed 4 times
		continue_update_from_init:
		andi t0, a0, 2 ; bit of button 1
		bne t0, zero, change_to_run_from_init ; if button 1 is pressed change to run
		jmpi skip_update_state
		change_to_rand_from_init:
			stw t2, CURR_STATE(zero) ; update state to rand
			jmpi continue_update_from_init
		change_to_run_from_init:
			stw t3, CURR_STATE(zero) ; update state to run
			call push_temps_on_stack
			call pause_game ; unpause game
			call pull_temps_from_stack
			jmpi skip_update_state

	update_state_from_rand:
		addi t0, zero, 2 ; value 2
		beq a0, t0, change_to_run_from_rand ; if button 1 is pressed change to run
		jmpi skip_update_state
		change_to_run_from_rand:
			stw t3, CURR_STATE(zero) ; update state to run
			jmpi skip_update_state

	update_state_from_run:
		addi t0, zero, 8 ; value 8
		beq a0, t0, change_to_init_from_run ; if button 3 is pressed change to init and resets
		jmpi skip_update_state
		change_to_init_from_run:
			call push_temps_on_stack
			call reset_game  ; 
			call pull_temps_from_stack
			stw t1, CURR_STATE(zero) ; update state to init
		
	skip_update_state:
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:update_state

; BEGIN:select_action
select_action:
	addi sp, sp, -4
	stw ra, 0(sp)

	ldw t0, CURR_STATE(zero) ; curr_state
	addi t1, zero, INIT ; INIT state
	addi t2, zero, RAND ; RAND state
	addi t3, zero, RUN ; RUN state

	beq t0, t1, select_action_from_init
	beq t0, t2, select_action_from_rand
	beq t0, t3, select_action_from_run
	jmpi skip_select_action

	select_action_from_init:
		addi t0, zero, 1 ; value 1
		beq a0, t0, select_action_from_init_button0
		addi t0, zero, 2 ; value 2
		beq a0, t0, select_action_from_init_button1
		addi t0, zero, 4 ; value 4
		beq a0, t0, select_action_from_init_button2
		addi t0, zero, 8 ; value 8
		beq a0, t0, select_action_from_init_button3
		addi t0, zero, 16 ; value 16
		beq a0, t0, select_action_from_init_button4
		jmpi skip_select_action

		select_action_from_init_button0: ; increment seed if button 0
			call push_temps_on_stack
			call increment_seed
			call pull_temps_from_stack

			jmpi skip_select_action
		select_action_from_init_button1: 
			jmpi skip_select_action
		select_action_from_init_button2: ; change steps if button 2, 3 or 4
			addi a2, zero, 1
			add a1, zero, zero
			add a0, zero, zero
			call push_temps_on_stack
			call change_steps
			call pull_temps_from_stack
			jmpi skip_select_action
		select_action_from_init_button3:
			add a2, zero, zero
			addi a1, zero, 1
			add a0, zero, zero
			call push_temps_on_stack
			call change_steps
			call pull_temps_from_stack
			jmpi skip_select_action	
		select_action_from_init_button4:
			add a2, zero, zero
			add a1, zero, zero
			addi a0, zero, 1
			call push_temps_on_stack
			call change_steps
			call pull_temps_from_stack
			jmpi skip_select_action

	select_action_from_rand:
		addi t0, zero, 1 ; value 1
		beq a0, t0, select_action_from_rand_button0
		addi t0, zero, 2 ; value 2
		beq a0, t0, select_action_from_rand_button1
		addi t0, zero, 4 ; value 4
		beq a0, t0, select_action_from_rand_button2
		addi t0, zero, 8 ; value 8
		beq a0, t0, select_action_from_rand_button3
		addi t0, zero, 16 ; value 16
		beq a0, t0, select_action_from_rand_button4
		jmpi skip_select_action
		
		select_action_from_rand_button0: ; generate random gsa if button 0
			call push_temps_on_stack
			call random_gsa
			call pull_temps_from_stack
			jmpi skip_select_action

		select_action_from_rand_button1:
			call push_temps_on_stack
			call pause_game ; unpause game
			call pull_temps_from_stack
			jmpi skip_select_action
		select_action_from_rand_button2: ; change steps if button 2, 3 or 4
			addi a2, zero, 1
			add a1, zero, zero
			add a0, zero, zero
			call push_temps_on_stack
			call change_steps
			call pull_temps_from_stack
			jmpi skip_select_action
		select_action_from_rand_button3:
			add a2, zero, zero
			addi a1, zero, 1
			add a0, zero, zero
			call push_temps_on_stack
			call change_steps
			call pull_temps_from_stack
			jmpi skip_select_action	
		select_action_from_rand_button4:
			add a2, zero, zero
			add a1, zero, zero
			addi a0, zero, 1
			call push_temps_on_stack
			call change_steps
			call pull_temps_from_stack
			jmpi skip_select_action				
			
	select_action_from_run:
		addi t0, zero, 1 ; value 1
		beq a0, t0, select_action_from_run_button0
		addi t0, zero, 2 ; value 2
		beq a0, t0, select_action_from_run_button1
		addi t0, zero, 4 ; value 4
		beq a0, t0, select_action_from_run_button2
		addi t0, zero, 8 ; value 8
		beq a0, t0, select_action_from_run_button3
		addi t0, zero, 16 ; value 16
		beq a0, t0, select_action_from_run_button4
		jmpi skip_select_action
		
		select_action_from_run_button0: ; pause game if button 0
			call push_temps_on_stack
			call pause_game
			call pull_temps_from_stack
			jmpi skip_select_action	
		select_action_from_run_button1: ; increment speed if button 1
			add a0, zero, zero
			call push_temps_on_stack
			call change_speed
			call pull_temps_from_stack
			jmpi skip_select_action
		select_action_from_run_button2: ; decrement speed if button 2
			addi a0, zero, 1
			call push_temps_on_stack
			call change_speed
			call pull_temps_from_stack
			jmpi skip_select_action	
		select_action_from_run_button3: 
			jmpi skip_select_action
	 	select_action_from_run_button4: ; generate random gsa if button 4
			call push_temps_on_stack
			call random_gsa
			call pull_temps_from_stack	
						
	skip_select_action:
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:select_action

; BEGIN:cell_fate
cell_fate:
	addi t0, zero, 3
	beq a0, t0, live_fate
	addi t0, zero, 2
	beq a0, t0, check_if_alive_fate
	add v0, zero, zero
	jmpi skip_alive_fate
	check_if_alive_fate:
		addi t0, zero, 1
		beq a1, t0, live_fate
		add v0, zero, zero
		jmpi skip_alive_fate
	live_fate:
		addi v0, zero, 1 
	skip_alive_fate:
	ret
; END:cell_fate

; BEGIN:find_neighbours
find_neighbours:
	addi sp, sp, -4
	stw ra, 0(sp)

	add t6, zero, zero ; counter of live neighbours
	add t2, zero, a0 ; x coordinate
	beq t2, zero, minus_1_find_neighbours ; if the x coordinate is zero, you need x-1 = 11
	addi t5, t2, -1 ; x-1 coordinate
	jmpi skip_minus_1_find_neighbours
	minus_1_find_neighbours:
		addi t5, zero, 11 ; x-1 coordinate
	skip_minus_1_find_neighbours:
	addi t7, zero, 11
	beq t2, t7, twelve_find_neighbours	 ; if x = 11 you need x + 1 = 0
	addi t7, t2, 1 ; x+1 coordinate
	jmpi skip_twelve_find_neighbours
	twelve_find_neighbours:
		add t7, zero, zero
	skip_twelve_find_neighbours:

	; x

	add a0, zero, a1 ; y coordinate

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line of cell
	srl t3, t3, t2 ; store the specific bit in lsb
	andi v1, t3, 1 ; keep only lsb

	addi t4, a1, 1 ; y coordinate + 1
	andi t4, t4, 7 ; (y+1) mod 8
	add a0, zero, t4 ; y+1 mod 8

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line y+1
	srl t3, t3, t2 ; store the specific bit in lsb
	andi t3, t3, 1 ; keep only lsb
	add t6, t6, t3 ; add 1 in number of neighbours if alive

	addi t4, a1, -1 ; y coordinate - 1
	andi t4, t4, 7 ; (y-1) mod 8
	add a0, zero, t4 ; y-1 mod 8

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line y-1
	srl t3, t3, t2 ; store the specific bit in lsb
	andi t3, t3, 1 ; keep only lsb
	add t6, t6, t3 ; add 1 in number of neighbours if alive

	; x-1

	add a0, zero, a1 ; y coordinate

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line of cell
	srl t3, t3, t5 ; store the specific bit in lsb
	andi t3, t3, 1 ; keep only lsb
	add t6, t6, t3 ; add 1 in number of neighbours if alive

	addi t4, a1, 1 ; y coordinate + 1
	andi t4, t4, 7 ; (y+1) mod 8
	add a0, zero, t4 ; y+1 mod 8

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line y+1
	srl t3, t3, t5 ; store the specific bit in lsb
	andi t3, t3, 1 ; keep only lsb
	add t6, t6, t3 ; add 1 in number of neighbours if alive

	addi t4, a1, -1 ; y coordinate - 1
	andi t4, t4, 7 ; (y-1) mod 8
	add a0, zero, t4 ; y-1 mod 8

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line y-1
	srl t3, t3, t5 ; store the specific bit in lsb
	andi t3, t3, 1 ; keep only lsb
	add t6, t6, t3 ; add 1 in number of neighbours if alive

	; x+1

	add a0, zero, a1 ; y coordinate

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line of cell
	srl t3, t3, t7 ; store the specific bit in lsb
	andi t3, t3, 1 ; keep only lsb
	add t6, t6, t3 ; add 1 in number of neighbours if alive

	addi t4, a1, 1 ; y coordinate + 1
	andi t4, t4, 7 ; (y+1) mod 8
	add a0, zero, t4 ; y+1 mod 8

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line y+1
	srl t3, t3, t7 ; store the specific bit in lsb
	andi t3, t3, 1 ; keep only lsb
	add t6, t6, t3 ; add 1 in number of neighbours if alive

	addi t4, a1, -1 ; y coordinate - 1
	andi t4, t4, 7 ; (y-1) mod 8
	add a0, zero, t4 ; y-1 mod 8

	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack

	add t3, zero, v0 ; line y-1
	srl t3, t3, t7 ; store the specific bit in lsb
	andi t3, t3, 1 ; keep only lsb
	add t6, t6, t3 ; add 1 in number of neighbours if alive

	add v0, zero, t6 ; return value in counter
	
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:find_neighbours

; BEGIN:update_gsa
update_gsa:
	addi sp, sp, -4
	stw ra, 0(sp)

	ldw t0, PAUSE(zero) 
	beq t0, zero, skip_update_gsa ; if game is paused, skip update
	
	
	add t1, zero, zero ; initialize y coordinate
	loop_y_update_gsa:
		add t4, zero, zero ; current line
		add t0, zero, zero ; initialize x coordinate
		loop_x_update_gsa:
			add a0, zero, t0 ; x
			add a1, zero, t1 ; y

			call push_temps_on_stack
			call find_neighbours
			call pull_temps_from_stack				

			add a0, zero, v0 ; number of neighbours
			add a1, zero, v1 ; current state
			call push_temps_on_stack
			call cell_fate
			call pull_temps_from_stack

			add t3, zero, v0 ; next state
			sll t3, t3, t0 ; place at correct column
			or t4, t4, t3 ; add to the current line
	
			addi t0, t0, 1
			addi t2, zero, N_GSA_COLUMNS
			blt t0, t2, loop_x_update_gsa

		add a0, zero, t4 ; new line
		add a1, zero, t1 ; y

		ldw t0, GSA_ID(zero) ; load current gsa id
		xori t0, t0, 1 ; invert value
		stw t0, GSA_ID(zero) ; store new value

		call push_temps_on_stack
		call set_gsa
		call pull_temps_from_stack

		ldw t0, GSA_ID(zero) ; load current gsa id
		xori t0, t0, 1 ; invert value
		stw t0, GSA_ID(zero) ; store new value

		addi t1, t1, 1
		addi t2, zero, N_GSA_LINES
		blt t1, t2, loop_y_update_gsa
	
	    ldw t0, GSA_ID(zero) ; load current gsa id
		xori t0, t0, 1 ; invert value
		stw t0, GSA_ID(zero) ; store new value
		
	skip_update_gsa:
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:update_gsa

; BEGIN:mask
mask:
	addi sp, sp, -4
	stw ra, 0(sp)

	addi t3, zero, N_GSA_LINES

	ldw t2, SEED(zero) ; load seed, which corresponds to exactly the mask index in our implementation
	slli t2, t2, 2 ; seed * 4
	ldw t2, MASKS(t2) ; get mask address

	add a1, zero, zero ; line index (y-coordinate)
	loop_mask:
		add a0, zero, a1 ; y coordinate
		ldw t4, GSA_ID(zero)
		call push_temps_on_stack
		call get_gsa ; get current line value
		call pull_temps_from_stack

		ldw t1, 0(t2) ; get mask value
		and a0, v0, t1 ; apply mask
			
		call push_temps_on_stack
		call set_gsa
		call pull_temps_from_stack
			
		addi a1, a1, 1
		addi t2, t2, 4
		blt a1, t3, loop_mask ; while (a1 < 8) repeat
			
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:mask

; BEGIN:get_input
get_input:
	addi t0, zero, 4 ; value 4
	ldw t0, BUTTONS(t0) ; extract buttons
	addi t1, zero, -1 ; lsb position that is set
	addi t4, zero, 5 ; value 5
	choose_get_input:
		addi t1, t1, 1 ; increment position
		beq t1, t4, no_button_pressed_get_input
		srl t2, t0, t1 ; put it at the end
		andi t3, t2, 1 ; keep only last bit
		beq	t3, zero, choose_get_input ; if not '1', go to next position
	sll v0, t3, t1 ; move the bit to its correct position
	jmpi skip_no_button_get_input
	no_button_pressed_get_input:
		add v0, zero, zero ; output 0 if no button is pressed 
	skip_no_button_get_input:
	addi t0, zero, 4 ; value 4
	stw zero, BUTTONS(t0) ; clear edgecapture
	ret
; END:get_input

; BEGIN:decrement_step
decrement_step:
	addi sp, sp, -4
	stw ra, 0(sp)

	ldw t0, CURR_STATE(zero) ; curr_state
	addi t1, zero, RUN ; run state
	bne t0, t1, return_0_decrement_step ; if state is not run, skip decrement
	ldw t0, PAUSE(zero) 
	beq t0, zero, return_0_decrement_step ; if game is paused, skip decrement

	ldw t0, CURR_STEP(zero) ; curr_step
	beq t0, zero, return_1_decrement_step
	addi t0, t0, -1 ; decrement step
	stw t0, CURR_STEP(zero)

	jmpi return_0_decrement_step
	return_1_decrement_step:
		addi v0, zero, 1 ; return 
		jmpi skip_return0_decrement_step
	return_0_decrement_step:
		
		call push_temps_on_stack
		call store_step_in_7_segs
		call pull_temps_from_stack

		add v0, zero, zero ; if step not 0 return 0
	skip_return0_decrement_step:
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:decrement_step

; BEGIN:reset_game
reset_game:
	addi sp, sp, -4
	stw ra, 0(sp)

	addi t0, zero, INIT ; value 1
	stw t0, CURR_STATE(zero) ; set state to init

	addi t0, zero, 1 ; value 1
	stw t0, CURR_STEP(zero) ; set step to 1

	call push_temps_on_stack
	call store_step_in_7_segs ; store step in 7seg
	call pull_temps_from_stack

	stw zero, SEED(zero) ; set seed to seed0

	stw zero, GSA_ID(zero) ; set gsa to gsa0
	
	call push_temps_on_stack
	call copy_seed_in_gsa ; initialize game state
	call pull_temps_from_stack

	call push_temps_on_stack
	call draw_gsa ; draw the gsa
	call pull_temps_from_stack

	stw zero, PAUSE(zero) ; game is paused
	
	stw t0, SPEED(zero) ; set speed to 1
	
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
; END:reset_game

font_data:
    .word 0xFC ; 0
    .word 0x60 ; 1
    .word 0xDA ; 2
    .word 0xF2 ; 3
    .word 0x66 ; 4
    .word 0xB6 ; 5
    .word 0xBE ; 6
    .word 0xE0 ; 7
    .word 0xFE ; 8
    .word 0xF6 ; 9
    .word 0xEE ; A
    .word 0x3E ; B
    .word 0x9C ; C
    .word 0x7A ; D
    .word 0x9E ; E
    .word 0x8E ; F

seed0:
    .word 0xC00
    .word 0xC00
    .word 0x000
    .word 0x060
    .word 0x0A0
    .word 0x0C6
    .word 0x006
    .word 0x000

seed1:
    .word 0x000
    .word 0x000
    .word 0x05C
    .word 0x040
    .word 0x240
    .word 0x200
    .word 0x20E
    .word 0x000

seed2:
    .word 0x000
    .word 0x010
    .word 0x020
    .word 0x038
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000

seed3:
    .word 0x000
    .word 0x000
    .word 0x090
    .word 0x008
    .word 0x088
    .word 0x078
    .word 0x000
    .word 0x000

    ;; Predefined seeds
SEEDS:
    .word seed0
    .word seed1
    .word seed2
    .word seed3

mask0:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF

mask1:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x1FF
	.word 0x1FF
	.word 0x1FF

mask2:
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF

mask3:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000

mask4:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000

MASKS:
    .word mask0
    .word mask1
    .word mask2
    .word mask3
    .word mask4
