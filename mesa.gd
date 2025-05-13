extends Node2D

# --- POSICIONES BASE PARA CADA CARRIL (IZQUIERDA, CENTRO, DERECHA) ---
# (Asegúrate que estos valores X den la separación que quieres, y los Y coincidan con tus ZonaJugador/ZonaIA)
var posiciones_carriles_jugador = [
	Vector2(150, 600),  # Carril Izquierdo 
	Vector2(360, 600),  # Carril Centro
	Vector2(570, 600)   # Carril Derecho
]
# IA (Y=500 según tu configuración de ZonaIA, o el valor que tengas)
var posiciones_carriles_ia = [
	Vector2(150, 500),  # Carril Izquierdo
	Vector2(360, 500),  # Carril Centro
	Vector2(570, 500)   # Carril Derecho
]

# --- ROTACIONES LEVES PARA CADA CARRIL (¡LAS QUE TE GUSTABAN!) ---
var rotaciones_carriles_jugador = [-2.5, 0.5, 3.0] # Ejemplo: Leve inclinación (ajusta a tu gusto)
var rotaciones_carriles_ia    = [1.5, -0.5, -2.0] # Ejemplo: Leve inclinación para la IA

# --- OFFSET PARA LA CARTA PERDEDORA DENTRO DEL MISMO CARRIL ---
var offset_carta_perdedora = Vector2(10, 10) # Ajusta a tu gusto

var tamano_logico_mesa = Vector2(700, 1000) 

# --- FUNCIONES GET (sin cambios en su lógica interna) ---
func get_posicion_jugador_en_carril(indice_mano_ronda: int) -> Vector2:
	if indice_mano_ronda >= 0 and indice_mano_ronda < posiciones_carriles_jugador.size():
		return posiciones_carriles_jugador[indice_mano_ronda]
	else:
		print("ERROR mesa.gd: Índice de carril jugador (%d) fuera de rango." % indice_mano_ronda)
		return Vector2(360, 600) if posiciones_carriles_jugador.is_empty() else posiciones_carriles_jugador[0]

func get_rotacion_jugador_en_carril(indice_mano_ronda: int) -> float:
	if indice_mano_ronda >= 0 and indice_mano_ronda < rotaciones_carriles_jugador.size():
		return rotaciones_carriles_jugador[indice_mano_ronda] # Devolverá la rotación leve
	return 0.0

func get_posicion_ia_en_carril(indice_mano_ronda: int) -> Vector2:
	if indice_mano_ronda >= 0 and indice_mano_ronda < posiciones_carriles_ia.size():
		return posiciones_carriles_ia[indice_mano_ronda]
	else:
		print("ERROR mesa.gd: Índice de carril IA (%d) fuera de rango." % indice_mano_ronda)
		return Vector2(360, 500) if posiciones_carriles_ia.is_empty() else posiciones_carriles_ia[0]

func get_rotacion_ia_en_carril(indice_mano_ronda: int) -> float:
	if indice_mano_ronda >= 0 and indice_mano_ronda < rotaciones_carriles_ia.size():
		return rotaciones_carriles_ia[indice_mano_ronda] # Devolverá la rotación leve
	return 0.0

func get_offset_carta_perdedora() -> Vector2:
	return offset_carta_perdedora
