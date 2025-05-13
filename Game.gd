# game.gd - Script principal del juego
extends Node2D

const CardScene = preload("res://Scenes/card.tscn")
var deck_script_instance: Node
var carta_seleccionada = null

# --- POSICIONES Y ROTACIONES PARA LAS CARTAS EN MANO DEL JUGADOR ---
var slot_positions = [Vector2(240, 950), Vector2(400, 930), Vector2(560, 950)]
var slot_rotations = [-10, 0, 10]

# --- ESTADO DEL JUEGO Y CARTAS ---
var cartas_en_mesa_jugador: Array[Area2D] = []
var cartas_en_mesa_ia: Array[Area2D] = []
var mano_logica_ia: Array[Dictionary] = []

var resultado_manos_ronda = [0, 0, 0] # 0: no jugado, 1: gana jugador, 2: gana IA, 3: parda
var ronda_de_mesa_actual = 0 # 0, 1, 2 para las tres manos de una ronda

@onready var nodo_mesa = $Mesa

# --- VARIABLES Y CONSTANTES PARA EL HUD DE PUNTOS ---
var puntos_chico_jugador = 0
var puntos_chico_ia = 0
const PUNTOS_PARA_GANAR_CHICO = 15 # O 30 según se configure el juego

@onready var contenedor_puntos_yo: HBoxContainer = $HUD_Puntos/ContenedorInfoGlobal/InfoYo/PuntosYoContainer
@onready var contenedor_puntos_ia: HBoxContainer = $HUD_Puntos/ContenedorInfoGlobal/InfoElla/PuntosEllaContainer

var textura_punto_ganado = load("res://assets/ui/punto_lleno.png")
var textura_punto_vacio = load("res://assets/ui/punto_vacio.png")

# --- CONSTANTES VISUALES ---
const COLOR_ILUMINACION_GANADORA = Color(1.25, 1.25, 1.05, 1.0)
const COLOR_NORMAL_CARTA = Color(1.0, 1.0, 1.0, 1.0)
const ESCALA_CARTA_EN_MESA = Vector2(0.7, 0.7)

# --- VARIABLES PARA LOS BOTONES DE CANTO ---
@onready var panel_de_acciones: Control = $PanelDeAcciones
@onready var boton_envido: Button = $PanelDeAcciones/ContenedorCantosPrincipales/BotonEnvido
@onready var boton_real_envido: Button = $PanelDeAcciones/ContenedorCantosPrincipales/BotonRealEnvido
@onready var boton_falta_envido: Button = $PanelDeAcciones/ContenedorCantosPrincipales/BotonFaltaEnvido
@onready var boton_flor: Button = $PanelDeAcciones/ContenedorCantosPrincipales/BotonFlor
@onready var boton_truco: Button = $PanelDeAcciones/ContenedorCantosPrincipales/BotonTruco
@onready var boton_retruco: Button = $PanelDeAcciones/ContenedorCantosPrincipales/BotonRetruco 
@onready var boton_vale_cuatro: Button = $PanelDeAcciones/ContenedorCantosPrincipales/BotonValeCuatro 

@onready var contenedor_respuestas: HBoxContainer = $PanelDeAcciones/ContenedorRespuestas
@onready var boton_quiero: Button = $PanelDeAcciones/ContenedorRespuestas/BotonQuiero
@onready var boton_no_quiero: Button = $PanelDeAcciones/ContenedorRespuestas/BotonNoQuiero

# --- ESTADOS DEL JUEGO PARA LOS CANTOS ---
var envido_cantado_en_ronda_de_mesa = false 
var flor_cantada_por_jugador = false
var flor_cantada_por_ia = false
var truco_estado = 0 # 0: no cantado, 1: truco, 2: retruco, 3: vale4
var esperando_respuesta_de_jugador = false 
var esperando_respuesta_de_ia = false    
var canto_actual_ia = null 
var canto_actual_jugador = null 

# --- VARIABLES DE ESTADO DE TURNO Y MANO ---
enum QuiJuega { JUGADOR, IA, NADIE } 
var turno_actual: QuiJuega = QuiJuega.NADIE # Quién tiene el turno general (para cantar o jugar)
var jugador_que_inicio_mano_de_mesa = QuiJuega.NADIE # Quién jugó primero en la mano de mesa actual
var jugador_es_mano_en_ronda_de_reparto = false # Quién es mano en el reparto actual de 3 cartas

var repartidor_global: QuiJuega = QuiJuega.NADIE # Quién reparte en la partida (chico), el otro es mano de la partida
# var primera_ronda_de_reparto_de_la_partida = true # Ya no se necesita, se maneja con repartidor_global == NADIE

func _ready():
	randomize() 
	var deck_node = get_node_or_null("DeckNode")
	if not is_instance_valid(deck_node):
		print("GAME.GD: Creando nueva instancia de Deck y añadiéndola a la escena como 'DeckNode'.")
		deck_script_instance = preload("res://Scripts/deck.gd").new()
		deck_script_instance.name = "DeckNode"
		add_child(deck_script_instance)
	else:
		print("GAME.GD: Usando instancia existente de DeckNode.")
		deck_script_instance = deck_node
	
	if not deck_script_instance.has_method("preparar_nuevo_mazo_para_ronda"):
		print("ERROR game.gd: El nodo DeckNode no tiene el script deck.gd correcto asignado o el método falta.")
		return

	if not textura_punto_ganado is Texture2D:
		var path = textura_punto_ganado.resource_path if textura_punto_ganado else "NULA"
		print("ERROR game.gd: 'textura_punto_ganado' no cargada o es inválida. Verifica la ruta: ", path)
	if not textura_punto_vacio is Texture2D:
		var path = textura_punto_vacio.resource_path if textura_punto_vacio else "NULA"
		print("ERROR game.gd: 'textura_punto_vacio' no cargada o es inválida. Verifica la ruta: ", path)
	
	conectar_senales_botones()
	iniciar_nueva_partida_completa() 

func _process(_delta):
	pass

#-----------------------------------------------------------------------------#
# INICIO Y CONTROL DE PARTIDA / RONDA DE REPARTO / MANO DE MESA               #
#-----------------------------------------------------------------------------#
func iniciar_nueva_partida_completa(): # Inicia un nuevo "chico"
	print("--- NUEVA PARTIDA COMPLETA (NUEVO CHICO) INICIADA ---")
	puntos_chico_jugador = 0
	puntos_chico_ia = 0
	
	# Determinar quién reparte y quién es mano para esta partida (chico)
	if repartidor_global == QuiJuega.NADIE: # Primera vez que se juega desde que se abrió el juego
		if randi() % 2 == 0:
			repartidor_global = QuiJuega.JUGADOR # Jugador reparte, IA es mano de la partida
		else:
			repartidor_global = QuiJuega.IA      # IA reparte, Jugador es mano de la partida
	else: # Alternar repartidor para la nueva partida (chico)
		repartidor_global = QuiJuega.IA if repartidor_global == QuiJuega.JUGADOR else QuiJuega.JUGADOR
	
	print("Nueva Partida: Reparte ", repartidor_global)
	iniciar_nueva_ronda_de_reparto()

func iniciar_nueva_ronda_de_reparto(): 
	print("--- NUEVA RONDA DE REPARTO INICIADA ---")
	for carta_nodo in cartas_en_mesa_jugador:
		if is_instance_valid(carta_nodo): carta_nodo.queue_free()
	for carta_nodo in cartas_en_mesa_ia:
		if is_instance_valid(carta_nodo): carta_nodo.queue_free()
	cartas_en_mesa_jugador.clear()
	cartas_en_mesa_ia.clear()
	
	if is_instance_valid(deck_script_instance):
		deck_script_instance.preparar_nuevo_mazo_para_ronda()
	else:
		print("ERROR game.gd: deck_script_instance no es válido al iniciar nueva ronda de reparto.")
		return 
	
	repartir_cartas_visuales_al_jugador()
	repartir_cartas_logicas_a_la_ia()

	ronda_de_mesa_actual = 0 
	resultado_manos_ronda = [0,0,0] 
	if carta_seleccionada: reset_carta_seleccionada()
	
	envido_cantado_en_ronda_de_mesa = false
	flor_cantada_por_jugador = false
	flor_cantada_por_ia = false
	truco_estado = 0 
	esperando_respuesta_de_jugador = false
	esperando_respuesta_de_ia = false
	canto_actual_ia = null
	canto_actual_jugador = null
	
	# Determinar quién es mano para ESTA RONDA DE REPARTO
	jugador_es_mano_en_ronda_de_reparto = (repartidor_global == QuiJuega.IA)
	
	print("Ronda de Reparto: Mano es ", "Jugador" if jugador_es_mano_en_ronda_de_reparto else "IA")

	# El mano de la ronda de reparto inicia la primera mano de mesa.
	if jugador_es_mano_en_ronda_de_reparto:
		turno_actual = QuiJuega.JUGADOR
		jugador_que_inicio_mano_de_mesa = QuiJuega.JUGADOR
		print("Jugador (mano) inicia la primera mano de mesa.")
	else:
		turno_actual = QuiJuega.IA
		jugador_que_inicio_mano_de_mesa = QuiJuega.IA
		print("IA (mano) inicia la primera mano de mesa.")
	
	actualizar_hud_puntos()
	actualizar_visibilidad_botones() 
	
	if turno_actual == QuiJuega.IA:
		await get_tree().create_timer(1.0).timeout 
		if not self: return 
		ia_decide_accion()

#-----------------------------------------------------------------------------#
# MANEJO DEL HUD DE PUNTOS                                                    #
#-----------------------------------------------------------------------------#
func actualizar_hud_puntos():
	if not is_instance_valid(contenedor_puntos_yo) or not is_instance_valid(contenedor_puntos_ia):
		print("ERROR game.gd: Contenedores de puntos del HUD no encontrados.")
		return
	if not (textura_punto_ganado is Texture2D and textura_punto_vacio is Texture2D):
		print("ERROR game.gd: Texturas de puntos no cargadas.")
		return

	for i in range(contenedor_puntos_yo.get_child_count()):
		var punto_nodo = contenedor_puntos_yo.get_child(i)
		if punto_nodo is TextureRect: 
			if i < puntos_chico_jugador: punto_nodo.texture = textura_punto_ganado
			else: punto_nodo.texture = textura_punto_vacio
	
	for i in range(contenedor_puntos_ia.get_child_count()):
		var punto_nodo = contenedor_puntos_ia.get_child(i)
		if punto_nodo is TextureRect:
			if i < puntos_chico_ia: punto_nodo.texture = textura_punto_ganado
			else: punto_nodo.texture = textura_punto_vacio

#-----------------------------------------------------------------------------#
# REPARTO Y MANEJO DE CARTAS DEL JUGADOR                                      #
#-----------------------------------------------------------------------------#
func repartir_cartas_visuales_al_jugador():
	for child in get_children():
		if child is Area2D and child.has_method("setup_carta") and child.input_pickable == true: 
			child.queue_free()
			
	var cartas_para_jugador = deck_script_instance.sacar_cartas(3)
	if cartas_para_jugador.size() < 3:
		print("WARN game.gd: No suficientes cartas en el mazo para repartir al jugador.")
		return
		
	for i in range(cartas_para_jugador.size()):
		var carta_data = cartas_para_jugador[i]
		var carta_visual = CardScene.instantiate()
		add_child(carta_visual) 
		carta_visual.setup_carta(carta_data["valor"], carta_data["palo"])
		
		carta_visual.position = slot_positions[i] + Vector2(0, 150) 
		carta_visual.rotation_degrees = slot_rotations[i] 
		carta_visual.z_index = i + 1 
		
		var tween = carta_visual.create_tween().set_parallel(true)
		tween.tween_property(carta_visual, "position", slot_positions[i], 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(carta_visual, "rotation_degrees", slot_rotations[i], 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func repartir_cartas_logicas_a_la_ia():
	mano_logica_ia.clear()
	var cartas_sacadas_ia = deck_script_instance.sacar_cartas(3) 
	if cartas_sacadas_ia.size() < 3:
		print("WARN game.gd: No suficientes cartas en el mazo para repartir a la IA.")
		return

	for carta_data in cartas_sacadas_ia:
		var valor_carta = carta_data["valor"]
		if valor_carta is String:
			if valor_carta.is_valid_int():
				valor_carta = int(valor_carta)
			else: 
				match valor_carta.to_lower():
					"sota": valor_carta = 10
					"caballo": valor_carta = 11
					"rey": valor_carta = 12
					_:
						print_debug("WARN game.gd: Valor de carta string no reconocido para IA: ", valor_carta)
						valor_carta = 0 
		elif not valor_carta is int:
			print_debug("WARN game.gd: Valor de carta no numérico ni string reconocible para IA: ", valor_carta)
			valor_carta = 0 
		mano_logica_ia.append({"valor": valor_carta, "palo": carta_data["palo"]})
	print("Mano lógica IA: ", mano_logica_ia)


func set_carta_seleccionada(carta_actual: Area2D):
	if carta_seleccionada == null and carta_actual.input_pickable: 
		carta_seleccionada = carta_actual
		carta_seleccionada.scale = Vector2(1.1, 1.1) 

func reset_carta_seleccionada():
	if is_instance_valid(carta_seleccionada): 
		if carta_seleccionada.input_pickable == true: 
			carta_seleccionada.scale = Vector2(1, 1) 
			carta_seleccionada.modulate = COLOR_NORMAL_CARTA 
	carta_seleccionada = null

#-----------------------------------------------------------------------------#
# LÓGICA DE JUEGO DE CARTAS (TURNO DEL JUGADOR Y IA)                          #
#-----------------------------------------------------------------------------#
func jugador_ha_jugado_carta(carta_que_jugo: Area2D):
	if turno_actual != QuiJuega.JUGADOR:
		print("WARN: Jugador intentó jugar carta fuera de su turno. Turno actual: ", turno_actual)
		if carta_seleccionada == carta_que_jugo:
			reset_carta_seleccionada()
			reorganize_player_hand_con_drop(carta_que_jugo, obtener_slot_original_carta(carta_que_jugo))
		return
	
	if cartas_en_mesa_jugador.size() > ronda_de_mesa_actual:
		print("WARN: Jugador intentó jugar más de una carta en la mano de mesa actual (%s)." % ronda_de_mesa_actual)
		if carta_seleccionada == carta_que_jugo:
			reset_carta_seleccionada()
			reorganize_player_hand_con_drop(carta_que_jugo, obtener_slot_original_carta(carta_que_jugo))
		return

	if not is_instance_valid(carta_que_jugo): return 
	
	print("JUGADOR JUGÓ: ", carta_que_jugo.valor, " de ", carta_que_jugo.palo, " en mano de mesa ", ronda_de_mesa_actual)
	
	# Animación de la carta jugada
	if is_instance_valid(nodo_mesa):
		var pos_base_carril = nodo_mesa.get_posicion_jugador_en_carril(ronda_de_mesa_actual)
		var rot_en_carril = nodo_mesa.get_rotacion_jugador_en_carril(ronda_de_mesa_actual)
		var dur_total_anim = 0.45
		var alt_lev = -40 
		var esc_max = Vector2(1.1,1.1) 
		
		carta_que_jugo.modulate = COLOR_NORMAL_CARTA 

		var t1 = carta_que_jugo.create_tween()
		t1.set_parallel(true)
		t1.tween_property(carta_que_jugo, "scale", esc_max, dur_total_anim*0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t1.tween_property(carta_que_jugo, "global_position:y", carta_que_jugo.global_position.y + alt_lev, dur_total_anim*0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if carta_que_jugo.rotation_degrees != 0 : 
			t1.tween_property(carta_que_jugo, "rotation_degrees", 0, dur_total_anim*0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		await t1.finished
		if not self: return 

		var t2 = carta_que_jugo.create_tween()
		t2.set_parallel(true)
		t2.tween_property(carta_que_jugo, "global_position", pos_base_carril, dur_total_anim*0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t2.tween_property(carta_que_jugo, "scale", ESCALA_CARTA_EN_MESA, dur_total_anim*0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t2.tween_property(carta_que_jugo, "rotation_degrees", rot_en_carril, dur_total_anim*0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Z-index se maneja en comparar_cartas o al colocar la primera carta de la mano
	else:
		print("ERROR game.gd: nodo_mesa no encontrado para animar carta del jugador.")
		carta_que_jugo.scale = ESCALA_CARTA_EN_MESA 
	
	cartas_en_mesa_jugador.append(carta_que_jugo)
	reset_carta_seleccionada() 
	reorganize_player_hand_con_drop() 
	
	# Si la IA ya jugó su carta para esta mano de mesa, procesamos la mano.
	if cartas_en_mesa_ia.size() > ronda_de_mesa_actual: # IA ya jugó, jugador fue segundo
		print("Jugador jugó (segundo en la mano de mesa). Procesando mano de mesa...")
		turno_actual = QuiJuega.NADIE 
		actualizar_visibilidad_botones()
		await get_tree().create_timer(0.1).timeout 
		if not self: return
		procesar_fin_de_mano_de_mesa()
	else: # IA aún no jugó en esta mano de mesa (Jugador fue primero)
		print("Jugador jugó (primero en la mano de mesa). Turno de la IA.")
		turno_actual = QuiJuega.IA
		actualizar_visibilidad_botones() # IA no debería poder cantar envido/flor ahora que jugador jugó.
		await get_tree().create_timer(0.6).timeout 
		if not self: return
		ia_decide_accion()


func ia_decide_accion():
	if esperando_respuesta_de_jugador: # Si IA está esperando respuesta a su canto
		print("IA está esperando respuesta del jugador a su canto: ", canto_actual_ia)
		return # No hace nada más

	if turno_actual != QuiJuega.IA:
		print("DEBUG IA: No es el turno de la IA para decidir acción. Turno: ", turno_actual)
		return

	print("IA DECIDE ACCIÓN...")
	
	# 1. ¿Cantar Envido/Flor?
	#    Solo en la primera mano de mesa (ronda_de_mesa_actual == 0)
	#    y ANTES de que la IA juegue su primera carta en esa mano de mesa.
	#    Y si el jugador no cantó flor ya.
	#    Y si no hay un truco ya iniciado por el jugador.
	if ronda_de_mesa_actual == 0 and cartas_en_mesa_ia.is_empty() and \
	   not envido_cantado_en_ronda_de_mesa and not flor_cantada_por_jugador and truco_estado == 0:
		if ia_intenta_cantar_envido_o_flor():
			turno_actual = QuiJuega.NADIE # Espera respuesta del jugador
			return 

	# 2. ¿Cantar Truco o derivados?
	#    La IA puede cantar truco si no hay un envido/flor activo esperando respuesta,
	#    y si el estado del truco lo permite.
	if not esperando_respuesta_de_ia and not esperando_respuesta_de_jugador: # Asegura que no haya cantos pendientes
		if ia_intenta_cantar_truco_o_derivados():
			turno_actual = QuiJuega.NADIE # Espera respuesta del jugador
			return 

	# 3. Si no cantó nada y es su turno de jugar carta, y no ha jugado ya en esta mano.
	if turno_actual == QuiJuega.IA and cartas_en_mesa_ia.size() == ronda_de_mesa_actual:
		jugar_turno_ia_carta()
	elif turno_actual == QuiJuega.IA and cartas_en_mesa_ia.size() > ronda_de_mesa_actual:
		print("DEBUG IA: Ya jugó carta en esta mano de mesa (", ronda_de_mesa_actual, "). Cartas IA en mesa: ", cartas_en_mesa_ia.size())
		# Esto es un bug si ocurre. El turno debería haber pasado.
		turno_actual = QuiJuega.NADIE 
		actualizar_visibilidad_botones()
	else:
		print("DEBUG IA: No es turno de jugar carta (Turno: %s, Cartas IA en mesa: %s, Ronda: %s) y no cantó." % [turno_actual, cartas_en_mesa_ia.size(), ronda_de_mesa_actual])
		actualizar_visibilidad_botones()


func ia_intenta_cantar_envido_o_flor() -> bool:
	# Condición para cantar envido/flor: primera mano de mesa, IA no ha jugado su carta aún,
	# no se ha cantado envido/flor en esta ronda de reparto, y el jugador no ha cantado flor.
	# Y no hay un truco ya iniciado.
	if not (ronda_de_mesa_actual == 0 and cartas_en_mesa_ia.is_empty() and \
			not envido_cantado_en_ronda_de_mesa and not flor_cantada_por_jugador and truco_estado == 0):
		return false 

	# Decisión de cantar FLOR por la IA
	if tiene_flor(mano_logica_ia) and not flor_cantada_por_ia: 
		print("IA CANTA: FLOR")
		flor_cantada_por_ia = true
		envido_cantado_en_ronda_de_mesa = true 
		canto_actual_ia = "FLOR_IA"
		esperando_respuesta_de_jugador = true
		actualizar_visibilidad_botones()
		return true

	# Decisión de cantar ENVIDO por la IA (si no tiene flor o ya se descartó cantar flor)
	var tantos_ia = calcular_tantos_envido(mano_logica_ia)
	if tantos_ia >= 27 and randf() < 0.6: # 60% de probabilidad si tiene buen envido
		var canto_envido_ia = "ENVIDO_IA"
		if tantos_ia >= 30 and randf() < 0.4: 
			canto_envido_ia = "REAL_ENVIDO_IA"
		# TODO: Lógica para Falta Envido por la IA
		
		print("IA CANTA: ", canto_envido_ia.replace("_IA",""))
		envido_cantado_en_ronda_de_mesa = true
		canto_actual_ia = canto_envido_ia
		esperando_respuesta_de_jugador = true
		actualizar_visibilidad_botones()
		return true
		
	return false 


func ia_intenta_cantar_truco_o_derivados() -> bool:
	if esperando_respuesta_de_jugador or esperando_respuesta_de_ia : return false 

	# Solo canta si es su turno general de acción o si está respondiendo a un truco del jugador (que se maneja en IA_responde_a_canto)
	# Esta función es para INICIAR o ELEVAR un truco cuando la IA tiene la palabra.
	if turno_actual != QuiJuega.IA and not (canto_actual_jugador != null and "TRUCO" in canto_actual_jugador) : # Si no es turno IA y no está respondiendo a un truco
		# print_debug("IA no tiene la palabra para iniciar/elevar truco. Turno: ", turno_actual)
		return false

	# Decisión de cantar TRUCO
	if truco_estado == 0:
		var mayor_poder_ia = 0
		for carta_data in mano_logica_ia:
			var poder = get_poder_truco_carta_logica(carta_data)
			if poder > mayor_poder_ia: mayor_poder_ia = poder
		
		if mayor_poder_ia > 65 and randf() < 0.4: # 40% de probabilidad
			print("IA CANTA: TRUCO")
			truco_estado = 1
			canto_actual_ia = "TRUCO_IA"
			esperando_respuesta_de_jugador = true
			actualizar_visibilidad_botones()
			return true
	
	# Decisión de cantar RETRUCO (IA eleva)
	# Esto ocurre si IA cantó Truco, Jugador quiso, y ahora IA quiere elevar.
	# O si Jugador cantó Truco, IA quiso, y ahora IA quiere elevar.
	# Simplificación: Si truco_estado es 1 y no hay canto activo del jugador.
	elif truco_estado == 1 and canto_actual_jugador == null: 
		var cartas_fuertes_para_retruco = 0
		for carta_data in mano_logica_ia:
			if get_poder_truco_carta_logica(carta_data) > 75: cartas_fuertes_para_retruco +=1
		
		if cartas_fuertes_para_retruco >= 1 and randf() < 0.35: 
			print("IA CANTA: RETRUCO")
			truco_estado = 2
			canto_actual_ia = "RETRUCO_IA"
			esperando_respuesta_de_jugador = true
			actualizar_visibilidad_botones()
			return true
			
	# Decisión de cantar VALE CUATRO (IA eleva)
	elif truco_estado == 2 and canto_actual_jugador == null:
		var cartas_muy_fuertes_para_vc = 0
		for carta_data in mano_logica_ia:
			if get_poder_truco_carta_logica(carta_data) > 85: cartas_muy_fuertes_para_vc +=1
		if cartas_muy_fuertes_para_vc >=1 and randf() < 0.3: 
			print("IA CANTA: VALE CUATRO")
			truco_estado = 3
			canto_actual_ia = "VALE_CUATRO_IA"
			esperando_respuesta_de_jugador = true
			actualizar_visibilidad_botones()
			return true
			
	return false

# --- FIN DE LA PARTE 1 ---
# El código continúa en la Parte 2 con la función jugar_turno_ia_carta()
# --- COMIENZO DE LA PARTE 2 ---
# (Continuación desde la Parte 1)

func jugar_turno_ia_carta():
	# IA solo juega si es su turno y no ha jugado ya en esta mano de mesa.
	if turno_actual != QuiJuega.IA or cartas_en_mesa_ia.size() > ronda_de_mesa_actual:
		print("DEBUG IA: Intento de jugar carta fuera de turno o ya jugó en esta mano de mesa. Turno: ", turno_actual, " Cartas IA en mesa: ", cartas_en_mesa_ia.size(), " Ronda: ", ronda_de_mesa_actual)
		if turno_actual == QuiJuega.IA and cartas_en_mesa_ia.size() > ronda_de_mesa_actual:
			print_debug("ERROR LÓGICO: IA intentando jugar segunda carta en la misma mano de mesa.")
			turno_actual = QuiJuega.NADIE 
			actualizar_visibilidad_botones()
		return

	print("IA JUEGA CARTA. Ronda de mesa actual: ", ronda_de_mesa_actual)
	if mano_logica_ia.is_empty(): 
		print("IA no tiene más cartas para jugar en esta ronda de reparto.")
		if ronda_de_mesa_actual < 3:
			if cartas_en_mesa_jugador.size() > ronda_de_mesa_actual: # Jugador ya jugó y espera a IA
				procesar_fin_de_mano_de_mesa_sin_carta_ia()
			else: # Ni jugador ni IA han jugado en esta mano, pero IA no tiene cartas. IA era mano.
				print("IA (mano) sin cartas y jugador tampoco jugó. Turno del jugador.")
				turno_actual = QuiJuega.JUGADOR
				actualizar_visibilidad_botones()
		return

	# --- LÓGICA DE DECISIÓN DE LA IA PARA JUGAR CARTA (MUY BÁSICA) ---
	# TODO: Implementar una mejor IA para elegir qué carta jugar.
	var carta_data_ia = mano_logica_ia.pop_front() 
	# --- FIN LÓGICA DE DECISIÓN IA ---

	var carta_ia_visual = CardScene.instantiate()
	add_child(carta_ia_visual) 
	carta_ia_visual.setup_carta(carta_data_ia["valor"], carta_data_ia["palo"])
	carta_ia_visual.input_pickable = false 
	carta_ia_visual.modulate = COLOR_NORMAL_CARTA
	print("IA JUGÓ: ", carta_ia_visual.valor, " de ", carta_ia_visual.palo, " en mano de mesa ", ronda_de_mesa_actual)
	
	if is_instance_valid(nodo_mesa):
		var pos_final_ia_en_carril = nodo_mesa.get_posicion_ia_en_carril(ronda_de_mesa_actual)
		var rot_final_ia_en_carril = nodo_mesa.get_rotacion_ia_en_carril(ronda_de_mesa_actual)
		var pos_inicial_anim_ia = pos_final_ia_en_carril + Vector2(randf_range(-25, 25), -70) 
		var rot_inicial_anim_ia = randf_range(-5, 5)
		var escala_inicial_anim_ia = Vector2(0.3, 0.3) 
		var duracion_anim_ia = 0.5

		carta_ia_visual.global_position = pos_inicial_anim_ia
		carta_ia_visual.scale = escala_inicial_anim_ia
		carta_ia_visual.rotation_degrees = rot_inicial_anim_ia
		# Z-index se maneja en comparar_cartas_mano_de_mesa

		var tween_ia = carta_ia_visual.create_tween()
		tween_ia.set_parallel(true)
		tween_ia.tween_property(carta_ia_visual, "global_position", pos_final_ia_en_carril, duracion_anim_ia)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_ia.tween_property(carta_ia_visual, "scale", ESCALA_CARTA_EN_MESA, duracion_anim_ia)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween_ia.tween_property(carta_ia_visual, "rotation_degrees", rot_final_ia_en_carril, duracion_anim_ia)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		print("ERROR game.gd: nodo_mesa no está asignado para la IA! Colocando carta sin animación.")
		carta_ia_visual.scale = ESCALA_CARTA_EN_MESA
	
	cartas_en_mesa_ia.append(carta_ia_visual)
	
	# Determinar el siguiente estado
	if cartas_en_mesa_jugador.size() > ronda_de_mesa_actual: # Jugador ya jugó su carta para esta mano de mesa
		print("IA jugó (segunda en la mano de mesa). Procesando mano de mesa...")
		turno_actual = QuiJuega.NADIE 
		actualizar_visibilidad_botones()
		await get_tree().create_timer(0.1).timeout 
		if not self: return
		procesar_fin_de_mano_de_mesa()
	else: # Jugador aún no jugó en esta mano de mesa (IA fue primero)
		print("IA jugó (primera en la mano de mesa). Turno del Jugador.")
		turno_actual = QuiJuega.JUGADOR
		actualizar_visibilidad_botones()


#-----------------------------------------------------------------------------#
# PROCESAMIENTO DEL FIN DE MANO DE MESA Y RONDA DE REPARTO                    #
#-----------------------------------------------------------------------------#
func procesar_fin_de_mano_de_mesa_sin_carta_ia():
	print("Procesando mano de mesa %d - IA no jugó (sin cartas para esta mano)." % ronda_de_mesa_actual)
	if cartas_en_mesa_jugador.size() > ronda_de_mesa_actual: 
		var carta_j = cartas_en_mesa_jugador[ronda_de_mesa_actual]
		resultado_manos_ronda[ronda_de_mesa_actual] = 1 # Jugador gana
		print("Jugador GANA la mano de mesa %d (IA sin carta para jugar)" % ronda_de_mesa_actual)
		
		var z_base_actual_carril = 15 + (ronda_de_mesa_actual * 2)
		carta_j.z_index = z_base_actual_carril + 1 
		carta_j.modulate = COLOR_ILUMINACION_GANADORA
		carta_j.scale = ESCALA_CARTA_EN_MESA 
		
		jugador_que_inicio_mano_de_mesa = QuiJuega.JUGADOR
	else:
		print("WARN: procesar_fin_de_mano_de_mesa_sin_carta_ia pero jugador tampoco jugó.")
		jugador_que_inicio_mano_de_mesa = QuiJuega.JUGADOR if jugador_es_mano_en_ronda_de_reparto else QuiJuega.IA

	ronda_de_mesa_actual += 1
	print("Próxima mano de mesa será: ", ronda_de_mesa_actual)

	if ronda_de_mesa_actual < 3 : 
		turno_actual = jugador_que_inicio_mano_de_mesa 
		print("Inicia siguiente mano de mesa. Juega primero: ", turno_actual)
		actualizar_visibilidad_botones()
		if turno_actual == QuiJuega.IA:
			await get_tree().create_timer(0.5).timeout 
			if not self: return
			ia_decide_accion()
	else: 
		print("RONDA DE REPARTO TERMINADA (3 manos de mesa jugadas)")
		determinar_ganador_ronda_de_reparto()
		turno_actual = QuiJuega.NADIE 
	
	if carta_seleccionada: reset_carta_seleccionada()

func procesar_fin_de_mano_de_mesa():
	if not (cartas_en_mesa_jugador.size() > ronda_de_mesa_actual and cartas_en_mesa_ia.size() > ronda_de_mesa_actual):
		# Este caso puede darse si un jugador se queda sin cartas y el otro ya había jugado.
		if cartas_en_mesa_jugador.size() > ronda_de_mesa_actual and mano_logica_ia.is_empty() and cartas_en_mesa_ia.size() <= ronda_de_mesa_actual:
			print("Jugador jugó, IA no tiene más cartas para esta mano. Procesando como mano ganada por jugador.")
			procesar_fin_de_mano_de_mesa_sin_carta_ia() # IA no pudo jugar
			return
		# Similar para el jugador si la IA jugó y el jugador no tiene más cartas (menos común con la lógica actual de turnos)
		
		print("ERROR: procesar_fin_de_mano_de_mesa llamada sin que ambos hayan jugado o uno se haya quedado sin cartas. Jugador cartas: ", cartas_en_mesa_jugador.size(), " IA cartas: ", cartas_en_mesa_ia.size(), " Ronda: ", ronda_de_mesa_actual)
		# Fallback: determinar turno basado en quién debía jugar.
		if cartas_en_mesa_jugador.size() <= ronda_de_mesa_actual and (turno_actual == QuiJuega.JUGADOR or jugador_que_inicio_mano_de_mesa == QuiJuega.JUGADOR):
			turno_actual = QuiJuega.JUGADOR
		elif cartas_en_mesa_ia.size() <= ronda_de_mesa_actual and (turno_actual == QuiJuega.IA or jugador_que_inicio_mano_de_mesa == QuiJuega.IA):
			turno_actual = QuiJuega.IA
		else: 
			turno_actual = jugador_que_inicio_mano_de_mesa 
		actualizar_visibilidad_botones()
		if turno_actual == QuiJuega.IA: await get_tree().create_timer(0.5).timeout; ia_decide_accion()
		return

	var ultima_carta_j = cartas_en_mesa_jugador[ronda_de_mesa_actual]
	var ultima_carta_ia = cartas_en_mesa_ia[ronda_de_mesa_actual]
	
	ultima_carta_j.modulate = COLOR_NORMAL_CARTA
	ultima_carta_ia.modulate = COLOR_NORMAL_CARTA
	ultima_carta_j.scale = ESCALA_CARTA_EN_MESA
	ultima_carta_ia.scale = ESCALA_CARTA_EN_MESA
	
	comparar_cartas_mano_de_mesa(ultima_carta_j, ultima_carta_ia) 

	ronda_de_mesa_actual += 1
	print("Próxima mano de mesa será: ", ronda_de_mesa_actual)

	if ronda_de_mesa_actual < 3 : 
		turno_actual = jugador_que_inicio_mano_de_mesa 
		print("Inicia siguiente mano de mesa. Juega primero: ", turno_actual)
		actualizar_visibilidad_botones()
		if turno_actual == QuiJuega.IA:
			await get_tree().create_timer(0.5).timeout 
			if not self: return
			ia_decide_accion()
	else: 
		print("RONDA DE REPARTO TERMINADA (3 manos de mesa jugadas)")
		determinar_ganador_ronda_de_reparto()
		turno_actual = QuiJuega.NADIE 
	
	if carta_seleccionada: reset_carta_seleccionada()


func determinar_ganador_ronda_de_reparto(): 
	print("Evaluando resultados de la ronda de reparto: ", resultado_manos_ronda)
	var manos_ganadas_jugador = 0
	var manos_ganadas_ia = 0

	for resultado_mano_de_mesa in resultado_manos_ronda:
		if resultado_mano_de_mesa == 1: manos_ganadas_jugador += 1
		elif resultado_mano_de_mesa == 2: manos_ganadas_ia += 1
	
	var puntos_por_ronda = 0 

	# Puntos del Truco según tu especificación
	if truco_estado == 0 : puntos_por_ronda = 1 # Ronda normal sin truco aceptado
	elif truco_estado == 1: puntos_por_ronda = 1 # TRUCO querido = 1 punto
	elif truco_estado == 2: puntos_por_ronda = 2 # RETRUCO querido = 2 puntos
	elif truco_estado == 3: puntos_por_ronda = 4 # VALE CUATRO querido = 4 puntos
	
	var quien_gana_los_puntos_de_cartas = QuiJuega.NADIE

	if manos_ganadas_jugador >= 2:
		print("¡JUGADOR GANA LA RONDA DE CARTAS!")
		quien_gana_los_puntos_de_cartas = QuiJuega.JUGADOR
	elif manos_ganadas_ia >= 2:
		print("¡IA GANA LA RONDA DE CARTAS!")
		quien_gana_los_puntos_de_cartas = QuiJuega.IA
	else: # Lógica de pardas para la ronda de reparto
		# Regla: Primera mano parda, define la segunda. Si segunda parda, define la tercera.
		# Si primera y segunda parda, define la tercera.
		# Si las tres pardas, gana el mano de la ronda de reparto.
		# Si A gana primera, y hay pardas después, gana A.
		if resultado_manos_ronda[0] == 1: # Jugador ganó la primera
			quien_gana_los_puntos_de_cartas = QuiJuega.JUGADOR
		elif resultado_manos_ronda[0] == 2: # IA ganó la primera
			quien_gana_los_puntos_de_cartas = QuiJuega.IA
		elif resultado_manos_ronda[0] == 3: # Primera parda
			if resultado_manos_ronda[1] == 1: quien_gana_los_puntos_de_cartas = QuiJuega.JUGADOR
			elif resultado_manos_ronda[1] == 2: quien_gana_los_puntos_de_cartas = QuiJuega.IA
			elif resultado_manos_ronda[1] == 3: # Segunda también parda
				if resultado_manos_ronda[2] == 1: quien_gana_los_puntos_de_cartas = QuiJuega.JUGADOR
				elif resultado_manos_ronda[2] == 2: quien_gana_los_puntos_de_cartas = QuiJuega.IA
				elif resultado_manos_ronda[2] == 3: # Triple parda
					quien_gana_los_puntos_de_cartas = QuiJuega.JUGADOR if jugador_es_mano_en_ronda_de_reparto else QuiJuega.IA
					print("TRIPLE PARDA. Gana el mano de la ronda: ", "Jugador" if quien_gana_los_puntos_de_cartas == QuiJuega.JUGADOR else "IA")
		
	if quien_gana_los_puntos_de_cartas != QuiJuega.NADIE:
		print(("Jugador" if quien_gana_los_puntos_de_cartas == QuiJuega.JUGADOR else "IA"), " GANA ", puntos_por_ronda, " PUNTOS por las cartas.")
		if quien_gana_los_puntos_de_cartas == QuiJuega.JUGADOR:
			puntos_chico_jugador += puntos_por_ronda
		else:
			puntos_chico_ia += puntos_por_ronda
	else: # Si después de la lógica de pardas no hay ganador (no debería pasar con la lógica actual)
		print("DEBUG: No se determinó ganador de ronda de reparto. Resultados: ", resultado_manos_ronda)
		# Fallback MUY improbable: gana el mano de la ronda.
		var mano_de_la_ronda = QuiJuega.JUGADOR if jugador_es_mano_en_ronda_de_reparto else QuiJuega.IA
		print("Fallback parda extrema: Gana el mano de la ronda de reparto (", mano_de_la_ronda, ") ", puntos_por_ronda, " puntos.")
		if mano_de_la_ronda == QuiJuega.JUGADOR: puntos_chico_jugador += puntos_por_ronda
		else: puntos_chico_ia += puntos_por_ronda

	actualizar_hud_puntos()
	verificar_fin_de_partida_completa() 

func verificar_fin_de_partida_completa(): 
	var fin_partida_chico = false
	if puntos_chico_jugador >= PUNTOS_PARA_GANAR_CHICO:
		print("¡¡¡JUGADOR GANÓ LA PARTIDA (CHICO) (%d a %d)!!!" % [puntos_chico_jugador, puntos_chico_ia])
		fin_partida_chico = true
	elif puntos_chico_ia >= PUNTOS_PARA_GANAR_CHICO:
		print("¡¡¡IA GANÓ LA PARTIDA (CHICO) (%d a %d)!!!" % [puntos_chico_ia, puntos_chico_jugador])
		fin_partida_chico = true
	
	if fin_partida_chico:
		await get_tree().create_timer(3.0).timeout 
		if not self: return
		iniciar_nueva_partida_completa() 
	else:
		await get_tree().create_timer(2.0).timeout 
		if not self: return
		iniciar_nueva_ronda_de_reparto()

func comparar_cartas_mano_de_mesa(carta_j: Area2D, carta_ia: Area2D):
	var z_base_actual_carril = 15 + (ronda_de_mesa_actual * 2)
	# Quien jugó primero en esta mano de mesa va abajo, el segundo encima.
	if jugador_que_inicio_mano_de_mesa == QuiJuega.JUGADOR: 
		carta_j.z_index = z_base_actual_carril
		carta_ia.z_index = z_base_actual_carril + 1
	else: # IA jugó primero
		carta_ia.z_index = z_base_actual_carril
		carta_j.z_index = z_base_actual_carril + 1
	
	var ganador_mano_actual = 0 # 1: Jugador, 2: IA, 3: Parda
	
	var poder_j = carta_j.get_poder_truco()
	var poder_ia = carta_ia.get_poder_truco()
	
	if poder_j > poder_ia: ganador_mano_actual = 1
	elif poder_ia > poder_j: ganador_mano_actual = 2
	else: ganador_mano_actual = 3 
	
	var offset_p = nodo_mesa.get_offset_carta_perdedora() 

	if ganador_mano_actual == 1: 
		print("Jugador GANA la mano de mesa %d" % (ronda_de_mesa_actual))
		carta_j.z_index = z_base_actual_carril + 2 
		carta_j.modulate = COLOR_ILUMINACION_GANADORA
		var t = carta_ia.create_tween() 
		t.tween_property(carta_ia, "global_position", carta_ia.global_position + offset_p, 0.2)
		jugador_que_inicio_mano_de_mesa = QuiJuega.JUGADOR # Jugador empieza la siguiente mano de mesa
	elif ganador_mano_actual == 2: 
		print("IA GANA la mano de mesa %d" % (ronda_de_mesa_actual))
		carta_ia.z_index = z_base_actual_carril + 2
		carta_ia.modulate = COLOR_ILUMINACION_GANADORA
		var t = carta_j.create_tween()
		t.tween_property(carta_j, "global_position", carta_j.global_position + offset_p, 0.2)
		jugador_que_inicio_mano_de_mesa = QuiJuega.IA # IA empieza la siguiente mano de mesa
	elif ganador_mano_actual == 3: 
		print("Mano de mesa %d EMPATADA (parda)" % (ronda_de_mesa_actual))
		# Quien era mano en esta mano de mesa (jugador_que_inicio_mano_de_mesa), sigue siendo mano para la siguiente.
		# No se cambia jugador_que_inicio_mano_de_mesa.
		var t_ia = carta_ia.create_tween()
		t_ia.tween_property(carta_ia, "global_position", carta_ia.global_position + offset_p*0.5, 0.2)
		var t_j = carta_j.create_tween()
		t_j.tween_property(carta_j, "global_position", carta_j.global_position + offset_p*0.5, 0.2)

	resultado_manos_ronda[ronda_de_mesa_actual] = ganador_mano_actual
	carta_j.scale = ESCALA_CARTA_EN_MESA
	carta_ia.scale = ESCALA_CARTA_EN_MESA

#-----------------------------------------------------------------------------#
# REORGANIZACIÓN DE MANO DEL JUGADOR (VISUAL)                                 #
#-----------------------------------------------------------------------------#
func obtener_slot_original_carta(carta_nodo: Area2D) -> int:
	var mejor_slot = -1
	var menor_dist_x = INF
	for i in range(slot_positions.size()):
		var dist_x = abs(carta_nodo.position.x - slot_positions[i].x)
		if dist_x < menor_dist_x:
			menor_dist_x = dist_x
			mejor_slot = i
	return mejor_slot

# --- FIN DE LA PARTE 2 ---
# El código continúa en la Parte 3 con la función solto_carta_para_reordenar_mano()
# --- COMIENZO DE LA PARTE 3 ---
# (Continuación desde la Parte 2)

func solto_carta_para_reordenar_mano(carta_soltada: Area2D, posicion_mouse_global: Vector2):
	var slot_destino_idx = -1
	var distancia_minima_al_slot = INF
	var posicion_mouse_local_a_game = to_local(posicion_mouse_global) 
	var encontrado_por_area_directa = false

	for i in range(slot_positions.size()):
		var slot_rect_para_drop = Rect2(slot_positions[i] - Vector2(75, 120), Vector2(150, 240))
		if slot_rect_para_drop.has_point(posicion_mouse_local_a_game):
			slot_destino_idx = i
			encontrado_por_area_directa = true
			break
			
	if not encontrado_por_area_directa:
		for i in range(slot_positions.size()):
			var distancia = posicion_mouse_local_a_game.distance_to(slot_positions[i])
			if distancia < distancia_minima_al_slot:
				distancia_minima_al_slot = distancia
				slot_destino_idx = i
				
	if slot_destino_idx != -1: 
		reorganize_player_hand_con_drop(carta_soltada, slot_destino_idx)
	else: 
		print("ADVERTENCIA game.gd: No se pudo determinar un slot destino para reordenar, usando reorganización simple.")
		reorganize_player_hand_con_drop()

func reorganize_player_hand_con_drop(carta_arrastrada: Area2D = null, slot_para_arrastrada: int = -1):
	var cartas_en_mano_actuales: Array[Area2D] = [] 
	for child in get_children():
		if child is Area2D and child.has_method("setup_carta") and child.input_pickable == true:
			cartas_en_mano_actuales.append(child)
			
	var nueva_disposicion_cartas: Array[Area2D] = [] 
	for i in range(slot_positions.size()): nueva_disposicion_cartas.append(null)

	var es_reorganizacion_simple = (carta_arrastrada == null or slot_para_arrastrada < 0 or slot_para_arrastrada >= slot_positions.size())

	if not es_reorganizacion_simple and is_instance_valid(carta_arrastrada):
		if slot_para_arrastrada < nueva_disposicion_cartas.size() and slot_para_arrastrada >= 0 : #Bounds check
			nueva_disposicion_cartas[slot_para_arrastrada] = carta_arrastrada
		else:
			print_debug("Error: slot_para_arrastrada fuera de rango en reorganize_player_hand_con_drop")
			es_reorganizacion_simple = true # Fallback a reorganización simple
		
	var otras_cartas_temp: Array[Area2D] = []
	for c in cartas_en_mano_actuales:
		var incluir_carta = true
		if not es_reorganizacion_simple and c == carta_arrastrada:
			incluir_carta = false
		if incluir_carta:
			otras_cartas_temp.append(c)
			
	otras_cartas_temp.sort_custom(func(a,b): return a.position.x < b.position.x)
	
	var idx_otras_cartas = 0
	for i in range(nueva_disposicion_cartas.size()):
		if nueva_disposicion_cartas[i] == null: 
			if idx_otras_cartas < otras_cartas_temp.size():
				nueva_disposicion_cartas[i] = otras_cartas_temp[idx_otras_cartas]
				idx_otras_cartas += 1
				
	for i in range(nueva_disposicion_cartas.size()):
		var carta_para_slot = nueva_disposicion_cartas[i]
		if is_instance_valid(carta_para_slot): 
			animar_carta_a_slot(carta_para_slot, i)

func animar_carta_a_slot(carta_nodo: Area2D, slot_idx: int):
	if not is_instance_valid(carta_nodo): return 
	if slot_idx < 0 or slot_idx >= slot_positions.size(): return
	
	var target_pos = slot_positions[slot_idx]
	var target_rot = slot_rotations[slot_idx]
	
	var tween = carta_nodo.create_tween().set_parallel(true)
	tween.tween_property(carta_nodo, "position", target_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(carta_nodo, "rotation_degrees", target_rot, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	carta_nodo.z_index = slot_idx + 1

#-----------------------------------------------------------------------------#
# LÓGICA DE BOTONES DE CANTO Y RESPUESTAS                                     #
#-----------------------------------------------------------------------------#
func conectar_senales_botones():
	if is_instance_valid(boton_envido): boton_envido.pressed.connect(_on_boton_envido_pressed)
	else: print_debug("Error game.gd: BotonEnvido no encontrado.")
	
	if is_instance_valid(boton_real_envido): boton_real_envido.pressed.connect(_on_boton_real_envido_pressed)
	else: print_debug("Error game.gd: BotonRealEnvido no encontrado.")
	
	if is_instance_valid(boton_falta_envido): boton_falta_envido.pressed.connect(_on_boton_falta_envido_pressed)
	else: print_debug("Error game.gd: BotonFaltaEnvido no encontrado.")

	if is_instance_valid(boton_flor): boton_flor.pressed.connect(_on_boton_flor_pressed)
	else: print_debug("Error game.gd: BotonFlor no encontrado.")

	if is_instance_valid(boton_truco): boton_truco.pressed.connect(_on_boton_truco_pressed)
	else: print_debug("Error game.gd: BotonTruco no encontrado.")

	if is_instance_valid(boton_retruco): boton_retruco.pressed.connect(_on_boton_retruco_pressed)
	else: print_debug("Error game.gd: BotonRetruco no encontrado. Verifica la ruta en @onready.")
	
	if is_instance_valid(boton_vale_cuatro): boton_vale_cuatro.pressed.connect(_on_boton_vale_cuatro_pressed)
	else: print_debug("Error game.gd: BotonValeCuatro no encontrado. Verifica la ruta en @onready.")

	if is_instance_valid(boton_quiero): boton_quiero.pressed.connect(_on_boton_quiero_pressed)
	else: print_debug("Error game.gd: BotonQuiero no encontrado.")
	
	if is_instance_valid(boton_no_quiero): boton_no_quiero.pressed.connect(_on_boton_no_quiero_pressed)
	else: print_debug("Error game.gd: BotonNoQuiero no encontrado.")

func actualizar_visibilidad_botones():
	if not is_instance_valid(panel_de_acciones):
		print_debug("PanelDeAcciones no encontrado en actualizar_visibilidad_botones.")
		return

	var jugador_tiene_la_palabra_para_cantar_o_jugar = (turno_actual == QuiJuega.JUGADOR and not esperando_respuesta_de_ia)
	
	# Condición para poder cantar Envido o Flor:
	# 1. Primera mano de mesa (ronda_de_mesa_actual == 0).
	# 2. Ninguna carta jugada por ninguno de los dos en esta mano de mesa.
	# 3. No se ha cantado Envido o Flor previamente en esta ronda de reparto.
	# 4. Es el turno del jugador para actuar (cantar o jugar).
	var puede_cantar_envido_o_flor_inicial = (ronda_de_mesa_actual == 0 and \
											cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty() and \
											not envido_cantado_en_ronda_de_mesa)

	# Visibilidad de botones de Envido y Flor del jugador
	var mostrar_envidos_jugador = puede_cantar_envido_o_flor_inicial and jugador_tiene_la_palabra_para_cantar_o_jugar and \
								not flor_cantada_por_jugador and not flor_cantada_por_ia and truco_estado == 0 # Envido antes de Truco
	if is_instance_valid(boton_envido): boton_envido.visible = mostrar_envidos_jugador
	if is_instance_valid(boton_real_envido): boton_real_envido.visible = mostrar_envidos_jugador
	if is_instance_valid(boton_falta_envido): boton_falta_envido.visible = mostrar_envidos_jugador
	
	var jugador_tiene_flor_fisica = tiene_flor(obtener_cartas_mano_logica_jugador())
	if is_instance_valid(boton_flor): boton_flor.visible = puede_cantar_envido_o_flor_inicial and jugador_tiene_la_palabra_para_cantar_o_jugar and \
													jugador_tiene_flor_fisica and not flor_cantada_por_jugador and truco_estado == 0
	
	# Visibilidad de botones de Truco del jugador
	var puede_jugador_cantar_truco_inicial = jugador_tiene_la_palabra_para_cantar_o_jugar and truco_estado == 0
	# Regla: "primero está el Envido". Si se puede cantar envido/flor, el truco espera.
	# Excepción: si el jugador NO es mano, y el mano jugó su primera carta sin cantar envido/flor, el pie puede cantar truco.
	if puede_cantar_envido_o_flor_inicial and (jugador_es_mano_en_ronda_de_reparto or (not jugador_es_mano_en_ronda_de_reparto and cartas_en_mesa_ia.is_empty())) :
		puede_jugador_cantar_truco_inicial = false


	if is_instance_valid(boton_truco):
		boton_truco.visible = puede_jugador_cantar_truco_inicial
	
	if is_instance_valid(boton_retruco):
		# Jugador puede cantar RETRUCO si:
		# 1. IA cantó TRUCO y jugador está por responder.
		# 2. Jugador cantó TRUCO, IA dijo QUIERO, y ahora es turno del jugador de hablar/elevar.
		var responde_a_truco_ia = (esperando_respuesta_de_jugador and canto_actual_ia == "TRUCO_IA")
		var eleva_su_propio_truco_aceptado = (jugador_tiene_la_palabra_para_cantar_o_jugar and truco_estado == 1 and canto_actual_jugador == null and canto_actual_ia == null)
		boton_retruco.visible = responde_a_truco_ia or eleva_su_propio_truco_aceptado
		
	if is_instance_valid(boton_vale_cuatro):
		var responde_a_retruco_ia = (esperando_respuesta_de_jugador and canto_actual_ia == "RETRUCO_IA")
		var eleva_su_propio_retruco_aceptado = (jugador_tiene_la_palabra_para_cantar_o_jugar and truco_estado == 2 and canto_actual_jugador == null and canto_actual_ia == null)
		boton_vale_cuatro.visible = responde_a_retruco_ia or eleva_su_propio_retruco_aceptado

	# Visibilidad de botones de respuesta ("Quiero", "No Quiero")
	if is_instance_valid(contenedor_respuestas): contenedor_respuestas.visible = esperando_respuesta_de_jugador
	
	# Ocultar botones de canto principales si se está esperando una respuesta del jugador a un canto de la IA
	if esperando_respuesta_de_jugador:
		if is_instance_valid(boton_envido): boton_envido.visible = false
		if is_instance_valid(boton_real_envido): boton_real_envido.visible = false
		if is_instance_valid(boton_falta_envido): boton_falta_envido.visible = false
		if is_instance_valid(boton_flor): boton_flor.visible = false
		
		# Si IA cantó TRUCO, el botón de TRUCO del jugador se oculta (debería ver RETRUCO).
		if canto_actual_ia == "TRUCO_IA" and is_instance_valid(boton_truco) : boton_truco.visible = false
		# Si IA cantó RETRUCO, el botón de RETRUCO del jugador se oculta (debería ver VALE CUATRO).
		if canto_actual_ia == "RETRUCO_IA" and is_instance_valid(boton_retruco) : boton_retruco.visible = false
		# Si IA cantó VALE CUATRO, el botón de VALE CUATRO del jugador se oculta.
		if canto_actual_ia == "VALE_CUATRO_IA" and is_instance_valid(boton_vale_cuatro) : boton_vale_cuatro.visible = false


	# Si es turno de la IA para jugar carta, o se espera respuesta de la IA (y no del jugador), el jugador no debería poder iniciar cantos
	if (turno_actual == QuiJuega.IA or esperando_respuesta_de_ia) and not esperando_respuesta_de_jugador: 
		if is_instance_valid(boton_envido): boton_envido.visible = false
		if is_instance_valid(boton_real_envido): boton_real_envido.visible = false
		if is_instance_valid(boton_falta_envido): boton_falta_envido.visible = false
		if is_instance_valid(boton_flor): boton_flor.visible = false
		if is_instance_valid(boton_truco): boton_truco.visible = false
		if is_instance_valid(boton_retruco): boton_retruco.visible = false
		if is_instance_valid(boton_vale_cuatro): boton_vale_cuatro.visible = false


func puede_jugador_cantar_ahora() -> bool:
	# Condiciones generales para que el jugador pueda iniciar un canto (no responder)
	if esperando_respuesta_de_ia: return false # IA está pensando o por responder
	if esperando_respuesta_de_jugador: return false # Jugador ya está en proceso de responder a IA
	if turno_actual != QuiJuega.JUGADOR and not (jugador_es_mano_en_ronda_de_reparto and ronda_de_mesa_actual == 0 and cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty()):
		# No es turno del jugador, A MENOS que sea mano y sea el inicio absoluto de la ronda de cartas.
		return false
	return true

func _on_boton_envido_pressed():
	if not puede_jugador_cantar_ahora(): return
	if not boton_envido.visible: return 
	if not (ronda_de_mesa_actual == 0 and cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty() and not envido_cantado_en_ronda_de_mesa and truco_estado == 0): return

	print("JUGADOR CANTA: ENVIDO")
	envido_cantado_en_ronda_de_mesa = true 
	canto_actual_jugador = "ENVIDO" 
	esperando_respuesta_de_ia = true
	turno_actual = QuiJuega.NADIE 
	actualizar_visibilidad_botones()
	
	await get_tree().create_timer(1.0).timeout 
	if not self: return
	IA_responde_a_canto_jugador()

func _on_boton_real_envido_pressed():
	if not puede_jugador_cantar_ahora(): return
	if not boton_real_envido.visible: return
	if not (ronda_de_mesa_actual == 0 and cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty() and not envido_cantado_en_ronda_de_mesa and truco_estado == 0): return

	print("JUGADOR CANTA: REAL ENVIDO")
	envido_cantado_en_ronda_de_mesa = true
	canto_actual_jugador = "REAL_ENVIDO"
	esperando_respuesta_de_ia = true
	turno_actual = QuiJuega.NADIE
	actualizar_visibilidad_botones()

	await get_tree().create_timer(1.0).timeout
	if not self: return
	IA_responde_a_canto_jugador()

func _on_boton_falta_envido_pressed():
	if not puede_jugador_cantar_ahora(): return
	if not boton_falta_envido.visible: return
	if not (ronda_de_mesa_actual == 0 and cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty() and not envido_cantado_en_ronda_de_mesa and truco_estado == 0): return

	print("JUGADOR CANTA: FALTA ENVIDO")
	envido_cantado_en_ronda_de_mesa = true
	canto_actual_jugador = "FALTA_ENVIDO"
	esperando_respuesta_de_ia = true
	turno_actual = QuiJuega.NADIE
	actualizar_visibilidad_botones()

	await get_tree().create_timer(1.0).timeout
	if not self: return
	IA_responde_a_canto_jugador()

func _on_boton_flor_pressed():
	if not puede_jugador_cantar_ahora(): return
	if not boton_flor.visible: return
	if not (ronda_de_mesa_actual == 0 and cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty() and not envido_cantado_en_ronda_de_mesa and truco_estado == 0): return
	if not tiene_flor(obtener_cartas_mano_logica_jugador()):
		print("JUGADOR INTENTÓ CANTAR FLOR SIN TENERLA!") 
		return 
		
	print("JUGADOR CANTA: FLOR")
	flor_cantada_por_jugador = true
	envido_cantado_en_ronda_de_mesa = true 
	canto_actual_jugador = "FLOR"
	esperando_respuesta_de_ia = true
	turno_actual = QuiJuega.NADIE
	actualizar_visibilidad_botones()

	await get_tree().create_timer(1.0).timeout
	if not self: return
	IA_responde_a_canto_jugador()

func _on_boton_truco_pressed():
	if not puede_jugador_cantar_ahora(): return
	# Regla: "primero está el Envido". Si se puede cantar envido/flor, el truco espera.
	if ronda_de_mesa_actual == 0 and cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty() and not envido_cantado_en_ronda_de_mesa:
		if jugador_es_mano_en_ronda_de_reparto: # Si jugador es mano, debe esperar a que pase la chance de envido/flor
			var puede_cantar_envido_flor_ahora = (tiene_flor(obtener_cartas_mano_logica_jugador()) and not flor_cantada_por_jugador) or \
												(not tiene_flor(obtener_cartas_mano_logica_jugador()) and not envido_cantado_en_ronda_de_mesa)
			if puede_cantar_envido_flor_ahora:
				print("Jugador (mano) debe resolver Envido/Flor antes de Truco.")
				return
		# Si jugador es pie, y el mano (IA) no cantó envido/flor y jugó carta, jugador puede cantar truco.
		# Esta condición se maneja mejor por `turno_actual` y `jugador_tiene_la_palabra_para_cantar` en `actualizar_visibilidad_botones`.

	if not boton_truco.visible or truco_estado != 0: return
	print("JUGADOR CANTA: TRUCO")
	truco_estado = 1
	canto_actual_jugador = "TRUCO"
	esperando_respuesta_de_ia = true
	turno_actual = QuiJuega.NADIE 
	actualizar_visibilidad_botones()

	await get_tree().create_timer(1.0).timeout
	if not self: return
	IA_responde_a_canto_jugador()

# --- FIN DE LA PARTE 3 ---
# El código continúa en la Parte 4 con la función _on_boton_retruco_pressed()
# --- COMIENZO DE LA PARTE 4 ---
# (Continuación desde la Parte 3)

func _on_boton_retruco_pressed():
	# Jugador puede cantar retruco si:
	# 1. IA cantó TRUCO y jugador está por responder (esperando_respuesta_de_jugador y canto_actual_ia == "TRUCO_IA")
	# 2. Jugador cantó TRUCO, IA dijo QUIERO, y ahora es "turno de hablar" del jugador para elevar.
	var puede_cantar_retruco_como_respuesta = (esperando_respuesta_de_jugador and canto_actual_ia == "TRUCO_IA")
	var puede_cantar_retruco_como_elevacion = (turno_actual == QuiJuega.JUGADOR and \
												not esperando_respuesta_de_ia and \
												not esperando_respuesta_de_jugador and \
												truco_estado == 1 and canto_actual_jugador == null and canto_actual_ia == null)


	if not (puede_cantar_retruco_como_respuesta or puede_cantar_retruco_como_elevacion):
		print("WARN: Jugador intentó Retruco fuera de contexto. Visible: ", boton_retruco.visible, " TrucoE: ", truco_estado)
		return
	if not boton_retruco.visible : return # Solo si el botón está visible (lógica de visibilidad debe ser correcta)
	if truco_estado != 1: # Solo se puede retrucar un truco
		print("WARN: Jugador intentó Retruco pero truco_estado no es 1. Estado: ", truco_estado)
		return

	print("JUGADOR CANTA: RETRUCO")
	truco_estado = 2
	canto_actual_jugador = "RETRUCO" 
	esperando_respuesta_de_ia = true
	esperando_respuesta_de_jugador = false # Jugador ya habló, espera respuesta de IA
	canto_actual_ia = null # Limpiar canto de IA previo si lo había (ej. TRUCO_IA)
	turno_actual = QuiJuega.NADIE # El juego de cartas se pausa hasta que IA responda
	actualizar_visibilidad_botones()

	await get_tree().create_timer(1.0).timeout
	if not self: return
	IA_responde_a_canto_jugador()


func _on_boton_vale_cuatro_pressed():
	var puede_cantar_vc_como_respuesta = (esperando_respuesta_de_jugador and canto_actual_ia == "RETRUCO_IA")
	var puede_cantar_vc_como_elevacion = (turno_actual == QuiJuega.JUGADOR and \
											not esperando_respuesta_de_ia and \
											not esperando_respuesta_de_jugador and \
											truco_estado == 2 and canto_actual_jugador == null and canto_actual_ia == null)

	if not (puede_cantar_vc_como_respuesta or puede_cantar_vc_como_elevacion): 
		print("WARN: Jugador intentó ValeCuatro fuera de contexto.")
		return
	if not boton_vale_cuatro.visible : return 
	if truco_estado != 2: # Solo se puede Vale4 a un Retruco
		print("WARN: Jugador intentó ValeCuatro pero truco_estado no es 2. Estado: ", truco_estado)
		return

	print("JUGADOR CANTA: VALE CUATRO")
	truco_estado = 3
	canto_actual_jugador = "VALE_CUATRO"
	esperando_respuesta_de_ia = true
	esperando_respuesta_de_jugador = false
	canto_actual_ia = null
	turno_actual = QuiJuega.NADIE
	actualizar_visibilidad_botones()

	await get_tree().create_timer(1.0).timeout
	if not self: return
	IA_responde_a_canto_jugador()


func _on_boton_quiero_pressed():
	if not esperando_respuesta_de_jugador or not boton_quiero.visible: return
	print("JUGADOR RESPONDE: QUIERO al ", canto_actual_ia)
	
	var canto_ia_era_envido_flor = canto_actual_ia in ["ENVIDO_IA", "REAL_ENVIDO_IA", "FALTA_ENVIDO_IA", "FLOR_IA", "CONTRAFLOR_IA"]
	var canto_ia_era_truco = canto_actual_ia in ["TRUCO_IA", "RETRUCO_IA", "VALE_CUATRO_IA"]

	if canto_ia_era_envido_flor:
		if canto_actual_ia == "FLOR_IA": 
			resolver_flor_querida_por_jugador() 
		elif canto_actual_ia == "CONTRAFLOR_IA": 
			resolver_contraflor_querida_por_jugador() 
		else: 
			resolver_envido_querido_por_jugador() 
		envido_cantado_en_ronda_de_mesa = true 
		
		# Determinar quién juega después de resolver envido/flor
		if cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty(): 
			turno_actual = QuiJuega.JUGADOR if jugador_es_mano_en_ronda_de_reparto else QuiJuega.IA
		else: 
			turno_actual = jugador_que_inicio_mano_de_mesa 
		print("Envido/Flor resuelto. Turno para jugar carta: ", turno_actual)

	elif canto_ia_era_truco:
		print("Jugador quiere el ", canto_actual_ia)
		# truco_estado ya fue seteado por la IA cuando cantó.
		# Ahora, el que fue "querido" (la IA) tiene la opción de jugar carta o elevar.
		turno_actual = QuiJuega.IA 
		print("Truco querido por jugador. Turno de la IA para jugar carta o elevar.")
	
	esperando_respuesta_de_jugador = false
	canto_actual_ia = null 
	actualizar_visibilidad_botones()

	if turno_actual == QuiJuega.IA:
		await get_tree().create_timer(0.5).timeout
		if not self: return
		ia_decide_accion()
	# Si el turno es del jugador, se espera su acción (jugar carta o cantar).


func _on_boton_no_quiero_pressed():
	if not esperando_respuesta_de_jugador or not boton_no_quiero.visible: return
	print("JUGADOR RESPONDE: NO QUIERO al ", canto_actual_ia)
	var puntos_ganados_ia = 0
	var finaliza_ronda_de_reparto_por_no_quiero = false 

	match canto_actual_ia:
		"ENVIDO_IA": puntos_ganados_ia = 1
		"REAL_ENVIDO_IA": puntos_ganados_ia = 1 
		"FALTA_ENVIDO_IA": puntos_ganados_ia = 1 
		"FLOR_IA":
			puntos_ganados_ia = 3 
			flor_cantada_por_ia = true 
		"CONTRAFLOR_IA": 
			puntos_ganados_ia = 3 # Si jugador no quiere la Contraflor de IA, IA gana los puntos de SU flor.
			flor_cantada_por_ia = true
		"TRUCO_IA":
			puntos_ganados_ia = 1 
			finaliza_ronda_de_reparto_por_no_quiero = true
		"RETRUCO_IA":
			puntos_ganados_ia = 1 # IA cantó Retruco, jugador no quiere. IA gana los puntos del Truco anterior (1 punto).
			finaliza_ronda_de_reparto_por_no_quiero = true
		"VALE_CUATRO_IA":
			puntos_ganados_ia = 2 # IA cantó ValeCuatro, jugador no quiere. IA gana los puntos del Retruco anterior (2 puntos).
			finaliza_ronda_de_reparto_por_no_quiero = true
	
	if puntos_ganados_ia > 0:
		print("IA suma %d puntos por el NO QUIERO del jugador al %s" % [puntos_ganados_ia, canto_actual_ia])
		puntos_chico_ia += puntos_ganados_ia
		actualizar_hud_puntos()

	if canto_actual_ia and ("ENVIDO" in canto_actual_ia or "FLOR" in canto_actual_ia or "CONTRAFLOR" in canto_actual_ia) :
		envido_cantado_en_ronda_de_mesa = true 
	
	esperando_respuesta_de_jugador = false
	var _canto_previo_ia = canto_actual_ia 
	canto_actual_ia = null
	actualizar_visibilidad_botones()
	
	if finaliza_ronda_de_reparto_por_no_quiero:
		finalizar_ronda_de_reparto_por_canto_no_querido()
	else: # Envido/Flor no querido, el juego de cartas continúa.
		print("Envido/Flor no querido por Jugador. Turno de la IA.")
		# El que cantó y no fue querido (IA) tiene la palabra.
		turno_actual = QuiJuega.IA 
		ia_decide_accion()


func finalizar_ronda_de_reparto_por_canto_no_querido():
	# Se llama si un Truco (o derivado) es rechazado.
	print("Finalizando ronda de reparto actual (canto de truco no querido). Preparando para nueva ronda de reparto.")
	# Aquí podrían ir animaciones o mensajes de "IA se lleva X puntos".
	await get_tree().create_timer(1.5).timeout
	if not self: return
	
	verificar_fin_de_partida_completa() # Esto iniciará nueva ronda de reparto o nueva partida completa.


func IA_responde_a_canto_jugador():
	if not esperando_respuesta_de_ia: 
		print("DEBUG IA: No se esperaba respuesta de IA, pero se llamó IA_responde_a_canto_jugador.")
		return 
		
	print("IA RESPONDE A CANTO DEL JUGADOR: ", canto_actual_jugador)
	var decision_ia = "NO_QUIERO" 
	var puntos_a_ganar_jugador_si_no_quiere_ia = 0
	
	match canto_actual_jugador:
		"ENVIDO":
			puntos_a_ganar_jugador_si_no_quiere_ia = 1
			if calcular_tantos_envido(mano_logica_ia) >= 27 and randf() < 0.7: decision_ia = "QUIERO" 
		"REAL_ENVIDO":
			puntos_a_ganar_jugador_si_no_quiere_ia = 1 
			if calcular_tantos_envido(mano_logica_ia) >= 29 and randf() < 0.6: decision_ia = "QUIERO"
		"FALTA_ENVIDO":
			puntos_a_ganar_jugador_si_no_quiere_ia = 1 
			if calcular_tantos_envido(mano_logica_ia) >= 30 and randf() < 0.5: decision_ia = "QUIERO"
		"FLOR":
			puntos_a_ganar_jugador_si_no_quiere_ia = 3 
			if tiene_flor(mano_logica_ia):
				if calcular_valor_flor(mano_logica_ia) > calcular_valor_flor(obtener_cartas_mano_logica_jugador()) and randf() < 0.5: 
					decision_ia = "CONTRAFLOR_IA"
				else: 
					decision_ia = "QUIERO_FLOR_AJENA" 
			else: 
				decision_ia = "NO_TENGO_FLOR" 
		"TRUCO":
			puntos_a_ganar_jugador_si_no_quiere_ia = 1 
			var poder_max_ia = 0
			for c in mano_logica_ia: poder_max_ia = max(poder_max_ia, get_poder_truco_carta_logica(c))
			if poder_max_ia > 60 and randf() < 0.7: 
				decision_ia = "QUIERO"
				if poder_max_ia > 75 and randf() < 0.3: 
					decision_ia = "RETRUCO_IA"
		"RETRUCO":
			puntos_a_ganar_jugador_si_no_quiere_ia = 1 # Jugador cantó Retruco, si IA no quiere, Jugador gana puntos del Truco (1 punto).
			if randf() < 0.5: 
				decision_ia = "QUIERO"
				if tiene_cartas_para_vale_cuatro(mano_logica_ia) and randf() < 0.25:
					decision_ia = "VALE_CUATRO_IA"
		"VALE_CUATRO":
			puntos_a_ganar_jugador_si_no_quiere_ia = 2 # Jugador cantó Vale4, si IA no quiere, Jugador gana puntos del Retruco (2 puntos).
			if randf() < 0.4: decision_ia = "QUIERO"

	# Procesar decisión de la IA
	print("DECISIÓN IA: ", decision_ia)
	esperando_respuesta_de_ia = false 
	
	if decision_ia == "QUIERO":
		print("IA RESPONDE: QUIERO al ", canto_actual_jugador)
		if canto_actual_jugador in ["ENVIDO", "REAL_ENVIDO", "FALTA_ENVIDO"]:
			resolver_envido_querido_por_ia() 
			envido_cantado_en_ronda_de_mesa = true
			# Determinar quién juega después de resolver envido
			if cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty(): # Canto antes de jugar cartas
				turno_actual = QuiJuega.JUGADOR if jugador_es_mano_en_ronda_de_reparto else QuiJuega.IA
			else: # Canto después de que alguien jugó (improbable para envido, pero cubierto)
				turno_actual = jugador_que_inicio_mano_de_mesa 
		elif canto_actual_jugador == "FLOR": 
			resolver_flor_querida_por_ia() 
			flor_cantada_por_jugador = true
			if cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty():
				turno_actual = QuiJuega.JUGADOR if jugador_es_mano_en_ronda_de_reparto else QuiJuega.IA
			else:
				turno_actual = jugador_que_inicio_mano_de_mesa
		elif canto_actual_jugador == "TRUCO":
			# IA quiere el Truco del jugador. Jugador (que cantó) juega carta.
			turno_actual = QuiJuega.JUGADOR
		elif canto_actual_jugador == "RETRUCO":
			# IA quiere el Retruco del jugador. Jugador (que cantó) juega.
			turno_actual = QuiJuega.JUGADOR
		elif canto_actual_jugador == "VALE_CUATRO":
			# IA quiere el Vale Cuatro. Jugador (que cantó) juega.
			turno_actual = QuiJuega.JUGADOR
		
		var canto_previo_jugador_temp = canto_actual_jugador # Guardar antes de limpiar
		canto_actual_jugador = null
		actualizar_visibilidad_botones()
		
		# Si la IA quiso un canto de Truco y ahora es turno del jugador, se espera acción del jugador.
		# Si la IA quiso un Envido/Flor y es su turno, IA actúa.
		if turno_actual == QuiJuega.IA: 
			print("IA quiso Envido/Flor. Turno de la IA.")
			await get_tree().create_timer(0.5).timeout
			if not self: return
			ia_decide_accion()
		elif turno_actual == QuiJuega.JUGADOR:
			print("IA quiso %s. Turno del jugador." % canto_previo_jugador_temp)
			# No se llama a ia_decide_accion(), se espera acción del jugador.


	elif decision_ia == "NO_QUIERO" or decision_ia == "NO_TENGO_FLOR":
		print("IA RESPONDE: NO QUIERO al ", canto_actual_jugador)
		if puntos_a_ganar_jugador_si_no_quiere_ia > 0:
			print("Jugador suma %d puntos por el NO QUIERO de la IA al %s" % [puntos_a_ganar_jugador_si_no_quiere_ia, canto_actual_jugador])
			puntos_chico_jugador += puntos_a_ganar_jugador_si_no_quiere_ia
			actualizar_hud_puntos()

		if canto_actual_jugador and ("ENVIDO" in canto_actual_jugador or "FLOR" in canto_actual_jugador) :
			envido_cantado_en_ronda_de_mesa = true 
			if "FLOR" in canto_actual_jugador: flor_cantada_por_jugador = true
		
		var era_canto_de_truco_rechazado_por_ia = canto_actual_jugador in ["TRUCO", "RETRUCO", "VALE_CUATRO"]
		var _canto_previo_jugador = canto_actual_jugador 
		canto_actual_jugador = null
		actualizar_visibilidad_botones()

		if era_canto_de_truco_rechazado_por_ia:
			finalizar_ronda_de_reparto_por_canto_no_querido()
		else: # Envido/Flor no querido por IA. Jugador (que cantó) puede jugar carta o cantar truco.
			turno_actual = QuiJuega.JUGADOR
			print("Envido/Flor no querido por IA. Turno del jugador para jugar o cantar truco.")
			
	elif decision_ia == "RETRUCO_IA" or decision_ia == "VALE_CUATRO_IA" or decision_ia == "CONTRAFLOR_IA": 
		print("IA CANTA DE VUELTA: ", decision_ia)
		if decision_ia == "RETRUCO_IA": truco_estado = 2
		elif decision_ia == "VALE_CUATRO_IA": truco_estado = 3
		elif decision_ia == "CONTRAFLOR_IA": 
			flor_cantada_por_ia = true 
			envido_cantado_en_ronda_de_mesa = true 
		
		canto_actual_ia = decision_ia 
		esperando_respuesta_de_jugador = true 
		canto_actual_jugador = null
		turno_actual = QuiJuega.NADIE 
		actualizar_visibilidad_botones()
	
	elif decision_ia == "QUIERO_FLOR_AJENA": 
		print("IA RESPONDE: CON FLOR QUIERO (acepta la flor del jugador, porque la suya es peor o no quiere Contraflor)")
		puntos_chico_jugador += 3 # Jugador suma 3 por su flor
		flor_cantada_por_jugador = true 
		flor_cantada_por_ia = true # IA también tenía, pero aceptó la del jugador
		envido_cantado_en_ronda_de_mesa = true
		actualizar_hud_puntos()
		
		canto_actual_jugador = null
		actualizar_visibilidad_botones()
		# Determinar quién juega carta
		if cartas_en_mesa_jugador.is_empty() and cartas_en_mesa_ia.is_empty():
			turno_actual = QuiJuega.JUGADOR if jugador_es_mano_en_ronda_de_reparto else QuiJuega.IA
		else: 
			turno_actual = jugador_que_inicio_mano_de_mesa
		if turno_actual == QuiJuega.IA: await get_tree().create_timer(0.5).timeout; ia_decide_accion()


# --- FUNCIONES AUXILIARES PARA LÓGICA DE JUEGO Y CANTOS ---
func get_poder_truco_carta_logica(carta_data: Dictionary) -> int:
	if not ("valor" in carta_data and "palo" in carta_data):
		print_debug("ERROR: carta_data inválida en get_poder_truco_carta_logica: ", carta_data)
		return 0
	var valor = carta_data["valor"]
	var palo = carta_data["palo"]
	
	if palo == "espada" and valor == 1: return 100 
	if palo == "basto" and valor == 1: return 90  
	if palo == "espada" and valor == 7: return 80  
	if palo == "oro" and valor == 7: return 70    
	if valor == 3: return 60 
	if valor == 2: return 50 
	if (palo == "copa" or palo == "oro") and valor == 1: return 40 
	if valor == 12: return 30 
	if valor == 11: return 28 
	if valor == 10: return 26 
	if (palo == "copa" or palo == "basto") and valor == 7: return 24 
	if valor == 6: return 22 
	if valor == 5: return 20 
	if valor == 4: return 18 
	return 0

func obtener_cartas_mano_logica_jugador() -> Array[Dictionary]:
	var mano_logica: Array[Dictionary] = [] 
	for child in get_children():
		if child is Area2D and child.has_method("get_poder_truco") and child.input_pickable: 
			if "valor" in child and "palo" in child:
				mano_logica.append({"valor": child.valor, "palo": child.palo}) 
			else:
				print_debug("WARN: Carta en mano del jugador no tiene 'valor' o 'palo' definidos: ", child.name)
	return mano_logica

func tiene_flor(cartas_mano_logica: Array[Dictionary]) -> bool:
	if cartas_mano_logica.size() < 3: return false
	if cartas_mano_logica.is_empty(): return false 
	var primer_palo = cartas_mano_logica[0]["palo"]
	for i in range(1, cartas_mano_logica.size()):
		if cartas_mano_logica[i]["palo"] != primer_palo:
			return false
	return true

func calcular_tantos_envido(cartas_mano_logica: Array[Dictionary]) -> int:
	if cartas_mano_logica.size() < 2: return 0 
	
	var valores_numericos: Array[int] = []
	var palos_cartas: Array[String] = []

	for carta_data in cartas_mano_logica:
		var valor_carta = carta_data["valor"]
		var valor_para_envido = 0
		if valor_carta >= 1 and valor_carta <= 7: # Cartas del 1 al 7 suman su valor
			valor_para_envido = valor_carta
		# Sota (10), Caballo (11), Rey (12) valen 0 para el envido.
		
		valores_numericos.append(valor_para_envido)
		palos_cartas.append(carta_data["palo"])

	var max_tantos = 0

	# Caso 1: Dos o tres cartas del mismo palo
	var palos_contados = {}
	for p in palos_cartas:
		if not palos_contados.has(p):
			palos_contados[p] = 0
		palos_contados[p] += 1

	for palo_evaluado in palos_contados:
		if palos_contados[palo_evaluado] >= 2: # Si hay al menos dos cartas de este palo
			var valores_del_palo: Array[int] = []
			for i in range(cartas_mano_logica.size()):
				if palos_cartas[i] == palo_evaluado:
					valores_del_palo.append(valores_numericos[i])
			
			valores_del_palo.sort() # Ordenar para tomar las más altas si hay 3
			var tantos_este_palo = 20
			if valores_del_palo.size() == 2:
				tantos_este_palo += valores_del_palo[0] + valores_del_palo[1]
			elif valores_del_palo.size() == 3: # Tomar las dos más altas
				tantos_este_palo += valores_del_palo[1] + valores_del_palo[2]
			
			if tantos_este_palo > max_tantos:
				max_tantos = tantos_este_palo
	
	# Caso 2: Si no hay dos del mismo palo (max_tantos sigue en 0), el tanto es la carta más alta (no figura)
	if max_tantos == 0:
		for val in valores_numericos:
			if val > max_tantos:
				max_tantos = val
				
	return max_tantos

func calcular_valor_flor(cartas_mano_logica: Array[Dictionary]) -> int:
	if not tiene_flor(cartas_mano_logica): return 0 
	var suma_valores = 0
	for carta_data in cartas_mano_logica:
		var valor_carta = carta_data["valor"]
		if valor_carta >=1 && valor_carta <= 7: 
			suma_valores += valor_carta
	return 20 + suma_valores


func resolver_envido_querido_por_jugador(): 
	print("Resolviendo Envido/Real/Falta querido por el Jugador (IA cantó)...")
	var tantos_jugador = calcular_tantos_envido(obtener_cartas_mano_logica_jugador())
	var tantos_ia = calcular_tantos_envido(mano_logica_ia)
	print("Tantos Jugador: ", tantos_jugador, " Tantos IA: ", tantos_ia)
	
	var puntos_en_juego = 0
	match canto_actual_ia: 
		"ENVIDO_IA": puntos_en_juego = 2
		"REAL_ENVIDO_IA": puntos_en_juego = 3
		"FALTA_ENVIDO_IA": 
			var puntos_del_que_va_ganando = max(puntos_chico_jugador, puntos_chico_ia)
			puntos_en_juego = PUNTOS_PARA_GANAR_CHICO - puntos_del_que_va_ganando
			if puntos_en_juego <=0 : puntos_en_juego = PUNTOS_PARA_GANAR_CHICO # Si ya ganó, se juega el chico entero.

	if tantos_jugador > tantos_ia:
		print("Jugador gana el envido.")
		puntos_chico_jugador += puntos_en_juego
	elif tantos_ia > tantos_jugador:
		print("IA gana el envido.")
		puntos_chico_ia += puntos_en_juego
	else: 
		print("Empate de envido. Gana el mano de la ronda de reparto.")
		if jugador_es_mano_en_ronda_de_reparto: puntos_chico_jugador += puntos_en_juego
		else: puntos_chico_ia += puntos_en_juego
	actualizar_hud_puntos()
	verificar_fin_de_partida_completa() # El envido puede terminar el chico

func resolver_flor_querida_por_jugador(): 
	print("IA cantó FLOR, jugador aceptó (o no pudo contraflorar). IA suma 3 puntos.")
	puntos_chico_ia += 3 
	flor_cantada_por_ia = true
	envido_cantado_en_ronda_de_mesa = true 
	actualizar_hud_puntos()
	verificar_fin_de_partida_completa()

func resolver_contraflor_querida_por_jugador(): 
	print("Resolviendo Contraflor querida por el Jugador (IA cantó Contraflor)...")
	var valor_flor_jugador = calcular_valor_flor(obtener_cartas_mano_logica_jugador())
	var valor_flor_ia = calcular_valor_flor(mano_logica_ia)
	print("Valor Flor Jugador: ", valor_flor_jugador, " Valor Flor IA: ", valor_flor_ia)
	
	var puntos_en_juego = 6 # Flor (3) + Contraflor (3)

	if valor_flor_jugador > valor_flor_ia:
		print("Jugador gana la Contraflor.")
		puntos_chico_jugador += puntos_en_juego
	elif valor_flor_ia > valor_flor_jugador:
		print("IA gana la Contraflor.")
		puntos_chico_ia += puntos_en_juego
	else: 
		print("Empate de Contraflor. Gana el mano de la ronda de reparto.")
		if jugador_es_mano_en_ronda_de_reparto: puntos_chico_jugador += puntos_en_juego
		else: puntos_chico_ia += puntos_en_juego
	actualizar_hud_puntos()
	verificar_fin_de_partida_completa()


func resolver_envido_querido_por_ia(): 
	print("Resolviendo Envido/Real/Falta querido por la IA (Jugador cantó)...")
	var tantos_jugador = calcular_tantos_envido(obtener_cartas_mano_logica_jugador())
	var tantos_ia = calcular_tantos_envido(mano_logica_ia)
	print("Tantos Jugador: ", tantos_jugador, " Tantos IA: ", tantos_ia)

	var puntos_en_juego = 0
	match canto_actual_jugador: 
		"ENVIDO": puntos_en_juego = 2
		"REAL_ENVIDO": puntos_en_juego = 3
		"FALTA_ENVIDO": 
			var puntos_del_que_va_ganando = max(puntos_chico_jugador, puntos_chico_ia)
			puntos_en_juego = PUNTOS_PARA_GANAR_CHICO - puntos_del_que_va_ganando
			if puntos_en_juego <=0 : puntos_en_juego = PUNTOS_PARA_GANAR_CHICO

	if tantos_jugador > tantos_ia:
		print("Jugador gana el envido.")
		puntos_chico_jugador += puntos_en_juego
	elif tantos_ia > tantos_jugador:
		print("IA gana el envido.")
		puntos_chico_ia += puntos_en_juego
	else: 
		print("Empate de envido. Gana el mano de la ronda de reparto.")
		if jugador_es_mano_en_ronda_de_reparto: puntos_chico_jugador += puntos_en_juego
		else: puntos_chico_ia += puntos_en_juego
	actualizar_hud_puntos()
	verificar_fin_de_partida_completa()

func resolver_flor_querida_por_ia(): 
	print("Jugador cantó FLOR, IA aceptó (o no pudo contraflorar). Jugador suma 3 puntos.")
	puntos_chico_jugador += 3
	flor_cantada_por_jugador = true
	envido_cantado_en_ronda_de_mesa = true
	actualizar_hud_puntos()
	verificar_fin_de_partida_completa()

func tiene_cartas_para_vale_cuatro(cartas_mano_logica: Array[Dictionary]) -> bool:
	for carta in cartas_mano_logica:
		if (carta["palo"] == "espada" and carta["valor"] == 1) or \
		   (carta["palo"] == "basto" and carta["valor"] == 1):
			return true
	return false
