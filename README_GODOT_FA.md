# LIFE CITY — Godot 4

این مخزن به‌صورت اختصاصی برای **Godot Engine 4** نگهداری می‌شود. پروژه با GDScript نوشته شده و برای اجرای موبایل از رندرر Mobile استفاده می‌کند.

## نیازمندی‌ها
- Godot 4.7.2 یا نسخه سازگار 4.x
- Android SDK و OpenJDK 17 برای خروجی Android
- قالب‌های Export متناسب با نسخه Godot برای ساخت APK

## اجرای پروژه
پروژه را در Godot Import کنید و صحنهٔ اصلی `res://scenes/main.tscn` را اجرا کنید.

## ساخت APK
تنظیمات خروجی Android در `export_presets.cfg` قرار دارد. گردش‌کار خودکار ساخت APK در `.github/workflows/build-godot-android.yml` تعریف شده است. خروجی فقط پس از موفقیت workflow به‌عنوان artifact قابل دریافت خواهد بود.

## ساختار
- `project.godot`: تنظیمات پروژه
- `scenes/`: صحنه‌های بازی
- `scripts/`: اسکریپت‌های GDScript
- `.github/workflows/build-godot-android.yml`: ساخت خودکار APK

## وضعیت
بازی هنوز در حال توسعه است. شهر، بازیکن و رابط‌های اولیه وجود دارند؛ سیستم‌های اقتصاد، بانک، فروشگاه، NPC و خدمات شهری در حد نمونه اولیه‌اند. وجود این نمونه‌ها به معنی تکمیل نهایی یا تست کامل آن‌ها نیست.
