# card.gd - Script para cada carta individual
extends Area2D

var arrastrando = false
var offset = Vector2.ZERO

var mesa = null 
var valor: int # El valor numérico de la carta (1-7, 10-12)
var palo: String # "espada", "basto", "oro", "copa"

func _ready():
	# Intenta obtener una referencia al nodo Mesa si existe como hermano del padre
	# o en una ruta conocida. Ajusta esta lógica si tu nodo Mesa está en otro lugar.
	if get_parent() and get_parent().has_node("Mesa"):
		mesa = get_parent().get_node("Mesa")
	elif get_node_or_null("/root/Game/Mesa"): # Ejemplo de ruta absoluta si Game es tu escena principal
		mesa = get_node("/root/Game/Mesa")

	input_pickable = true # Permite que el Area2D reciba eventos de input
	z_as_relative = false # Asegura que z_index funcione en el espacio del viewport

func _input(event):
	var padre = get_parent() 
	if not is_instance_valid(padre): return # Seguridad: si no hay padre, no hacer nada

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not input_pickable: # Si la carta no es pickable (ej. ya jugada), no hacer nada
				return 
			
			var mouse_pos_global = get_global_mouse_position()
			# Comprobar si el clic fue dentro de esta carta, considerando el Z-index
			# para seleccionar la carta de más arriba si hay varias superpuestas.
			var cartas_bajo_el_mouse_en_el_mismo_punto = []
			for otra_carta_nodo in padre.get_children():
				if otra_carta_nodo is Area2D and otra_carta_nodo.visible and otra_carta_nodo.has_method("setup_carta") and otra_carta_nodo.input_pickable: 
					var otra_transform_global_inverso = otra_carta_nodo.get_global_transform().affine_inverse()
					var mouse_pos_local_a_otra = otra_transform_global_inverso * mouse_pos_global
					var otra_col_shape_temp = otra_carta_nodo.get_node_or_null("CollisionShape2D")
					var otra_rect_temp = Rect2()
					if otra_col_shape_temp and otra_col_shape_temp.shape:
						# Asumimos que la forma es un RectangleShape2D y su origen es el centro.
						otra_rect_temp = Rect2(-otra_col_shape_temp.shape.extents, otra_col_shape_temp.shape.extents * 2)
					else:
						continue # Si no tiene forma de colisión válida, la ignoramos
						
					if otra_rect_temp.has_point(mouse_pos_local_a_otra):
						cartas_bajo_el_mouse_en_el_mismo_punto.append(otra_carta_nodo)
			
			if cartas_bajo_el_mouse_en_el_mismo_punto.is_empty(): return # No se hizo clic en ninguna carta

			# Ordenar por Z-index para seleccionar la de más arriba
			cartas_bajo_el_mouse_en_el_mismo_punto.sort_custom(func(a, b): return a.z_index > b.z_index)
			
			if cartas_bajo_el_mouse_en_el_mismo_punto[0] == self: # Si esta carta es la de más arriba
				if padre.has_method("set_carta_seleccionada") and padre.carta_seleccionada == null:
					padre.set_carta_seleccionada(self) 
					arrastrando = true
					offset = global_position - mouse_pos_global
					bring_to_front() # Trae la carta al frente visualmente y en Z-order
		
		elif not event.pressed and arrastrando: # Si se suelta el botón del mouse y se estaba arrastrando
			arrastrando = false
			
			var fue_jugada_en_zona_de_juego = false
			# Asumimos que "Mesa/ZonaJugador" es la ruta al área donde se pueden jugar las cartas.
			# Esta área debería ser un Area2D en tu escena "Mesa".
			var zona_jugador_node = null
			if is_instance_valid(mesa) and mesa.has_node("ZonaJugador"):
				zona_jugador_node = mesa.get_node("ZonaJugador")

			if zona_jugador_node is Area2D:
				var areas_solapadas = get_overlapping_areas()
				if zona_jugador_node in areas_solapadas: # Si la carta se soltó sobre la zona de juego
					fue_jugada_en_zona_de_juego = true
					input_pickable = false # La carta ya no es clickeable/arrastrable
					if padre.has_method("jugador_ha_jugado_carta"):
						padre.jugador_ha_jugado_carta(self)
			
			if not fue_jugada_en_zona_de_juego: # Si no se jugó, se intenta reordenar en la mano
				if padre.has_method("solto_carta_para_reordenar_mano"):
					padre.solto_carta_para_reordenar_mano(self, get_global_mouse_position())
				else:
					print("ERROR card.gd: La función 'solto_carta_para_reordenar_mano' no existe en el script padre (game.gd).")
					# Podrías añadir un comportamiento de fallback, como volver a una posición por defecto.
				
				# Si no se jugó, y el padre tiene reset_carta_seleccionada, llamarlo.
				# Esto asegura que si no se jugó, la carta seleccionada se deseleccione.
				if padre.has_method("reset_carta_seleccionada"):
					padre.reset_carta_seleccionada()
			# Si FUE jugada, game.gd es responsable de llamar a reset_carta_seleccionada
			# después de que la IA juegue, o cuando corresponda.

	elif event is InputEventMouseMotion and arrastrando: # Si se mueve el mouse mientras se arrastra
		global_position = event.global_position + offset


func esta_sobre_mesa() -> bool: 
	if is_instance_valid(mesa):
		# Asumimos que el nodo Mesa tiene una variable exportada o una función 
		# que devuelve su rectángulo lógico en coordenadas globales.
		# Esto es un placeholder, necesitas implementar cómo obtener el área de la mesa.
		var tam_mesa = mesa.get("tamano_logico_mesa") if mesa.has_method("get") else null 
		if tam_mesa != null and tam_mesa is Vector2: # Asumiendo que tamano_logico_mesa es el tamaño
			var posicion_centro_mesa = mesa.global_position # Asumiendo que el origen de Mesa es su centro
			var rect_mesa = Rect2(posicion_centro_mesa - tam_mesa / 2.0, tam_mesa)
			return rect_mesa.has_point(self.global_position)
		else:
			#print("ADVERTENCIA card.gd: 'tamano_logico_mesa' no definido o no es Vector2 en el script de Mesa.")
			# Si no se puede determinar el tamaño de la mesa, se asume que no está sobre ella.
			# O podrías tener otra lógica, ej. si el padre es el nodo Mesa.
			return false 
	return false

func bring_to_front():
	var padre = get_parent()
	if is_instance_valid(padre):
		# Un Z-index alto para asegurar que esté por encima de otras cartas en mano.
		# El Z-index de las cartas en mesa se maneja en game.gd.
		self.z_index = 100 
		# Mover el nodo al final de la lista de hijos del padre también ayuda visualmente
		# pero z_index es el control principal para el renderizado 2D.
		# padre.move_child(self, padre.get_child_count() - 1) # Esto puede ser útil si no usas z_index activamente para todo.
	if arrastrando: # Efecto visual mientras se arrastra
		modulate = Color(1.2, 1.2, 1.2) # Ligeramente más brillante

func setup_carta(v: int, p: String): # Especificar tipos para v y p
	valor = v
	palo = p
	name = "Carta_%s_%s" % [str(valor), palo] # Nombre útil para debugging

	var texture_path = "res://Cartas/%s_%s.png" % [str(valor), palo] # Asegurar que valor sea string para el path
	var sprite_node = get_node_or_null("Sprite2D") # Asume que tienes un Sprite2D como hijo
	
	if sprite_node and sprite_node is Sprite2D:
		if ResourceLoader.exists(texture_path):
			sprite_node.texture = load(texture_path)
		else:
			push_error("Falta textura para la carta: " + texture_path + " (Verifica la ruta y el nombre del archivo)")
	else:
		push_error("Nodo Sprite2D no encontrado (debe llamarse 'Sprite2D') o no es del tipo Sprite2D en la escena Card para: " + name)

# --- FUNCIÓN AÑADIDA PARA EL PODER EN TRUCO ---
# Esta función devuelve el poder de la carta para el juego de Truco.
# Los valores más altos indican cartas más fuertes.
func get_poder_truco() -> int:
	# Matas (cartas más poderosas)
	if palo == "espada" and valor == 1: return 100 # Ancho de Espada
	if palo == "basto" and valor == 1: return 90  # Ancho de Basto
	if palo == "espada" and valor == 7: return 80  # Siete de Espada
	if palo == "oro" and valor == 7: return 70    # Siete de Oro
	
	# Cartas comunes (3, 2, anchos falsos)
	if valor == 3: return 60 # Treses
	if valor == 2: return 50 # Doses
	if (palo == "copa" or palo == "oro") and valor == 1: return 40 # Anchos falsos (Copa y Oro)
	
	# Figuras y el resto de las cartas ("cartas negras" o de menor valor)
	if valor == 12: return 30 # Reyes (12)
	if valor == 11: return 28 # Caballos (11)
	if valor == 10: return 26 # Sotas (10)
	# Sietes falsos
	if (palo == "copa" or palo == "basto") and valor == 7: return 24 # Siete de Copa y Basto
	if valor == 6: return 22 # Seises
	if valor == 5: return 20 # Cincos
	if valor == 4: return 18 # Cuatros
	
	# Si por alguna razón una carta no coincide con ninguna regla (no debería pasar con una baraja estándar)
	print_debug("WARN card.gd: Carta sin poder de truco definido: %s de %s" % [str(valor), palo])
	return 0 

# Puedes añadir otras funciones útiles aquí, por ejemplo, para el envido:
# func get_valor_envido() -> int:
#   if valor >= 10: # Sota, Caballo, Rey valen 0 para el envido
#       return 0
#   return valor
