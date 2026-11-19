extends Node
## Integrated LIFE CITY mobile, commerce, garage, citizen and rank prototype.
signal notice_changed(message: String)

var ledger: Node
var player: CharacterBody3D
var vehicle: CharacterBody3D
var network: Node
var phone_panel: PanelContainer
var content_layout: VBoxContainer
var notice_label: Label
var details_label: Label
var target_input: LineEdit
var amount_input: LineEdit
var pin_input: LineEdit
var order_list: Array[Dictionary] = []
var sim_cards: Array[Dictionary] = []
var roles: Dictionary = {1: "سازنده"}
var placed_furniture: Array[String] = []
var cheques: Array[Dictionary] = []
var owned_homes: Array[String] = []
var owned_vehicles: Array[String] = []
var game_day_seconds := 0.0
var active_page := "home"
var home_interior: Node3D
var previous_player_position := Vector3.ZERO
var inside_owned_home := false
var selected_role: String = "وزیر"

const GAME_DAY_LENGTH := 360.0
const ONLINE_PRODUCTS := {
	"گوشی هوشمند": 4500, "گوشی پرچمدار": 9000,
	"کامپیوتر گیمینگ": 18000, "مانیتور گیمینگ": 4200,
	"کنسول بازی": 7000, "دسته بازی": 1200,
	"مبل": 1800, "تخت خواب": 2400, "یخچال": 3200,
	"تلویزیون": 2800, "میز ناهارخوری": 1500, "کمد": 1100
}
const HOME_CATALOG := {"خانه اقتصادی": 18000, "آپارتمان اقتصادی": 22000, "خانه جنوب شهر": 30000, "آپارتمان شهری": 48000, "خانه شمال شهر": 65000, "خانه ساحلی": 80000, "ویلای ساحلی": 95000, "پنت‌هاوس": 140000}
const CAR_PRICES := {"دنا": 14000, "پژو ۲۰۷": 16000, "لندکروزر": 95000, "لکسوس RX": 78000, "فراری": 240000, "لامبورگینی": 320000, "تیبا": 8000, "تیبا ۲": 9000, "پراید": 6000}
const ROLES := ["وزیر", "فرمانده نیروی زمینی", "فرمانده نیروی هوایی", "فرمانده نیروی دریایی", "فرمانده نیروی فضایی", "فرمانده گارد ساحلی", "فرمانده تفنگداران دریایی", "فرمانده گارد ملی"]

func configure(ledger_node: Node, player_node: CharacterBody3D, vehicle_node: CharacterBody3D, network_node: Node) -> void:
	ledger = ledger_node
	player = player_node
	vehicle = vehicle_node
	network = network_node
	if ledger and ledger.has_signal("balance_changed") and not ledger.balance_changed.is_connected(_on_balance_changed):
		ledger.balance_changed.connect(_on_balance_changed)
	if not multiplayer.peer_connected.is_connected(_on_peer_list_changed):
		multiplayer.peer_connected.connect(_on_peer_list_changed)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_list_changed):
		multiplayer.peer_disconnected.connect(_on_peer_list_changed)

func _ready() -> void:
	_seed_phone()
	_load_services()
	_build_home_interior()
	_restore_furniture()
	_build_ui()
	_refresh()
	if ledger and ledger.has_signal("balance_changed"):
		ledger.balance_changed.connect(_on_balance_changed)

func _seed_phone() -> void:
	var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	sim_cards = [
		{"number":"0912%07d" % (1200000 + peer_id), "carrier":"همراه اول", "data_mb": 0, "accounts":[]}
	]

func _process(delta: float) -> void:
	game_day_seconds += delta
	var delivery_changed := false
	for order in order_list:
		if not bool(order.get("delivered", false)):
			order["remaining"] = maxf(0.0, float(order.get("remaining", GAME_DAY_LENGTH)) - delta)
			if float(order["remaining"]) <= 0.0:
				order["delivered"] = true
				delivery_changed = true
				notice_changed.emit("سفارش تحویل شد: " + str(order.get("item", "")))
	if delivery_changed:
		_save_services()
	_refresh_status()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LifeCityServicesUI"
	add_child(layer)
	var toggle := Button.new()
	toggle.name = "ServicesToggle"
	toggle.text = "موبایل و خدمات"
	toggle.position = Vector2(18, 136)
	toggle.custom_minimum_size = Vector2(170, 48)
	layer.add_child(toggle)
	toggle.pressed.connect(_toggle_panel)
	phone_panel = PanelContainer.new()
	phone_panel.name = "ServicesPanel"
	phone_panel.anchor_left = 0.0
	phone_panel.anchor_right = 0.0
	phone_panel.offset_left = 12
	phone_panel.offset_right = 360
	phone_panel.offset_top = 190
	phone_panel.offset_bottom = 680
	layer.add_child(phone_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phone_panel.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.name = "Content"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	content_layout = layout
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
	return content_layout

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
	elif action == "buy_sim":
		_buy_sim()
	elif action == "transfer":
		_transfer()
	elif action == "issue_cheque":
		_issue_cheque()
	elif action == "enter_home":
		_enter_home()
	elif action == "exit_home":
		_exit_home()
	elif action == "owner_withdraw":
		_owner_withdraw()
	elif action == "assign_role":
		_assign_role(int(arg))
	_refresh()
	_save_services()

func _render_page() -> void:
	_clear_dynamic()
	var layout := _content()
	match active_page:
		"home":
			notice_changed.emit("خدمات بازی از این پنل جداگانه باز می‌شوند.")
		"phone":
			notice_changed.emit("حداکثر دو سیم‌کارت؛ هر سیم‌کارت حداکثر سه حساب بانکی.")
			pin_input = _add_input("رمز چهار تا هشت رقمی حساب")
			if sim_cards.size() < 2:
				_add_button(layout, "خرید سیم‌کارت دوم", "buy_sim")
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
			notice_changed.emit("چک‌ها و شناسه پیگیری آن‌ها.")
			_add_button(layout, "صدور چک ۱۰۰۰ سکه‌ای", "issue_cheque")
			for cheque in cheques:
				layout.add_child(_label("%s | %s | %d" % [cheque.id, cheque.status, int(cheque.amount)]))
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
			_add_button(layout, "ورود به خانه و چیدمان وسایل", "enter_home")
			_add_button(layout, "خروج از خانه", "exit_home")
		"garage":
			notice_changed.emit("پارکینگ خودروهای خریداری‌شده؛ انتخاب خودرو و اسپاون در شهر.")
			for car in CAR_PRICES:
				_add_button(layout, "خرید %s | %d سکه" % [car, CAR_PRICES[car]], "buy_car", car)
			var garage_cars: Array[String] = owned_vehicles.duplicate()
			if ledger:
				var owner_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
				for document in ledger.get_documents_for(owner_id):
					var item_name := str(document.get("item_id", ""))
					if CAR_PRICES.has(item_name) and not garage_cars.has(item_name):
						garage_cars.append(item_name)
			for car in garage_cars:
				_add_button(layout, "اسپاون " + car, "spawn_car", car)
		"intel":
			if not _is_creator():
				notice_changed.emit("این بخش فقط در اختیار سازنده/میزبان است.")
				return
			notice_changed.emit("وزارت اطلاعات | اطلاعات بازیکنان آنلاین و موجودی بانکی")
			var role_picker := OptionButton.new()
			for role_name in ROLES:
				role_picker.add_item(role_name)
			role_picker.item_selected.connect(func(index: int): selected_role = ROLES[index])
			layout.add_child(role_picker)
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
	var actual_peer := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else peer_id
	return int(ledger.get_balance(actual_peer)) if ledger else 10000

func _buy_online(item: String) -> void:
	var price := int(ONLINE_PRODUCTS.get(item, 0))
	if price <= 0 or _get_balance() < price:
		notice_changed.emit("موجودی کافی نیست یا کالا معتبر نیست.")
		return
	if ledger:
		ledger.request_purchase(item)
	order_list.append({"item":item, "remaining":GAME_DAY_LENGTH, "delivered":false})
	notice_changed.emit("سفارش ثبت شد؛ تحویل پس از یک روز کامل درون‌بازی.")

func _buy_home(home: String) -> void:
	var price := int(HOME_CATALOG.get(home, 0))
	if price <= 0 or _get_balance() < price:
		notice_changed.emit("موجودی کافی نیست.")
		return
	if ledger:
		ledger.request_purchase(home)
	owned_homes.append(home)
	notice_changed.emit("ملک خریداری شد؛ خانه در ابتدا خالی است و باید وسایل بخری.")

func _buy_car(car: String) -> void:
	var price := int(CAR_PRICES.get(car, 0))
	if price <= 0 or _get_balance() < price:
		notice_changed.emit("موجودی کافی نیست.")
		return
	if ledger:
		ledger.request_purchase(car)
	owned_vehicles.append(car)
	notice_changed.emit("خودرو خریداری شد و به پنل پارکینگ اضافه شد.")

func _spawn_car(car: String) -> void:
	var has_car := owned_vehicles.has(car)
	if ledger:
		var owner_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		for document in ledger.get_documents_for(owner_id):
			if str(document.get("item_id", "")) == car:
				has_car = true
	if not vehicle or not has_car:
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
	var furniture_positions := {
		"مبل": Vector3(-2.8, 0.55, -2.0), "تخت خواب": Vector3(2.7, 0.35, -2.2),
		"یخچال": Vector3(-5.2, 1.0, -5.2), "تلویزیون": Vector3(0, 1.1, -6.2),
		"میز ناهارخوری": Vector3(3.8, 0.55, 2.4), "کمد": Vector3(5.3, 1.1, -1.8)
	}
	var dimensions := {
		"مبل": Vector3(2.8, 1.1, 1.0), "تخت خواب": Vector3(2.4, 0.7, 2.0),
		"یخچال": Vector3(1.0, 2.0, 1.0), "تلویزیون": Vector3(1.8, 1.1, 0.15),
		"میز ناهارخوری": Vector3(2.0, 1.1, 1.3), "کمد": Vector3(1.2, 2.2, 0.7)
	}
	_home_box("Furniture_" + item, furniture_positions.get(item, Vector3.ZERO), dimensions.get(item, Vector3.ONE), Color(0.28, 0.34, 0.42))
	notice_changed.emit("وسیله داخل خانه چیده شد: " + item)

func _create_account(sim_index: int) -> void:
	if sim_index < 0 or sim_index >= sim_cards.size():
		return
	var accounts: Array = sim_cards[sim_index].accounts
	if accounts.size() >= 3:
		notice_changed.emit("برای این سیم‌کارت سه حساب ساخته شده است.")
		return
	if pin_input == null or pin_input.text.length() < 4 or pin_input.text.length() > 8 or not pin_input.text.is_valid_int():
		notice_changed.emit("رمز حساب باید بین ۴ تا ۸ رقم باشد.")
		return
	var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var account_number := "LC-%04d-%d-%03d" % [peer_id, sim_index + 1, accounts.size() + 1]
	accounts.append({"number":account_number, "balance":_get_balance(), "pin":pin_input.text})
	sim_cards[sim_index].accounts = accounts
	notice_changed.emit("حساب جدید ساخته شد: " + account_number)


func _buy_sim() -> void:
	if sim_cards.size() >= 2:
		notice_changed.emit("هر شهروند حداکثر دو سیم‌کارت می‌تواند داشته باشد.")
		return
	if _get_balance() < 500:
		notice_changed.emit("برای خرید سیم‌کارت ۵۰۰ سکه لازم است.")
		return
	if ledger:
		ledger.request_adjust_balance(-500, "telecom_sim_purchase")
	var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	sim_cards.append({"number":"0935%07d" % (2300000 + peer_id), "carrier":"ایرانسل", "data_mb":0, "accounts":[]})
	notice_changed.emit("سیم‌کارت دوم خریداری شد.")

func _buy_data(sim_index: int) -> void:
	if sim_index < 0 or sim_index >= sim_cards.size() or _get_balance() < 250:
		notice_changed.emit("خرید بسته اینترنت ناموفق بود.")
		return
	if ledger:
		ledger.request_adjust_balance(-250, "mobile_data_bundle")
	sim_cards[sim_index].data_mb = int(sim_cards[sim_index].data_mb) + 5000
	notice_changed.emit("بسته ۵ گیگابایتی فعال شد.")

func _issue_cheque() -> void:
	var cheque_id := "LC-CHQ-%04d" % (cheques.size() + 1)
	cheques.append({"id": cheque_id, "issuer": 1, "amount": 1000, "status": "صادر شده"})
	notice_changed.emit("چک آزمایشی ثبت شد: " + cheque_id)

func _transfer() -> void:
	if target_input == null or amount_input == null:
		return
	var amount := int(amount_input.text)
	if amount <= 0:
		notice_changed.emit("مبلغ معتبر نیست.")
		return
	var target_text := target_input.text.strip_edges()
	var target_peer := int(target_text)
	if target_text.begins_with("LC-"):
		var parts := target_text.split("-")
		if parts.size() >= 4:
			target_peer = int(parts[1])
	if target_peer <= 0:
		notice_changed.emit("شماره حساب مقصد معتبر نیست.")
		return
	if ledger:
		ledger.request_player_cash_transfer(target_peer, amount)
		notice_changed.emit("درخواست انتقال ثبت شد؛ موجودی و تراکنش در دفترکل ثبت می‌شود.")

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
	var role: String = selected_role
	roles[peer_id] = role
	_save_services()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		rpc("sync_role", peer_id, role)
	notice_changed.emit("مقام شهروند %d تغییر کرد: %s" % [peer_id, role])

@rpc("authority", "call_remote", "reliable")
func sync_role(peer_id: int, role: String) -> void:
	roles[peer_id] = role

func _on_balance_changed(_peer_id: int, _balance: int) -> void:
	if active_page == "intel":
		_render_page()

func _on_peer_list_changed(_peer_id: int) -> void:
	if active_page == "intel":
		_render_page()

func _refresh_status() -> void:
	if is_instance_valid(details_label):
		var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		details_label.text = "نقش: %s | روز بازی: %d" % [str(roles.get(peer_id, "شهروند")), int(game_day_seconds / GAME_DAY_LENGTH) + 1]

func _refresh() -> void:
	_refresh_status()
	if is_instance_valid(notice_label) and notice_label.text.is_empty():
		notice_label.text = "آماده"

func _build_home_interior() -> void:
	home_interior = Node3D.new()
	home_interior.name = "OwnedHomeInterior"
	home_interior.position = Vector3(360, 0, 0)
	add_child(home_interior)
	var floor_body := StaticBody3D.new()
	floor_body.name = "HomeFloorCollision"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(14, 0.3, 14)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.15
	home_interior.add_child(floor_body)
	_home_box("Floor", Vector3(0, -0.16, 0), Vector3(14, 0.25, 14), Color(0.48, 0.39, 0.29))
	_home_box("BackWall", Vector3(0, 2.0, -7), Vector3(14, 4, 0.25), Color(0.78, 0.76, 0.70))
	_home_box("LeftWall", Vector3(-7, 2.0, 0), Vector3(0.25, 4, 14), Color(0.72, 0.74, 0.72))
	_home_box("RightWall", Vector3(7, 2.0, 0), Vector3(0.25, 4, 14), Color(0.72, 0.74, 0.72))
	_home_box("FrontLeftWall", Vector3(-5.0, 2.0, 7), Vector3(4, 4, 0.25), Color(0.72, 0.74, 0.72))
	_home_box("FrontRightWall", Vector3(5.0, 2.0, 7), Vector3(4, 4, 0.25), Color(0.72, 0.74, 0.72))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.65, 0.82, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var window := MeshInstance3D.new()
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(5.5, 2.2, 0.08)
	window.mesh = window_mesh
	window.material_override = glass
	window.position = Vector3(0, 2.4, 6.85)
	home_interior.add_child(window)
	var sign := Label3D.new()
	sign.text = "خانه من | فضای داخلی قابل چیدمان"
	sign.position = Vector3(0, 3.4, -6.7)
	home_interior.add_child(sign)

func _home_box(label: String, pos: Vector3, dimensions: Vector3, color: Color) -> void:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	item.material_override = material
	item.position = pos
	home_interior.add_child(item)

func _enter_home() -> void:
	if owned_homes.is_empty():
		notice_changed.emit("ابتدا باید از فروشگاه حضوری یک خانه بخری.")
		return
	if inside_owned_home:
		return
	previous_player_position = player.global_position
	player.global_position = home_interior.global_position + Vector3(0, 1.2, 4)
	player.velocity = Vector3.ZERO
	inside_owned_home = true
	notice_changed.emit("وارد خانه شدی؛ وسایل خریداری‌شده را از سفارش‌های تحویل‌شده بچین.")

func _exit_home() -> void:
	if not inside_owned_home:
		return
	player.global_position = previous_player_position
	player.velocity = Vector3.ZERO
	inside_owned_home = false
	notice_changed.emit("از خانه خارج شدی.")

func _save_services() -> void:
	var payload := {
		"sim_cards": sim_cards, "order_list": order_list, "roles": roles,
		"placed_furniture": placed_furniture, "cheques": cheques,
		"owned_homes": owned_homes, "owned_vehicles": owned_vehicles,
		"game_day_seconds": game_day_seconds
	}
	var file := FileAccess.open("user://life_city_services.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func _load_services() -> void:
	if not FileAccess.file_exists("user://life_city_services.json"):
		return
	var file := FileAccess.open("user://life_city_services.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var saved_sims: Array = parsed.get("sim_cards", [])
	if not saved_sims.is_empty():
		sim_cards.clear()
		for sim in saved_sims:
			if sim is Dictionary:
				sim_cards.append(sim)
	for order in parsed.get("order_list", []):
		if order is Dictionary:
			order_list.append(order)
	for key in parsed.get("roles", {}).keys():
		roles[int(key)] = str(parsed.roles[key])
	for item in parsed.get("placed_furniture", []):
		placed_furniture.append(str(item))
	for cheque in parsed.get("cheques", []):
		if cheque is Dictionary:
			cheques.append(cheque)
	for home in parsed.get("owned_homes", []):
		owned_homes.append(str(home))
	for car in parsed.get("owned_vehicles", []):
		owned_vehicles.append(str(car))
	game_day_seconds = float(parsed.get("game_day_seconds", 0.0))

func _restore_furniture() -> void:
	var furniture_positions := {
		"مبل": Vector3(-2.8, 0.55, -2.0), "تخت خواب": Vector3(2.7, 0.35, -2.2),
		"یخچال": Vector3(-5.2, 1.0, -5.2), "تلویزیون": Vector3(0, 1.1, -6.2),
		"میز ناهارخوری": Vector3(3.8, 0.55, 2.4), "کمد": Vector3(5.3, 1.1, -1.8)
	}
	var dimensions := {
		"مبل": Vector3(2.8, 1.1, 1.0), "تخت خواب": Vector3(2.4, 0.7, 2.0),
		"یخچال": Vector3(1.0, 2.0, 1.0), "تلویزیون": Vector3(1.8, 1.1, 0.15),
		"میز ناهارخوری": Vector3(2.0, 1.1, 1.3), "کمد": Vector3(1.2, 2.2, 0.7)
	}
	for item in placed_furniture:
		_home_box("Furniture_" + item, furniture_positions.get(item, Vector3.ZERO), dimensions.get(item, Vector3.ONE), Color(0.28, 0.34, 0.42))
