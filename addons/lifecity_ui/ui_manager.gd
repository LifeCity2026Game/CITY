extends Node
## Shared responsive UI helpers for LIFE CITY.
## This styles existing controls without changing their signal connections or actions.

const MIN_TOUCH_HEIGHT := 48.0
const MIN_TOUCH_WIDTH := 48.0

func apply_to_tree(root: Node) -> void:
	if root is Control:
		_style_control(root as Control)
	for child in root.get_children():
		apply_to_tree(child)

func _style_control(control: Control) -> void:
	if control is Button:
		var button := control as Button
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, MIN_TOUCH_HEIGHT)
		button.add_theme_font_size_override("font_size", maxi(button.get_theme_font_size("font_size"), 16))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_button(button)
	elif control is OptionButton:
		var option_button := control as OptionButton
		option_button.custom_minimum_size.y = maxf(option_button.custom_minimum_size.y, MIN_TOUCH_HEIGHT)
		_style_button(option_button)
	elif control is LineEdit:
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, MIN_TOUCH_HEIGHT)
	elif control is CheckBox or control is CheckButton:
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, MIN_TOUCH_HEIGHT)

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("263f5d")
	normal.border_color = Color("7597bd")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("345b82")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("1b3048")
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("343b45")
	disabled.border_color = Color("555f6b")

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("aab2bc"))

## Safe-area layout for large panels. Ratios keep panels usable on phones and tablets.
func apply_safe_panel_layout(
	panel: Control,
	left_ratio: float = 0.055,
	top_ratio: float = 0.12,
	right_ratio: float = 0.945,
	bottom_ratio: float = 0.91
) -> void:
	panel.anchor_left = clampf(left_ratio, 0.0, 0.45)
	panel.anchor_top = clampf(top_ratio, 0.0, 0.45)
	panel.anchor_right = clampf(right_ratio, 0.55, 1.0)
	panel.anchor_bottom = clampf(bottom_ratio, 0.55, 1.0)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0

## Positions a square touch control in a screen corner without relying on fixed screen pixels.
func dock_touch_control(
	control: Control,
	corner: StringName = &"bottom_right",
	size: float = 56.0,
	margin: float = 22.0
) -> void:
	var target_size := maxf(size, MIN_TOUCH_WIDTH)
	control.custom_minimum_size = Vector2(target_size, maxf(size, MIN_TOUCH_HEIGHT))
	match corner:
		&"top_left":
			control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			control.offset_left = margin
			control.offset_top = margin
			control.offset_right = margin + target_size
			control.offset_bottom = margin + target_size
		&"top_right":
			control.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			control.offset_left = -margin - target_size
			control.offset_top = margin
			control.offset_right = -margin
			control.offset_bottom = margin + target_size
		&"bottom_left":
			control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
			control.offset_left = margin
			control.offset_top = -margin - target_size
			control.offset_right = margin + target_size
			control.offset_bottom = -margin
		_:
			control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			control.offset_left = -margin - target_size
			control.offset_top = -margin - target_size
			control.offset_right = -margin
			control.offset_bottom = -margin
