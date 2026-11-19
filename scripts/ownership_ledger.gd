extends Node
class_name OwnershipLedger

signal receipt_issued(document: Dictionary)
signal ledger_notice(message: String)
signal balance_changed(peer_id: int, balance: int)

const CATALOG := {
	"لباس رسمی": 600,
	"لباس ورزشی": 350,
	"خانه کوچک": 5000,
	"خودروی شهری": 7500,
	"گوشی هوشمند": 4500, "گوشی پرچمدار": 9000,
	"کامپیوتر گیمینگ": 18000, "مانیتور گیمینگ": 4200,
	"کنسول بازی": 7000, "دسته بازی": 1200,
	"مبل": 1800, "تخت خواب": 2400, "یخچال": 3200,
	"تلویزیون": 2800, "میز ناهارخوری": 1500, "کمد": 1100,
	"آپارتمان اقتصادی": 22000, "آپارتمان شهری": 48000,
	"ویلای ساحلی": 95000, "پنت‌هاوس": 140000,
	"دنا": 14000, "پژو ۲۰۷": 16000, "لندکروزر": 95000,
	"لکسوس RX": 78000, "فراری": 240000, "لامبورگینی": 320000,
	"تیبا": 8000, "تیبا ۲": 9000, "پراید": 6000
}
const NPC_IDS := ["NPC-001", "NPC-002"]
var balances: Dictionary = {1: 10000}
var documents: Dictionary = {}
var next_document_number := 1
var cash_transactions: Dictionary = {}

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

func _valid_npc(npc_id: String) -> bool:
	return NPC_IDS.has(npc_id)

func _new_document(item_id: String, owner_peer: int, price: int, event_name: String, source: String) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var doc := {
		"document_id": "LC-DOC-%06d" % next_document_number,
		"item_id": item_id,
		"owner_peer_id": owner_peer,
		"owner_name": "بازیکن %d" % owner_peer,
		"purchase_price": price,
		"created_unix": now,
		"history": [{"event": event_name, "from": source, "to": owner_peer, "time": now}],
		"status": "valid"
	}
	next_document_number += 1
	return doc

func request_adjust_balance(amount: int, reason: String = "adjustment") -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		adjust_balance(peer_id, amount, reason)
	else:
		rpc_id(1, "rpc_request_adjust_balance", amount, reason)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_adjust_balance(amount: int, reason: String) -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		adjust_balance(sender, amount, reason)

func adjust_balance(peer_id: int, amount: int, reason: String = "adjustment") -> bool:
	if not _is_authority():
		return false
	var current := get_balance(peer_id)
	if current + amount < 0:
		return false
	balances[peer_id] = current + amount
	var transaction_id := "LC-ADJ-%06d" % next_document_number
	next_document_number += 1
	cash_transactions[transaction_id] = {"transaction_id": transaction_id, "peer_id": peer_id, "amount": amount, "reason": reason, "time": int(Time.get_unix_time_from_system()), "status": "completed"}
	_save_ledger()
	balance_changed.emit(peer_id, get_balance(peer_id))
	_send_balance(peer_id)
	return true

func owner_withdraw(target_peer_id: int, amount: int) -> bool:
	if not _is_authority() or _local_peer_id() != 1 or target_peer_id <= 0 or amount <= 0:
		return false
	if get_balance(target_peer_id) < amount:
		return false
	return adjust_balance(target_peer_id, -amount, "creator_withdrawal_by_peer_1")

func issue_custom_document(item_id: String, owner_peer_id: int, price: int) -> void:
	if not _is_authority() or item_id.is_empty() or owner_peer_id <= 0:
		return
	var doc := _new_document(item_id, owner_peer_id, price, "purchase", "CITY_SERVICES")
	documents[doc.document_id] = doc
	_save_ledger()
	receipt_issued.emit(doc)

func request_purchase(item_id: String) -> void:
	if _is_authority():
		_commit_purchase(_local_peer_id(), item_id)
	else:
		rpc_id(1, "rpc_request_purchase", item_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_purchase(item_id: String) -> void:
	if multiplayer.is_server():
		_commit_purchase(multiplayer.get_remote_sender_id(), item_id)

func _commit_purchase(peer_id: int, item_id: String) -> void:
	if not CATALOG.has(item_id):
		_send_notice(peer_id, "این کالا در فروشگاه وجود ندارد.")
		return
	var price: int = CATALOG[item_id]
	var balance := int(balances.get(peer_id, 0))
	if balance < price:
		_send_notice(peer_id, "موجودی کافی نیست.")
		return
	balances[peer_id] = balance - price
	balance_changed.emit(peer_id, get_balance(peer_id))
	var doc := _new_document(item_id, peer_id, price, "purchase", "SHOP")
	documents[doc.document_id] = doc
	_save_ledger()
	_send_receipt(peer_id, doc)
	_send_notice(peer_id, "سند مالکیت %s صادر شد." % doc.document_id)

func request_player_transfer(document_id: String, target_peer_id: int) -> void:
	if _is_authority():
		_commit_player_transfer(_local_peer_id(), document_id, target_peer_id)
	else:
		rpc_id(1, "rpc_request_player_transfer", document_id, target_peer_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_player_transfer(document_id: String, target_peer_id: int) -> void:
	if multiplayer.is_server():
		_commit_player_transfer(multiplayer.get_remote_sender_id(), document_id, target_peer_id)

func _commit_player_transfer(from_peer: int, document_id: String, target_peer: int) -> void:
	if not documents.has(document_id):
		_send_notice(from_peer, "سند مالکیت پیدا نشد.")
		return
	if int(documents[document_id].get("owner_peer_id", -999)) != from_peer:
		_send_notice(from_peer, "این دارایی متعلق به حساب تو نیست.")
		return
	if target_peer <= 0 or target_peer == from_peer:
		_send_notice(from_peer, "شناسه بازیکن مقصد معتبر نیست.")
		return
	if multiplayer.has_multiplayer_peer() and target_peer != 1 and not multiplayer.get_peers().has(target_peer):
		_send_notice(from_peer, "بازیکن مقصد آنلاین نیست.")
		return
	_transfer_document(document_id, from_peer, target_peer, "player_trade", "بازیکن %d" % target_peer)
	_send_notice(from_peer, "مالکیت با موفقیت به بازیکن %d منتقل شد." % target_peer)
	_send_notice(target_peer, "یک دارایی با سند %s به تو منتقل شد." % document_id)

func request_npc_purchase(item_id: String, npc_id: String = "NPC-001") -> void:
	if _is_authority():
		_commit_npc_purchase(_local_peer_id(), item_id, npc_id)
	else:
		rpc_id(1, "rpc_request_npc_purchase", item_id, npc_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_npc_purchase(item_id: String, npc_id: String) -> void:
	if multiplayer.is_server():
		_commit_npc_purchase(multiplayer.get_remote_sender_id(), item_id, npc_id)

func _commit_npc_purchase(peer_id: int, item_id: String, npc_id: String) -> void:
	if not _valid_npc(npc_id) or not CATALOG.has(item_id):
		_send_notice(peer_id, "فروشنده یا کالا معتبر نیست.")
		return
	var price: int = CATALOG[item_id]
	var balance := int(balances.get(peer_id, 10000))
	if balance < price:
		_send_notice(peer_id, "موجودی کافی نیست.")
		return
	balances[peer_id] = balance - price
	var doc := _new_document(item_id, peer_id, price, "npc_purchase", npc_id)
	documents[doc.document_id] = doc
	_save_ledger()
	_send_receipt(peer_id, doc)
	_send_notice(peer_id, "خرید از %s انجام شد و سند مالکیت صادر شد." % npc_id)

func simulate_npc_to_npc_trade(document_id: String, buyer_npc_id: String) -> bool:
	if not _is_authority() or not documents.has(document_id) or not _valid_npc(buyer_npc_id):
		return false
	if int(documents[document_id].get("owner_peer_id", 0)) != -1:
		return false
	_transfer_document(document_id, -1, -2, "npc_to_npc:" + buyer_npc_id, buyer_npc_id)
	return true

func request_npc_sale(document_id: String, npc_id: String = "NPC-001") -> void:
	if _is_authority():
		_commit_npc_sale(_local_peer_id(), document_id, npc_id)
	else:
		rpc_id(1, "rpc_request_npc_sale", document_id, npc_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_npc_sale(document_id: String, npc_id: String) -> void:
	if multiplayer.is_server():
		_commit_npc_sale(multiplayer.get_remote_sender_id(), document_id, npc_id)

func _commit_npc_sale(peer_id: int, document_id: String, npc_id: String) -> void:
	if not _valid_npc(npc_id) or not documents.has(document_id) or int(documents[document_id].get("owner_peer_id", -999)) != peer_id:
		_send_notice(peer_id, "سند معتبر یا مالکیت دارایی تأیید نشد.")
		return
	var item_id := str(documents[document_id].get("item_id", ""))
	if not CATALOG.has(item_id):
		_send_notice(peer_id, "کالای این سند در فهرست معتبر نیست.")
		return
	var resale_value := int(CATALOG[item_id] * 0.5)
	balances[peer_id] = int(balances.get(peer_id, 10000)) + resale_value
	_transfer_document(document_id, peer_id, -1, "npc_sale:" + npc_id, npc_id)
	simulate_npc_to_npc_trade(document_id, "NPC-002" if npc_id == "NPC-001" else "NPC-001")
	_send_balance(peer_id)
	_send_notice(peer_id, "فروش به %s انجام شد؛ %d سکه دریافت کردی." % [npc_id, resale_value])

func _transfer_document(document_id: String, from_peer: int, to_peer: int, event_name: String, new_owner_name: String = "") -> void:
	var doc: Dictionary = documents[document_id].duplicate(true)
	doc["owner_peer_id"] = to_peer
	if not new_owner_name.is_empty():
		doc["owner_name"] = new_owner_name
	elif to_peer == -1 or to_peer == -2:
		doc["owner_name"] = "NPC"
	else:
		doc["owner_name"] = "بازیکن %d" % to_peer
	doc["history"].append({"event": event_name, "from": from_peer, "to": to_peer, "time": int(Time.get_unix_time_from_system())})
	documents[document_id] = doc
	_save_ledger()
	if _is_authority():
		receipt_issued.emit(doc)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if from_peer > 1 and multiplayer.get_peers().has(from_peer):
			rpc_id(from_peer, "rpc_sync_document", doc)
		if to_peer > 1 and to_peer != from_peer and multiplayer.get_peers().has(to_peer):
			rpc_id(to_peer, "rpc_sync_document", doc)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_document(doc: Dictionary) -> void:
	documents[str(doc.get("document_id", ""))] = doc
	receipt_issued.emit(doc)

func request_player_cash_transfer(target_peer_id: int, amount: int) -> void:
	if _is_authority():
		_commit_player_cash_transfer(_local_peer_id(), target_peer_id, amount)
	else:
		rpc_id(1, "rpc_request_player_cash_transfer", target_peer_id, amount)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_player_cash_transfer(target_peer_id: int, amount: int) -> void:
	if multiplayer.is_server():
		_commit_player_cash_transfer(multiplayer.get_remote_sender_id(), target_peer_id, amount)

func _commit_player_cash_transfer(from_peer: int, target_peer: int, amount: int) -> void:
	if amount <= 0 or amount > 1000000000:
		_send_notice(from_peer, "مبلغ انتقال معتبر نیست.")
		return
	if target_peer <= 0 or target_peer == from_peer:
		_send_notice(from_peer, "شناسه مقصد معتبر نیست.")
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if target_peer != 1 and not multiplayer.get_peers().has(target_peer):
			_send_notice(from_peer, "بازیکن مقصد آنلاین نیست.")
			return
	var sender_balance := get_balance(from_peer)
	if sender_balance < amount:
		_send_notice(from_peer, "موجودی برای این انتقال کافی نیست.")
		return
	balances[from_peer] = sender_balance - amount
	balances[target_peer] = get_balance(target_peer) + amount
	balance_changed.emit(from_peer, get_balance(from_peer))
	balance_changed.emit(target_peer, get_balance(target_peer))
	var transaction_id := "LC-CASH-%06d" % next_document_number
	next_document_number += 1
	var transaction := {
		"transaction_id": transaction_id,
		"from_peer": from_peer,
		"to_peer": target_peer,
		"amount": amount,
		"time": int(Time.get_unix_time_from_system()),
		"status": "completed"
	}
	cash_transactions[transaction_id] = transaction
	_save_ledger()
	_send_balance(from_peer)
	_send_balance(target_peer)
	_send_notice(from_peer, "انتقال %d سکه انجام شد؛ رسید %s" % [amount, transaction_id])
	_send_notice(target_peer, "%d سکه از بازیکن %d دریافت کردی؛ رسید %s" % [amount, from_peer, transaction_id])

func get_balance(peer_id: int) -> int:
	return int(balances.get(peer_id, 0))

func _send_balance(peer_id: int) -> void:
	var current_balance := get_balance(peer_id)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id > 1 and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "rpc_receive_balance", current_balance)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_balance(current_balance: int) -> void:
	balances[_local_peer_id()] = current_balance
	balance_changed.emit(_local_peer_id(), current_balance)

func _send_receipt(peer_id: int, doc: Dictionary) -> void:
	_send_balance(peer_id)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id > 1:
		rpc_id(peer_id, "rpc_receive_receipt", doc)
	else:
		receipt_issued.emit(doc)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_receipt(doc: Dictionary) -> void:
	documents[str(doc.get("document_id", ""))] = doc
	receipt_issued.emit(doc)

func _send_notice(peer_id: int, message: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id > 1:
		rpc_id(peer_id, "rpc_receive_notice", message)
	else:
		ledger_notice.emit(message)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_notice(message: String) -> void:
	ledger_notice.emit(message)

func get_document(document_id: String) -> Dictionary:
	return documents.get(document_id, {})

func get_documents_for(peer_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for doc in documents.values():
		if int(doc.get("owner_peer_id", -999)) == peer_id:
			result.append(doc)
	return result

func send_snapshot(peer_id: int) -> void:
	if not _is_authority() or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var private_documents: Dictionary = {}
	for document_id in documents.keys():
		if int(documents[document_id].get("owner_peer_id", -999)) == peer_id:
			private_documents[document_id] = documents[document_id]
	rpc_id(peer_id, "rpc_receive_snapshot", private_documents, get_balance(peer_id), next_document_number)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_snapshot(server_documents: Dictionary, own_balance: int, next_number: int) -> void:
	documents = server_documents.duplicate(true)
	balances[_local_peer_id()] = own_balance
	next_document_number = next_number

func _save_ledger() -> void:
	if not _is_authority():
		return
	var saved_balances: Dictionary = {}
	for peer_key in balances.keys():
		saved_balances[str(peer_key)] = balances[peer_key]
	var payload := {"balances": saved_balances, "documents": documents, "next_document_number": next_document_number, "cash_transactions": cash_transactions}
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
		var saved_balances: Dictionary = parsed.get("balances", {})
		balances.clear()
		for peer_key in saved_balances.keys():
			balances[int(peer_key)] = int(saved_balances[peer_key])
		documents = parsed.get("documents", documents)
		next_document_number = int(parsed.get("next_document_number", next_document_number))
		cash_transactions = parsed.get("cash_transactions", {})
