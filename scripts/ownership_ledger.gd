extends Node
class_name OwnershipLedger

signal receipt_issued(document: Dictionary)
signal ledger_notice(message: String)

const CATALOG := {
	"لباس رسمی": 600,
	"لباس ورزشی": 350,
	"خانه کوچک": 5000,
	"خودروی شهری": 7500
}
var balances: Dictionary = {1: 10000}
var documents: Dictionary = {}
var next_document_number := 1

func _ready() -> void:
	_load_ledger()

func is_owner_peer(peer_id: int) -> bool:
	return peer_id == 1

func has_owner_access(area: String, peer_id: int) -> bool:
	if area in ["creator", "military_command", "intelligence", "owner_settings", "private_records"]:
		return is_owner_peer(peer_id)
	return true

func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _local_peer_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

func request_purchase(item_id: String) -> void:
	if _is_authority():
		_commit_purchase(_local_peer_id(), item_id)
	else:
		rpc_id(1, "rpc_request_purchase", item_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_purchase(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	_commit_purchase(multiplayer.get_remote_sender_id(), item_id)

func _commit_purchase(peer_id: int, item_id: String) -> void:
	if not CATALOG.has(item_id):
		_send_notice(peer_id, "این کالا در فروشگاه وجود ندارد.")
		return
	var price: int = CATALOG[item_id]
	if int(balances.get(peer_id, 10000 if peer_id == 1 else 0)) < price:
		_send_notice(peer_id, "موجودی کافی نیست.")
		return
	balances[peer_id] = int(balances.get(peer_id, 10000 if peer_id == 1 else 0)) - price
	var doc := {
		"document_id": "LC-DOC-%06d" % next_document_number,
		"item_id": item_id,
		"owner_peer_id": peer_id,
		"owner_name": "بازیکن %d" % peer_id,
		"purchase_price": price,
		"created_unix": int(Time.get_unix_time_from_system()),
		"history": [{"event": "purchase", "from": "SHOP", "to": peer_id, "time": int(Time.get_unix_time_from_system())}],
		"status": "valid"
	}
	next_document_number += 1
	documents[doc.document_id] = doc
	_save_ledger()
	_send_receipt(peer_id, doc)
	ledger_notice.emit("سند مالکیت %s صادر شد." % doc.document_id)

func request_player_transfer(document_id: String, target_peer_id: int) -> void:
	if _is_authority():
		_commit_player_transfer(_local_peer_id(), document_id, target_peer_id)
	else:
		rpc_id(1, "rpc_request_player_transfer", document_id, target_peer_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_player_transfer(document_id: String, target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_commit_player_transfer(multiplayer.get_remote_sender_id(), document_id, target_peer_id)

func _commit_player_transfer(from_peer: int, document_id: String, target_peer: int) -> void:
	if not documents.has(document_id):
		_send_notice(from_peer, "سند مالکیت پیدا نشد.")
		return
	if int(documents[document_id].owner_peer_id) != from_peer:
		_send_notice(from_peer, "این دارایی متعلق به حساب تو نیست.")
		return
	if target_peer == from_peer or (multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().has(target_peer)):
		_send_notice(from_peer, "بازیکن مقصد معتبر یا آنلاین نیست.")
		return
	_transfer_document(document_id, from_peer, target_peer, "player_trade")
	_send_notice(from_peer, "مالکیت با موفقیت به بازیکن %d منتقل شد." % target_peer)

func request_npc_sale(document_id: String, npc_id: String = "NPC-001") -> void:
	if _is_authority():
		_commit_npc_sale(_local_peer_id(), document_id, npc_id)
	else:
		rpc_id(1, "rpc_request_npc_sale", document_id, npc_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_npc_sale(document_id: String, npc_id: String) -> void:
	if not multiplayer.is_server():
		return
	_commit_npc_sale(multiplayer.get_remote_sender_id(), document_id, npc_id)

func _commit_npc_sale(peer_id: int, document_id: String, npc_id: String) -> void:
	if not documents.has(document_id) or int(documents[document_id].owner_peer_id) != peer_id:
		_send_notice(peer_id, "سند معتبر یا مالکیت دارایی تأیید نشد.")
		return
	var item_id: String = str(documents[document_id].item_id)
	var resale_value: int = int(CATALOG.get(item_id, 0) * 0.5)
	balances[peer_id] = int(balances.get(peer_id, 0)) + resale_value
	_transfer_document(document_id, peer_id, -1, "npc_sale:" + npc_id)
	_send_notice(peer_id, "فروش به %s انجام شد؛ %d سکه دریافت کردی." % [npc_id, resale_value])

func _transfer_document(document_id: String, from_peer: int, to_peer: int, event_name: String) -> void:
	var doc: Dictionary = documents[document_id]
	doc.owner_peer_id = to_peer
	doc.owner_name = "NPC" if to_peer == -1 else "بازیکن %d" % to_peer
	doc.history.append({"event": event_name, "from": from_peer, "to": to_peer, "time": int(Time.get_unix_time_from_system())})
	documents[document_id] = doc
	_save_ledger()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc("rpc_sync_document", doc)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_document(doc: Dictionary) -> void:
	documents[str(doc.document_id)] = doc
	receipt_issued.emit(doc)

func _send_receipt(peer_id: int, doc: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id != 1:
		rpc_id(peer_id, "rpc_receive_receipt", doc)
	else:
		receipt_issued.emit(doc)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_receipt(doc: Dictionary) -> void:
	documents[str(doc.document_id)] = doc
	receipt_issued.emit(doc)

func _send_notice(peer_id: int, message: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id != 1:
		rpc_id(peer_id, "rpc_receive_notice", message)
	else:
		ledger_notice.emit(message)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_notice(message: String) -> void:
	ledger_notice.emit(message)

func get_documents_for(peer_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for doc in documents.values():
		if int(doc.owner_peer_id) == peer_id:
			result.append(doc)
	return result

func _save_ledger() -> void:
	if not _is_authority():
		return
	var payload := {"balances": balances, "documents": documents, "next_document_number": next_document_number}
	var file := FileAccess.open("user://ownership_ledger.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func _load_ledger() -> void:
	if not _is_authority() or not FileAccess.file_exists("user://ownership_ledger.json"):
		return
	var file := FileAccess.open("user://ownership_ledger.json", FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		balances = parsed.get("balances", balances)
		documents = parsed.get("documents", documents)
		next_document_number = int(parsed.get("next_document_number", next_document_number))
