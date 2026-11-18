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

func _ready() -> void:
	_seed_npcs()
	_build_interface()
	_refresh()

func _seed_npcs() -> void:
	for i in range(12):
		var id := "NPC" + str(1000 + i)
		npc_accounts[id] = {"name": "شهروند " + str(i + 1), "balance": 1200 + i * 275, "job": "شهروند"}

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
	_add_button(layout, "وزارت اطلاعات و پرونده‌ها", "intel")
	_add_button(layout, "کاخ ریاست جمهوری", "palace")
	_add_button(layout, "ستاد کل و هفت نیرو", "military")
	_add_button(layout, "پلیس و ساختمان دولت", "civic")
	_add_button(layout, "راهنمای خدمات", "help")

func _add_button(parent: VBoxContainer, caption: String, action: String) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(290, 38)
	b.pressed.connect(_on_action.bind(action))
	parent.add_child(b)

func _add_action_button(caption: String, action: String, arg: String = "") -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(290, 34)
	b.pressed.connect(_on_action.bind(action, arg))
	panel.get_child(0).add_child(b)

func _clear_actions() -> void:
	var layout := panel.get_child(0) as VBoxContainer
	while layout.get_child_count() > 10:
		var child := layout.get_child(layout.get_child_count() - 1)
		layout.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	status_label.text = notice
	details_label.text = "موجودی: %d سکه | پول سیاه: %d" % [player_balance, player_black_money]

func _on_action(action: String, arg: String = "") -> void:
	_clear_actions()
	match action:
		"bank":
			notice = "بانک آزمایشی | انتقال فقط با موجودی کافی"
			_add_action_button("نمایش حساب NPC1000", "resolve", "NPC1000")
			_add_action_button("انتقال ۵۰۰ سکه به NPC1000", "transfer", "NPC1000")
			_add_action_button("دریافت ۳۰۰ سکه از NPC1000", "withdraw", "NPC1000")
			_add_action_button("تراکنش با حساب ناموجود (آزمایش)", "resolve", "UNKNOWN")
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
			notice = "فروشگاه اینترنتی | خرید با پول داخل بازی"
			for item in SHOP:
				_add_action_button("خرید %s | %d" % [item, SHOP[item]], "buy", item)
			_add_action_button("نمایش سفارش‌ها", "orders")
		"buy":
			var price: int = SHOP.get(arg, 0)
			if price > 0 and player_balance >= price:
				player_balance -= price
				owned_items.append(arg)
				orders.append({"item": arg, "status": "در انتظار تحویل"})
				notice = "سفارش ثبت شد: " + arg
			else:
				notice = "خرید انجام نشد: موجودی کافی نیست"
		"orders":
			notice = "سفارش‌های ثبت‌شده: " + str(orders)
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
