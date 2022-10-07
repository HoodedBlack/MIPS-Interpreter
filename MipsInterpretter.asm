		.data
curTok:		.word 	0:3				# 2-word token & its TYPE
#tokenTab:	.word	0:30				# 10-entry token table
tokenTab:	.word	0:60
symTab:		.word 	0:40
outBuf:		.byte	24
inBuf:		.word 	0:20
ddErr:		.asciiz "Double definition error\n"
headr:		.asciiz "\nTOKEN \t\t VALUE \t\t STATUS\n"
dividr:		.asciiz "----------------------------------------\n"
newLine:  	.asciiz "\n"
#pound:		.byte	'#'				# end an input line with '#'
saveReg:	.word	0,0,0,0				# space to save up to four registers
low:		.word	0x0400
	
		.text
#######################################################################
#
# Main
#
#	read an input line
#	call scanner driver
#	clear buffers
#
#  	Global Registers
#	  $t9: index to inBuf in bytes
#	  $s0: T, char type
#	  $s1: Qx, current State
#  	  $s3: index to the new char space in curTok
#  	  $a3: index to tokArray in 12 bytes per entry
#
######################################################################
	    li 		$s5, 0
newline:
	    jal		getline			# get a new input string
	    li		$t9,0			# $t5: index to inBuf
	    li		$a3,0			# $a3: index to tokArray
		# State table driver
	    la		$s1, Q0			# initial state ($s1) = Q0
	    li		$s0, 1			# initial T ($s0) = 1
driver:
	    lw		$s2, 0($s1)		# get the action routine
	    jalr	$v1, $s2		# execute the action
	    sll		$s0, $s0, 2		# compute byte offset of T
	    add		$s1, $s1, $s0		# locate the next state
	    la		$s1, ($s1)
	    lw		$s1, ($s1)		# next State in $s1
	    sra		$s0, $s0, 2		# reset $s0 for T
	    b		driver			# go to the next state

symStart:
            li        	$t9, 0                # index to tokenTab
nextTok:        
            lb        	$t8, tokenTab+12
            bne        	$t8, ':', operator
            lw        	$a0, tokenTab        # TOKEN
            lw        	$a1, tokenTab+4
            li        	$a2, 1            # DEFN = 1
            jal        	VAR
            addi    	$t9, $t9, 2
operator:        
            addi    	$t9, $t9, 1
            li        	$s7, 1            # isComma
chkVar:        
            li          $t2, 12
            mul         $t9, $t2, $t9     
            lb       	$t8, tokenTab($t9)
            beq        	$t8, '#', dump            
            beq        	$s7, 0, nextVar
            lw        	$t8, tokenTab+8($t9)
            bne        	$t8, 2, nextVar   
            lw        	$a0, tokenTab($t9)        # TOKEN
            lw        	$a1, tokenTab+4($t9)
            li       	$a2, 0            # DEFN = 1
            jal    	VAR

nextVar: 
            lb        	$t8, tokenTab($t9)
            li        	$s7, 1
            bne       	$t8, ',', resetFlag
            b    	nextToken
resetFlag:    
	    li        	$s7, 0
nextToken:
            li        	$t0, 12
            div        	$t9, $t9, $t0
            addi    	$t9, $t9, 1
            b    	chkVar
dump:        
            jal    	clearInBuf        # clear input buffer
            jal    	clearTokTab        # clear tokenTab
            jal    	ps      
            lw        	$t0, low
            addi    	$t0, $t0, 4
            sw        	$t0, low
            b     	newline
saveSymTab:
	    move	$v0, $s5 		#$v0 = $s5;
	    sw	        $a0, symTab($s5)	#*(int*)(symTab + $s5) = 0;
	    sw		$a1, symTab+4($s5)	#*(int*)(symTab + $s5 + 4) = 0;
	    sw		$a2, symTab+12($s5)	#*(int*)(symTab + $s5 + 12) = 0;
	    addi	$s5, $s5, 16		#s5 = $s5+16;
            jr 		$ra			#return;
VAR:
	    move	$s6, $ra		#$s6 = $ra;
	    jal 	SSS			#$ra = SSS();
	    bge 	$v0, 0, VARe		#if($v0 >= 0) goto VARe
	    ori		$t1, $a2, 0x4		#$t1 = ($a1 || 0x4);
	    move	$t7, $t1		#$t7 = $t1;
	    move	$a2, $t7		#$a2 = $t7;
	    jal		saveSymTab		#$ra = saveSymTab();
	    j		VARr			#goto VARr;
VARe:
	    move 	$t2, $v0		#$t2 = $v0;
	    lw		$t1, symTab+12($t2)	#$t1 = *(int*)(symTab + $t2 + 12);
	    andi	$t2, $t1, 0x2		#$t2 = ($t1 && 0x2);
	    andi	$t1, $t1, 0x1		#t1 = ($t1 && 0x2);
	    sll		$t1, $t1, 1		#$t1 = $t1 << 1;
	    or		$t1, $t2, $t1		#$t1 = ($t2 || $t1);
	    or		$t1, $a2, $t1		#$t1 = ($a2 || $t1);
	    move	$t7, $t1		# $t7 = $t1;
	    move	$t1, $v0		#$t1 = $v0;
	    sw		$t7, symTab+12($t1)	#*(int*)(symTab + $t1 + 12) = 0;
VARr:
	    la 		$s0, symACTS		#$s0 = &symActs
	    move	$t3, $t1		#$t3 = $t1;
	    sll 	$t3, $t3, 2		#$t3 = $t3 << 2;
	    add 	$s0, $s0, $t3		#$s0 = $s0 + $t3;
	    jr 		$s0			#return $s0;
VARrtrn:
	    jr 		$s6			#return $s6;
ps:
	    move	$t3, $ra		#$t3 = $ra;
	    li		$t7, 0x20		#$t7 = &(0x20);
	    li		$t6, '\n'		#$t6 = '\n';
	    li 		$t5, '\t'		#$t5 = '\t';
	    li		$t0, 0			#$t0 = 0;
	    b 		newRow			#goto newRow;
loop2:	
	    bge		$t0, $s5, exitClr	#if($t0 >= $s5) goto exitClr;
	    li		$v0, 4	
	    la		$a0, newLine
	    syscall				#std::cout<<newLine;
newRow:
	    lw		$t1, symTab($t0)	#$t1 = *(int*)(symTab + $t0);
	    sw		$t1, outBuf		#$t1 = *(int*)(outBuf);
	    lw		$t1, symTab+4($t0)	#$t1 = *(int*)(symTab + $t0 + 4);
	    sw		$t1, outBuf+4		#$t1 = *(int*)(outBuf + 4);
	    li		$t9, -1			#$t9 = -1;
loop3:	
	    addi	$t9, $t9, 1		#$t9 = $t9 + 1;
	    bge		$t9, 8, val		#if($t9 >= 8) goto val;
	    lb		$t8, outBuf($t9)	#$t8 = *(int*)(outBuf + $t9);
	    bne		$t8, $zero, loop3	#if($t8 != 0) goto loop;
	    sb		$t7, outBuf($t9)	#$t7 = *(int*)(outBuf + $t9);
	    b		loop3			#goto loop3;
val:
	    sb		$t5, outBuf+8		#$t5 = *(int*)(outBuf + 8);
	    lw		$a0, symTab+8($t0)	#$a0 = *(int*)(symTab + $t0 + 8);
	    jal		hex2char		#$ra = hex2char();
	    li		$t2, '0'		#t2 = '0';
	    sb		$t2, outBuf+9		#$t2 = *(int*)(outBuf + 9);
	    li		$t2, 'x'		#$t2 = 'x';
	    sb		$t2, outBuf+10		#%t2 = *(int*)(outBuf + 10);
	    li		$t1, 0			#$t1 = 0;
loop4:
	    bge		$t1, 4, sts1		#if($t1 >= 4) goto sts1;
	    la		$t4, outBuf+11		#$t4 = *(int*)(outBuf + 11);
	    add		$t4, $t4, $t1		#$t4 = $t4 + $t1;
	    sb		$v0, ($t4)		#$v0 = *(int*)(%t4);
	    srl		$v0, $v0, 8		#$v0 = $v0 >> 8;
	    addi	$t1, $t1, 1		#$t1 = $t1 + 1;
	    j		loop4			#goto loop4;
sts1:
	    sb		$t5, outBuf+15		#$t5 = *(int*)(outBuf + 15);
	    sb 		$t5, outBuf+16		#$t5 = *(int*)(outBuf + 16);
	    lw		$a0, symTab+12($t0)	#*(int*)(symTab + $t0 + 12) = 0;
	    jal		hex2char		#$ra = hex2char();
	    srl		$v0, $v0, 24		#$v0 = $v0 >> 24;
	    li		$t2, '0'		#$t2 = '0';
	    sb		$t2, outBuf+17		#$t2 = *(int*)(outBuf + 17);
	    li		$t2, 'x'		#$t2 = 'x';
	    sb		$t2, outBuf+18		#$t2 = *(int*)(outBuf + 18);
	    sb		$v0, outBuf+19		#$v0 = *(int*)(outBuf + 19);
	    sb		$t6, outBuf+20		#$t6 = *(int*)(outBuf + 20);
	    sb		$zero,  outBuf+21	#$zero = *(int*)(outBuf + 21);
	    la		$a0, dividr
	    li		$v0, 4	
	    syscall				#std::cout<<dividr<<std::endl;
	    la		$a0, headr
	    li		$v0, 4
	    syscall				#std::cout<<headr<<std::endl;
	    la		$a0, dividr
	    li		$v0, 4
	    syscall				#std::cout<<dividr<<std::endl;
	    la		$a0, outBuf
	    li		$v0, 4
	    syscall				#std::cout<<outBuf<<std::endl;
	    la		$a0, dividr
	    li		$v0, 4
	    syscall				#std::cout<<dividr<<std::endl;
	    addi	$t0, $t0, 16		#$t0 = $t0 + 16;
	    sw		$zero,  outBuf		#$zero = *(int*)(outBuf);
	    sw		$zero,  outBuf+4	#$zero = *(int*)(outBuf + 4);
	    sw	        $zero,  outBuf+8	#$zero = *(int*)(outBuf + 8);
	    sw		$zero,  outBuf+12	#$zero = *(int*)(outBuf + 12);
	    sw		$zero,  outBuf+16	#$zero = *(int*)(outBuf + 16);
	    sw		$zero,  outBuf+20	#$zero = *(int*)(outBuf + 20);
	    b		loop2			#goto loop2;
exitClr:
	    move	$ra, $t3		#$ra = $t3;
            jr		$ra			#return;
symACTS: 	
	    b 		symACT0			#goto symACT0;
	    b 		symACT1			#goto symACT1;
	    b 		symACT2			#goto symACT2;
	    b 		symACT3			#goto symACT3;
	    b 		symACT4			#goto symACT4;
	    b 		symACT5			#goto symACT5;
#################################################
# symACT functions
#
#
#################################################
symACT0:
	lw	$t2, low			#$t2 = low;
	move	$t1, $t2			#$t1 = $t2;
	move 	$t2, $v0			#$t2 = $v0;
	sw	$t1, symTab+8($t2)		#$t1 = *(int*)(symTab + $t2 + 8);
symACT1:
	lw	$t3, low			#$t3 = low;
	move	$t1, $t3			#$t1 = $t3;
	move 	$t3, $v0			#$t3 = $v0;
	sw	$t1, symTab+8($t3)		#$t1 = *(int*)(symTab + $t3 + 8);
symACT2:
	b 	VARrtrn				# goto VARrtrn;
symACT3:
	li 	$t5, 4				#$t5 = 4;
	move 	$v0, $t5			#$v0 = $t5;
	la 	$a0, ddErr			#$a0 = &(ddErr);
	syscall					#std::cout<<ddErr<<endl;
	b 	VARrtrn				#goto VARrtrn;
symACT4:
	lw	$t4, low			#$t4 = low;
	move	$t1, $t4			#$t1 = $t4;
	move 	$t4, $v0			#$t4 = $v0;
	sw	$t1, symTab+8($t4)		#$t1 = *(int*)(symTab + $t4 + 8);
symACT5:
	lw	$t5, low			#$t5 = low;
	move	$t1, $t5			#$t1 = $t5;
	move 	$t5, $v0			#$t5 = $v0;
	sw	$t1, symTab+8($t5)		#$t1 = *(int*)(symTab + $t5 + 8);
##################################################
SSS:
	li	$t0,0				#$t0 = 0;
	li	$s0, 7				#$s0 = 7;
loopSrch1:
	beq	$t0, $s5, NF 			#if($t0 >= $s5) goto NF;
	lw	$t1, symTab($t0)		#$t1 = *(int*)(symTab + $t0);
	lw 	$t2, symTab+4($t0)		#$t1 = *(int*)(symTab + $t0 + 4);
	xor 	$t1, $a0, $t1			#$t1 = ($a0 ^ $t1);
	xor	$t2, $a1, $t2			#%t2 = ($a1 ^ $t2);
	bne	$t1, $zero, NE			#if($t1 != $zero) goto NE;
	bne	$t2, $zero, NE			#if($t2 != $zero) goto NE;
	move	$v0, $t0			#$v0 = $t0;
	j 	SSS_retrn			#goto SSS_retrn;
NE:
	addi	$t0, $t0, 16			#$t0 = $t0 + 16;
	j 	loopSrch1			#goto loopSrch1;
NF:
	li 	$v0, -1				#$v0 = -1;
SSS_retrn:
	jr 	$ra				#return $ra;
####################### STATE ACTION ROUTINES #####################
##############################################
#
# ACT1:
#	$t9: global index to inBuf for the next char
#       $a0: search key char from inBuf[$t9]
#	return $s0 with T = char type
#
##############################################
ACT1:
	lb	$a0, inBuf($t9)			# $a0: next char
	jal	lin_search			# $s0 returns T (char type)
	addi	$t9, $t9, 1			# $t9++ to point to the next char in inBuf	lw	$a0, saveReg			# restore $a0
	jr	$v1
	
###############################################
#
# ACT2:
#	$a0: char to save into curTok for the first time
#	$s0: char type as curTok type
#	set remaining curTok space
#
##############################################
ACT2:
	li	$s3, 0				# initialize index to curTok char 
	sb	$a0, curTok($s3)			# save 1st char to curTok
	sb	$s0, curTok+8($s3)		# save T (curTok type)
	addi	$s3, $s3, 1
	jr 	$v1
	
#############################################
#
# ACT3:
#	collect char to curTok
#	update remaining token space
#
#############################################
ACT3:
	bgt	$s3, 7, lenError		# curTok length error
	sb	$a0, curTok($s3)			# save char to curTok
	addi	$s3, $s3, 1			# $s3: global index to curTok
	jr	$v1	
lenError:
	li	$s0, 7				# T=7 for token length error
	jr	$v1
					
#############################################
#
#  ACT4:
#	move curTok to TabTok
#	$a3 - global index into TabTok
#
############################################
ACT4:
	lw	$t0, curTok($0)			# get 1st word of curTok
	sw	$t0, tokenTab($a3)		# save 1st word to tokenTab
	lw	$t0, curTok+4($0)		# get 2nd word of curTok
	sw	$t0, tokenTab+4($a3)		# save 2nd word to tokenTab
	lw	$t0, curTok+8($0)		# get curTok Type
	blt	$t0, 6, ACT4Type		# chartype of 6
	addi	$t0, $t0, -1			#  into token type 5
ACT4Type:
	sw	$t0, tokenTab+8($a3)		# save Token Type to tokemTab
	addi	$a3, $a3, 12			# update index to tokenTab
	
	jal	clearTok			# clear 3-word curTok
	jr	$v1

############################################
#
#  RETURN:
#	End of the input string
#
############################################
RETURN:
	b	symStart				# leave the state table


#############################################
#
#  ERROR:
#	Error statement and quit
#
############################################
	.data
st_error:	.asciiz	"An error has occurred. \n"	

	.text
ERROR:
	la	$a0, st_error			# print error occurrence
	li	$v0, 4
	syscall
	b	dump


############################### BOOK-KEEPING FUNCTIONS #########################
#############################################
#
#  clearTok:
#	clear 3-word curTok after copying it to tokenTab
#
#############################################
clearTok:
	sw	$0, curTok
	sw	$0, curTok+4
	sw	$0, curTok+8
	jr	$ra
	
#############################################
#
#  printline:
#	Echo print input string
#
#############################################
printline:
	la	$a0, inBuf			# input Buffer address
	li	$v0,4
	syscall
	jr	$ra


############################################
#
#  clearInBuf:
#	clear inbox
#
############################################
clearInBuf:
	li	$t0,0
loopInB:
	bge	$t0, 80, doneInB
	sw	$0, inBuf($t0)		# clear inBuf to 0x0
	addi	$t0, $t0, 4
	b	loopInB
doneInB:
	jr	$ra
	
###########################################
#
# clearTokTab:
#	clear tokenTab
#
###########################################
clearTokTab:
	li	$t0, 0
loopCTok:
	bge	$t0, $a3, doneCTok
	sw	$0, tokenTab($t0)		# clear
	sw	$0, tokenTab+4($t0)		#  3-word entry
	sw	$0, tokenTab+8($t0)		#  in tokArray
	addi	$t0, $t0, 12
	b	loopCTok
doneCTok:
	jr	$ra
	

###################################################################
#
#  getline:
#	get input string into inbox
#
###################################################################
	.data
new:		.asciiz "\n"
st_prompt:	.asciiz	"Enter a new input line. \n"

	.text
getline: 
	la	$a0, new			# New line after every input (for allignment purposes)
	li	$v0, 4
	syscall

	la	$a0, st_prompt			# Prompt to enter a new line
	li	$v0, 4
	syscall

	la	$a0, inBuf			# read a new line
	li	$a1, 80	
	li	$v0, 8
	syscall
	jr	$ra


##################################################################
#
#  lin_search:
#	Linear search of Tabchar
#
#   	$a0: char key
#   	$s0: char type, T
#
#	return type is initialized to 7 for search failure
#	End of charTab is indicated by 0x7F
#
#################################################################
lin_search:
	li	$t0,0				# i = 0
	li	$s0, 7				# retVal = 7 (char type)
loopSrch:
	lb	$t1, charTab($t0)		# t1 = charTab[i]
	beq	$t1, 0x7F, charFail		# if (t1==end_of_table) goto charFail
	beq	$t1, $a0, charFound		# if (t1==key) goto charFound
	addi	$t0, $t0, 8			# i++8 in bytes
	b	loopSrch			# goto loopSrch

charFound:
	lw	$s0, charTab+4($t0)		# return char type
charFail:
	jr	$ra

#################################################################
#
#  hex2char:
# 	Function used to print a hex value into ASCII string.
# 	Convert a hex in $a0 to char hex in $v0 (0x6b6a in $a0, $v0 should have 'a''6''b''6')
#
# 	4-bit mask slides from right to left in $a0.
# 	As corresponding char is collected into $v0,
# 	$a0 is shifted right by four bits for the next hex digit in the last four bits
#
# 	Make it sure that you are handling nested function calls in return addresses
#################################################################
	.text
hex2char:
	# save registers
	sw 	$t0, saveReg($0) # hex digit to process
	sw 	$t1, saveReg+4($0) # 4-bit mask
	sw 	$t9, saveReg+8($0)
	# initialize registers
	li 	$t1, 0x0000000f # $t1: mask of 4 bits
	li 	$t9, 3 # $t9: counter limit
nibble2char:
	and 	$t0, $a0, $t1 # $t0 = least significant 4 bits of $a0
	# convert 4-bit number to hex char
	bgt 	$t0, 9, hex_alpha # if ($t0 > 9) goto alpha
	# hex char '0' to '9'
	addi 	$t0, $t0, 0x30 # convert to hex digit
	b 	collect
hex_alpha:
	addi 	$t0, $t0, -10 # subtract hex # "A"
	addi 	$t0, $t0, 0x61 # convert to hex char, a..f
	# save converted hex char to $v0
collect:
	sll 	$v0, $v0, 8 # make a room for a new hex char
	or 	$v0, $v0, $t0 # collect the new hex char
	# loop counter bookkeeping
	srl 	$a0, $a0, 4 # right shift $a0 for the next digit
	addi 	$t9, $t9, -1 # $t9--
	bgez 	$t9, nibble2char
	# restore registers
	lw 	$t0, saveReg($0)
	lw 	$t1, saveReg+4($0)
	lw 	$t9, saveReg+8($0)
	jr 	$ra


	.data

stateTAB:
Q0:     .word  ACT1
        .word  Q1   # T1
        .word  Q1   # T2
        .word  Q1   # T3
        .word  Q1   # T4
        .word  Q1   # T5
        .word  Q1   # T6
        .word  Q11  # T7

Q1:     .word  ACT2
        .word  Q2   # T1
        .word  Q5   # T2
        .word  Q3   # T3
        .word  Q3   # T4
        .word  Q0   # T5
        .word  Q4   # T6
        .word  Q11  # T7

Q2:     .word  ACT1
        .word  Q6   # T1
        .word  Q7   # T2
        .word  Q7   # T3
        .word  Q7   # T4
        .word  Q7   # T5
        .word  Q7   # T6
        .word  Q11  # T7

Q3:     .word  ACT4
        .word  Q0   # T1
        .word  Q0   # T2
        .word  Q0   # T3
        .word  Q0   # T4
        .word  Q0   # T5
        .word  Q0   # T6
        .word  Q11  # T7

Q4:     .word  ACT4
        .word  Q10  # T1
        .word  Q10  # T2
        .word  Q10  # T3
        .word  Q10  # T4
        .word  Q10  # T5
        .word  Q10  # T6
        .word  Q11  # T7

Q5:     .word  ACT1
        .word  Q8   # T1
        .word  Q8   # T2
        .word  Q9   # T3
        .word  Q9   # T4
        .word  Q9   # T5
        .word  Q9   # T6
        .word  Q11  # T7

Q6:     .word  ACT3
        .word  Q2   # T1
        .word  Q2   # T2
        .word  Q2   # T3
        .word  Q2   # T4
        .word  Q2   # T5
        .word  Q2   # T6
        .word  Q11  # T7

Q7:     .word  ACT4
        .word  Q1   # T1
        .word  Q1   # T2
        .word  Q1   # T3
        .word  Q1   # T4
        .word  Q1   # T5
        .word  Q1   # T6
        .word  Q11  # T7

Q8:     .word  ACT3
        .word  Q5   # T1
        .word  Q5   # T2
        .word  Q5   # T3
        .word  Q5   # T4
        .word  Q5   # T5
        .word  Q5   # T6
        .word  Q11  # T7

Q9:     .word  ACT4
        .word  Q1  # T1
        .word  Q1  # T2
        .word  Q1  # T3
        .word  Q1  # T4
        .word  Q1  # T5
        .word  Q1  # T6
        .word  Q11 # T7

Q10:	.word	RETURN
        .word  Q10  # T1
        .word  Q10  # T2
        .word  Q10  # T3
        .word  Q10  # T4
        .word  Q10  # T5
        .word  Q10  # T6
        .word  Q11  # T7

Q11:    .word  ERROR 
	.word  Q4  # T1
	.word  Q4  # T2
	.word  Q4  # T3
	.word  Q4  # T4
	.word  Q4  # T5
	.word  Q4  # T6
	.word  Q4  # T7
	
	
charTab: 
	.word ' ', 5
 	.word '#', 6
 	.word '$', 4 
	.word '(', 4
	.word ')', 4 
	.word '*', 3 
	.word '+', 3 
	.word ',', 4 
	.word '-', 3 
	.word '.', 4 
	.word '/', 3 

	.word '0', 1
	.word '1', 1 
	.word '2', 1 
	.word '3', 1 
	.word '4', 1 
	.word '5', 1 
	.word '6', 1 
	.word '7', 1 
	.word '8', 1 
	.word '9', 1 

	.word ':', 4 

	.word 'A', 2
	.word 'B', 2 
	.word 'C', 2 
	.word 'D', 2 
	.word 'E', 2 
	.word 'F', 2 
	.word 'G', 2 
	.word 'H', 2 
	.word 'I', 2 
	.word 'J', 2 
	.word 'K', 2
	.word 'L', 2 
	.word 'M', 2 
	.word 'N', 2 
	.word 'O', 2 
	.word 'P', 2 
	.word 'Q', 2 
	.word 'R', 2 
	.word 'S', 2 
	.word 'T', 2 
	.word 'U', 2
	.word 'V', 2 
	.word 'W', 2 
	.word 'X', 2 
	.word 'Y', 2
	.word 'Z', 2

	.word 'a', 2 
	.word 'b', 2 
	.word 'c', 2 
	.word 'd', 2 
	.word 'e', 2 
	.word 'f', 2 
	.word 'g', 2 
	.word 'h', 2 
	.word 'i', 2 
	.word 'j', 2 
	.word 'k', 2
	.word 'l', 2 
	.word 'm', 2 
	.word 'n', 2 
	.word 'o', 2 
	.word 'p', 2 
	.word 'q', 2 
	.word 'r', 2 
	.word 's', 2 
	.word 't', 2 
	.word 'u', 2
	.word 'v', 2 
	.word 'w', 2 
	.word 'x', 2 
	.word 'y', 2
	.word 'z', 2

	.word 0x7F, 0
