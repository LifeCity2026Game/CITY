extends Node
## Integrated LIFE CITY mobile, commerce, garage, citizen and rank prototype.
signal notice_changed(message: String)

var ledger: Node
var player: CharacterBody3D
var vehicle: CharacterBody3D
var network: Node
var phone_panel: PanelContainer
var notice_label: Label
var details_label: Label
var target_input: LineEdit
var amount_input: LineEdit
var order_list: Array[Dictionary] = []
var sim_cards: Array[Dictionary] = []
var roles: Dictionary = {1: "سازنده"}
var placed_furniture: Array[String] = []
var owned_homes: Array[String] = []
var owned_vehicles: Array[String] = []
var game_day_seconds := 0.0
var active_page := "home"

const GAME_DAY_LENGTH := 360.0
const ONLINE_PRODUCTS := {
	"گوشی هوشمند": 4500, "گوشی پرچمدار": 9000,
	"کامپیوتر گیمینگ": 18000, "مانیتور گیمینگ": 4200,
	"کنسول بازی": 7000, "دسته بازی": 1200,
	"مبل": 1800, "تخت خواب": 2400, "یخچال": 3200,
	"تلویزیون": 2800, "میز ناهارخوری": 1500, "کمد": 1100
}
const HOME_CATALOG := {"آپارتمان اقتصادی": 22000, "آپارتمان شهری": 48000, "ویلای ساحلی": 95000, "پنت‌هاوس": 140000}
const CAR_PRICES := {"دنا": 14000, "پژو ۲۰۷": 16000, "لندکروزر": 95000, "لکسوس RX": 78000, "فراری": 240000, "لامبورگینی": 320000, "تیبا": 8000, "تیبا ۲": 9000, "پراید": 6000}
const ROLES := ["وزیر", "فرمانده نیروی زمینی", "فرمانده نیروی هوایی", "فرمانده نیروی دریایی", "فرمانده نیروی فضایی", "فرمانده گارد ساحلی", "فرمانده تفنگداران دریایی", "فرمانده گارد ملی"]

func configure(ledger_node: Node, player_node: CharacterBody3D, vehicle_node: CharacterBody3D, network_node: Node) -> void:
	ledger = ledger_node
	player = player_node
	vehicle = vehicle_node
	network = network_node

func _ready() -> void:
	_seed_phone()
	_build_ui()
	_refresh()
	if ledger and ledger.has_signal("balance_changed"):
		ledger.balance_changed.connect(_on_balance_changed)

func _seed_phone() -> void:
	sim_cards = [
		{"number":"09120000001", "carrier":"همراه اول", "data_mb": 0, "accounts":[]},
		{"number":"09350000002", "carrier":"ایرانسل", "data_mb": 0, "accounts":[]}
	]

func _process(delta: float) -> void:
	game_day_seconds += delta
	for order in order_list:
		if not bool(order.get("delivered", false)):
			order["remaining"] = maxf(0.0, float(order.get("remaining", GAME_DAY_LENGTH)) - delta)
			if float(order["remaining"]) <= 0.0:
				order["delivered"] = true
				notice_changed.emit("سفارش تحویل شد: " + str(order.get("item", "")))
	_refresh_status()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LifeCityServicesUI"
	add_child(layer)
	var toggle := Button.new()
	toggle.name = "ServicesToggle"
	toggle.text = "موبایل و خدمات"
	toggle.position = Vector2(18, 18)
	toggle.custom_minimum_size = Vector2(170, 48)
	layer.add_child(toggle)
	toggle.pressed.connect(_toggle_panel)
	phone_panel = PanelContainer.new()
	phone_panel.name = "ServicesPanel"
	phone_panel.anchor_left = 1.0
	phone_panel.anchor_right = 1.0
	phone_panel.offset_left = -360
	phone_panel.offset_right = -12
	phone_panel.offset_top = 72
	phone_panel.offset_bottom = 690
	layer.add_child(phone_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phone_panel.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.name = "Content"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	var heading := Label.new()
	heading.text = "LIFE CITY | موبایل و خدمات شهر"
	layout.add_child(heading)
	notice_label = Label.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(notice_label)
	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(details_label)
	for entry in [
		["خانه", "home"], ["موبایل و سیم‌کارت", "phone"], ["اینترنت‌بانک و چک", "bank"],
		["فروشگاه آنلاین", "online_shop"], ["املاک حضوری", "property"],
		["نمایشگاه خودرو و پارکینگ", "garage"], ["وزارت اطلاعات و مقام‌ها", "intel"]
	]:
		_add_button(layout, entry[0], "page", entry[1])
	phone_panel.visible = false
	notice_changed.connect(func(message: String): notice_label.text = message)

func _content() -> VBoxContainer:
	return phone_panel.get_node("ScrollContainer/Content") as VBoxContainer

func _clear_dynamic() -> void:
	var layout := _content()
	while layout.get_child_count() > 3:
		var child := layout.get_child(layout.get_child_count() - 1)
		layout.remove_child(child)
		child.queue_free()

func _add_button(parent: Node, caption: String, action: String, arg: String = "") -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(300, 42)
	parent.add_child(button)
	button.pressed.connect(_action.bind(action, arg))
	return button

func _add_input(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	_content().add_child(field)
	return field

func _toggle_panel() -> void:
	phone_panel.visible = not phone_panel.visible

func _action(action: String, arg: String = "") -> void:
	if action == "page":
		active_page = arg
		_render_page()
	elif action == "buy_online":
		_buy_online(arg)
	elif action == "buy_home":
		_buy_home(arg)
	elif action == "buy_car":
		_buy_car(arg)
	elif action == "spawn_car":
		_spawn_car(arg)
	elif action == "place_item":
		_place_item(arg)
	elif action == "create_account":
		_create_account(int(arg))
	elif action == "buy_data":
		_buy_data(int(arg))
	elif action == "transfer":
		_transfer()
	elif action == "owner_withdraw":
		_owner_withdraw()
	elif action == "assign_role":
		_assign_role(int(arg))
	_refresh()

func _render_page() -> void:
	_clear_dynamic()
	var layout := _content()
	match active_page:
		"home":
			notice_changed.emit("خدمات بازی از این پنل جداگانه باز می‌شوند.")
		"phone":
			notice_changed.emit("حداکثر دو سیم‌کارت؛ هر سیم‌کارت حداکثر سه حساب بانکی.")
			for i in range(sim_cards.size()):
				var sim: Dictionary = sim_cards[i]
				layout.add_child(_label("%s | %s | اینترنت: %d MB" % [sim.number, sim.carrier, int(sim.data_mb)]))
				_add_button(layout, "خرید بسته اینترنت برای سیم‌کارت %d" % (i + 1), "buy_data", str(i))
				_add_button(layout, "افتتاح حساب روی سیم‌کارت %d" % (i + 1), "create_account", str(i))
				for account in sim.accounts:
					layout.add_child(_label("حساب: %s | موجودی: %d" % [account.number, int(account.balance)]))
		"bank":
			notice_changed.emit("اینترنت‌بانک: انتقال بین شهروندان و حساب‌های NPC.")
			target_input = _add_input("شماره حساب مقصد")
			amount_input = _add_input("مبلغ انتقال")
			amount_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
			_add_button(layout, "انتقال وجه", "transfer")
			_add_button(layout, "صدور چک آزمایشی", "page", "cheques")
			_add_button(layout, "نمایش تراکنش‌ها", "page", "transactions")
		"cheques":
			notice_changed.emit("چک‌ها در این نسخه به‌صورت سند قابل پیگیری و ثبت‌شده نمایش داده می‌شوند.")
			_add_button(layout, "صدور چک ۱۰۰۰ سکه‌ای", "issue_cheque")
		"transactions":
			notice_changed.emit("سوابق تراکنش در دفترکل بانکی ثبت می‌شوند.")
			if ledger:
				for transaction in ledger.cash_transactions.values():
					layout.add_child(_label(str(transaction)))
		"online_shop":
			notice_changed.emit("فروشگاه آنلاین | تحویل سفارش یک روز کامل درون‌بازی بعد از خرید.")
			for item in ONLINE_PRODUCTS:
				_add_button(layout, "%s | %d سکه" % [item, ONLINE_PRODUCTS[item]], "buy_online", item)
			_add_button(layout, "سفارش‌های من", "page", "orders")
		"orders":
			for order in order_list:
				var status := "تحویل شد" if bool(order.delivered) else "در انتظار تحویل: %.0f ثانیه بازی" % float(order.remaining)
				layout.add_child(_label("%s | %s" % [order.item, status]))
				if bool(order.delivered) and str(order.item) in ["مبل","تخت خواب","یخچال","تلویزیون","میز ناهارخوری","کمد"]:
					_add_button(layout, "قرار دادن %s در خانه" % order.item, "place_item", str(order.item))
		"property":
			notice_changed.emit("فروشگاه حضوری املاک | خرید ملک از دفتر داخل شهر.")
			for home in HOME_CATALOG:
				_add_button(layout, "خرید %s | %d سکه" % [home, HOME_CATALOG[home]], "buy_home", home)
			for home in owned_homes:
				layout.add_child(_label("ملک تحت مالکیت: " + home))
		"garage":
			notice_changed.emit("پارکینگ خودروهای خریداری‌شده؛ انتخاب خودرو و اسپاون در شهر.")
			for car in CAR_PRICES:
				_add_button(layout, "خرید %s | %d سکه" % [car, CAR_PRICES[car]], "buy_car", car)
			for car in owned_vehicles:
				_add_button(layout, "اسپاون " + car, "spawn_car", car)
		"intel":
			if not _is_creator():
				notice_changed.emit("این بخش فقط در اختیار سازنده/میزبان است.")
				return
			notice_changed.emit("وزارت اطلاعات | اطلاعات بازیکنان آنلاین و موجودی بانکی")
			var peers: Array[int] = [1]
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				for peer_id in multiplayer.get_peers():
					peers.append(int(peer_id))
			for peer_id in peers:
				var balance := int(ledger.get_balance(peer_id)) if ledger else 0
				layout.add_child(_label("شهروند %d | %s | موجودی %d" % [peer_id, str(roles.get(peer_id, "شهروند")), balance]))
				_add_button(layout, "انتصاب مقام برای شهروند %d" % peer_id, "assign_role", str(peer_id))
			target_input = _add_input("شناسه شهروند برای برداشت")
			amount_input = _add_input("مبلغ برداشت")
			amount_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
			_add_button(layout, "برداشت سازنده از حساب شهروند", "owner_withdraw")

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _get_balance(peer_id: int = 1) -> int:
	return int(ledger.get_balance(peer_id)) if ledger else 10000

func _buy_online(item: String) -> void:
	var price := int(ONLINE_PRODUCTS.get(item, 0))
	if price <= 0 or _get_balance() < price:
		notice_changed.emit("موجودی کافی نیست یا کالا معتبر نیست.")
		return
	if ledger:
		ledger.adjust_balance(1, -price, "online_order:" + item)
	order_list.append({"item":item, "remaining":GAME_DAY_LENGTH, "delivered":false})
	notice_changed.emit("سفارش ثبت شد؛ تحویل پس از یک روز کامل درون‌بازی.")

func _buy_home(home: String) -> void:
	var price := int(HOME_CATALOG.get(home, 0))
	if price <= 0 or _get_balance() < price:
		notice_changed.emit("موجودی کافی نیست.")
		return
	if ledger:
		ledger.adjust_balance(1, -price, "property_purchase:" + home)
		ledger.issue_custom_document(home, 1, price)
	owned_homes.append(home)
	notice_changed.emit("ملک خریداری شد؛ خانه در ابتدا خالی است و باید وسایل بخری.")

func _buy_car(car: String) -> void:
	var price := int(CAR_PRICES.get(car, 0))
	if price <= 0 or _get_balance() < price:
		notice_changed.emit("موجودی کافی نیست.")
		return
	if ledger:
		ledger.adjust_balance(1, -price, "vehicle_purchase:" + car)
		ledger.issue_custom_document(car, 1, price)
	owned_vehicles.append(car)
	notice_changed.emit("خودرو خریداری شد و به پنل پارکینگ اضافه شد.")

func _spawn_car(car: String) -> void:
	if not vehicle or not owned_vehicles.has(car):
		notice_changed.emit("این خودرو در مالکیت تو نیست.")
		return
	var selector := vehicle.controls_layer.get_node_or_null("ModelSelector") as Button
	if selector:
		for i in range(vehicle.VEHICLE_CATALOG.size()):
			if str(vehicle.VEHICLE_CATALOG[vehicle.model_index].name) == car:
				break
			vehicle._cycle_vehicle_model()
	vehicle.global_position = player.global_position + -player.global_transform.basis.z * 5.0
	vehicle.global_rotation.y = player.global_rotation.y
	notice_changed.emit("خودرو در نزدیکی تو اسپاون شد.")

func _place_item(item: String) -> void:
	if not owned_homes.size() > 0:
		notice_changed.emit("برای چیدن وسایل ابتدا باید خانه بخری.")
		return
	if not placed_furniture.has(item):
		placed_furniture.append(item)
	notice_changed.emit("وسیله در فهرست چیدمان خانه ثبت شد: " + item)

func _create_account(sim_index: int) -> void:
	if sim_index < 0 or sim_index >= sim_cards.size():
		return
	var accounts: Array = sim_cards[sim_index].accounts
	if accounts.size() >= 3:
		notice_changed.emit("برای این سیم‌کارت سه حساب ساخته شده است.")
		return
	var account_number := "LC-%d-%03d" % [sim_index + 1, accounts.size() + 1]
	accounts.append({"number":account_number, "balance":0, "pin":"0000"})
	sim_cards[sim_index].accounts = accounts
	notice_changed.emit("حساب جدید ساخته شد: " + account_number)

func _buy_data(sim_index: int) -> void:
	if sim_index < 0 or sim_index >= sim_cards.size() or _get_balance() < 250:
		notice_changed.emit("خرید بسته اینترنت ناموفق بود.")
		return
	if ledger:
		ledger.adjust_balance(1, -250, "mobile_data_bundle")
	sim_cards[sim_index].data_mb = int(sim_cards[sim_index].data_mb) + 5000
	notice_changed.emit("بسته ۵ گیگابایتی فعال شد.")

func _transfer() -> void:
	if target_input == null or amount_input == null:
		return
	var amount := int(amount_input.text)
	if amount <= 0:
		notice_changed.emit("مبلغ معتبر نیست.")
		return
	if ledger:
		ledger.request_player_cash_transfer(int(target_input.text), amount)
		notice_changed.emit("درخواست انتقال ثبت شد؛ تأیید و موجودی توسط دفترکل سرور مدیریت می‌شود.")

func _is_creator() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _owner_withdraw() -> void:
	if not _is_creator() or target_input == null or amount_input == null or ledger == null:
		notice_changed.emit("برداشت فقط برای سازنده و میزبان مجاز است.")
		return
	var target := int(target_input.text)
	var amount := int(amount_input.text)
	if ledger.owner_withdraw(target, amount):
		notice_changed.emit("برداشت سازنده ثبت شد و در سابقه مالی ذخیره شد.")
	else:
		notice_changed.emit("برداشت ناموفق: شناسه یا موجودی نامعتبر است.")

func _assign_role(peer_id: int) -> void:
	if not _is_creator():
		return
	var role := ROLES[mini(roles.size() % ROLES.size(), ROLES.size() - 1)]
	roles[peer_id] = role
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc("sync_role", peer_id, role)
	notice_changed.emit("مقام شهروند %d تغییر کرد: %s" % [peer_id, role])

@rpc("authority", "call_remote", "reliable")
func sync_role(peer_id: int, role: String) -> void:
	roles[peer_id] = role

func _on_balance_changed(_peer_id: int, _balance: int) -> void:
	if active_page == "intel":
		_render_page()

func _refresh_status() -> void:
	if is_instance_valid(details_label):
		details_label.text = "نقش: %s | روز بازی: %d" % [str(roles.get(1, "شهروند")), int(game_day_seconds / GAME_DAY_LENGTH) + 1]

func _refresh() -> void:
	_refresh_status()
	if is_instance_valid(notice_label) and notice_label.text.is_empty():
		notice_label.text = "آماده"
