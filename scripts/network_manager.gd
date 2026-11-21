extends Node

signal status_changed(message: String)

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const GAME_PORT := 7777
const MAX_PLAYERS := 2
var local_player: CharacterBody3D
var remote_players: Dictionary = {}
var sync_clock := 0.0
var connected := false
var address_input: LineEdit
var status_label: Label
var host_button: Button
var join_button: Button

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_build_network_panel()

func set_local_player(player: CharacterBody3D) -> void:
	local_player = player

func host_game() -> void:
	_close_existing_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(GAME_PORT, MAX_PLAYERS - 1)
	if error != OK:
		status_changed.emit("ساخت اتاق وای‌فای ناموفق بود: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	connected = true
	var addresses := _get_lan_ipv4_addresses()
	if addresses.is_empty():
		status_changed.emit("اتاق ساخته شد، اما IP وای‌فای پیدا نشد. مطمئن شو وای‌فای روشن است.")
	else:
		if address_input:
			address_input.text = addresses[0]
		status_changed.emit("میزبان آماده است. دوستت باید به همین وای‌فای وصل شود و این IP را وارد کند: %s:%d" % [", ".join(addresses), GAME_PORT])
	if host_button:
		host_button.disabled = true
	if join_button:
		join_button.disabled = false

func join_game(address: String) -> void:
	var host_address := address.strip_edges()
	if host_address.is_empty():
		status_changed.emit("IP گوشی میزبان را وارد کن؛ هر دو گوشی باید به یک وای‌فای وصل باشند.")
		return
	_close_existing_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host_address, GAME_PORT)
	if error != OK:
		status_changed.emit("شروع اتصال ناموفق بود: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	status_changed.emit("در حال اتصال به میزبان %s:%d در شبکه محلی..." % [host_address, GAME_PORT])
	if host_button:
		host_button.disabled = false
	if join_button:
		join_button.disabled = true

func _close_existing_peer() -> void:
	connected = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	for peer_id in remote_players.keys():
		_remove_remote(int(peer_id))
	if host_button:
		host_button.disabled = false
	if join_button:
		join_button.disabled = false

func _get_lan_ipv4_addresses() -> PackedStringArray:
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	return addresses

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	status_changed.emit("بازیکن دوم به وای‌فای متصل شد؛ شناسه: %d" % peer_id)
	var ledger := get_parent().get_node_or_null("OwnershipLedger")
	if ledger:
		ledger.register_online_player(peer_id)
		ledger.send_snapshot(peer_id)
		ledger.send_permission_snapshot(peer_id)
		ledger.send_prison_status(peer_id)
	var services := get_parent().get_node_or_null("LifeCityServices")
	if services:
		for role_peer_id in services.roles.keys():
			services.rpc_id(peer_id, "sync_role", int(role_peer_id), services._roles_for_peer(int(role_peer_id)))
	_spawn_remote(peer_id)
	rpc("spawn_remote", peer_id)
	rpc_id(peer_id, "spawn_remote", 1)
	for existing_id in remote_players.keys():
		rpc_id(peer_id, "spawn_remote", int(existing_id))

func _on_connected_to_server() -> void:
	connected = true
	status_changed.emit("با موفقیت به بازی میزبان وصل شدی. بازیکن دوم وارد شهر شد.")
	_spawn_remote(1)
	for peer_id in multiplayer.get_peers():
		_spawn_remote(peer_id)
	if host_button:
		host_button.disabled = false
	if join_button:
		join_button.disabled = true

func _on_peer_disconnected(peer_id: int) -> void:
	_remove_remote(peer_id)
	rpc("remove_remote", peer_id)
	status_changed.emit("بازیکن دوم از بازی خارج شد.")
	if host_button:
		host_button.disabled = false
	if join_button:
		join_button.disabled = false

func _on_connection_failed() -> void:
	connected = false
	status_changed.emit("اتصال برقرار نشد. هر دو گوشی را به یک وای‌فای وصل کن و IP میزبان را دوباره بررسی کن.")
	if host_button:
		host_button.disabled = false
	if join_button:
		join_button.disabled = false

func _on_server_disconnected() -> void:
	connected = false
	status_changed.emit("ارتباط با میزبان قطع شد.")
	if host_button:
		host_button.disabled = false
	if join_button:
		join_button.disabled = false

func _spawn_remote(peer_id: int) -> void:
	if local_player == null or peer_id == multiplayer.get_unique_id() or remote_players.has(peer_id):
		return
	var avatar := CharacterBody3D.new()
	avatar.name = "RemotePlayer_%d" % peer_id
	avatar.set_script(PLAYER_SCRIPT)
	avatar.configure_remote()
	var spawn_position := local_player.global_position + Vector3(2.0, 0.0, 0.0)
	avatar.target_position = spawn_position
	get_parent().add_child(avatar)
	avatar.global_position = spawn_position
	remote_players[peer_id] = avatar

func _remove_remote(peer_id: int) -> void:
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)

@rpc("authority", "call_remote", "reliable")
func spawn_remote(peer_id: int) -> void:
	_spawn_remote(peer_id)

@rpc("authority", "call_remote", "reliable")
func remove_remote(peer_id: int) -> void:
	_remove_remote(peer_id)

@rpc("any_peer", "call_remote", "unreliable")
func submit_state(peer_id: int, pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	if remote_players.has(peer_id):
		remote_players[peer_id].set_remote_state(pos, yaw)
	rpc("relay_state", peer_id, pos, yaw)

@rpc("authority", "call_remote", "unreliable")
func relay_state(peer_id: int, pos: Vector3, yaw: float) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	if remote_players.has(peer_id):
		remote_players[peer_id].set_remote_state(pos, yaw)

func _process(delta: float) -> void:
	if not connected or local_player == null or multiplayer.multiplayer_peer == null:
		return
	sync_clock += delta
	if sync_clock < 0.05:
		return
	sync_clock = 0.0
	var peer_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		rpc("relay_state", peer_id, local_player.global_position, local_player.rotation.y)
	else:
		rpc_id(1, "submit_state", peer_id, local_player.global_position, local_player.rotation.y)

func _build_network_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LocalMultiplayerLobbyUI"
	layer.layer = 15
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "WifiLobbyPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -340
	panel.offset_right = -12
	panel.offset_top = 78
	panel.offset_bottom = 330
	layer.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "LIFE CITY | دونفره با وای‌فای"
	layout.add_child(title)
	address_input = LineEdit.new()
	address_input.name = "HostAddress"
	address_input.placeholder_text = "IP گوشی میزبان، مثل 192.168.1.5"
	address_input.text = ""
	layout.add_child(address_input)
	host_button = Button.new()
	host_button.text = "میزبان شو (گوشی اول)"
	host_button.pressed.connect(host_game)
	layout.add_child(host_button)
	join_button = Button.new()
	join_button.text = "اتصال به میزبان (گوشی دوم)"
	join_button.pressed.connect(func(): join_game(address_input.text))
	layout.add_child(join_button)
	status_label = Label.new()
	status_label.name = "NetworkStatus"
	status_label.text = "هر دو گوشی به یک وای‌فای وصل باشند. گوشی اول میزبان شود و IP نمایش‌داده‌شده را به گوشی دوم بدهد."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)
	status_changed.connect(func(message: String): status_label.text = message)
