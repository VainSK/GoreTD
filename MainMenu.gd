extends Control

@onready var new_game_button = $VBoxContainer/NewGame
@onready var settings_button = $VBoxContainer/Settings
@onready var exit_button = $VBoxContainer/Exit
@onready var settings_window = $SettingsWindow
@onready var music_slider = $SettingsWindow/VBoxContainer/MusicVolume
@onready var effects_slider = $SettingsWindow/VBoxContainer/EffectsVolume
@onready var menu_slider = $SettingsWindow/VBoxContainer/MenuVolume
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
	
	# Connect volume sliders
	if music_slider:
		music_slider.value_changed.connect(_on_music_slider_changed)
	if effects_slider:
		effects_slider.value_changed.connect(_on_effects_slider_changed)
	if menu_slider:
		menu_slider.value_changed.connect(_on_menu_slider_changed)
	
	load_settings()
	_init_sliders()
	
	# Center the settings window
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

func _on_resized():
	if settings_window:
		var window_size = settings_window.size as Vector2
		var viewport_size = get_viewport().get_visible_rect().size
		settings_window.position = (viewport_size - window_size) / 2

# --- VOLUME SLIDER FUNCTIONALITY BELOW ---

func _on_music_slider_changed(value):
	var bus_index = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	save_settings()

func _on_effects_slider_changed(value):
	var bus_index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	save_settings()

func _on_menu_slider_changed(value):
	var bus_index = AudioServer.get_bus_index("Menu")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	save_settings()

# Logarithmic mapping for natural volume feel
func linear_to_db(value):
	if value <= 0.001:
		return -80.0
	return 40.0 * log(value) / log(10)  # -80dB at 0.01, 0dB at 1, much smoother


func db_to_linear(db):
	if db <= -80.0:
		return 0.0
	return pow(10, db / 20.0)

func _init_sliders():
	if music_slider:
		var db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
		music_slider.value = db_to_linear(db)
	if effects_slider:
		var db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
		effects_slider.value = db_to_linear(db)
	if menu_slider:
		var db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Menu"))
		menu_slider.value = db_to_linear(db)

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "effects_volume", effects_slider.value)
	config.set_value("audio", "menu_volume", menu_slider.value)
	config.save("user://settings.cfg")

func load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		if music_slider:
			music_slider.value = config.get_value("audio", "music_volume", 1.0)
		if effects_slider:
			effects_slider.value = config.get_value("audio", "effects_volume", 1.0)
		if menu_slider:
			menu_slider.value = config.get_value("audio", "menu_volume", 1.0)
