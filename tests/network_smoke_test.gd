extends SceneTree

const NETWORK_SCRIPT = preload("res://scripts/network_manager.gd")
const GAME_PORT := 7777
const TEST_TIMEOUT := 12.0

var manager: Node
var local_player: CharacterBody3D

func _initialize() -> void:
	call_deferred("_run")

func _make_network() -> void:
	local_player = CharacterBody3D.new()
	local_player.name = "LocalTestPlayer"
	root.add_child(local_player)
	manager = Node.new()
	manager.name = "NetworkManager"
	manager.set_script(NETWORK_SCRIPT)
	root.add_child(manager)
	manager.set_local_player(local_player)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(not args.is_empty(), "Pass server or client as the first user argument")
	_make_network()
	if args[0] == "server":
		await _run_server()
	elif args[0] == "client":
		await _run_client()
	else:
		assert(false, "Unknown network test mode: " + args[0])
	quit(0)

func _run_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, 1)
	assert(err == OK, "ENet server could not start: %s" % err)
	root.get_multiplayer().multiplayer_peer = peer
	manager.connected = true
	print("NETWORK_TEST_SERVER_READY")
	var elapsed := 0.0
	while elapsed < TEST_TIMEOUT and root.get_multiplayer().get_peers().is_empty():
		await create_timer(0.1).timeout
		elapsed += 0.1
	assert(not root.get_multiplayer().get_peers().is_empty(), "No client peer connected to host")
	var client_peer_id := int(root.get_multiplayer().get_peers()[0])
	elapsed = 0.0
	while elapsed < TEST_TIMEOUT and not manager.remote_players.has(client_peer_id):
		await create_timer(0.1).timeout
		elapsed += 0.1
	assert(manager.remote_players.has(client_peer_id), "Client %d did not spawn on host; peers=%s remote_players=%s" % [client_peer_id, str(root.get_multiplayer().get_peers()), str(manager.remote_players.keys())])
	await create_timer(0.8).timeout
	var remote_client: CharacterBody3D = manager.remote_players[client_peer_id]
	var relayed_client_position: Vector3 = remote_client.get("target_position")
	assert(relayed_client_position.distance_to(Vector3(10, 0, 0)) < 1.0, "Client movement was not relayed to host: %s" % str(relayed_client_position))
	local_player.global_position = Vector3(20, 0, 0)
	await create_timer(1.0).timeout
	print("NETWORK_SMOKE_TEST_SERVER_PASS")

func _run_client() -> void:
	manager.join_game("127.0.0.1")
	var elapsed := 0.0
	while elapsed < TEST_TIMEOUT and not manager.connected:
		await create_timer(0.1).timeout
		elapsed += 0.1
	assert(manager.connected, "Client failed to connect to local ENet host")
	elapsed = 0.0
	while elapsed < TEST_TIMEOUT and not manager.remote_players.has(1):
		await create_timer(0.1).timeout
		elapsed += 0.1
	assert(manager.remote_players.has(1), "Host avatar was not spawned on client; remote_players=%s" % str(manager.remote_players.keys()))
	local_player.global_position = Vector3(10, 0, 0)
	elapsed = 0.0
	var observed_host_movement := false
	while elapsed < TEST_TIMEOUT:
		if manager.remote_players.has(1):
			var host_avatar: CharacterBody3D = manager.remote_players[1]
			if host_avatar.global_position.distance_to(Vector3(20, 0, 0)) < 1.5:
				observed_host_movement = true
				break
		await create_timer(0.1).timeout
		elapsed += 0.1
	assert(observed_host_movement, "Host movement was not relayed to client; remote_players=%s" % str(manager.remote_players.keys()))
	print("NETWORK_SMOKE_TEST_CLIENT_PASS")
