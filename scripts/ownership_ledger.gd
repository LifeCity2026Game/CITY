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
	"خانه اقتصادی": 18000, "آپارتمان اقتصادی": 22000, "خانه جنوب شهر": 30000,
	"آپارتمان شهری": 48000, "خانه شمال شهر": 65000, "خانه ساحلی": 80000,
	"ویلای ساحلی": 95000, "پنت‌هاوس": 140000,
	"دنا": 14000, "پژو ۲۰۷": 16000, "لندکروزر": 95000,
	"لکسوس RX": 78000, "فراری": 240000, "لامبورگینی": 320000,
	"تیبا": 8000, "تیبا ۲": 9000, "پراید": 6000
}
const NPC_IDS := ["NPC-001", "NPC-002", "NPC-003", "NPC-004", "NPC-005", "NPC-006"]
var balances: Dictionary = {1: 0}
var documents: Dictionary = {}
var next_document_number := 1
var cash_transactions: Dictionary = {}

func _ready() -> void:
	_load_ledger()
	_seed_citizens()

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
		"purchased_by_peer_id": owner_peer,
		"owner_name": "بازیکن %d" % owner_peer,
		"purchase_price": price,
		"created_unix": now,
		"history": [{"event": event_name, "from": source, "to": owner_peer, "time": now}],
		"status": "valid"
	}
	if item_id in ["خانه اقتصادی", "آپارتمان اقتصادی", "خانه جنوب شهر", "آپارتمان شهری", "خانه شمال شهر", "خانه ساحلی", "ویلای ساحلی", "پنت‌هاوس"]:
		var districts := ["مرکز شهر", "شمال شهر", "جنوب شهر", "ساحل"]
		var district: String = str(districts[abs(owner_peer + next_document_number) % districts.size()])
		doc["address"] = "شهر LIFE CITY، محله %s، خیابان اصلی، پلاک %04d" % [district, next_document_number]
	if item_id in ["دنا", "پژو ۲۰۷", "لندکروزر", "لکسوس RX", "فراری", "لامبورگینی", "تیبا", "تیبا ۲", "پراید"]:
		doc["plate"] = "LC-%05d" % next_document_number
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
	var tax := int(ceil(float(price) * 0.10))
	central_bank_treasury += tax
	var doc := _new_document(item_id, peer_id, price, "purchase", "SHOP")
	doc["tax_paid"] = tax
	doc["seller_net"] = price - tax
	documents[doc.document_id] = doc
	_save_ledger()
	_send_receipt(peer_id, doc)
	_send_notice(peer_id, "سند مالکیت %s صادر شد." % doc.document_id)

func request_player_transfer(document_id: String, target_peer_id: int) -> void:
	if _is_authority():
		_create_ownership_offer(_local_peer_id(), document_id, target_peer_id)
	else:
		rpc_id(1, "rpc_request_player_transfer", document_id, target_peer_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_player_transfer(document_id: String, target_peer_id: int) -> void:
	if multiplayer.is_server():
		_create_ownership_offer(multiplayer.get_remote_sender_id(), document_id, target_peer_id)

func request_accept_ownership_transfer(offer_id: String) -> void:
	if _is_authority():
		_accept_ownership_offer(_local_peer_id(), offer_id)
	else:
		rpc_id(1, "rpc_request_accept_ownership_transfer", offer_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_accept_ownership_transfer(offer_id: String) -> void:
	if multiplayer.is_server():
		_accept_ownership_offer(multiplayer.get_remote_sender_id(), offer_id)

func _create_ownership_offer(from_peer: int, document_id: String, target_peer: int) -> void:
	if not documents.has(document_id):
		_send_notice(from_peer, "سند مالکیت پیدا نشد.")
		return
	if int(documents[document_id].get("owner_peer_id", -999)) != from_peer:
		_send_notice(from_peer, "این دارایی متعلق به حساب تو نیست.")
		return
	if target_peer <= 0 or target_peer == from_peer:
		_send_notice(from_peer, "شناسه بازیکن مقصد معتبر نیست.")
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer and target_peer != 1 and not multiplayer.get_peers().has(target_peer):
		_send_notice(from_peer, "بازیکن مقصد آنلاین نیست.")
		return
	var offer_id := "LC-TRF-%06d" % next_document_number
	next_document_number += 1
	ownership_transfer_offers[offer_id] = {"offer_id": offer_id, "document_id": document_id, "from_peer": from_peer, "to_peer": target_peer, "status": "pending", "created_unix": int(Time.get_unix_time_from_system())}
	_save_ledger()
	_send_notice(from_peer, "درخواست انتقال %s برای بازیکن %d فرستاده شد؛ انتقال پس از تأیید او انجام می‌شود. کد: %s" % [document_id, target_peer, offer_id])
	_send_notice(target_peer, "پیشنهاد دریافت سند %s از بازیکن %d رسید. برای قبول، کد %s را وارد کن." % [document_id, from_peer, offer_id])

func _accept_ownership_offer(actor_peer: int, offer_id: String) -> void:
	if not ownership_transfer_offers.has(offer_id):
		_send_notice(actor_peer, "درخواست انتقال پیدا نشد.")
		return
	var offer: Dictionary = ownership_transfer_offers[offer_id]
	if int(offer.get("to_peer", -1)) != actor_peer or str(offer.get("status", "")) != "pending":
		_send_notice(actor_peer, "این پیشنهاد برای تو نیست یا قبلاً تعیین تکلیف شده است.")
		return
	var document_id := str(offer.get("document_id", ""))
	var from_peer := int(offer.get("from_peer", -1))
	if not documents.has(document_id) or int(documents[document_id].get("owner_peer_id", -999)) != from_peer:
		offer["status"] = "invalid"
		ownership_transfer_offers[offer_id] = offer
		_save_ledger()
		_send_notice(actor_peer, "مالکیت سند تغییر کرده و این پیشنهاد دیگر معتبر نیست.")
		return
	offer["status"] = "accepted"
	ownership_transfer_offers[offer_id] = offer
	_transfer_document(document_id, from_peer, actor_peer, "player_trade", "بازیکن %d" % actor_peer)
	_send_notice(from_peer, "انتقال سند %s با تأیید مقصد نهایی شد." % document_id)
	_send_notice(actor_peer, "سند %s به مالکیت تو درآمد و در پنل دارایی‌ها ثبت شد." % document_id)

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
	var tax := int(ceil(float(price) * 0.10))
	central_bank_treasury += tax
	var doc := _new_document(item_id, peer_id, price, "npc_purchase", npc_id)
	doc["tax_paid"] = tax
	doc["seller_net"] = price - tax
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
	var tax := int(ceil(float(resale_value) * 0.10))
	balances[peer_id] = int(balances.get(peer_id, 10000)) + resale_value - tax
	central_bank_treasury += tax
	cash_transactions["NPC-SALE-%06d" % next_document_number] = {"type": "npc_purchase", "buyer_npc": npc_id, "seller_peer": peer_id, "amount": resale_value, "tax_paid": tax, "time": int(Time.get_unix_time_from_system())}
	next_document_number += 1
	_transfer_document(document_id, peer_id, -1, "npc_sale:" + npc_id, npc_id)
	simulate_npc_to_npc_trade(document_id, "NPC-002" if npc_id == "NPC-001" else "NPC-001")
	_send_balance(peer_id)
	_send_notice(peer_id, "فروش به %s انجام شد؛ %d سکه دریافت کردی." % [npc_id, resale_value])

func _transfer_document(document_id: String, from_peer: int, to_peer: int, event_name: String, new_owner_name: String = "") -> void:
	var doc: Dictionary = documents[document_id].duplicate(true)
	doc["previous_owner_peer_id"] = from_peer
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

func send_permission_snapshot(peer_id: int) -> void:
	if not _is_authority() or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	rpc_id(peer_id, "rpc_receive_my_permissions", role_permissions.get(str(peer_id), {}))

@rpc("authority", "call_remote", "reliable")
func rpc_receive_my_permissions(permissions: Dictionary) -> void:
	role_permissions[str(_local_peer_id())] = permissions.duplicate(true)

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


# --- Citizen banking, Central Bank, cheques and prison records ---
signal account_created(peer_id: int, account_number: String)
signal cheque_updated(cheque_id: String, status: String)
signal citizen_record_changed(citizen_id: String)
signal prison_state_changed(peer_id: int, record_id: String, imprisoned: bool)

var bank_accounts: Dictionary = {}
var citizen_registry: Dictionary = {}
var citizen_accounts: Dictionary = {}
var cheque_book: Dictionary = {}
var prison_records: Dictionary = {}
var central_bank_treasury: int = 0
var next_account_number: int = 41000001
var next_citizen_number: int = 11000001
var game_clock_seconds: float = 0.0
var role_permissions: Dictionary = {}
var shared_account_access: Dictionary = {}
var cheque_spending_ban: Dictionary = {}
var ownership_transfer_offers: Dictionary = {}
var marriage_proposals: Dictionary = {}
var marriage_records: Dictionary = {}
var next_social_number: int = 1

func _process(delta: float) -> void:
	if not _is_authority():
		return
	game_clock_seconds += delta
	_settle_due_cheques()

func _hash_pin(pin: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(pin.to_utf8_buffer())
	return context.finish().hex_encode()

func _new_citizen_id() -> String:
	while citizen_registry.has(str(next_citizen_number)):
		next_citizen_number += 1
	var result := str(next_citizen_number)
	next_citizen_number += 1
	return result

func _new_account_number() -> String:
	while bank_accounts.has(str(next_account_number)) or next_account_number > 99999999:
		next_account_number += 1
	if next_account_number > 99999999:
		next_account_number = 41000001
		while bank_accounts.has(str(next_account_number)):
			next_account_number += 1
	var result := str(next_account_number)
	next_account_number += 1
	return result

func _ensure_citizen(citizen_id: String, owner_type: String, owner_peer: int, display_name: String) -> void:
	if not citizen_registry.has(citizen_id):
		citizen_registry[citizen_id] = {
			"citizen_id": citizen_id, "owner_type": owner_type,
			"owner_peer_id": owner_peer, "name": display_name,
			"created_unix": int(Time.get_unix_time_from_system())
		}
		citizen_accounts[citizen_id] = []

func _seed_citizens() -> void:
	if not _is_authority():
		return
	_ensure_citizen("11000001", "player", 1, "سازنده")
	# Account 1 belongs to the creator and has an unlimited balance.
	if citizen_accounts["11000001"].is_empty():
		var primary_number := _new_account_number()
		bank_accounts[primary_number] = {
			"number": primary_number, "account_index": 1,
			"citizen_id": "11000001", "owner_type": "player",
			"owner_peer_id": 1, "balance": 2147483647,
			"unlimited_balance": true, "pin_hash": _hash_pin("0000"),
			"created_unix": int(Time.get_unix_time_from_system())
		}
		citizen_accounts["11000001"].append(primary_number)
	else:
		var primary_number := str(citizen_accounts["11000001"][0])
		if bank_accounts.has(primary_number):
			bank_accounts[primary_number]["account_index"] = 1
			bank_accounts[primary_number]["unlimited_balance"] = true
			bank_accounts[primary_number]["balance"] = 2147483647
	# Accounts 2-6 are NPC citizen cards; they start empty.
	for i in range(1, 7):
		var npc_id := "NPC-%03d" % i
		var citizen_id := "9900%04d" % i
		_ensure_citizen(citizen_id, "npc", -i, "شهروند NPC %d" % i)
		if i <= 5:
			if citizen_accounts[citizen_id].is_empty():
				var account_number := _new_account_number()
				bank_accounts[account_number] = {
					"number": account_number, "account_index": i + 1,
					"citizen_id": citizen_id, "owner_type": "npc",
					"owner_peer_id": -i, "balance": 0,
					"pin_hash": _hash_pin("0000"),
					"created_unix": int(Time.get_unix_time_from_system())
				}
				citizen_accounts[citizen_id].append(account_number)
			else:
				var npc_account_number := str(citizen_accounts[citizen_id][0])
				if bank_accounts.has(npc_account_number):
					bank_accounts[npc_account_number]["account_index"] = i + 1
					bank_accounts[npc_account_number]["balance"] = 0
		if not citizen_registry[citizen_id].has("npc_id"):
			citizen_registry[citizen_id]["npc_id"] = npc_id
	_save_ledger()

func register_online_player(peer_id: int) -> String:
	if not _is_authority() or peer_id <= 0:
		return ""
	var citizen_id := _citizen_id_for_peer(peer_id)
	citizen_registry[citizen_id]["last_seen_unix"] = int(Time.get_unix_time_from_system())
	_save_ledger()
	return citizen_id

func _citizen_id_for_peer(peer_id: int) -> String:
	for citizen_id in citizen_registry:
		if str(citizen_registry[citizen_id].get("owner_type", "")) == "player" and int(citizen_registry[citizen_id].get("owner_peer_id", -999)) == peer_id:
			return str(citizen_id)
	var citizen_id := _new_citizen_id()
	_ensure_citizen(citizen_id, "player", peer_id, "بازیکن %d" % peer_id)
	return citizen_id

func _actor_has_permission(actor_peer: int, permission: String) -> bool:
	if actor_peer == 1:
		return true
	var permissions: Dictionary = role_permissions.get(str(actor_peer), {})
	return bool(permissions.get(permission, false))

func request_open_bank_account(pin: String, sim_index: int = 0) -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		_open_bank_account(peer_id, pin, sim_index)
	else:
		rpc_id(1, "rpc_request_open_bank_account", pin, sim_index)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_open_bank_account(pin: String, sim_index: int) -> void:
	if multiplayer.is_server():
		_open_bank_account(multiplayer.get_remote_sender_id(), pin, sim_index)

func _open_bank_account(peer_id: int, pin: String, sim_index: int) -> void:
	if pin.length() < 4 or pin.length() > 8 or not pin.is_valid_int():
		_send_notice(peer_id, "رمز حساب باید ۴ تا ۸ رقم باشد.")
		return
	if sim_index < 0 or sim_index > 1:
		_send_notice(peer_id, "سیم‌کارت انتخاب‌شده معتبر نیست.")
		return
	var citizen_id := _citizen_id_for_peer(peer_id)
	var accounts_on_sim := 0
	for existing_number in citizen_accounts.get(citizen_id, []):
		if int(bank_accounts.get(str(existing_number), {}).get("sim_index", -1)) == sim_index:
			accounts_on_sim += 1
	if accounts_on_sim >= 3:
		_send_notice(peer_id, "هر سیم‌کارت حداکثر سه حساب بانکی دارد.")
		return
	var number := _new_account_number()
	bank_accounts[number] = {
		"number": number, "citizen_id": citizen_id, "owner_type": "player",
		"owner_peer_id": peer_id, "sim_index": sim_index, "balance": get_balance(peer_id),
		"pin_hash": _hash_pin(pin), "created_unix": int(Time.get_unix_time_from_system())
	}
	citizen_accounts[citizen_id].append(number)
	balances[peer_id] = 0
	account_created.emit(peer_id, number)
	_send_own_accounts(peer_id)
	_save_ledger()
	_send_notice(peer_id, "حساب بانکی با شماره %s افتتاح شد." % number)
	citizen_record_changed.emit(citizen_id)

func _account_pin_matches(account_number: String, pin: String) -> bool:
	if not bank_accounts.has(account_number):
		return false
	return str(bank_accounts[account_number].get("pin_hash", "")) == _hash_pin(pin)

func request_account_transfer(source_account: String, pin: String, target_account: String, amount: int) -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		_account_transfer(peer_id, source_account, pin, target_account, amount)
	else:
		rpc_id(1, "rpc_request_account_transfer", source_account, pin, target_account, amount)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_account_transfer(source_account: String, pin: String, target_account: String, amount: int) -> void:
	if multiplayer.is_server():
		_account_transfer(multiplayer.get_remote_sender_id(), source_account, pin, target_account, amount)

func _account_transfer(actor_peer: int, source_account: String, pin: String, target_account: String, amount: int) -> void:
	if amount <= 0 or not _account_pin_matches(source_account, pin) or not bank_accounts.has(target_account):
		_send_notice(actor_peer, "شماره حساب، رمز یا مبلغ انتقال معتبر نیست.")
		return
	var source: Dictionary = bank_accounts[source_account]
	if str(source.get("owner_type", "")) != "player" or int(source.get("owner_peer_id", -1)) != actor_peer:
		_send_notice(actor_peer, "این حساب متعلق به تو نیست.")
		return
	var destination: Dictionary = bank_accounts[target_account]
	var source_is_unlimited := bool(source.get("unlimited_balance", false))
	if not source_is_unlimited and int(source.balance) < amount:
		_send_notice(actor_peer, "موجودی حساب کافی نیست.")
		return
	if not source_is_unlimited:
		source.balance = int(source.balance) - amount
	if not bool(destination.get("unlimited_balance", false)):
		destination.balance = int(destination.balance) + amount
	bank_accounts[source_account] = source
	bank_accounts[target_account] = destination
	var tx_id := "TR-%06d" % next_document_number
	next_document_number += 1
	cash_transactions[tx_id] = {
		"transaction_id": tx_id, "from_account": source_account,
		"to_account": target_account, "amount": amount,
		"from_citizen_id": str(source.get("citizen_id", "")),
		"to_citizen_id": str(destination.get("citizen_id", "")),
		"from_owner_peer_id": actor_peer,
		"to_owner_peer_id": int(destination.get("owner_peer_id", -999)),
		"time": int(Time.get_unix_time_from_system()), "status": "completed"
	}
	_save_ledger()
	_send_own_accounts(actor_peer)
	var destination_owner := int(destination.get("owner_peer_id", -999))
	if destination_owner > 0 and destination_owner != actor_peer:
		_send_own_accounts(destination_owner)
	_send_notice(actor_peer, "انتقال بانکی انجام شد؛ کد پیگیری %s" % tx_id)
	citizen_record_changed.emit(str(source.citizen_id))
	citizen_record_changed.emit(str(destination.citizen_id))

func request_account_purchase(account_number: String, pin: String, item_id: String) -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		_account_purchase(peer_id, account_number, pin, item_id, false)
	else:
		rpc_id(1, "rpc_request_account_purchase", account_number, pin, item_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_account_purchase(account_number: String, pin: String, item_id: String) -> void:
	if multiplayer.is_server():
		_account_purchase(multiplayer.get_remote_sender_id(), account_number, pin, item_id, false)

func request_shared_account_purchase(account_number: String, item_id: String) -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		_account_purchase(peer_id, account_number, "", item_id, true)
	else:
		rpc_id(1, "rpc_request_shared_account_purchase", account_number, item_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_shared_account_purchase(account_number: String, item_id: String) -> void:
	if multiplayer.is_server():
		_account_purchase(multiplayer.get_remote_sender_id(), account_number, "", item_id, true)

func request_share_account_with_peer(account_number: String, target_peer_id: int, enabled: bool) -> void:
	var actor := _local_peer_id()
	if _is_authority():
		_set_account_share(actor, account_number, target_peer_id, enabled)
	else:
		rpc_id(1, "rpc_request_share_account_with_peer", account_number, target_peer_id, enabled)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_share_account_with_peer(account_number: String, target_peer_id: int, enabled: bool) -> void:
	if multiplayer.is_server():
		_set_account_share(multiplayer.get_remote_sender_id(), account_number, target_peer_id, enabled)

func _set_account_share(owner_peer: int, account_number: String, target_peer_id: int, enabled: bool) -> void:
	if not bank_accounts.has(account_number) or target_peer_id <= 0 or target_peer_id == owner_peer:
		_send_notice(owner_peer, "شماره حساب یا شناسه بازیکن معتبر نیست.")
		return
	var account: Dictionary = bank_accounts[account_number]
	if int(account.get("owner_peer_id", -1)) != owner_peer or str(account.get("owner_type", "")) != "player":
		_send_notice(owner_peer, "فقط صاحب حساب می‌تواند دسترسی خرید بدهد.")
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer and target_peer_id != 1 and not multiplayer.get_peers().has(target_peer_id):
		_send_notice(owner_peer, "بازیکن مقصد آنلاین نیست.")
		return
	var access: Dictionary = shared_account_access.get(account_number, {})
	if enabled:
		access[str(target_peer_id)] = true
	else:
		access.erase(str(target_peer_id))
	shared_account_access[account_number] = access
	_save_ledger()
	_send_notice(owner_peer, "اجازه خرید با حساب %s برای بازیکن %d %s شد." % [account_number, target_peer_id, "فعال" if enabled else "لغو"])
	if enabled:
		_send_notice(target_peer_id, "صاحب حساب %s اجازه خرید با کارت بازی‌اش را به تو داد؛ رمز او لازم نیست." % account_number)

func _account_purchase(peer_id: int, account_number: String, pin: String, item_id: String, use_shared_access: bool = false) -> void:
	if not CATALOG.has(item_id) or not bank_accounts.has(account_number):
		_send_notice(peer_id, "کالا یا شماره حساب معتبر نیست.")
		return
	var account: Dictionary = bank_accounts[account_number]
	var owner_peer := int(account.get("owner_peer_id", -1))
	var is_owner := owner_peer == peer_id and str(account.get("owner_type", "")) == "player"
	var is_shared := use_shared_access and bool(shared_account_access.get(account_number, {}).get(str(peer_id), false))
	if not is_owner and not is_shared:
		_send_notice(peer_id, "صاحب حساب اجازه خرید با این کارت را به تو نداده است.")
		return
	if is_owner and not _account_pin_matches(account_number, pin):
		_send_notice(peer_id, "رمز حساب معتبر نیست.")
		return
	var price: int = CATALOG[item_id]
	var account_is_unlimited := bool(account.get("unlimited_balance", false))
	if not account_is_unlimited and int(account.balance) < price:
		_send_notice(peer_id, "موجودی حساب کافی نیست.")
		return
	var tax := int(ceil(float(price) * 0.10))
	if not account_is_unlimited:
		account.balance = int(account.balance) - price
	bank_accounts[account_number] = account
	central_bank_treasury += tax
	var doc := _new_document(item_id, peer_id, price, "shared_card_purchase" if is_shared else "cash_purchase", account_number)
	doc["paid_by_peer_id"] = owner_peer
	doc["payment_account"] = account_number
	doc["tax_paid"] = tax
	documents[doc.document_id] = doc
	_save_ledger()
	_send_own_accounts(owner_peer)
	_send_receipt(peer_id, doc)
	_send_notice(peer_id, "خرید با کارت بازی انجام شد؛ مالیات %d سکه به خزانه رفت." % tax)
	if is_shared:
		_send_notice(owner_peer, "بازیکن %d با اجازه تو خرید کرد؛ مبلغ %d سکه از حساب %s کم شد." % [peer_id, price, account_number])
	citizen_record_changed.emit(str(account.citizen_id))

func request_issue_cheque(account_number: String, pin: String, face_value: int) -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		_issue_cheque_for_peer(peer_id, account_number, pin, face_value)
	else:
		rpc_id(1, "rpc_request_issue_cheque", account_number, pin, face_value)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_issue_cheque(account_number: String, pin: String, face_value: int) -> void:
	if multiplayer.is_server():
		_issue_cheque_for_peer(multiplayer.get_remote_sender_id(), account_number, pin, face_value)

func _issue_cheque_for_peer(peer_id: int, account_number: String, pin: String, face_value: int) -> void:
	if cheque_spending_ban.get(str(peer_id), false):
		_send_notice(peer_id, "به علت سابقه چک برگشتی، فعلاً اجازه دریافت چک نداری.")
		return
	if face_value <= 0 or not _account_pin_matches(account_number, pin):
		_send_notice(peer_id, "مبلغ، شماره حساب یا رمز معتبر نیست.")
		return
	var account: Dictionary = bank_accounts[account_number]
	if int(account.get("owner_peer_id", -1)) != peer_id:
		_send_notice(peer_id, "این حساب متعلق به تو نیست.")
		return
	var cheque_id := "چک-%06d" % next_document_number
	next_document_number += 1
	cheque_book[cheque_id] = {
		"id": cheque_id, "issuer_peer_id": peer_id,
		"issuer_citizen_id": str(account.citizen_id),
		"account_number": account_number, "face_value": face_value,
		"remaining_value": face_value, "status": "صادرشده",
		"issued_unix": int(Time.get_unix_time_from_system()),
		"spends": [], "dishonoured_count": 0
	}
	_save_ledger()
	_send_own_cheques(peer_id)
	_send_notice(peer_id, "چک %s صادر شد؛ اعتبار اولیه %d سکه." % [cheque_id, face_value])
	citizen_record_changed.emit(str(account.citizen_id))

func request_cheque_purchase(cheque_id: String, item_id: String) -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		_cheque_purchase(peer_id, cheque_id, item_id)
	else:
		rpc_id(1, "rpc_request_cheque_purchase", cheque_id, item_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_cheque_purchase(cheque_id: String, item_id: String) -> void:
	if multiplayer.is_server():
		_cheque_purchase(multiplayer.get_remote_sender_id(), cheque_id, item_id)

func _cheque_purchase(peer_id: int, cheque_id: String, item_id: String) -> void:
	if cheque_spending_ban.get(str(peer_id), false):
		_send_notice(peer_id, "به علت سابقه چک برگشتی، اجازه خرید با چک نداری.")
		return
	if not cheque_book.has(cheque_id) or not CATALOG.has(item_id):
		_send_notice(peer_id, "چک یا کالا معتبر نیست.")
		return
	var cheque: Dictionary = cheque_book[cheque_id]
	if int(cheque.get("issuer_peer_id", -1)) != peer_id or str(cheque.get("status", "")) != "صادرشده":
		_send_notice(peer_id, "این چک متعلق به تو نیست یا قابل استفاده نیست.")
		return
	var price: int = CATALOG[item_id]
	if int(cheque.remaining_value) < price:
		_send_notice(peer_id, "اعتبار باقی‌مانده چک از قیمت کالا کمتر است.")
		return
	cheque.remaining_value = int(cheque.remaining_value) - price
	var spend_id := "CS-%06d" % next_document_number
	next_document_number += 1
	var doc := _new_document(item_id, peer_id, price, "cheque_purchase", cheque_id)
	doc["cheque_id"] = cheque_id
	doc["spend_id"] = spend_id
	doc["status"] = "pending_cheque_settlement"
	documents[doc.document_id] = doc
	cheque.spends.append({
		"spend_id": spend_id, "document_id": doc.document_id,
		"item_id": item_id, "amount": price,
		"due_game_time": game_clock_seconds + 1440.0,
		"status": "در انتظار تسویه"
	})
	cheque_book[cheque_id] = cheque
	_save_ledger()
	_send_own_cheques(peer_id)
	_send_receipt(peer_id, doc)
	_send_notice(peer_id, "خرید با چک ثبت شد؛ تسویه پس از یک روز بازی انجام می‌شود.")
	citizen_record_changed.emit(str(cheque.issuer_citizen_id))

func _settle_due_cheques() -> void:
	var changed := false
	for cheque_id in cheque_book.keys():
		var cheque: Dictionary = cheque_book[cheque_id]
		var spends: Array = cheque.get("spends", [])
		for index in range(spends.size()):
			var spend: Dictionary = spends[index]
			if str(spend.get("status", "")) != "در انتظار تسویه" or float(spend.get("due_game_time", 0.0)) > game_clock_seconds:
				continue
			var account_number := str(cheque.get("account_number", ""))
			var account: Dictionary = bank_accounts.get(account_number, {})
			var amount := int(spend.get("amount", 0))
			var doc_id := str(spend.get("document_id", ""))
			if not account.is_empty() and (bool(account.get("unlimited_balance", false)) or int(account.get("balance", 0)) >= amount):
				if not bool(account.get("unlimited_balance", false)):
					account.balance = int(account.balance) - amount
				bank_accounts[account_number] = account
				var tax := int(ceil(float(amount) * 0.10))
				central_bank_treasury += tax
				spend.status = "پاس‌شده"
				spend["tax_paid"] = tax
				if documents.has(doc_id):
					documents[doc_id]["status"] = "valid"
					documents[doc_id]["tax_paid"] = tax
					_send_receipt(int(cheque.issuer_peer_id), documents[doc_id])
				_send_notice(int(cheque.issuer_peer_id), "چک %s با موفقیت پاس شد." % cheque_id)
			else:
				spend.status = "برگشت‌خورده"
				cheque_spending_ban[str(cheque.issuer_peer_id)] = true
				cheque.dishonoured_count = int(cheque.get("dishonoured_count", 0)) + 1
				if documents.has(doc_id):
					documents[doc_id]["status"] = "repossessed"
					documents[doc_id]["repossessed"] = true
					documents[doc_id]["previous_owner_peer_id"] = int(cheque.issuer_peer_id)
					documents[doc_id]["owner_peer_id"] = -3
					documents[doc_id]["owner_name"] = "اموال توقیف‌شده"
					documents[doc_id]["history"].append({"event": "repossession", "from": int(cheque.issuer_peer_id), "to": -3, "time": int(Time.get_unix_time_from_system())})
					_send_receipt(int(cheque.issuer_peer_id), documents[doc_id])
				var record_id := "JAIL-%06d" % next_document_number
				next_document_number += 1
				prison_records[record_id] = {
					"record_id": record_id, "citizen_id": str(cheque.issuer_citizen_id),
					"peer_id": int(cheque.issuer_peer_id), "reason": "چک برگشتی",
					"cheque_id": cheque_id, "spend_id": str(spend.spend_id),
					"amount": amount, "item_id": str(spend.item_id),
					"entered_game_time": game_clock_seconds,
					"status": "زندانی", "released_by": 0,
					"release_reason": ""
				}
				_send_notice(int(cheque.issuer_peer_id), "چک برگشت خورد؛ سند خرید توقیف شد و پرونده زندان ثبت شد.")
				_notify_prison_state(int(cheque.issuer_peer_id), record_id, true)
			spends[index] = spend
			changed = true
		cheque.spends = spends
		if int(cheque.get("remaining_value", 0)) <= 0:
			cheque.status = "مصرف‌شده"
		cheque_book[cheque_id] = cheque
	if changed:
		_save_ledger()
		var synced_cheque_owners: Dictionary = {}
		for cheque in cheque_book.values():
			var cheque_owner := int(cheque.get("issuer_peer_id", -999))
			if cheque_owner > 0 and not synced_cheque_owners.has(cheque_owner):
				synced_cheque_owners[cheque_owner] = true
				_send_own_cheques(cheque_owner)
				_send_own_accounts(cheque_owner)
		for citizen_id in citizen_registry.keys():
			citizen_record_changed.emit(str(citizen_id))

func send_prison_status(peer_id: int) -> void:
	if not _is_authority():
		return
	for record_id in prison_records.keys():
		var record: Dictionary = prison_records[record_id]
		if int(record.get("peer_id", -999)) == peer_id and str(record.get("status", "")) == "زندانی":
			_notify_prison_state(peer_id, str(record_id), true)
			return

func _notify_prison_state(peer_id: int, record_id: String, imprisoned: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id > 1 and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "rpc_receive_prison_state", record_id, imprisoned)
	elif peer_id == _local_peer_id():
		prison_state_changed.emit(peer_id, record_id, imprisoned)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_prison_state(record_id: String, imprisoned: bool) -> void:
	prison_state_changed.emit(_local_peer_id(), record_id, imprisoned)

func pardon_cheque_ban(actor_peer: int, target_peer: int, reason: String) -> bool:
	if not _is_authority() or not _actor_has_permission(actor_peer, "pardon_cheque_ban") or target_peer <= 0:
		return false
	cheque_spending_ban[str(target_peer)] = false
	var citizen_id := _citizen_id_for_peer(target_peer)
	var pardon_id := "PARDON-%06d" % next_document_number
	next_document_number += 1
	cash_transactions[pardon_id] = {
		"transaction_id": pardon_id, "type": "cheque_ban_pardon",
		"citizen_id": citizen_id, "actor_peer": actor_peer,
		"reason": reason, "time": int(Time.get_unix_time_from_system())
	}
	_save_ledger()
	_send_notice(target_peer, "محرومیت چک با دستور مقام مجاز برداشته شد؛ سوابق قبلی باقی است.")
	return true

func set_role_permissions(actor_peer: int, target_peer: int, permissions: Dictionary) -> bool:
	if not _is_authority() or actor_peer != 1 or target_peer <= 1:
		return false
	role_permissions[str(target_peer)] = permissions.duplicate(true)
	_save_ledger()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and multiplayer.get_peers().has(target_peer):
		send_permission_snapshot(target_peer)
	return true

func central_bank_withdraw(actor_peer: int, target_account: String, amount: int, reason: String) -> bool:
	if not _is_authority() or not _actor_has_permission(actor_peer, "central_bank_withdraw") or amount <= 0 or amount > central_bank_treasury or not bank_accounts.has(target_account):
		return false
	central_bank_treasury -= amount
	if not bool(bank_accounts[target_account].get("unlimited_balance", false)):
		bank_accounts[target_account].balance = int(bank_accounts[target_account].balance) + amount
	var tx_id := "CB-%06d" % next_document_number
	next_document_number += 1
	cash_transactions[tx_id] = {
		"transaction_id": tx_id, "type": "central_bank_withdrawal",
		"account": target_account, "amount": amount,
		"actor_peer": actor_peer, "reason": reason,
		"time": int(Time.get_unix_time_from_system())
	}
	_save_ledger()
	var recipient_peer := int(bank_accounts[target_account].get("owner_peer_id", -999))
	if recipient_peer > 0:
		_send_own_accounts(recipient_peer)
	var citizen_id := str(bank_accounts[target_account].get("citizen_id", ""))
	if not citizen_id.is_empty():
		citizen_record_changed.emit(citizen_id)
	_send_notice(actor_peer, "برداشت %d سکه از خزانه مرکزی به کارت %s ثبت شد." % [amount, target_account])
	return true

func release_prisoner(actor_peer: int, record_id: String, reason: String) -> bool:
	if not _is_authority() or not _actor_has_permission(actor_peer, "release_prisoner") or not prison_records.has(record_id):
		return false
	var record: Dictionary = prison_records[record_id]
	if str(record.get("status", "")) != "زندانی":
		return false
	record.status = "آزادشده"
	record.released_by = actor_peer
	record.release_reason = reason
	record.released_game_time = game_clock_seconds
	prison_records[record_id] = record
	_save_ledger()
	var released_peer := int(record.get("peer_id", -1))
	_send_notice(released_peer, "با دستور مقام مجاز از زندان آزاد شدی.")
	_notify_prison_state(released_peer, record_id, false)
	return true


signal central_bank_snapshot_received(data: Dictionary)
signal citizen_record_received(data: Dictionary)


signal own_accounts_received(accounts: Array)
signal own_cheques_received(cheques: Array)

func _send_own_cheques(peer_id: int) -> void:
	var result: Array = []
	for cheque in cheque_book.values():
		if int(cheque.get("issuer_peer_id", -999)) == peer_id:
			result.append(cheque.duplicate(true))
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id > 1 and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "rpc_receive_own_cheques", result)
	elif peer_id == _local_peer_id():
		own_cheques_received.emit(result)

func request_own_cheques() -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		_send_own_cheques(peer_id)
	else:
		rpc_id(1, "rpc_request_own_cheques")

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_own_cheques() -> void:
	if multiplayer.is_server():
		_send_own_cheques(multiplayer.get_remote_sender_id())

@rpc("authority", "call_remote", "reliable")
func rpc_receive_own_cheques(cheques: Array) -> void:
	own_cheques_received.emit(cheques)

func _send_own_accounts(peer_id: int) -> void:
	var accounts := get_accounts_for_peer(peer_id)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and peer_id > 1 and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "rpc_receive_own_bank_accounts", accounts)
	elif peer_id == _local_peer_id():
		own_accounts_received.emit(accounts)

func request_own_bank_accounts() -> void:
	var peer_id := _local_peer_id()
	if _is_authority():
		own_accounts_received.emit(get_accounts_for_peer(peer_id))
	else:
		rpc_id(1, "rpc_request_own_bank_accounts")

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_own_bank_accounts() -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		rpc_id(sender, "rpc_receive_own_bank_accounts", get_accounts_for_peer(sender))

@rpc("authority", "call_remote", "reliable")
func rpc_receive_own_bank_accounts(accounts: Array) -> void:
	own_accounts_received.emit(accounts)

func get_accounts_for_peer(peer_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var citizen_id := _citizen_id_for_peer(peer_id) if _is_authority() else ""
	if citizen_id.is_empty():
		return result
	for number in citizen_accounts.get(citizen_id, []):
		var account: Dictionary = bank_accounts.get(str(number), {}).duplicate(true)
		account.erase("pin_hash")
		account["pin_security"] = "رمز محرمانه و هش‌شده"
		if bool(account.get("unlimited_balance", false)):
			account["balance_display"] = "نامحدود"
		else:
			account["balance_display"] = str(account.get("balance", 0))
		result.append(account)
	return result

func request_central_bank_snapshot() -> void:
	var actor := _local_peer_id()
	if _is_authority():
		central_bank_snapshot_received.emit(get_central_bank_snapshot(actor))
	else:
		rpc_id(1, "rpc_request_central_bank_snapshot")

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_central_bank_snapshot() -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		var data := get_central_bank_snapshot(sender)
		if not data.is_empty():
			rpc_id(sender, "rpc_receive_central_bank_snapshot", data)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_central_bank_snapshot(data: Dictionary) -> void:
	central_bank_snapshot_received.emit(data)

func request_citizen_record(citizen_id: String) -> void:
	var actor := _local_peer_id()
	if _is_authority():
		var data := get_citizen_full_record(citizen_id) if _actor_has_permission(actor, "view_citizen_records") else {}
		citizen_record_received.emit(data)
	else:
		rpc_id(1, "rpc_request_citizen_record", citizen_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_citizen_record(citizen_id: String) -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		if not _actor_has_permission(sender, "view_citizen_records"):
			return
		rpc_id(sender, "rpc_receive_citizen_record", get_citizen_full_record(citizen_id))

@rpc("authority", "call_remote", "reliable")
func rpc_receive_citizen_record(data: Dictionary) -> void:
	citizen_record_received.emit(data)

func request_pardon_cheque_ban(target_peer: int, reason: String) -> void:
	var actor := _local_peer_id()
	if _is_authority():
		if pardon_cheque_ban(actor, target_peer, reason):
			_send_notice(actor, "محرومیت چک با ثبت سابقه بخشیده شد.")
	else:
		rpc_id(1, "rpc_request_pardon_cheque_ban", target_peer, reason)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_pardon_cheque_ban(target_peer: int, reason: String) -> void:
	if multiplayer.is_server():
		pardon_cheque_ban(multiplayer.get_remote_sender_id(), target_peer, reason)

func request_release_prisoner(record_id: String, reason: String) -> void:
	var actor := _local_peer_id()
	if _is_authority():
		release_prisoner(actor, record_id, reason)
	else:
		rpc_id(1, "rpc_request_release_prisoner", record_id, reason)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_release_prisoner(record_id: String, reason: String) -> void:
	if multiplayer.is_server():
		release_prisoner(multiplayer.get_remote_sender_id(), record_id, reason)

func request_central_bank_withdraw(target_account: String, amount: int, reason: String) -> void:
	var actor := _local_peer_id()
	if _is_authority():
		if central_bank_withdraw(actor, target_account, amount, reason):
			_send_notice(actor, "برداشت از خزانه ثبت شد.")
	else:
		rpc_id(1, "rpc_request_central_bank_withdraw", target_account, amount, reason)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_central_bank_withdraw(target_account: String, amount: int, reason: String) -> void:
	if multiplayer.is_server():
		var actor := multiplayer.get_remote_sender_id()
		if central_bank_withdraw(actor, target_account, amount, reason):
			_send_notice(actor, "برداشت از خزانه ثبت شد.")

func request_role_permissions(target_peer: int, permissions: Dictionary) -> void:
	if _local_peer_id() != 1:
		return
	if _is_authority():
		set_role_permissions(1, target_peer, permissions)
	else:
		rpc_id(1, "rpc_request_role_permissions", target_peer, permissions)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_role_permissions(target_peer: int, permissions: Dictionary) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == 1:
		set_role_permissions(1, target_peer, permissions)

func get_citizen_full_record(citizen_id: String) -> Dictionary:
	if not _is_authority():
		return {}
	var citizen: Dictionary = citizen_registry.get(citizen_id, {})
	if citizen.is_empty():
		for key in citizen_registry.keys():
			if str(citizen_registry[key].get("owner_peer_id", "")) == citizen_id:
				citizen_id = str(key)
				citizen = citizen_registry[citizen_id]
				break
	if citizen.is_empty():
		return {}
	var accounts: Array = []
	for number in citizen_accounts.get(citizen_id, []):
		var account: Dictionary = bank_accounts.get(str(number), {}).duplicate(true)
		account.erase("pin_hash")
		account["pin_security"] = "رمز ذخیره‌شده به‌صورت هش؛ قابل مشاهده نیست"
		accounts.append(account)
	var citizen_cheques: Array = []
	for cheque in cheque_book.values():
		if str(cheque.get("issuer_citizen_id", "")) == citizen_id:
			citizen_cheques.append(cheque.duplicate(true))
	var citizen_prison: Array = []
	for record in prison_records.values():
		if str(record.get("citizen_id", "")) == citizen_id:
			citizen_prison.append(record.duplicate(true))
	var assets: Array[Dictionary] = []
	var owner_peer := int(citizen.get("owner_peer_id", -999))
	var total_purchases := 0
	var total_tax_paid := 0
	for doc in documents.values():
		if int(doc.get("owner_peer_id", -999)) == owner_peer and str(doc.get("status", "valid")) == "valid":
			assets.append(doc.duplicate(true))
			total_purchases += int(doc.get("purchase_price", 0))
			total_tax_paid += int(doc.get("tax_paid", 0))
	var citizen_transactions: Array = []
	var own_account_numbers: Array = citizen_accounts.get(citizen_id, [])
	for transaction in cash_transactions.values():
		var tx: Dictionary = transaction
		if str(tx.get("from_account", "")) in own_account_numbers or str(tx.get("to_account", "")) in own_account_numbers or int(tx.get("peer_id", -999)) == owner_peer or int(tx.get("from_peer", -999)) == owner_peer or int(tx.get("to_peer", -999)) == owner_peer:
			citizen_transactions.append(tx.duplicate(true))
	var honoured_count := 0
	var dishonoured_count := 0
	for cheque in citizen_cheques:
		for spend in cheque.get("spends", []):
			if str(spend.get("status", "")) == "پاس‌شده":
				honoured_count += 1
			elif str(spend.get("status", "")) == "برگشت‌خورده":
				dishonoured_count += 1
	return {
		"citizen": citizen.duplicate(true), "accounts": accounts,
		"cheques": citizen_cheques, "honoured_cheque_spends": honoured_count,
		"dishonoured_cheque_spends": dishonoured_count,
		"prison_records": citizen_prison, "assets": assets,
		"transactions": citizen_transactions,
		"total_purchases": total_purchases, "total_tax_paid": total_tax_paid,
		"cheque_banned": bool(cheque_spending_ban.get(str(citizen.get("owner_peer_id", -999)), false))
	}

func can_access_permission(actor_peer: int, permission: String) -> bool:
	return _actor_has_permission(actor_peer, permission)

func get_central_bank_snapshot(actor_peer: int) -> Dictionary:
	var snapshot: Dictionary = {}
	if _actor_has_permission(actor_peer, "view_central_bank"):
		var safe_accounts: Dictionary = {}
		for number in bank_accounts.keys():
			var safe_account: Dictionary = bank_accounts[number].duplicate(true)
			safe_account.erase("pin_hash")
			safe_account["pin_security"] = "رمز محرمانه و هش‌شده؛ قابل مشاهده نیست"
			safe_accounts[number] = safe_account
		snapshot["treasury"] = central_bank_treasury
		snapshot["accounts"] = safe_accounts
		snapshot["cheques"] = cheque_book.duplicate(true)
		snapshot["transactions"] = cash_transactions.duplicate(true)
	if _actor_has_permission(actor_peer, "view_prison_records"):
		snapshot["prison_records"] = prison_records.duplicate(true)
	if _actor_has_permission(actor_peer, "view_citizen_records"):
		snapshot["citizens"] = citizen_registry.duplicate(true)
	return snapshot


func request_marriage_proposal(target_peer: int) -> void:
	if _is_authority():
		_create_marriage_proposal(_local_peer_id(), target_peer)
	else:
		rpc_id(1, "rpc_request_marriage_proposal", target_peer)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_marriage_proposal(target_peer: int) -> void:
	if multiplayer.is_server():
		_create_marriage_proposal(multiplayer.get_remote_sender_id(), target_peer)

func _create_marriage_proposal(from_peer: int, target_peer: int) -> void:
	if from_peer <= 0 or target_peer <= 0 or from_peer == target_peer:
		_send_notice(from_peer, "شناسه بازیکن مقصد معتبر نیست.")
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer and target_peer != 1 and not multiplayer.get_peers().has(target_peer):
		_send_notice(from_peer, "برای عقد، بازیکن مقصد باید آنلاین باشد.")
		return
	for marriage in marriage_records.values():
		if str(marriage.get("status", "")) == "married" and (int(marriage.get("partner_a", -1)) == from_peer or int(marriage.get("partner_b", -1)) == from_peer or int(marriage.get("partner_a", -1)) == target_peer or int(marriage.get("partner_b", -1)) == target_peer):
			_send_notice(from_peer, "یکی از دو بازیکن در حال حاضر متأهل است.")
			return
	var proposal_id := "LC-MRG-%06d" % next_social_number
	next_social_number += 1
	marriage_proposals[proposal_id] = {"proposal_id": proposal_id, "from_peer": from_peer, "to_peer": target_peer, "status": "pending", "created_unix": int(Time.get_unix_time_from_system())}
	_save_ledger()
	_send_notice(from_peer, "درخواست عقد برای بازیکن %d ارسال شد؛ کد درخواست: %s" % [target_peer, proposal_id])
	_send_notice(target_peer, "درخواست ازدواج از بازیکن %d دریافت شد. برای قبول، کد %s را وارد کن." % [from_peer, proposal_id])

func request_accept_marriage(proposal_id: String) -> void:
	if _is_authority():
		_accept_marriage(_local_peer_id(), proposal_id)
	else:
		rpc_id(1, "rpc_request_accept_marriage", proposal_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_accept_marriage(proposal_id: String) -> void:
	if multiplayer.is_server():
		_accept_marriage(multiplayer.get_remote_sender_id(), proposal_id)

func _accept_marriage(actor_peer: int, proposal_id: String) -> void:
	if not marriage_proposals.has(proposal_id):
		_send_notice(actor_peer, "درخواست عقد پیدا نشد.")
		return
	var proposal: Dictionary = marriage_proposals[proposal_id]
	var partner_a := int(proposal.get("from_peer", -1))
	if int(proposal.get("to_peer", -1)) != actor_peer or str(proposal.get("status", "")) != "pending":
		_send_notice(actor_peer, "این درخواست برای تو نیست یا قبلاً پاسخ داده شده است.")
		return
	for marriage in marriage_records.values():
		if str(marriage.get("status", "")) == "married" and [int(marriage.get("partner_a", -1)), int(marriage.get("partner_b", -1))].has(actor_peer):
			_send_notice(actor_peer, "تو در حال حاضر متأهل هستی.")
			return
	var marriage_id := "LC-NKAH-%06d" % next_social_number
	next_social_number += 1
	marriage_records[marriage_id] = {"marriage_id": marriage_id, "partner_a": partner_a, "partner_b": actor_peer, "status": "married", "ceremony": "محضر LIFE CITY", "married_unix": int(Time.get_unix_time_from_system())}
	proposal["status"] = "accepted"
	marriage_proposals[proposal_id] = proposal
	_save_ledger()
	_send_notice(partner_a, "عقد شما در محضر LIFE CITY ثبت شد. شماره ثبت: %s" % marriage_id)
	_send_notice(actor_peer, "عقد شما در محضر LIFE CITY ثبت شد. شماره ثبت: %s" % marriage_id)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if partner_a > 1 and multiplayer.get_peers().has(partner_a):
			rpc_id(partner_a, "rpc_sync_marriage_record", marriage_id, marriage_records[marriage_id])
		if actor_peer > 1 and multiplayer.get_peers().has(actor_peer):
			rpc_id(actor_peer, "rpc_sync_marriage_record", marriage_id, marriage_records[marriage_id])

@rpc("authority", "call_remote", "reliable")
func rpc_sync_marriage_record(marriage_id: String, marriage: Dictionary) -> void:
	marriage_records[marriage_id] = marriage.duplicate(true)

func request_post_bail(record_id: String) -> void:
	if _is_authority():
		_post_bail(_local_peer_id(), record_id)
	else:
		rpc_id(1, "rpc_request_post_bail", record_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_post_bail(record_id: String) -> void:
	if multiplayer.is_server():
		_post_bail(multiplayer.get_remote_sender_id(), record_id)

func _post_bail(actor_peer: int, record_id: String) -> void:
	if not prison_records.has(record_id):
		_send_notice(actor_peer, "پرونده زندان پیدا نشد.")
		return
	var record: Dictionary = prison_records[record_id]
	if str(record.get("status", "")) != "زندانی":
		_send_notice(actor_peer, "این پرونده فعال نیست.")
		return
	var bail_amount := int(record.get("bail_amount", 2500))
	if bail_amount <= 0 or get_balance(actor_peer) < bail_amount:
		_send_notice(actor_peer, "موجودی کافی برای ضمانت (%d سکه) نداری." % bail_amount)
		return
	balances[actor_peer] = get_balance(actor_peer) - bail_amount
	central_bank_treasury += bail_amount
	record["status"] = "آزادشده"
	record["released_by"] = actor_peer
	record["release_reason"] = "آزادی با سند ضمانت"
	record["bail_paid"] = bail_amount
	record["released_game_time"] = game_clock_seconds
	prison_records[record_id] = record
	var tx_id := "BAIL-%06d" % next_document_number
	next_document_number += 1
	cash_transactions[tx_id] = {"transaction_id": tx_id, "type": "prison_bail", "record_id": record_id, "prisoner_peer": int(record.get("peer_id", -1)), "guarantor_peer": actor_peer, "amount": bail_amount, "status": "completed", "time": int(Time.get_unix_time_from_system())}
	_save_ledger()
	_send_balance(actor_peer)
	_send_notice(actor_peer, "سند ضمانت ثبت شد؛ %d سکه پرداخت کردی." % bail_amount)
	_send_notice(int(record.get("peer_id", -1)), "دوستت/بازیکن %d برای آزادی تو سند ضمانت گذاشت و آزاد شدی." % actor_peer)
	_notify_prison_state(int(record.get("peer_id", -1)), record_id, false)

func _save_ledger() -> void:
	if not _is_authority():
		return
	var saved_balances: Dictionary = {}
	for peer_key in balances.keys():
		saved_balances[str(peer_key)] = balances[peer_key]
	var payload := {"balances": saved_balances, "documents": documents, "next_document_number": next_document_number, "cash_transactions": cash_transactions, "bank_accounts": bank_accounts, "citizen_registry": citizen_registry, "citizen_accounts": citizen_accounts, "cheque_book": cheque_book, "prison_records": prison_records, "central_bank_treasury": central_bank_treasury, "next_account_number": next_account_number, "next_citizen_number": next_citizen_number, "game_clock_seconds": game_clock_seconds, "role_permissions": role_permissions, "cheque_spending_ban": cheque_spending_ban, "shared_account_access": shared_account_access, "ownership_transfer_offers": ownership_transfer_offers, "marriage_proposals": marriage_proposals, "marriage_records": marriage_records, "next_social_number": next_social_number}
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
		bank_accounts = parsed.get("bank_accounts", {})
		citizen_registry = parsed.get("citizen_registry", {})
		citizen_accounts = parsed.get("citizen_accounts", {})
		cheque_book = parsed.get("cheque_book", {})
		prison_records = parsed.get("prison_records", {})
		central_bank_treasury = int(parsed.get("central_bank_treasury", 0))
		next_account_number = int(parsed.get("next_account_number", next_account_number))
		next_citizen_number = int(parsed.get("next_citizen_number", next_citizen_number))
		game_clock_seconds = float(parsed.get("game_clock_seconds", 0.0))
		role_permissions = parsed.get("role_permissions", {})
		cheque_spending_ban = parsed.get("cheque_spending_ban", {})
		shared_account_access = parsed.get("shared_account_access", {})
		ownership_transfer_offers = parsed.get("ownership_transfer_offers", {})
		marriage_proposals = parsed.get("marriage_proposals", {})
		marriage_records = parsed.get("marriage_records", {})
		next_social_number = int(parsed.get("next_social_number", next_social_number))
