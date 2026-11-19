extends Node

signal status_changed(message: String)

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const GAME_PORT := 7777
const MAX_PLAYERS := 2
var local_player: CharacterBody3D
var remote_players: Dictionary = {}
var sync_clock := 0.0
var connected := false
var upnp: UPNP
var upnp_mapped := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_build_network_panel()

func set_local_player(player: CharacterBody3D) -> void:
	local_player = player

func _exit_tree() -> void:
	if upnp and upnp_mapped:
		upnp.delete_port_mapping(GAME_PORT, "UDP")

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(GAME_PORT, MAX_PLAYERS - 1)
	if error != OK:
		status_changed.emit("ساخت اتاق ناموفق بود: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	connected = true
	var network_hint := "برای اتصال دوستت، آدرس عمومی و UDP پورت 7777 لازم است."
	upnp = UPNP.new()
	var discover_result := upnp.discover(1200, 2)
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		var map_result := upnp.add_port_mapping(GAME_PORT, GAME_PORT, "LIFE CITY", "UDP")
		if map_result == UPNP.UPNP_RESULT_SUCCESS:
			upnp_mapped = true
			var external_ip := upnp.query_external_address()
			network_hint = "آدرس میزبان: %s:%d | این آدرس را برای دوستت بفرست." % [external_ip, GAME_PORT]
		else:
			network_hint = "UPnP پیدا شد اما بازکردن پورت ناموفق بود؛ UDP 7777 را دستی باز کن."
	else:
		network_hint = "روتر UPnP پیدا نشد؛ UDP 7777 را دستی باز کن. اینترنت موبایل با CGNAT ممکن است اتصال مستقیم را مسدود کند."
	status_changed.emit("اتاق ساخته شد؛ شناسه میزبان: 1. " + network_hint)

func join_game(address: String) -> void:
	if address.strip_edges().is_empty():
		status_changed.emit("آدرس میزبان را وارد کن.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), GAME_PORT)
	if error != OK:
		status_changed.emit("اتصال شروع نشد: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	status_changed.emit("در حال اتصال به میزبان...")

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	status_changed.emit("بازیکن جدید متصل شد؛ شناسه بازیکن: %d" % peer_id)
	var ledger := get_parent().get_node_or_null("OwnershipLedger")
	if ledger:
		ledger.register_online_player(peer_id)
		ledger.send_snapshot(peer_id)
		ledger.send_permission_snapshot(peer_id)
		ledger.send_prison_status(peer_id)
	var services := get_parent().get_node_or_null("LifeCityServices")
	if services:
		for role_peer_id in services.roles.keys():
			services.rpc_id(peer_id, "sync_role", int(role_peer_id), str(services.roles[role_peer_id]))
	_spawn_remote(peer_id)
	rpc("spawn_remote", peer_id)
	rpc_id(peer_id, "spawn_remote", 1)
	for existing_id in remote_players.keys():
		rpc_id(peer_id, "spawn_remote", int(existing_id))

func _on_connected_to_server() -> void:
	connected = true
	status_changed.emit("به اتاق متصل شدی؛ شناسه بازیکن تو: %d" % multiplayer.get_unique_id())
	_spawn_remote(1)
	for peer_id in multiplayer.get_peers():
		_spawn_remote(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_remove_remote(peer_id)
	rpc("remove_remote", peer_id)

func _on_connection_failed() -> void:
	connected = false
	status_changed.emit("اتصال ناموفق بود. آدرس، اینترنت و پورت میزبان را بررسی کنید.")

func _on_server_disconnected() -> void:
	connected = false
	status_changed.emit("ارتباط با میزبان قطع شد.")

func _spawn_remote(peer_id: int) -> void:
	if local_player == null or peer_id == multiplayer.get_unique_id() or remote_players.has(peer_id):
		return
	var avatar := CharacterBody3D.new()
	avatar.name = "RemotePlayer_%d" % peer_id
	avatar.set_script(PLAYER_SCRIPT)
	avatar.configure_remote()
	var spawn_position := local_player.global_position + Vector3(2.0, 0.0, 0.0)
	avatar.target_position = spawn_position
	# global_position is only valid after the node enters the scene tree.
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
	layer.name = "OnlineLobbyUI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -340
	panel.offset_right = -12
	# Keep the lobby below the top-right graphics button so the two controls never overlap.
	panel.offset_top = 78
	panel.offset_bottom = 300
	layer.add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var title := Label.new()
	title.text = "LIFE CITY | بازی دونفره آنلاین"
	layout.add_child(title)
	var address := LineEdit.new()
	address.name = "HostAddress"
	address.placeholder_text = "IP عمومی میزبان (مثلاً 203.0.113.10)"
	address.text = ""
	layout.add_child(address)
	var host := Button.new()
	host.text = "ساخت اتاق"
	host.pressed.connect(host_game)
	layout.add_child(host)
	var join := Button.new()
	join.text = "ورود به اتاق"
	join.pressed.connect(func(): join_game(address.text))
	layout.add_child(join)
	var status := Label.new()
	status.name = "NetworkStatus"
	status.text = "برای اتصال از اینترنت دیگر، IP عمومی میزبان و دسترسی UDP پورت 7777 لازم است؛ 127.0.0.1 فقط روی همان دستگاه کار می‌کند."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
	status_changed.connect(func(message: String): status.text = message)
