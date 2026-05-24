extends MarginContainer

@onready var text_label = $label_margin/text_label
@onready var letter_timer_display = $letter_timer_display

const MAX_WIDTH = 256

var text= ""
var letter_index = 0 

var letter_display_timer = 0.07
var space_display_timer = 0.05
var punctuaction_display_timer = 0.02

signal text_display_finished()

func display_text(text_to_display: String):
	letter_index = 0
	text = text_to_display
	text_label.text = text_to_display
	
	await resized 
	
	custom_minimum_size.x = min(size.x, MAX_WIDTH)
	
	if size.x > MAX_WIDTH:
		text_label.autowrap_mode= TextServer.AUTOWRAP_WORD
		await resized
		await resized
		custom_minimum_size.y = size.y
		
	global_position.x -= size.x / 2
	global_position.y -= size.y+24
	text_label.text=""	
	display_letter()
	
func display_letter():
	# TRAVA DE SEGURANÇA: Se a função for chamada além do fim do texto, ignora e sai fora
	if letter_index >= text.length():
		return
	
	# Adiciona a letra atual na tela
	text_label.text += text[letter_index]
	letter_index += 1
	
	# Se acabou o texto aqui, avisa o gerenciador e para
	if letter_index >= text.length():
		text_display_finished.emit()
		return
	
	# Só analisa o próximo caractere se tiver certeza absoluta que ele existe
	match text[letter_index]:
		"!", "?", ",", ".":
			letter_timer_display.start(punctuaction_display_timer)
		" ":
			letter_timer_display.start(space_display_timer)
		_:
			letter_timer_display.start(letter_display_timer)
func _on_letter_timer_display_timeout():
	display_letter()
