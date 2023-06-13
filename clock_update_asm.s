.text                           # IMPORTANT: subsequent stuff is executable
.global  set_tod_from_ports

## ENTRY POINT FOR REQUIRED FUNCTION
set_tod_from_ports:
        movl    TIME_OF_DAY_PORT(%rip), %ecx    # copy global var to reg ecx
          
        ## Checking for a valid time
        cmpl    $0, %ecx                        # if (time_port < 0)
        jl     .INVALID_TOD
        cmpl    $1382400, %ecx                  # if (time_port > 86400 * 16)
        jg      .INVALID_TOD

        ## calculating --> seconds_since_start_of_day
        movl    %ecx, %r11d                     # r11d = seconds
        addl    $7, %r11d                       # Add 7 to the TIME_OF_DAY_PORTS
        shrl    $4, %r11d                       # shifting TIME_OF_DAY_PORTS to the right by 4 bits
        
        movl    %r11d, 0(%rdi)                  # storing seconds into tod->day_secs

        # calculating hours
        movl    0(%rdi), %eax                   # store seconds in eax
        movl    $3600, %ecx                     # moving 3600 into register %ecx
        cqto                                    # prepping for division
        idivl   %ecx                            # dividing eax by 3600
                                                # eax = seconds / 3600
                                                # edx = remainder
        
        movl    %eax, %r12d                     # storing hours in r12d

        movl    $12, %ecx                       # setting divisor to 12
        cqto
        idivl   %ecx                            # eax = (seconds / 3600) / 12
                                                # edx = (seconds / 3600) % 12

        movw    %dx, 8(%rdi)                    # setting tod->time_hours

        cmpw    $0, 8(%rdi)
        jne     .TIME_HOUR_NOT_ZERO
        movw    $12, 8(%rdi)

 .TIME_HOUR_NOT_ZERO:
        ## getting int minutes = (seconds_since_start_of_day / 60) % 60;
        ## tod->time_mins
        movl     %r11d, %eax                    # sets eax to seconds (r11d)
        movl     $60, %ecx                      # sets divisor to 60
        cqto
        idivl   %ecx                            # eax = (seconds / 60)
                                                # edx = remainder
        cqto
        idivl   %ecx                            # eax = (seconds / 60) / 60
                                                # edx  = (seconds / 60) % 60
        movw    %dx, 6(%rdi) 

        # tod->time_secs
        movl    %r11d, %eax                     # sets eax to seconds
        movl    $60, %ecx                       # sets divisor to 60
        cqto
        idivl   %ecx                            # eax = (seconds / 60)
                                                # edx = (seconds % 60)
        movw    %dx, 4(%rdi)                   

        ## getting tod->ampm
        movl    %r12d, %eax                     # sets eax to hours
        movl    $12, %ecx                       # set divisor to 12
        cqto
        idivl   %ecx                            # eax = (hours / 12)

        addl    $1, %eax                        # eax = (hours / 12) + 1
        movb    %al, 10(%rdi)

        movl    $0, %eax
        ret 

.INVALID_TOD:
        movl    $1, %eax                # returning 1 for error
        ret


.data                          
        masks:                          # array of bit-masks for each digit on clock 
                .int 0b1110111          # 0
                .int 0b0100100          # 1    
                .int 0b1011101          # 2
                .int 0b1101101          # 3
                .int 0b0101110          # 4
                .int 0b1101011          # 5
                .int 0b1111011          # 6
                .int 0b0100101          # 7
                .int 0b1111111          # 8
                .int 0b1101111
                          # 9   


.text                         
.global  set_display_from_tod
set_display_from_tod:
        movq    $0, %rbx
        movq    %rdx, %rbx              # move *display pointer to reg

        ## pushing all callee-save registers
        
   ## (1) -> If statements checking for valid tod times:

        # checking/grabbing tod.time_hours
        movq    %rsi, %r8               # move tod.time_hours into register r8
        andq    $0xFFFF, %r8              # clear out the upper bits
        cmpq    $12, %r8                # if tod.time_hours > 12 (using hexidecimal)
        jg      .RETURN_ONE
        cmpq    $1, %r8                 # if tod_time.hours < 1
        jl      .RETURN_ONE

        # checking/grabbing time_mins
        movq    %rdi, %r9               # move tod.time_mins into register r9
        shrq    $48, %r9                # shift to the right by 48
        andq    $0xFFFF, %r9              # grab the lower 8 bits
        cmpq    $0, %r9                 # tod.time_mins < 0
        jl      .RETURN_ONE
        cmpq    $60, %r9                # tod.time_mins >= 60      
        jge     .RETURN_ONE

        # checking/grabbing time_secs
        movq    %rdi, %r10              # move tod.time_secs into register r10
        shrq    $32, %r10               # shifting to the right by 32
        andq    $0xFFFF, %r10             # grabbing lower 8 bits
        cmpq    $0, %r10                # tod.time_secs < 0
        jl      .RETURN_ONE
        cmpq    $60, %r10               # tod.time_secs >= 60
        jge     .RETURN_ONE

        # checking/grabbing ampm
        movq    %rsi, %r11              # move tod.ampm into register r11
        shrq    $16, %r11               # shift to the right by 16
        andq    $0xFF, %r11              # grab the lower four bits
        cmpq    $2, %r11                # tod.ampm > 2 
        jg      .RETURN_ONE            
        cmpq    $1, %r11                # tod.ampm < 1
        jl      .RETURN_ONE


        ###############################
        #       Current Log :         #  
        # --------------------------- #            
        #     %r8 -> tod.time_hours   #
        #     %r9 -> tod.time_mins    #
        #     %r10 -> tod.time_secs   #
        #     %r11 -> tod.ampm        #
        #     %rbx -> *display        #
        ###############################

   ## (2) Arithmetic calcultions to find the time:

        # getting the hours_one by performing divison
        movq    %r8, %rax               # placing tod.time_hours into %rax
        movl    $10, %ecx               # placing 10 into %ebx
        cqto                            # prepping for division
        idivl   %ecx                    # quo -> %rax ; rem => %rdx
        movq    %rdx, %r12              # hours_one = register %r12

        # getting the hours_ten by performing divison
        movq    %r8, %rax               # placing tod.time_hours into %rax
        movl    $10, %ecx               # placing 10 into %ebx
        cqto                            # division prep
        idivl   %ecx                    # quo -> %rax ; rem -> %rdx
        movq    %rax, %r13              # hours_one = register %r13

        # getting the min_ones by performing division
        movq    %r9, %rax               # placing tod.time_mins into register %rax
        movl    $10, %ecx               # %ebx = 10
        cqto
        idivl   %ecx                    # quot -> %rax ; rem -> %rdx
        movq    %rdx, %r14              # min_ones = tod.time_mins % 10;

        # getting the min_tens by performing division
        movq    %r9, %rax               # moving tod.time_mins into %rax
        movl    $10, %ecx               # %ebx = 10
        cqto
        idivl   %ecx
        mov     %rax, %r15              # min_tens = (tod.time_mins / 10)

        # clearing out ALL tod fields (no longer needed)
        movq    $0, %r8
        movq    $0, %r9
        movq    $0, %r10

        ###############################
        #       Current Log :         #  
        # --------------------------- #    
        #     %r8 -> CLEARED          #
        #     %r9 -> CLEARED          #
        #     %r10 -> CLEARED         #
        #     %r11 -> tod.ampm        #    
        #     %r12 -> hours_one       #
        #     %r13 -> hours_ten       #
        #     %r14 -> min_ones        #
        #     %r15 -> min_tens        #
        #     %r15 -> min_tens        #
        #     %rbx -> *display        #
        ###############################

   ## (3) Shifting bit patterns to represent the digital using the mask array 
        leaq    masks(%rip), %r8         # %r8 now points to the masks array...
        movl    $0, %r9d                 # initializing display_pattern = 0

        # display_pattern = (masks[min_ones] << 0);
        movl    (%r8, %r14, 4), %r9d

        # display_pattern |= (masks[min_tens] << 7);
        movl    (%r8, %r15, 4), %r10d      # storing (masks[min_tens] into %r10d     
        shll    $7, %r10d                  # shifting to the left by 7   
        orl     %r10d, %r9d                # perfoming |= with display 

        # display_pattern |= (masks[hour_ones] << 14);  
        movl    (%r8, %r12, 4), %r10d      # storing (masks[hours_one] into %r10d
        shll    $14, %r10d                 # shifting to the left by 14
        orl     %r10d, %r9d                # perfoming |= with display

   ## (4) the tens digit of the hour is special in that it should be either 1 or blank, so adjustments were made:
        cmpq    $0, %r13                  # if hours_ten != 0...
        je      .CONTINUE                 
        
        # display_pattern |= masks[hour_tens] << 21;
        movl    (%r8, %r13, 4), %r10d     # storing masks[hours_ten] into %r10d
        shll    $21, %r10d                # shifting to the left by 21
        orl     %r10d, %r9d               # perfoming |= with display

.CONTINUE: 
        cmpq    $1, %r11                  # if tod.ampm is equal to 1
        jne     .AMPM_NOT_ONE
        orl     $1 << 28, %r9d 
        movl    %r9d,(%rbx)
        movl    $0, %eax
        ret

.AMPM_NOT_ONE:
        orl     $1 << 29, %r9d   
        movl    %r9d,(%rbx) 
        movl    $0, %eax
        ret

.RETURN_ONE:
        movl    $1, %eax                # return 1 for error
        ret

        ###############################################
        #              Current Log :                  #  
        # ------------------------------------------- #  
        #     %rbx -> *display                        # 
        #     %rcx -> *display                        # 
        #     %r8 -> masks []                         #
        #     %r9d -> display_pattern                 #
        #     %r10d -> temp for storing array indexes #
        ###############################################



.text
.global clock_update
        
clock_update:
      sub       $24, %rsp               # push 40 bytes onto the stack  
      movq      %rsp,%rdi               # set the stack pointer to point to arg 1
      call      set_tod_from_ports      # call the set_tod_from_ports function
      cmpl      $0x0, %eax              # check for valid return for funtion ^
      jne       .ERROR_TWO

      movq      0(%rsp), %rdi           # move tod_t tod -> register %rdi
      movq      8(%rsp), %rsi           # move *display -> register %rsi
      leaq      CLOCK_DISPLAY_PORT(%rip), %rdx
      call      set_display_from_tod  
      cmpl      $0x0, %eax              # check for valid return for funtion ^
      jne       .ERROR_TWO
      addq      $24, %rsp
      movl      $0x0, %eax
      ret

   .ERROR_TWO:
        movl    $0x1, %eax
        addq    $24, %rsp
        ret

        ###############################################
        #              Current Log :                  #  
        # ------------------------------------------- #  
        #     %rsp -> stack_pointer                   # 
        #     %rdi -> tod (arg 1)                     #
        #     %rsi -> (*display) arg 2                #
        ############################################### 
                        ##############
                        #   STACK    #
                        # ---------- #
                        #  %rsp -> 8 #
                        #  %rdi -> 8 #
                        #  %rsi -> 8 #
                        #  call -> 8 #
                        # TOTAL : 24 #
                        ##############

