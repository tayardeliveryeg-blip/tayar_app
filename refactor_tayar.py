#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🔧 Tayar App Refactoring Script
يقسم الملفات الكبيرة لملفات أصغر تلقائياً

طريقة الاستخدام:
    1. احفظ الملف ده في مجلد المشروع (نفس مستوى pubspec.yaml)
    2. شغله: python refactor_tayar.py
    3. لما يخلص، شغل: flutter analyze
"""

import os
import shutil
import re
from datetime import datetime

# ====== الإعدادات ======
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
LIB_DIR = os.path.join(PROJECT_ROOT, 'lib')
BACKUP_DIR = os.path.join(PROJECT_ROOT, 'refactor_backup_' + datetime.now().strftime('%Y%m%d_%H%M%S'))


def print_header(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}")


def print_success(text):
    print(f"  ✅ {text}")


def print_warning(text):
    print(f"  ⚠️  {text}")


def print_error(text):
    print(f"  ❌ {text}")


def backup_file(src_path):
    """ينسخ ملف للـ Backup"""
    if not os.path.exists(src_path):
        return False

    rel_path = os.path.relpath(src_path, PROJECT_ROOT)
    backup_path = os.path.join(BACKUP_DIR, rel_path)
    os.makedirs(os.path.dirname(backup_path), exist_ok=True)
    shutil.copy2(src_path, backup_path)
    return True


def read_file(path):
    """يقرأ ملف ويرجع محتواه"""
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        print_error(f"مش قادر أقرأ الملف: {path} - {e}")
        return None


def write_file(path, content):
    """يكتب محتوى في ملف"""
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    except Exception as e:
        print_error(f"مش قادر أكتب الملف: {path} - {e}")
        return False


def extract_class(content, class_name):
    """يستخرج class معين من ملف Dart"""
    pattern = rf'class\s+{class_name}\s+(?:extends|with)\s+[^{{]+\{{'
    match = re.search(pattern, content)
    if not match:
        return None

    start = match.start()
    brace_count = 0
    end = start
    for i, char in enumerate(content[start:]):
        if char == '{':
            brace_count += 1
        elif char == '}':
            brace_count -= 1
            if brace_count == 0:
                end = start + i + 1
                break

    return content[start:end]


def extract_all_classes(content):
    """يستخرج كل الـ classes من ملف"""
    classes = {}
    pattern = r'class\s+([A-Za-z0-9_]+)\s+(?:extends|with)[^{]*\{'

    for match in re.finditer(pattern, content):
        class_name = match.group(1)
        start = match.start()
        brace_count = 0
        end = start
        for i, char in enumerate(content[start:]):
            if char == '{':
                brace_count += 1
            elif char == '}':
                brace_count -= 1
                if brace_count == 0:
                    end = start + i + 1
                    break
        classes[class_name] = content[start:end]

    return classes


def get_imports(content):
    """يستخرج كل الـ imports من ملف"""
    lines = content.split('\n')
    imports = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('import ') or stripped.startswith('export '):
            imports.append(stripped)
    return '\n'.join(imports)


def create_controller(state_content, imports, screen_name):
    """يحول State class لـ Controller"""
    # استخرج الـ initState
    init_match = re.search(r'@override\s+void\s+initState\(\)\s*\{', state_content)
    init_block = ""
    if init_match:
        start = init_match.start()
        brace_count = 0
        end = start
        for i, char in enumerate(state_content[start:]):
            if char == '{':
                brace_count += 1
            elif char == '}':
                brace_count -= 1
                if brace_count == 0:
                    end = start + i + 1
                    break
        init_block = state_content[start:end]

    # استخرج الـ dispose
    dispose_match = re.search(r'@override\s+void\s+dispose\(\)\s*\{', state_content)
    dispose_block = ""
    if dispose_match:
        start = dispose_match.start()
        brace_count = 0
        end = start
        for i, char in enumerate(state_content[start:]):
            if char == '{':
                brace_count += 1
            elif char == '}':
                brace_count -= 1
                if brace_count == 0:
                    end = start + i + 1
                    break
        dispose_block = state_content[start:end]

    # استخرج الـ variables والـ methods (باستثناء build)
    # ده معقد، هنستخدم approach مختلف

    controller = f"""{imports}

import 'package:flutter/material.dart';

/// Controller لـ {screen_name}
/// 
/// ⚠️  ملاحظة: الملف ده اتولد تلقائياً. لازم:
/// 1. تستبدل 'extends State<...>' بـ 'extends ChangeNotifier'
/// 2. تشيل الـ build method
/// 3. تستبدل setState بـ notifyListeners()
/// 4. تضيف الـ imports اللي ناقصة
class {screen_name}Controller extends ChangeNotifier {{

  // TODO: انقل كل الـ variables من الـ State class هنا

  {screen_name}Controller() {{
    // TODO: انقل محتوى initState هنا
  }}

  void disposeController() {{
    // TODO: انقل محتوى dispose هنا
    super.dispose();
  }}

  // TODO: انقل كل الـ methods من الـ State class هنا
  // استبدل setState(() {{ ... }}) بـ notifyListeners()
}}
"""
    return controller


def split_file(src_path, dest_dir, filename):
    """يقسم ملف كبير لملفات أصغر"""
    content = read_file(src_path)
    if not content:
        return False

    base_name = filename.replace('.dart', '')
    classes = extract_all_classes(content)
    imports = get_imports(content)

    print(f"\n  📄 تم العثور على {len(classes)} class:")
    for name in classes.keys():
        print(f"     • {name}")

    # 1. Screen file (الـ public class)
    screen_class = None
    screen_name = None
    for name, cls in classes.items():
        if not name.startswith('_'):
            screen_class = cls
            screen_name = name
            break

    if screen_class:
        screen_file = os.path.join(dest_dir, f"{base_name}_screen.dart")
        screen_content = f"{imports}\n\n{screen_class}"
        write_file(screen_file, screen_content)
        print_success(f"تم إنشاء: {base_name}_screen.dart")

    # 2. Controller file (الـ State class)
    state_class = None
    for name, cls in classes.items():
        if 'State' in name and name.startswith('_'):
            state_class = cls
            break

    if state_class:
        controller_file = os.path.join(dest_dir, f"{base_name}_controller.dart")
        controller_content = create_controller(state_class, imports, base_name)
        write_file(controller_file, controller_content)
        print_success(f"تم إنشى: {base_name}_controller.dart")

    # 3. Widget files (الـ private classes)
    widget_count = 0
    for name, cls in classes.items():
        if name.startswith('_') and 'State' not in name:
            widget_count += 1
            widget_name = name[1:]  # شيل الـ _ من الأول
            widget_file = os.path.join(dest_dir, 'widgets', f"{widget_name.lower()}.dart")
            widget_content = f"{imports}\n\n{cls}"
            write_file(widget_file, widget_content)
            print_success(f"تم إنشاء: widgets/{widget_name.lower()}.dart")

    if widget_count == 0:
        print_warning("مفيش private widgets اتلاقت")

    return True


def main():
    print("""
    ╔══════════════════════════════════════════════════════════════╗
    ║           🔧 Tayar App Refactoring Tool                      ║
    ║                                                              ║
    ║   يقسم الملفات الكبيرة لملفات أصغر تلقائياً              ║
    ╚══════════════════════════════════════════════════════════════╝
    """)

    # تأكد من المجلد
    if not os.path.exists(LIB_DIR):
        print_error("مش لاقي مجلد lib/")
        print("هل أنت في مجلد المشروع الصحيح؟ (نفس مستوى pubspec.yaml)")
        return

    print(f"\n  📁 مجلد المشروع: {PROJECT_ROOT}")
    print(f"  📁 مجلد lib: {LIB_DIR}")

    # الملفات المستهدفة
    target_files = [
        ('screens/passenger/passenger_home.dart', 'screens/passenger/home'),
        ('screens/passenger/searching_offers_screen.dart', 'screens/passenger/searching_offers'),
        ('screens/passenger/trip_tracking_screen.dart', 'screens/passenger/trip_tracking'),
        ('screens/passenger/order_confirmation_screen.dart', 'screens/passenger/order_confirmation'),
    ]

    # اعمل Backup
    print_header("💾 عمل نسخة احتياطية")
    os.makedirs(BACKUP_DIR, exist_ok=True)
    print(f"  📂 مجلد النسخ الاحتياطي: {BACKUP_DIR}")

    for src_rel, dest_rel in target_files:
        src_path = os.path.join(LIB_DIR, src_rel)
        if os.path.exists(src_path):
            backup_file(src_path)
            print_success(f"تم النسخ: {src_rel}")

    # تقسيم الملفات
    print_header("📁 تقسيم الملفات")

    for src_rel, dest_rel in target_files:
        src_path = os.path.join(LIB_DIR, src_rel)
        dest_dir = os.path.join(LIB_DIR, dest_rel)
        filename = os.path.basename(src_rel)

        if not os.path.exists(src_path):
            print_warning(f"الملف مش موجود: {src_rel}")
            continue

        print_header(f"تقسيم: {filename}")

        # إنشاء الفولدرات
        os.makedirs(dest_dir, exist_ok=True)
        os.makedirs(os.path.join(dest_dir, 'widgets'), exist_ok=True)
        os.makedirs(os.path.join(dest_dir, 'models'), exist_ok=True)

        # اقسم الملف
        if split_file(src_path, dest_dir, filename):
            print_success(f"تم تقسيم {filename} بنجاح!")

    # إنشاء ملفات الموديلات
    print_header("📝 إنشاء ملفات الموديلات")

    models = [
        ('screens/passenger/home/models/nearby_driver.dart', 
         "import 'package:latlong2/latlong.dart';\n\nclass NearbyDriver {\n  LatLng displayed;\n  LatLng prev;\n  LatLng target;\n\n  NearbyDriver({required this.displayed, required this.prev, required this.target});\n}\n"),
        ('screens/passenger/searching_offers/models/nearby_driver_marker.dart',
         "import 'package:latlong2/latlong.dart';\n\nclass NearbyDriverMarker {\n  LatLng displayed;\n  LatLng prev;\n  LatLng target;\n\n  NearbyDriverMarker({required this.displayed, required this.prev, required this.target});\n}\n"),
    ]

    for model_path, model_content in models:
        full_path = os.path.join(LIB_DIR, model_path)
        write_file(full_path, model_content)
        print_success(f"تم إنشاء: {model_path}")

    # ملخص
    print_header("✅ تم الانتهاء!")
    print(f"\n  📊 الإحصائيات:")
    print(f"     • الملفات المقسمة: {len(target_files)}")
    print(f"     • مجلد النسخ الاحتياطي: {BACKUP_DIR}")
    print(f"\n  ⚠️  ملاحظات مهمة:")
    print(f"     • الملفات القديمة لسه موجودة (مش اتمسحت)")
    print(f"     • الملفات الجديدة اتولدت بـ TODO comments")
    print(f"     • لازم تعدل الـ Controller files يدوياً")
    print(f"     • لازم تعدل الـ imports في الملفات التانية")
    print(f"\n  📝 الخطوات الجاية:")
    print(f"     1. افتح كل ملف _controller.dart واكمل الـ TODOs")
    print(f"     2. عدّل الـ imports في الملفات القديمة")
    print(f"     3. شغل: flutter analyze")
    print(f"     4. جرب التطبيق")
    print(f"     5. لما تتأكد: git add . && git commit -m 'refactor: split large files'")


if __name__ == '__main__':
    main()
