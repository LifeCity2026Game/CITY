extends Node

# LIFE CITY Stage 2: playable prototype systems.
# All balances are fictional and local to this game build.
var player_balance: int = 10000
var player_black_money: int = 0
var selected_account: String = "NPC1000"
var notice: String = "مرحله دوم فعال شد"
var npc_accounts: Dictionary = {}
var owned_items: Array[String] = []
var orders: Array[Dictionary] = []
var reports: Array[String] = []
var ownership_ledger: Node
var creator_mode := false
var owner_only_buttons: Array[Button] = []
var base_layout_children := 0
var selected_document_id := ""
var transfer_target_input: LineEdit
var transfer_amount_input: LineEdit
var panel: PanelContainer
var status_label: Label
var details_label: Label

const DEPARTMENTS := [
	"نیروی زمینی", "نیروی هوایی", "نیروی دریایی", "نیروی فضایی",
	"گارد ساحلی", "تفنگداران دریایی", "گارد ملی"
]
const SHOP := {"لباس رسمی": 600, "لباس ورزشی": 350, "خانه کوچک": 5000, "خودروی شهری": 7500}
const SERVICES := [
	"بانک مرکزی", "بانک شهر", "فروشگاه اینترنتی", "وزارت اطلاعات",
	"کاخ ریاست جمهوری", "ستاد کل نیروهای مسلح", "پلیس و کلانتری", "ساختمان دولت"
]

func set_ownership_ledger(ledger: Node) -> void:
	ownership_ledger = ledger
	if ownership_ledger:
		ownership_ledger.receipt_issued.connect(_on_receipt_issued)
		ownership_ledger.ledger_notice.connect(_on_ledger_notice)

func _on_receipt_issued(document: Dictionary) -> void:
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if int(document.get("owner_peer_id", -999)) != local_peer_id:
		return
	var item_id := str(document.get("item_id", ""))
	owned_items.append(item_id)
	orders.append({"item": item_id, "status": "سند مالکیت صادر شد", "document_id": document.get("document_id", "")})
	notice = "سند مالکیت صادر شد: " + str(document.get("document_id", ""))
	_refresh()

func _on_ledger_notice(message: String) -> void:
	notice = message
	_refresh()

func _is_owner() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _ready() -> void:
	_seed_npcs()
	_build_interface()
	_refresh()

func _seed_npcs() -> void:
	for i in range(12):
		var id := "NPC" + str(1000 + i)
		npc_accounts[id] = {"name": "شهروند " + str(i + 1), "balance": 1200 + i * 275, "job": "شهروند"}

func _process(_delta: float) -> void:
	for owner_button in owner_only_buttons:
		owner_button.visible = _is_owner()

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Stage2Interface"
	add_child(layer)
	panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = 340
	panel.offset_bottom = 590
	layer.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	panel.add_child(layout)
	var heading := Label.new()
	heading.text = "LIFE CITY | خدمات شهر"
	heading.add_theme_font_size_override("font_size", 19)
	layout.add_child(heading)
	status_label = Label.new()
	status_label.text = notice
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)
	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(details_label)
	_add_button(layout, "بانک و انتقال وجه", "bank")
	_add_button(layout, "فروشگاه و سفارش‌ها", "shop")
	owner_only_buttons.append(_add_button(layout, "وزارت اطلاعات و پرونده‌ها", "intel"))
	_add_button(layout, "کاخ ریاست جمهوری", "palace")
	owner_only_buttons.append(_add_button(layout, "ستاد کل و هفت نیرو", "military"))
	_add_button(layout, "پلیس و ساختمان دولت", "civic")
	owner_only_buttons.append(_add_button(layout, "مدیریت سازنده", "creator"))
	_add_button(layout, "راهنمای خدمات", "help")
	base_layout_children = layout.get_child_count()

func _add_button(parent: VBoxContainer, caption: String, action: String) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(290, 46)
	_style_button(b)
	b.pressed.connect(_on_action.bind(action))
	parent.add_child(b)
	return b

func _add_action_button(caption: String, action: String, arg: String = "") -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(290, 42)
	_style_button(b)
	b.pressed.connect(_on_action.bind(action, arg))
	panel.get_child(0).add_child(b)

func _clear_actions() -> void:
	var layout := panel.get_child(0) as VBoxContainer
	while layout.get_child_count() > base_layout_children:
		var child := layout.get_child(layout.get_child_count() - 1)
		layout.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	status_label.text = notice
	var visible_balance := player_balance
	if ownership_ledger:
		var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		visible_balance = ownership_ledger.get_balance(peer_id)
	details_label.text = "موجودی: %d سکه | پول سیاه: %d" % [visible_balance, player_black_money]

func _on_action(action: String, arg: String = "") -> void:
	var private_areas := {
		"intel": "intelligence",
		"military": "military_command",
		"creator": "creator"
	}
	if private_areas.has(action):
		var requesting_peer: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		var ledger_allows: bool = ownership_ledger == null or bool(ownership_ledger.has_owner_access(str(private_areas[action]), requesting_peer))
		if not _is_owner() or not ledger_allows:
			notice = "دسترسی فقط برای حساب سازنده/میزبان مجاز است."
			_refresh()
			return
	if action not in ["select_document", "sell_npc", "transfer_player", "npc_buy", "cash_transfer"]:
		_clear_actions()
	match action:
		"bank":
			notice = "بانک آزمایشی | انتقال فقط با موجودی کافی"
			_add_action_button("نمایش حساب NPC1000", "resolve", "NPC1000")
			_add_action_button("انتقال ۵۰۰ سکه به NPC1000", "transfer", "NPC1000")
			_add_action_button("دریافت ۳۰۰ سکه از NPC1000", "withdraw", "NPC1000")
			_add_action_button("تراکنش با حساب ناموجود (آزمایش)", "resolve", "UNKNOWN")
			transfer_target_input = LineEdit.new()
			transfer_target_input.placeholder_text = "شناسه بازیکن آنلاین مقصد (مثلاً 2)"
			panel.get_child(0).add_child(transfer_target_input)
			transfer_amount_input = LineEdit.new()
			transfer_amount_input.placeholder_text = "مبلغ انتقال به سکه"
			transfer_amount_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
			panel.get_child(0).add_child(transfer_amount_input)
			_add_action_button("انتقال وجه به بازیکن آنلاین", "cash_transfer")
		"cash_transfer":
			if ownership_ledger and transfer_target_input and transfer_amount_input:
				var target_peer := int(transfer_target_input.text)
				var amount := int(transfer_amount_input.text)
				ownership_ledger.request_player_cash_transfer(target_peer, amount)
				notice = "درخواست انتقال وجه برای بررسی میزبان ارسال شد."
			else:
				notice = "سیستم حسابداری آنلاین در دسترس نیست."
		"resolve":
			if npc_accounts.has(arg):
				notice = "حساب پیدا شد: %s | موجودی: %d" % [npc_accounts[arg].name, npc_accounts[arg].balance]
			else:
				notice = "حساب پیدا نشد"
		"transfer":
			if npc_accounts.has(arg) and player_balance >= 500:
				player_balance -= 500
				npc_accounts[arg].balance += 500
				notice = "انتقال ۵۰۰ سکه با موفقیت انجام شد"
			else:
				notice = "انتقال ناموفق: حساب یا موجودی کافی نیست"
		"withdraw":
			if npc_accounts.has(arg) and npc_accounts[arg].balance >= 300:
				npc_accounts[arg].balance -= 300
				player_balance += 300
				notice = "۳۰۰ سکه از حساب آزمایشی دریافت شد"
			else:
				notice = "برداشت ناموفق: موجودی NPC کافی نیست"
		"shop":
			notice = "فروشگاه اینترنتی | خرید با پول داخل بازی و صدور سند مالکیت"
			for item in SHOP:
				_add_action_button("خرید %s | %d" % [item, SHOP[item]], "buy", item)
			_add_action_button("نمایش سفارش‌ها", "orders")
			_add_action_button("اسناد مالکیت و معاملات", "documents")
		"buy":
			var price: int = SHOP.get(arg, 0)
			var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
			var available_balance: int = ownership_ledger.get_balance(peer_id) if ownership_ledger != null else player_balance
			if price > 0 and available_balance >= price:
				if ownership_ledger:
					ownership_ledger.request_purchase(arg)
					notice = "درخواست خرید ثبت شد؛ پس از تأیید میزبان سند صادر می‌شود."
				else:
					player_balance -= price
					owned_items.append(arg)
					orders.append({"item": arg, "status": "در انتظار تحویل"})
					notice = "سفارش ثبت شد: " + arg
			else:
				notice = "خرید انجام نشد: موجودی کافی نیست"
		"orders":
			notice = "سفارش‌های ثبت‌شده: " + str(orders)
		"creator":
			notice = "پنل سازنده | فقط میزبان: مدیریت دسترسی‌ها و تنظیمات خصوصی."
			_add_action_button("نمایش اسناد مالکیت من", "documents")
			_add_action_button("بازگشت", "help")
		"documents":
			var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
			var owned_docs: Array[Dictionary] = ownership_ledger.get_documents_for(peer_id) if ownership_ledger else []
			_clear_actions()
			notice = "اسناد مالکیت معتبر: %d" % owned_docs.size()
			for document in owned_docs:
				var doc_id := str(document.document_id)
				_add_action_button("%s | %s" % [doc_id, document.item_id], "select_document", doc_id)
			_add_action_button("فروش سند انتخاب‌شده به NPC", "sell_npc")
			_add_action_button("خرید کالای انتخاب‌شده از NPC", "npc_buy", "لباس رسمی")
			transfer_target_input = LineEdit.new()
			transfer_target_input.placeholder_text = "شناسه بازیکن مقصد (مثلاً 2)"
			panel.get_child(0).add_child(transfer_target_input)
			_add_action_button("انتقال سند انتخاب‌شده به بازیکن", "transfer_player")
		"select_document":
			selected_document_id = arg
			var selected_doc: Dictionary = ownership_ledger.get_document(arg) if ownership_ledger else {}
			notice = "سند مالکیت: %s\nکالا: %s\nمالک: %s\nقیمت خرید: %s\nسابقه انتقال: %s" % [arg, selected_doc.get("item_id", "-"), selected_doc.get("owner_name", "-"), selected_doc.get("purchase_price", 0), str(selected_doc.get("history", []))]
		"sell_npc":
			if ownership_ledger and not selected_document_id.is_empty():
				ownership_ledger.request_npc_sale(selected_document_id)
				notice = "درخواست فروش به NPC ارسال شد."
			else:
				notice = "ابتدا یک سند را انتخاب کن."
		"npc_buy":
			if ownership_ledger:
				ownership_ledger.request_npc_purchase(arg)
				notice = "درخواست خرید از NPC ارسال شد."
		"transfer_player":
			if ownership_ledger and not selected_document_id.is_empty() and transfer_target_input:
				ownership_ledger.request_player_transfer(selected_document_id, int(transfer_target_input.text))
				notice = "درخواست انتقال مالکیت ارسال شد."
			else:
				notice = "سند و شناسه بازیکن مقصد را مشخص کن."
		"intel":
			notice = "وزارت اطلاعات | پرونده‌های کاملاً خیالی"
			_add_action_button("ثبت گزارش مالی مشکوک", "report")
			_add_action_button("نمایش پرونده‌ها", "reports")
			_add_action_button("نمایش پول سیاه آزمایشی", "black")
		"report":
			reports.append("گزارش مالی شماره " + str(reports.size() + 1) + " | نیازمند بررسی")
			notice = "گزارش ثبت شد؛ هنوز حکم یا اتهامی صادر نشده است"
		"reports":
			notice = "پرونده‌ها: " + str(reports)
		"black":
			notice = "پول سیاه صرفاً امتیاز داستانی و جدا از موجودی بانکی است: %d" % player_black_money
		"palace":
			notice = "کاخ ریاست جمهوری | ساختمان تشریفاتی و مرکز جلسات"
			_add_action_button("بازدید از لابی", "place", "لابی کاخ")
			_add_action_button("بازدید از سالن جلسات", "place", "سالن جلسات")
			_add_action_button("بازدید از دفتر ریاست جمهوری", "place", "دفتر ریاست جمهوری")
		"military":
			notice = "ستاد کل نیروهای مسلح | انتخاب شاخه"
			for department in DEPARTMENTS:
				_add_action_button(department, "department", department)
		"department":
			notice = "فرماندهی انتخاب‌شده: %s | مأموریت‌های نمایشی: گشت، دفاع، پشتیبانی و استقرار" % arg
			_add_action_button("ثبت مأموریت گشت", "mission", arg + " - گشت")
			_add_action_button("ثبت مأموریت دفاع", "mission", arg + " - دفاع")
		"mission":
			notice = "مأموریت داستانی ثبت شد: " + arg
		"civic":
			notice = "خدمات عمومی شهر"
			_add_action_button("ثبت گزارش به پلیس", "police")
			_add_action_button("درخواست مجوز از دولت", "permit")
		"police":
			notice = "گزارش پلیس ثبت شد؛ کد پیگیری: LC-%04d" % (reports.size() + 1)
		"permit":
			notice = "درخواست مجوز آزمایشی ثبت شد"
		"place":
			notice = "موقعیت انتخاب‌شده: " + arg + " | فضای داخلی در نسخه بعدی کامل‌تر می‌شود"
		"help":
			notice = "این مرحله نمونه اولیه سیستم‌های بانک، فروشگاه، پرونده، خدمات دولتی و ستاد کل است."
	_refresh()

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("2878d5")
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("3689e8")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("1e5eaa")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 16)
