#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🔄 Tayar App Import Updater
يحدّث كل الـ imports القديمة للجديدة تلقائياً في كل ملفات المشروع

طريقة الاستخدام:
    1. احفظ الملف ده في مجلد المشروع (نفس مستوى pubspec.yaml)
    2. شغله: python update_imports.py
    3. هيطبع لك تقرير بكل الملفات اللي اتعدلت
"""

import os
import shutil
from datetime import datetime

# ====== الإعدادات ======
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
LIB_DIR = os.path.join(PROJECT_ROOT, 'lib')
BACKUP_DIR = os.path.join(PROJECT_ROOT, 'import_backup_' + datetime.now().strftime('%Y%m%d_%H%M%S'))

# ====== قائمة الـ Imports اللي هتتغيّر ======
# الشكل: (النص القديم, النص الجديد)
IMPORT_REPLACEMENTS = [
    # 1. passenger_home.dart
    (
        "import 'package:tayay_app/screens/passenger/passenger_home.dart';",
        "import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart';\n"
        "import 'package:tayay_app/screens/passenger/home/passenger_home_controller.dart';"
    ),

    # 2. searching_offers_screen.dart
    (
        "import 'package:tayay_app/screens/passenger/searching_offers_screen.dart';",
        "import 'package:tayay_app/screens/passenger/searching_offers/searching_offers_screen.dart';\n"
        "import 'package:tayay_app/screens/passenger/searching_offers/searching_offers_controller.dart';"
    ),

    # 3. trip_tracking_screen.dart
    (
        "import 'package:tayay_app/screens/passenger/trip_tracking_screen.dart';",
        "import 'package:tayay_app/screens/passenger/trip_tracking/trip_tracking_screen.dart';\n"
        "import 'package:tayay_app/screens/passenger/trip_tracking/trip_tracking_controller.dart';"
    ),

    # 4. order_confirmation_screen.dart
    (
        "import 'package:tayay_app/screens/passenger/order_confirmation_screen.dart';",
        "import 'package:tayay_app/screens/passenger/order_confirmation/order_confirmation_screen.dart';\n"
        "import 'package:tayay_app/screens/passenger/order_confirmation/order_confirmation_controller.dart';"
    ),

    # 5. لو فيه imports جزئية (show)
    (
        "import 'package:tayay_app/screens/passenger/passenger_home.dart' show",
        "import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart' show"
    ),

    # 6. لو فيه relative imports من نفس المجلد
    (
        "import 'passenger_home.dart';",
        "import 'home/passenger_home_screen.dart';\n"
        "import 'home/passenger_home_controller.dart';"
    ),

    (
        "import 'searching_offers_screen.dart';",
        "import 'searching_offers/searching_offers_screen.dart';\n"
        "import 'searching_offers/searching_offers_controller.dart';"
    ),

    (
        "import 'trip_tracking_screen.dart';",
        "import 'trip_tracking/trip_tracking_screen.dart';\n"
        "import 'trip_tracking/trip_tracking_controller.dart';"
    ),

    (
        "import 'order_confirmation_screen.dart';",
        "import 'order_confirmation/order_confirmation_screen.dart';\n"
        "import 'order_confirmation/order_confirmation_controller.dart';"
    ),
]


def print_header(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}")


def print_success(text):
    print(f"  ✅ {text}")


def print_warning(text):
    print(f"  ⚠️  {text}")


def print_info(text):
    print(f"  ℹ️  {text}")


def backup_file(src_path):
    """ينسخ ملف للـ Backup"""
    rel_path = os.path.relpath(src_path, PROJECT_ROOT)
    backup_path = os.path.join(BACKUP_DIR, rel_path)
    os.makedirs(os.path.dirname(backup_path), exist_ok=True)
    shutil.copy2(src_path, backup_path)


def update_imports_in_file(file_path):
    """يحدّث الـ imports في ملف واحد ويرجع True لو اتعدل"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"  ❌ خطأ في قراءة {file_path}: {e}")
        return False

    original_content = content
    modified = False
    changes = []

    for old_import, new_import in IMPORT_REPLACEMENTS:
        if old_import in content:
            content = content.replace(old_import, new_import)
            modified = True
            changes.append(old_import.strip())

    if modified:
        # اعمل backup
        backup_file(file_path)

        # اكتب الملف المعدّل
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)

        return True, changes

    return False, []


def main():
    print("""
    ╔══════════════════════════════════════════════════════════════╗
    ║           🔄 Tayar App Import Updater                        ║
    ║                                                              ║
    ║   يحدّث كل الـ imports القديمة للجديدة تلقائياً          ║
    ╚══════════════════════════════════════════════════════════════╝
    """)

    # تأكد من المجلد
    if not os.path.exists(LIB_DIR):
        print("❌ مش لاقي مجلد lib/")
        print("هل أنت في مجلد المشروع الصحيح؟")
        return

    print(f"\n  📁 مجلد المشروع: {PROJECT_ROOT}")

    # اعمل Backup folder
    os.makedirs(BACKUP_DIR, exist_ok=True)
    print(f"  📂 مجلد النسخ الاحتياطي: {BACKUP_DIR}")

    # دور على كل ملفات .dart
    updated_files = []
    checked_files = 0

    print_header("🔍 البحث عن الملفات...")

    for root, dirs, files in os.walk(LIB_DIR):
        # اتجاهل الفولدرات الجديدة (مش عايزين نعدل فيها)
        dirs[:] = [d for d in dirs if d not in ['home', 'searching_offers', 'trip_tracking', 'order_confirmation']]

        for file in files:
            if not file.endswith('.dart'):
                continue

            file_path = os.path.join(root, file)
            checked_files += 1

            modified, changes = update_imports_in_file(file_path)

            if modified:
                rel_path = os.path.relpath(file_path, PROJECT_ROOT)
                updated_files.append((rel_path, changes))
                print_success(f"تم التحديث: {rel_path}")
                for change in changes:
                    print_info(f"     ↳ {change[:60]}...")

    # ملخص
    print_header("📊 ملخص التحديثات")
    print(f"\n  • ملفات تم فحصها: {checked_files}")
    print(f"  • ملفات تم تحديثها: {len(updated_files)}")

    if updated_files:
        print(f"\n  📁 الملفات اللي اتعدلت:")
        for file_path, changes in updated_files:
            print(f"     ✅ {file_path}")
    else:
        print(f"\n  ⚠️  مفيش ملفات اتعدلت. يا إما:")
        print(f"     • الملفات القديمة مش موجودة")
        print(f"     • الـ imports متعدلة قبل كده")
        print(f"     • الملفات في فولدرات متجاهلة")

    print(f"\n  💾 نسخة احتياطية محفوظة في: {BACKUP_DIR}")

    print_header("📝 الخطوة الجاية")
    print("\n  شغل دلوقتي:")
    print("     flutter analyze")
    print("\n  عشان تتأكد إن مفيش errors.")


if __name__ == '__main__':
    main()
