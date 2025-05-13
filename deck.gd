extends Node

# Este array guarda la composición completa de las 40 cartas del mazo de truco.
# Se usa para generar un nuevo mazo barajado en cada ronda.
var cartas_del_juego_base = []

# Este es el mazo que se usa durante una ronda, del cual se sacan las cartas.
var mazo_actual_en_juego = []

# Palos y valores estándar del truco español (40 cartas)
var valores = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12]
var palos = ["oro", "copa", "espada", "basto"]

# _init se llama una sola vez cuando se crea la instancia del script por primera vez.
# Ideal para definir la composición base del mazo.
func _init():
	cartas_del_juego_base.clear() # Asegurar que esté vacío por si acaso
	for p in palos:
		for v in valores:
			# Guardamos cada carta como un diccionario con valor, palo y un ID único.
			# El ID único puede ser útil para debugging o si necesitas identificar una carta específica.
			cartas_del_juego_base.append({"valor": v, "palo": p, "id": str(v) + "_" + p})
	print("DECK.GD: Plantilla de cartas_del_juego_base creada con %d cartas." % cartas_del_juego_base.size())

# Esta función debe ser llamada por game.gd al INICIO de cada nueva ronda completa.
func preparar_nuevo_mazo_para_ronda():
	# Creamos una copia fresca del mazo base para esta ronda.
	# .duplicate(true) hace una copia profunda, importante si los elementos fueran objetos complejos.
	# Para diccionarios simples como los nuestros, duplicate() o una copia simple bastaría,
	# pero duplicate(true) es más seguro si alguna vez añades nodos u otros resources a la data de la carta.
	mazo_actual_en_juego = cartas_del_juego_base.duplicate(true)
	mazo_actual_en_juego.shuffle() # Barajamos el mazo de esta ronda.
	print("DECK.GD: Nuevo mazo preparado y barajado con %d cartas." % mazo_actual_en_juego.size())

# Esta es la función que game.gd usará para pedir cartas.
# Saca 'cantidad' de cartas de la parte superior del 'mazo_actual_en_juego'.
# IMPORTANTE: Estas cartas se REMUEVEN del 'mazo_actual_en_juego'.
func sacar_cartas(cantidad: int) -> Array:
	var cartas_sacadas = []
	if mazo_actual_en_juego.size() < cantidad:
		print("ERROR deck.gd: No hay suficientes cartas en el mazo para sacar %d." % cantidad)
		# Aquí podrías decidir regenerar el mazo si se juega con mazo completo siempre,
		# o simplemente devolver un array vacío si el juego puede continuar con menos cartas.
		# Ejemplo:
		# preparar_nuevo_mazo_para_ronda() # Regenera y baraja si se acaba
		# if mazo_actual_en_juego.size() < cantidad: return [] # Si aún así no alcanza
		return [] # Por ahora, devolvemos vacío si no hay suficientes.

	for _i in range(cantidad):
		if not mazo_actual_en_juego.is_empty():
			cartas_sacadas.append(mazo_actual_en_juego.pop_front()) # Saca la primera y la quita
		else:
			# No debería llegar aquí si el chequeo de size() de arriba es correcto.
			print("ERROR deck.gd: Se intentó sacar de un mazo vacío en el bucle.")
			break 

	print("DECK.GD: Se sacaron %d cartas. Quedan %d en el mazo actual." % [cartas_sacadas.size(), mazo_actual_en_juego.size()])
	return cartas_sacadas

# Las funciones _ready(), generar_mazo(), barajar_cartas() y repartir_cartas()
# que tenías antes aquí ya no son necesarias porque game.gd ahora dirige
# cuándo se prepara el mazo y cuándo se sacan las cartas.
