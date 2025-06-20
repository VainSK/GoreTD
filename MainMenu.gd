extends Control

@onready var new_game_button = $VBoxContainer/NewGame
@onready var settings_button = $VBoxContainer/Settings
@onready var exit_button = $VBoxContainer/Exit
@onready var settings_window = $SettingsWindow
@onready var music_slider = $SettingsWindow/VBoxContainer/MusicVolumeSlider
@onready var effects_slider = $SettingsWindow/VBoxContainer/EffectsVolumeSlider
@onready var hover_sound = $ButtonHover
@onready var click_sound = $ButtonClick
@onready var mute_button = $MuteButton

var is_muted = false
var stored_master_volume = 0.0

func _ready():
	# Button actions
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	
	# Mute button
	if mute_button:
		mute_button.pressed.connect(_on_mute_button_pressed)
		update_mute_button_icon()
		mute_button.mouse_entered.connect(func(): play_hover_sound())
	
	# Sound for menu buttons
	setup_button_sounds()
	
	# Center the settings window (this is harmless)
	await get_tree().process_frame
	if settings_window:
		var window_size = settings_window.size as Vector2
		var viewport_size = get_viewport().get_visible_rect().size
		settings_window.position = (viewport_size - window_size) / 2

func setup_button_sounds():
	var vbox = $VBoxContainer
	for btn in vbox.get_children():
		if btn is BaseButton:
			btn.pressed.connect(func(): play_click_sound())
			btn.mouse_entered.connect(func(): play_hover_sound())

func play_click_sound():
	if not is_muted and click_sound and click_sound.stream:
		click_sound.stop()
		click_sound.play()

func play_hover_sound():
	if not is_muted and hover_sound and hover_sound.stream:
		hover_sound.stop()
		hover_sound.play()

func _on_new_game_pressed():
	play_click_sound()
	get_tree().change_scene_to_file("res://Game.tscn")

func _on_settings_pressed():
	play_click_sound()
	settings_window.visible = true

func _on_exit_pressed():
	play_click_sound()
	get_tree().quit()

func _on_settings_window_close_requested():
	settings_window.hide()

func _on_mute_button_pressed():
	toggle_mute()
	if not is_muted:
		play_click_sound()

func toggle_mute():
	is_muted = !is_muted
	var master_bus_index = AudioServer.get_bus_index("Master")
	if is_muted:
		stored_master_volume = AudioServer.get_bus_volume_db(master_bus_index)
		AudioServer.set_bus_volume_db(master_bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(master_bus_index, stored_master_volume)
	update_mute_button_icon()

func update_mute_button_icon():
	if not mute_button:
		return
	if is_muted:
		if ResourceLoader.exists("res://assets/MuteOn.png"):
			mute_button.texture_normal = load("res://assets/MuteOn.png")
	else:
		if ResourceLoader.exists("res://assets/MuteOff.png"):
			mute_button.texture_normal = load("res://assets/MuteOff.png")
