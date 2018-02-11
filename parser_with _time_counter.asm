CODE_SEG	SEGMENT
		ASSUME	CS:CODE_SEG,DS:CODE_SEG,SS:CODE_SEG
		ORG	100H
START:
	JMP	BEGIN
	CR	EQU	13
	LF	EQU	10
;=============================macro=================================
print_letter	macro	letter
	push	AX
	push	DX
	mov	DL, letter
	mov	AH,	02
	int	21h
	pop	DX
	pop	AX
endm
;===================================================================
print_mes	macro	message
	local	msg, nxt
	push	AX
	push	DX
	mov	DX, offset msg
	mov	AH,	09h
	int	21h
	pop	DX
	pop	AX
	jmp nxt
	msg	DB message,'$'
	nxt:
	endm
;===================================================================	
get_vector	macro	vector, DD_for_save_vector    
	push	BX
	push	ES
		mov AX,35&vector                     	 				;  получить вектор прерывания
		int 21h                           			  
		mov word ptr DD_for_save_vector,		BX 		;  ES:BX - вектор
		mov word ptr DD_for_save_vector+2,	ES  	
	pop	ES
	pop	BX
endm
;===================================================================
set_vector	macro	vector,	handler
    mov DX,offset handler      							;  получить смещение точки входа в новый  обработчик на DX
    mov AX,25&vector           								;  функция установки прерывания 
    int 21h  													;  изменить вектор AL - номер прерыв. DS:DX - ук-ль программы обр. прер.
endm
;===================================================================
recovery_vector	macro	vector,	DD_for_save_vector
push	DS
    lds    DX, 	CS:DD_for_save_vector   
    mov		AX,	25&vector        							; Заполнение вектора старым содержимым
    int    21h													;	DS:DX - указатель программы обработки пр
pop	DS														
endm
;===================================================================
start_time	macro	saved_vector_1Ch, count
local	nxt, new_1Ch
get_vector	1Ch,	saved_vector_1Ch
set_vector	1Ch,	new_1Ch
;
jmp nxt
new_1Ch	proc	far
		pushf
		inc		CS:count
		popf
		jmp		dword ptr CS:	[saved_vector_1Ch]
new_1Ch	endp	
nxt:
endm
;===================================================================
finish_time	macro	saved_vector, count
local	nxt, old_1Ch,new_1Ch
;
recovery_vector	1Ch,	saved_vector
			;Print_Word_hex	count
			Print_Word_dec	count
endm
;===================================================================
Print_Word_dec	macro	src	;	выводит на экран источник src в десятичном виде
local	l1, l2, ex, msg
;
push	AX
push	BX
push	CX
push	DX
print_letter	CR
print_letter	LF
print_mes	'time:'
	mov		ax,	src			;	Выводимое число в регисте AX
	push		-1						;	Сохраним признак конца числа
	mov		cx,	10				;	Делим на 10
l1:	
	xor		dx,	dx				;	Очистим регистр dx 
	div		cx						;	Делим 
	push		dx						;	Сохраним цифру
	or 			ax,	ax				;	Остался 0? (это оптимальнее, чем  cmp	ax,	0 )
	jne		l1						;	нет -> продолжим
	mov		ah,	2h
l2:	
	pop		dx						;	Восстановим цифру
	cmp		dx,	-1				;	Дошли до конца -> выход {оптимальнее: or dx,dx jl ex}
	je			ex
	add		dl,	'0'			;	Преобразуем число в цифру
	int		21h					;	Выведем цифру на экран
	jmp	l2							;	И продолжим
ex:	
pop		DX
pop		CX
pop		BX
pop		AX
;
endm
;===================================================================
;===================================================================
;
old_1Ch       DD  ?
time_count		DW	?
;===================================================================
	BEGIN:
start_time	old_1Ch, time_count	;	сразу после begin!!!!

		xor		CH,		CH
		mov		CL,		cs:[80h]		; кол-во параметров
		cmp		CL,		0
		je		file_parameters_error	; нет параметров (нет имени файла)
		
		cld
		mov		di,		81h					; параметры
		mov		AL,		' '		
		repe	scasb						; пропускаем пробелы
		dec		di							; первый символ после пробелов
		mov		DX,		di					; сохраняем начало имени файла
		
		mov		AL,		0Dh					; CR
		inc		di
		inc		CX
		repne	scasb						; ищем CR
		mov		byte ptr cs:[di - 1],	0	; заменяем на 0 
		
	open:	
		mov		AX,		3D00h			; открываем файл
		int		21h
		jc		open_error
		mov		handle,	AX	
	
		mov		AH,		3Ch
		lea		DX,		email_file_name
		xor		CX,		CX
		int		21h
		mov		mail_handle,	AX
		
		; mov		AX,		3D00h			; открываем файл
		; lea		DX,		file_name
		; int		21h
		; jc		open_error
		; mov		handle,	AX	

	read:
		; mov		AH,		01h
		; int		21h
		
		cmp		end_flag,	1
		jne		next
		jmp		_quit
	next:	
		mov		AH,		3Fh			; читаем файл
		mov		BX,		handle
		lea		DX,		buffer
		mov		CX,		buff_size	; сколько байтов хотим прочитать
		int		21h
		jc		read_error	

		cmp		CX,		AX			
		jne		set_end_flag
		call	move_pointer
		jmp		parse
		
	set_end_flag:	
		mov		CX,		AX			; прочитали меньше, чем хотели
		inc		end_flag			; в следующий раз не читаем
		jmp		parse
		
	; _quit:
		; call	write_emails
		; call	print_counter
		; int		20h
		
;-------------------------------------------------------
	file_parameters_error:
		lea		DX,		parameters_error_mes
		call	print_mesg
		int		20h
		
	read_error:						; сообщения ошибок
		lea		DX,		file_read_error
		call 	print_mesg
		int		21h
	
	open_error:
		cmp		AL,		2
		je		_open_error_1
		cmp		AL,		3
		je		_open_error_2
		
		lea		DX,		file_open_error_3
		jmp		_open_error_print
	
	_open_error_1:
		lea		DX,		file_open_error_1
		jmp		_open_error_print
		
	_open_error_2:
		lea		DX,		file_open_error_2
	
	_open_error_print:
		call	print_mesg
		int		20h			
;-------------------------------------------------------
	
	
	parse:
		lea		di,		buffer		; текст
	_@_search:
		mov		AL,		'@'			
		repne	scasb				; ищем @. di указывает на следущий после @ символ. CX уменьшается на 1
									; или на символ после конца файл
		cmp		CX,		0			; текст кончился
		je		read				; читаем новую порцию

		mov		AL,		[di - 2]	; проверяем символ слева от @
		call	is_allowed			; (но можно проверять только при поиске начала email'а)
		jne		_@_search

		mov		AL, 	[di]		; проверяем символ справа от @
		call	is_allowed			
		jne		_@_search			; (warning: этот символ проверится на @, но без "спагетти-кода" )
		
		cmp		AL,		'.'			; (если мы не хотим точку после @)
		je		_@_search			; (warning: этот символ проверится на @, но без "спагетти-кода" )
		
		mov		_@_position,	di	; созраняем позицию @
		dec		_@_position			; di указывает на следующий символ
		
		inc		di					; но мы уже проверили этот символ. После увеличение di показывает на следующий символ	
		dec		CX					; уменьшим счётчик непрочитанных символов для символа после @			
		mov		saved_cx,		CX	; сохраняем счётчик
			
		mov		si,		di			; lodsb работает с si		
	dot_search:									
		lodsb						; загружает ds:[si]	в AL. После загрузки si указывает на следующий символ
		dec		saved_cx			; уменьшаем кол-во непочитанных символов
		
		cmp		AL,		'.'			; нашли первую после @ точку?
		je		end_of_email_search
		
		call	is_allowed			; если не точка, то допустимый символ?
		je		dot_search			; переходим к следущему символу (si уже увеличен lods, saved_cx уже уменьшен)

		mov		di,		si			; недопустимый символ. (si указывает на следующий символ, saved_cx уже уменьшен)
		mov		CX,		saved_cx	; di указывает на следующий символ, cx -- непрочитанные символы		
		jmp		_@_search
	
	
	end_of_email_search:			; ищем конец email'а
		lodsb						; загружает ds:[si]	в AL. После загрузки si указывает на следующий символ		
		dec		saved_cx			; уменьшаем кол-во непочитанных символов
	
		lea		di,		divs		; сравниваем с символами-разделитлями
		mov		CX,		3			; !!!добавить enter	
		repne	scasb
		je		begin_of_email_search ; нашли разделитель, ищем начала email'а
		
		cmp		AL,		13			; CR нет смысла проверять NL
		je		begin_of_email_search
		
		cmp		AL,		'.'			; нашли вторую точку? => не подходит под правила
		je		nxt
		
		call	is_allowed
		je		end_of_email_search
		
	nxt:	
		mov		di,		si			; (si указывает на следующий символ, saved_cx уже уменьшен)
		mov		CX,		saved_cx	; di указывает на следующий символ, cx -- непрочитанные символы	
		jmp		_@_search
	
	
	begin_of_email_search:
		dec		si					; si указывал на символ после разделителя, теперь на разделитель
		mov		end_of_email,	si	; сохраняем адрес разделителя после email'а

		std							; меняем напрваление
		mov		si,		_@_position ; переносим в si адрес @
		sub		si,		2			; si указывает на второй символ после @ (первый уже проверен) 
		
	_begin_s:
		lodsb						; загружает ds:[si]	в AL. После загрузки si указывает на предыдущищй символ	
									; saved_cx не меняем, т.к. проверяем уже прочитанные символы
		lea		di,		divs		; сравниваем с символами-разделитлями
		mov		CX,		3			; !!!добавить enter	
		repne	scasb
		je		save_mail			; нашли разделитель? сохраняем email'а
		
		cmp		AL,		10			; NL нет смысла проверять CR
		je		save_mail
		
		call	is_allowed			
		je		_begin_s
									; нашли недопустимый символ
		cld							; восстанавливаем направление
		mov		di,		end_of_email; di указывает на разделитель после email'а
		inc		di					; не будем снова его проверять 
		mov		CX,		saved_cx	; но он уже учтён в saved_cx, поэтому не уменьшаем
		jmp		_@_search
	
	
	save_mail:
		cld							; восстанавливаем направление
		
		add		si,		2				; si указывал на символ перед разделителем, теперь на первый символ email'a
		
		; mov		begin_of_email,		si	; сохраняем его	
		; mov		di,		end_of_email	; указывает на разделитель после email'а
		
		mov		CX,		end_of_email	
		sub		CX,		si
		add		CX,		2					; рассчитываем длину email'а + 2 (CR NL)
		
		cmp		CX,		write_buffer_free_space
		jnl		save_mail_2						; в буффере достаточно места
		call	write_emails					; в буффере недостаточно места - пишем буфер в файл
	
	save_mail_2:	
		sub		write_buffer_free_space,	CX	; уменьшаем свободное место на длину email'а + 2 (CR NL)
		sub		CX,		2		; длина email'а
		mov		di,		write_buffer_pointer	
		
		rep		movsb							; перемешаем email в буффер (si -> di)
		mov		byte ptr cs:[di],		13				; добавляем  CR
		mov		byte ptr cs:[di + 1],	10				; и NL
		
		add		di,		2
		mov		write_buffer_pointer,	di		; сохраняем указатель после email'а
		

		
		; push	DX						; печать email'ов на экране	
		; mov		byte ptr DS:[di],		'$'		
		; mov		DX,		begin_of_email
		; mov		AH,		09h		
		; int		21h
		; call	print_nl
		; mov		byte ptr DS:[di],		' '	
		; pop		DX
		
		; push	DX
		; mov		BX,		mail_handle
		; mov		AH,		40h
		; mov		DX,		begin_of_email		; адрес начала email'а
		; mov		CX,		end_of_email		; адрес начала - адрес конца = длина email'а
		; sub		CX,		begin_of_email
		; int		21h
		
		; mov		AH,		40h					; CR NL
		; mov		CX,		2
		; lea		DX,		new_line
		; int		21h		
		; pop		DX

		mov		di,		end_of_email	; указывает на разделитель после email'а
		inc		di					; не будем снова его проверять 
		mov		CX,		saved_cx	; но он уже учтён в saved_cx, поэтому не уменьшаем
		inc		counter				; счётчик email'ов
		jmp		_@_search

		
;=======================================================
write_emails	proc	near
		push	CX
		push	DX
		
		mov		AH,		40h
		mov		BX,		mail_handle
		mov		CX,		write_buff_size
		sub		CX,		write_buffer_free_space		; в CX кол-во байтов, которые будем писать
		lea		DX,		write_buffer
		int		21h
		
		mov		write_buffer_free_space,	write_buff_size	; обновляем свободное место
		mov		write_buffer_pointer,		DX				; перемещаем указатель в начало буффера	
		
		pop		DX
		pop		CX
		ret
write_emails	endp
		
;=======================================================
is_allowed		proc	near
		push	di
		push	DX
		
		cmp		AL,		61h		; a-z
		jl		_0_9			; меньше
		cmp		AL,		7Ah
		jle		allowed			; меньше или равно
		jmp		not_allowed
	
	_0_9:
		cmp		AL,		30h		; 0-9
		jl		sym				; меньше
		cmp		AL,		39h
		jle		allowed			; меньше или равно
		
		cmp		AL,		41h
		jl		not_allowed
		cmp		AL,		5Ah		; A-Z
		jle		allowed			; меньше или равно
		
		cmp		AL,		'_'
		je		allowed
		
	not_allowed:
		inc		DX				; ZF = 0
		pop		DX
		pop		di
		ret
		
	sym:						; -.+'
		push	CX
		mov		CX,		5
		lea		di,		symbs
		repne	scasb
		pop		CX
		jne		not_allowed
		
	allowed:
		xor		DX,		DX		; ZF = 1
		pop		DX
		pop		di
		ret			
is_allowed		endp
		

;=======================================================
move_pointer		proc	near
		mov		saved_cx,	CX		; сохраняем CX
		lea		si,		buffer		
		add		si,		buff_size
		dec		si					; si указывает на последний символ буффера 
		
		std
	_move_pointer:
		lodsb					; загружает ds:[si]	в AL. После загрузки si указывает на предыдущищй символ	
		dec		saved_cx		; уменьшаем кол-во символов, остающихся для парсинга
		
		lea		di,		divs	; сравниваем с символами-разделитлями
		mov		CX,		3			
		repne	scasb
		je		pointer			; нашли разделитель? сохраняем email'а
		
		cmp		AL,		10		; NL
		je		pointer
		
		cmp		AL,		13		; есть смысл проверять CR, т.к. разделение кусков текста может произойти по CR <> NL
		je		pointer
	
		jmp		_move_pointer
		
	pointer:
		cld							; восстанавливаем направление
		
		mov		DX,		saved_cx	; saved_cx сколько будем реально читать из куска
		sub		DX,		buff_size	; поэтому остальная часть должна быть прочитана в следующем куске (получается отрицательное число, на которое смещаем курсор назад)
		
		mov		CX,		0FFFFh		; число в CX:DX поэтому делаем его отрицательным через CX
		mov		BX,		handle		; (вообще возможна ошибка, если во всём буффере не будет разделителя, но в таком случае непредсказуемое поведение начнётся уже в части _move_pointer)
		mov		AX,		4201h
		int		21h
		
		mov		CX,		saved_cx	; так как для корректной работы алгоритма парсинга символ разделитель нужно оставить и в старой части, и в новой,
		inc		CX					; то увеличим символов для чтения на один
		
		ret		
move_pointer		endp


;=======================================================
print_counter		proc	near
		mov		AX,		counter
		xor     CX, 	CX
		mov     BX, 	10 ; основание сс. 10
	prnt_cntr_1:
		xor     DX,		DX
		div     BX

		push    DX
		inc     CX

		test    AX, 	AX
		jnz     prnt_cntr_1

		mov     AH, 	02h
	prnt_cntr_2:
		pop     DX
		add     DL, 	30h
		int     21h
		
		loop    prnt_cntr_2
		call	print_nl
		ret
print_counter		endp

print_mesg		proc	near
		mov		AH,		09h
		int		21h		
		ret
print_mesg		endp

print_nl		proc	near
		push	DX
		lea		DX,		nl
		mov		AH,		09h
		int		21h
		pop		DX
		ret
		nl		db		13,10,'$'
print_nl		endp
;=======================================================

			
ckl:
inc count1
cmp count1,0
jne ckl
inc count2
cmp count2,0
jne ckl
;
_quit:
	call	write_emails
	call	print_counter

finish_time	 old_1Ch, time_count	;	непосредственно перед выходом
;
	mov		AX,	4C00h
	INT	21H
;
count1	DW	?
count2	DB	?

;=======================================================
symbs			db		"-._+'"
divs			db		' ;,'					

end_of_email	dw		?
_@_position		dw		?
; begin_of_email	dw		?

saved_cx		dw		0
counter			dw		0
end_flag		db		0
;=======================================================
parameters_error_mes	db	'run the programm with file name as parameter',13,10,'$'
file_open_error_1	db		'file not found',13,10,'$'
file_open_error_2	db		'path not found',13,10,'$'
file_open_error_3	db		'open file error',13,10,'$'	
file_read_error		db		'file read error',13,10,'$'
; new_line			db		13,10

email_file_name	db		'emails.txt',0
mail_handle		dw		?

handle			dw		?

buff_size		equ		0EFFFh
write_buff_size	equ		0B00h

buffer					db		buff_size		dup (?)
write_buffer			db		write_buff_size	dup	(?)
write_buffer_pointer	dw		offset	write_buffer
write_buffer_free_space	dw		write_buff_size
;=======================================================

CODE_SEG    ENDS
		END START