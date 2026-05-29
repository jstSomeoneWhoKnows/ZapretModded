#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import ctypes
import tkinter
import subprocess
import threading
import shutil
import winreg
import urllib.request
import re
import time
import random
import math
from pathlib import Path
from tkinter import messagebox

import customtkinter as ctk

# ----------------------------------------------------------------------
# Конфигурация
# ----------------------------------------------------------------------
LOCAL_VERSION = "1.2.0"
GITHUB_VERSION_URL = "https://raw.githubusercontent.com/jstSomeoneWhoKnows/ZapretModded/refs/heads/main/version.txt"
GITHUB_DOWNLOAD_URL = "https://github.com/jstSomeoneWhoKnows/ZapretModded/releases/latest"
HOSTS_URL = "https://raw.githubusercontent.com/jstSomeoneWhoKnows/ZapretModded/refs/heads/main/hosts"
IPSET_URL = "https://raw.githubusercontent.com/jstSomeoneWhoKnows/ZapretModded/refs/heads/main/lists/ipset-all.txt"

# ----------------------------------------------------------------------
# Локализация (i18n)
# ----------------------------------------------------------------------
LANGUAGES = {
    "en": {
        "title": "ZAPRETMODDED MANAGER",
        "main_menu": "MAIN MENU",
        "nav_home": "HOME //",
        "nav_config": "CONFIG //",
        "nav_strategy": "STRATEGY //",
        "nav_update": "UPDATE //",
        "nav_tools": "TOOLS //",
        "terminal_title": "TERMINAL OUTPUT",
        "copy_log": "COPY LOG",
        "status_awaiting": "AWAITING CONNECTION...",
        "status_connected": "SYSTEM CONNECTED",
        "btn_init": "INITIALIZE",
        "btn_terminate": "TERMINATE",
        "payload_none": "PAYLOAD: NONE",
        "payload_active": "PAYLOAD: [{name}] ACTIVE",
        "sys_config": "SYSTEM CONFIGURATION",
        "game_filter": "GAMING FILTER_PORT:",
        "ip_override": "IP_LIST OVERRIDE:",
        "auto_fetch": "AUTO_FETCH UPDATES:",
        "lang_select": "INTERFACE LANGUAGE:",
        "toggle_btn": "TOGGLE",
        "strat_deployment": "STRATEGY DEPLOYMENT",
        "strat_standard": "STANDARD [strategies]",
        "strat_special": "SPECIAL [specstrategies]",
        "avail_payloads": "AVAILABLE PAYLOADS",
        "btn_purge": "PURGE SERVICES",
        "btn_halt": "HALT EXECUTION",
        "btn_ping": "PING STATUS",
        "sys_updates": "SYSTEM UPDATES",
        "btn_fetch_ipset": "FETCH IPSET DEFINITIONS",
        "btn_patch_hosts": "PATCH HOSTS FILE",
        "btn_check_updates": "CHECK CORE UPDATES",
        "diag_tools": "DIAGNOSTIC TOOLS",
        "btn_run_diag": "RUN SYSTEM DIAGNOSTICS",
        "btn_exec_tests": "EXECUTE TESTS [WIP]",
        "enabled": "ENABLED",
        "disabled": "DISABLED",
        "all_traffic": "ALL_TRAFFIC",
        "bypass_disabled": "BYPASS_DISABLED",
        "loaded_only": "LOADED_ONLY",
        "status_online": "SYSTEM: ONLINE",
        "status_offline": "SYSTEM: OFFLINE",
        "msg_payload_req_title": "PAYLOAD REQUIRED",
        "msg_payload_req_body": "Select a strategy payload to deploy.",
        "log_empty": "LOG IS EMPTY.",
        "log_copied": "LOG COPIED TO MEMORY.",
        "copy_failed": "COPY FAILED: ",
        "init_purge": "=== INITIATING SERVICE PURGE ===",
        "srv_deleted": "SERVICE 'zapret' DELETED.",
        "srv_not_found": "SERVICE 'zapret' NOT FOUND.",
        "windivert_keep": "WinDivert KEPT ALIVE.",
        "deploy_payload": "=== DEPLOYING PAYLOAD ===",
        "wd_missing": "WinDivert MISSING. ATTEMPTING INJECTION...",
        "wd_injected": "WinDivert INJECTED.",
        "wd_err": "ERR: WinDivert64.sys NOT FOUND.",
        "wd_halted": "WinDivert HALTED. RESTARTING...",
        "wd_online": "WinDivert ONLINE.",
        "wd_start_failed": "WARN: WinDivert START FAILED. PROCEEDING ANYWAY.",
        "script_missing": "ERR: install_via_service.bat MISSING!",
        "deploy_success": "PAYLOAD DEPLOYED SUCCESSFULLY. [winws.exe RUNNING]",
        "deploy_failed": "DEPLOYMENT FAILED. [winws.exe NOT RUNNING]",
        "halt_winws": "HALTING winws.exe...",
        "proc_terminated": "PROCESS winws.exe TERMINATED.",
        "ping_status": "=== PINGING SYSTEM STATUS ===",
        "game_filt_en": "GAMING FILTER ENABLED.",
        "game_filt_dis": "GAMING FILTER DISABLED.",
        "toggle_ip_filt": "TOGGLING IP-FILTER FROM ",
        "restore_ipset": "RESTORED ipset-all.txt FROM BACKUP.",
        "backup_not_found": "BACKUP NOT FOUND. CREATED BLANK LIST.",
        "mode_bypass_dis": "MODE: BYPASS_DISABLED (ALLOW ALL TRAFFIC).",
        "mode_all_traf": "MODE: ALL_TRAFFIC (FULL LIST).",
        "auto_upd_en": "AUTO-UPDATES ENABLED.",
        "auto_upd_dis": "AUTO-UPDATES DISABLED.",
        "fetch_ipset": "FETCHING NEW ipset-all.txt...",
        "fetch_success": "FETCH SUCCESSFUL.",
        "fetch_failed": "FETCH FAILED: ",
        "hosts_patch_title": "HOSTS PATCH",
        "hosts_patch_body": "Auto-patch HOSTS file? (Yes = Auto, No = Manual mode)",
        "auto_patch_hosts": "AUTO-PATCHING HOSTS...",
        "download_failed": "DOWNLOAD FAILED: ",
        "hosts_success": "HOSTS FILE PATCHED SUCCESSFULLY!",
        "auto_write_failed": "AUTO-WRITE FAILED: {e}. FALLING BACK TO MANUAL.",
        "manual_hosts_init": "MANUAL HOSTS PATCH INITIALIZED...",
        "hosts_clipboard": "HOSTS CONTENT COPIED TO CLIPBOARD.",
        "clipboard_err": "CLIPBOARD INJECTION FAILED: ",
        "opening_notepad": "OPENING NOTEPAD AS ADMIN. PASTE AND SAVE.",
        "manual_patch_title": "MANUAL PATCH",
        "manual_patch_body": "Replace content, save file, and click OK.",
        "ping_server": "PINGING UPDATE SERVER...",
        "sys_up_to_date": "SYSTEM UP TO DATE [v{version}]",
        "new_ver_detect": "NEW VERSION DETECTED [v{version}]",
        "new_ver_title": "NEW VERSION",
        "new_ver_body": "Open download page?",
        "run_diag_title": "=== RUNNING SYSTEM DIAGNOSTICS ===",
        "bfe_status": "BFE SERVICE: ",
        "proxy_detect": "SYSTEM PROXY DETECTED: {proxy}. MAY CAUSE CONFLICTS.",
        "proxy_clear": "SYSTEM PROXY: CLEAR.",
        "tcp_ts_en": "TCP TIMESTAMPS: ENABLED.",
        "tcp_ts_dis": "TCP TIMESTAMPS: DISABLED. ENABLING...",
        "diag_complete": "DIAGNOSTICS COMPLETE.",
        "err_path_not_found": "ERR: {path} NOT FOUND",
        "err_no_payloads": "ERR: NO PAYLOADS FOUND",
    },
    "ru": {
        "title": "ZAPRETMODDED МЕНЕДЖЕР",
        "main_menu": "ГЛАВНОЕ МЕНЮ",
        "nav_home": "ГЛАВНАЯ //",
        "nav_config": "НАСТРОЙКИ //",
        "nav_strategy": "СТРАТЕГИИ //",
        "nav_update": "ОБНОВЛЕНИЕ //",
        "nav_tools": "УТИЛИТЫ //",
        "terminal_title": "ВЫВОД ТЕРМИНАЛА",
        "copy_log": "КОПИРОВАТЬ ЛОГ",
        "status_awaiting": "ОЖИДАНИЕ ПОДКЛЮЧЕНИЯ...",
        "status_connected": "СИСТЕМА ПОДКЛЮЧЕНА",
        "btn_init": "ЗАПУСТИТЬ",
        "btn_terminate": "ОСТАНОВИТЬ",
        "payload_none": "СТРАТЕГИЯ: НЕТ",
        "payload_active": "СТРАТЕГИЯ: [{name}] АКТИВНА",
        "sys_config": "КОНФИГУРАЦИЯ СИСТЕМЫ",
        "game_filter": "ИГРОВОЙ ФИЛЬТР (ПОРТЫ):",
        "ip_override": "ОБХОД ДЛЯ IP-ЛИСТА:",
        "auto_fetch": "АВТООБНОВЛЕНИЕ ЛИСТОВ:",
        "lang_select": "ЯЗЫК ИНТЕРФЕЙСА:",
        "toggle_btn": "ИЗМЕНИТЬ",
        "strat_deployment": "РАЗВЕРТЫВАНИЕ СТРАТЕГИИ",
        "strat_standard": "СТАНДАРТНЫЕ [strategies]",
        "strat_special": "СПЕЦИАЛЬНЫЕ [specstrategies]",
        "avail_payloads": "ДОСТУПНЫЕ СКРИПТЫ",
        "btn_purge": "УДАЛИТЬ СЛУЖБЫ",
        "btn_halt": "ОСТАНОВИТЬ WINWS",
        "btn_ping": "ПРОВЕРИТЬ СТАТУС",
        "sys_updates": "ОБНОВЛЕНИЕ СИСТЕМЫ",
        "btn_fetch_ipset": "СКАЧАТЬ IPSET-СПИСОК",
        "btn_patch_hosts": "ПРОПАТЧИТЬ HOSTS",
        "btn_check_updates": "ПРОВЕРИТЬ ОБНОВЛЕНИЯ",
        "diag_tools": "ДИАГНОСТИКА СИСТЕМЫ",
        "btn_run_diag": "ЗАПУСТИТЬ ДИАГНОСТИКУ",
        "btn_exec_tests": "ТЕСТИРОВАНИЕ [В РАЗРАБОТКЕ]",
        "enabled": "ВКЛЮЧЕН",
        "disabled": "ВЫКЛЮЧЕН",
        "all_traffic": "ДЛЯ ВСЕГО ТРАФИКА",
        "bypass_disabled": "ОБХОД ВЫКЛЮЧЕН",
        "loaded_only": "ТОЛЬКО ДЛЯ СПИСКА",
        "status_online": "СИСТЕМА: ОНЛАЙН",
        "status_offline": "СИСТЕМА: ОФЛАЙН",
        "msg_payload_req_title": "ТРЕБУЕТСЯ СТРАТЕГИЯ",
        "msg_payload_req_body": "Выберите сигнатуру или стратегию для запуска.",
        "log_empty": "ЖУРНАЛ СЕЙЧАС ПУСТ.",
        "log_copied": "ЛОГ СКОПИРОВАН В БУФЕР ОБМЕНА.",
        "copy_failed": "ОШИБКА КОПИРОВАНИЯ: ",
        "init_purge": "=== ИНИЦИАЛИЗАЦИЯ ОЧИСТКИ СЛУЖБ ===",
        "srv_deleted": "СЛУЖБА 'zapret' УСПЕШНО УДАЛЕНА.",
        "srv_not_found": "СЛУЖБА 'zapret' НЕ ОБНАРУЖЕНА.",
        "windivert_keep": "Драйвер WinDivert ОСТАВЛЕН В СИСТЕМЕ.",
        "deploy_payload": "=== РАЗВЕРТЫВАНИЕ СТРАТЕГИИ ===",
        "wd_missing": "WinDivert ОТСУТСТВУЕТ. ИНЖЕКТИРУЕМ...",
        "wd_injected": "Драйвер WinDivert ИНЖЕКТИРОВАН.",
        "wd_err": "ОШИБКА: WinDivert64.sys НЕ НАЙДЕН.",
        "wd_halted": "WinDivert ОСТАНОВЛЕН. ПЕРЕЗАПУСК...",
        "wd_online": "WinDivert ЗАПУЩЕН ОНЛАЙН.",
        "wd_start_failed": "ВНИМАНИЕ: ОШИБКА СТАРТА WinDivert. ПРОДОЛЖАЕМ НА СВОЙ СТРАХ И РИСК.",
        "script_missing": "ОШИБКА: Скрипт install_via_service.bat ОТСУТСТВУЕТ!",
        "deploy_success": "СТРАТЕГИЯ РАЗВЕРНУТА. [winws.exe ЗАПУЩЕН]",
        "deploy_failed": "СБОЙ РАЗВЕРТЫВАНИЯ. [winws.exe НЕ ЗАПУСТИЛСЯ]",
        "halt_winws": "ТЕРМИНИРУЕМ winws.exe...",
        "proc_terminated": "ПРОЦЕСС winws.exe ПОЛНОСТЬЮ ОСТАНОВЛЕН.",
        "ping_status": "=== ПРОВЕРКА АКТИВНОСТИ СИСТЕМЫ ===",
        "game_filt_en": "ИГРОВОЙ ФИЛЬТР УСПЕШНО ВКЛЮЧЕН.",
        "game_filt_dis": "ИГРОВОЙ ФИЛЬТР ВЫКЛЮЧЕН.",
        "toggle_ip_filt": "ИЗМЕНЕНИЕ IP-ФИЛЬТРАЦИИ С ТЕКУЩЕЙ: ",
        "restore_ipset": "ОБНОВЛЕН ipset-all.txt ИЗ РЕЗЕРВНОЙ КОПИИ.",
        "backup_not_found": "БЕКАП НЕ НАЙДЕН. СОЗДАН ПУСТОЙ ЛИСТ.",
        "mode_bypass_dis": "РЕЖИМ: ОБХОД ОТКЛЮЧЕН (РАЗРЕШИТЬ ВЕСЬ ТРАФИК).",
        "mode_all_traf": "РЕЖИМ: ДЛЯ ВСЕГО ТРАФИКА (ПОЛНЫЙ СПИСОК).",
        "auto_upd_en": "АВТООБНОВЛЕНИЯ ВКЛЮЧЕНЫ.",
        "auto_upd_dis": "АВТООБНОВЛЕНИЯ ВЫКЛЮЧЕНЫ.",
        "fetch_ipset": "СКАЧИВАНИЕ СВЕЖЕГО ipset-all.txt...",
        "fetch_success": "СПИСОК УСПЕШНО СКАЧАН И ОБНОВЛЕН.",
        "fetch_failed": "СБОЙ СКАЧИВАНИЯ: ",
        "hosts_patch_title": "ПАТЧ ХОСТОВ",
        "hosts_patch_body": "Запустить авто-патч файла HOSTS? (Да = Авто, Нет = Вручную)",
        "auto_patch_hosts": "АВТО-ПАТЧИНГ ФАЙЛА HOSTS...",
        "download_failed": "СБОЙ ЗАГРУЗКИ: ",
        "hosts_success": "ФАЙЛ HOSTS УСПЕШНО ПРОПАТЧЕН!",
        "auto_write_failed": "ОШИБКА АВТОЗАПИСИ: {e}. ПЕРЕХОДИМ К РУЧНОМУ РЕЖИМУ.",
        "manual_hosts_init": "ЗАПУЩЕН РУЧНОЙ ПАТЧ HOSTS...",
        "hosts_clipboard": "СОДЕРЖИМОЕ HOSTS СКОПИРОВАНО В БУФЕР ОБМЕНА.",
        "clipboard_err": "НЕ УДАЛОСЬ ЗАПИСАТЬ В БУФЕР: ",
        "opening_notepad": "ОТКРЫВАЕМ БЛОКНОТ ОТ АДМИНА. ВСТАВЬТЕ И СОХРАНИТЕ.",
        "manual_patch_title": "РУЧНОЙ ПАТЧ",
        "manual_patch_body": "Замените содержимое, сохраните файл и нажмите ОК.",
        "ping_server": "СВЯЗЬ С СЕРВЕРОМ ОБНОВЛЕНИЙ...",
        "sys_up_to_date": "СИСТЕМА АКТУАЛЬНА [v{version}]",
        "new_ver_detect": "ОБНАРУЖЕНА НОВАЯ ВЕРСИЯ [v{version}]",
        "new_ver_title": "ОБНОВЛЕНИЕ СИСТЕМЫ",
        "new_ver_body": "Открыть официальную страницу загрузки?",
        "run_diag_title": "=== ЗАПУСК КОМПЛЕКСНОЙ ДИАГНОСТИКИ ===",
        "bfe_status": "СЛУЖБА BFE: ",
        "proxy_detect": "ОБНАРУЖЕН СИСТЕМНЫЙ ПРОКСИ: {proxy}. ВОЗМОЖНЫ КОНФЛИКТЫ.",
        "proxy_clear": "СИСТЕМНЫЙ ПРОКСИ: ОТСУТСТВУЕТ (ЧИСТО).",
        "tcp_ts_en": "TCP TIMESTAMPS: АКТИВИРОВАНЫ.",
        "tcp_ts_dis": "TCP TIMESTAMPS: ВЫКЛЮЧЕНЫ. ИСПРАВЛЯЕМ И ВКЛЮЧАЕМ...",
        "diag_complete": "ДИАГНОСТИКА УСПЕШНО ЗАВЕРШЕНА.",
        "err_path_not_found": "ОШИБКА: ПУТЬ {path} НЕ НАЙДЕН",
        "err_no_payloads": "ОШИБКА: СКРИПТЫ НЕ НАЙДЕНЫ",
    }
}


# ----------------------------------------------------------------------
# Продвинутая система частиц (Хакерская нейросеть / Nexus)
# ----------------------------------------------------------------------
class ParticleSystem:
    def __init__(self, canvas, width, height, num_particles=45):
        self.canvas = canvas
        self.width = width
        self.height = height
        self.num_particles = num_particles
        self.particles = []
        self.running = True
        self.connection_distance = 100
        self.init_particles()

    def init_particles(self):
        for _ in range(self.num_particles):
            self.add_particle()

    def add_particle(self):
        x = random.randint(0, self.width)
        y = random.randint(0, self.height)
        vx = random.uniform(-0.5, 0.5)
        vy = random.uniform(-0.5, 0.5)
        size = random.uniform(1.5, 3.0)

        if random.random() > 0.5:
            color = "#00FFFF"  # Cyan
        else:
            color = "#FF00FF"  # Magenta

        particle = {
            'id': None,
            'x': x, 'y': y, 'vx': vx, 'vy': vy,
            'size': size, 'color': color
        }

        try:
            particle['id'] = self.canvas.create_oval(
                x - size, y - size, x + size, y + size,
                fill=color, outline=color, tags="particle"
            )
            self.particles.append(particle)
        except Exception:
            pass

    def update(self):
        if not self.running:
            return

        try:
            self.canvas.delete("connection")

            for p in self.particles:
                p['x'] += p['vx']
                p['y'] += p['vy']

                if p['x'] < 0 or p['x'] > self.width:
                    p['vx'] *= -1
                if p['y'] < 0 or p['y'] > self.height:
                    p['vy'] *= -1

                self.canvas.coords(p['id'],
                                   p['x'] - p['size'], p['y'] - p['size'],
                                   p['x'] + p['size'], p['y'] + p['size'])

            for i in range(len(self.particles)):
                for j in range(i + 1, len(self.particles)):
                    p1 = self.particles[i]
                    p2 = self.particles[j]
                    dist = math.hypot(p2['x'] - p1['x'], p2['y'] - p1['y'])

                    if dist < self.connection_distance:
                        intensity = int(255 * (1 - dist / self.connection_distance))
                        color = f"#{0:02x}{int(intensity * 0.8):02x}{intensity:02x}"
                        self.canvas.create_line(
                            p1['x'], p1['y'], p2['x'], p2['y'],
                            fill=color, width=1, tags="connection"
                        )

            self.canvas.tag_lower("connection")
            self.canvas.after(30, self.update)
        except Exception:
            self.running = False

    def resize(self, width, height):
        self.width = width
        self.height = height

    def stop(self):
        self.running = False


# ----------------------------------------------------------------------
# Вспомогательные функции
# ----------------------------------------------------------------------
def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except:
        return False


def run_as_admin():
    args = sys.argv[:]
    if '--elevated-requested' not in args:
        args.append('--elevated-requested')
    params = ' '.join(f'"{a}"' for a in args)
    result = ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, params, None, 1)
    if result <= 32:
        from tkinter import messagebox
        messagebox.showerror("Ошибка запуска", f"Не удалось запустить с правами администратора.\nКод ошибки: {result}")
    sys.exit()


def  get_base_dir():
    if getattr(sys, 'frozen', False):
        # Запущено из скомпилированного exe
        return Path(sys.executable).parent
    else:
        # Запущено как скрипт
        return Path(__file__).parent


def run_cmd(cmd, capture=True, show_error=True):
    startupinfo = subprocess.STARTUPINFO()
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startupinfo.wShowWindow = subprocess.SW_HIDE
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0
    try:
        if capture:
            proc = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                                  startupinfo=startupinfo, creationflags=creationflags,
                                  encoding='cp866', errors='replace')
            out_lines = [line for line in proc.stdout.splitlines()
                         if "Непредвиденное появление" not in line and ".bat" not in line]
            filtered_out = "\n".join(out_lines)
            return proc.returncode, filtered_out.strip(), proc.stderr.strip()
        else:
            proc = subprocess.run(cmd, shell=True, startupinfo=startupinfo, creationflags=creationflags)
            return proc.returncode, "", ""
    except Exception as e:
        if show_error:
            print(f"Ошибка выполнения команды: {e}")
        return -1, "", str(e)


def get_service_status(service_name):
    rc, out, _ = run_cmd(f'sc query "{service_name}"')
    if rc != 0: return "NOT_FOUND"
    if "RUNNING" in out: return "RUNNING"
    if "STOP_PENDING" in out: return "STOP_PENDING"
    return "STOPPED"


def stop_service(service_name):
    run_cmd(f'net stop "{service_name}"', show_error=False)


def delete_service(service_name):
    if get_service_status(service_name) != "NOT_FOUND":
        stop_service(service_name)
        run_cmd(f'sc delete "{service_name}"', show_error=False)


def get_reg_str(key, subkey, value_name):
    try:
        with winreg.OpenKey(key, subkey, 0, winreg.KEY_READ) as reg_key:
            value, _ = winreg.QueryValueEx(reg_key, value_name)
            return value
    except Exception:
        return None


# ----------------------------------------------------------------------
# Основной класс приложения
# ----------------------------------------------------------------------
class ZapretManagerApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.current_lang = "ru"  # По умолчанию русский
        self.geometry("950x750")
        self.minsize(800, 600)

        ctk.set_appearance_mode("dark")

        self._original_geometry = None
        self.bg_canvas = None
        self.particle_system = None

        self.base_dir = get_base_dir()
        self.bin_path = self.base_dir / "bin"
        self.lists_path = self.base_dir / "lists"
        self.utils_path = self.base_dir / "utils"
        self.strategies_path = self.base_dir / "strategies"
        self.spec_strategies_path = self.base_dir / "specstrategies"
        self.tools_path = self.base_dir / "tools"
        self.tools_path.mkdir(exist_ok=True)

        for p in [self.lists_path, self.utils_path]:
            p.mkdir(exist_ok=True)

        self._ensure_install_bat()

        self.game_filter_flag = self.utils_path / "game_filter.enabled"
        self.auto_update_flag = self.utils_path / "check_updates.enabled"
        self.ipset_file = self.lists_path / "ipset-all.txt"
        self.ipset_backup = self.lists_path / "ipset-all.txt.backup"

        self.winws_process = None

        self.strategy_label_var = ctk.StringVar()
        self.game_filter_var = ctk.StringVar()
        self.ipset_filter_var = ctk.StringVar()
        self.auto_update_var = ctk.StringVar()

        self.pulse_job = None
        self.connect_btn_pulsing = False
        self.blink_job = None
        self.blink_state = False

        # Создаём фон
        self._create_particle_background()

        self.grid_rowconfigure(1, weight=1)
        self.grid_columnconfigure(1, weight=1)

        # Верхняя панель (Header)
        self.header_frame = ctk.CTkFrame(self, height=45, corner_radius=0, fg_color="#0D0E15", border_width=1,
                                         border_color="#00FFFF")
        self.header_frame.grid(row=0, column=0, columnspan=2, sticky="ew")
        self.header_frame.grid_propagate(False)

        self.header_label = ctk.CTkLabel(
            self.header_frame,
            text="",
            font=ctk.CTkFont(family="Courier New", size=18, weight="bold"),
            text_color="#00FFFF"
        )
        self.header_label.pack(side="left", padx=20, pady=10)

        # Боковая панель
        self.sidebar = ctk.CTkFrame(self, width=220, corner_radius=0, fg_color="#11131A", border_width=1,
                                    border_color="#FF00FF")
        self.sidebar.grid(row=1, column=0, sticky="ns")
        self.sidebar.grid_propagate(False)
        self.sidebar.rowconfigure(0, weight=1)

        self.sidebar_title = ctk.CTkLabel(self.sidebar, text="", text_color="#555",
                                          font=ctk.CTkFont(family="Courier New", size=12))
        self.sidebar_title.pack(pady=(15, 5))

        self.nav_buttons = {}
        self.create_sidebar_buttons()

        # Основная область
        self.content_container = ctk.CTkFrame(self, fg_color="transparent")
        self.content_container.grid(row=1, column=1, sticky="nsew")
        self.content_container.grid_rowconfigure(0, weight=1)
        self.content_container.grid_columnconfigure(0, weight=1)

        self.pages = {}
        self.setting_labels = {}
        self.setting_btns = {}
        self.strat_ctrl_btns = {}
        self.update_btns = {}
        self.tools_btns = {}

        self.create_pages()

        # Лог-панель
        self.log_frame = ctk.CTkFrame(self, height=180, corner_radius=0, fg_color="#050508", border_width=1,
                                      border_color="#00FFCC")
        self.log_frame.grid(row=2, column=0, columnspan=2, sticky="ew")
        self.log_frame.grid_propagate(False)
        self.create_log_area()

        self.blink_label = None

        # Обновление текстов под выбранный язык
        self.update_ui_language()
        self.show_page("home")

        if self.auto_update_flag.exists():
            self.check_updates_auto()

        self.protocol("WM_DELETE_WINDOW", self._on_closing)
        self._start_blink_animation()

    def _create_particle_background(self):
        self.bg_canvas = tkinter.Canvas(self, highlightthickness=0, bg="#05050B")
        self.bg_canvas.place(x=0, y=0, relwidth=1, relheight=1)
        self.after(200, self._init_particles)

    def _init_particles(self):
        if self.bg_canvas and self.bg_canvas.winfo_exists():
            w = self.winfo_width()
            h = self.winfo_height()
            if w > 10 and h > 10:
                self.particle_system = ParticleSystem(self.bg_canvas, w, h, num_particles=50)
                self.particle_system.update()
                self.bind("<Configure>", self._on_resize)

    def _on_resize(self, event):
        if self.particle_system and event.widget == self:
            self.particle_system.resize(event.width, event.height)

    def _start_blink_animation(self):
        if not self.blink_label:
            home = self.pages.get("home")
            if home:
                self.blink_label = ctk.CTkLabel(home, text="",
                                                font=ctk.CTkFont(family="Courier New", size=16, weight="bold"),
                                                text_color="#FF0055")
                self.blink_label.place(x=20, y=20)
        self._blink_step()

    def _blink_step(self):
        try:
            if not self.blink_label or not self.winfo_exists() or not self.blink_label.winfo_exists(): return
            strings = LANGUAGES[self.current_lang]
            rc, out, _ = run_cmd('tasklist /FI "IMAGENAME eq winws.exe"')
            is_running = "winws.exe" in out
            if is_running:
                new_color = "#00FF00" if self.blink_state else "#004400"
                text = strings['status_online']
            else:
                new_color = "#FF0055" if self.blink_state else "#440011"
                text = strings['status_offline']

            self.blink_label.configure(text_color=new_color, text=text)
            self.blink_state = not self.blink_state
            self.blink_job = self.after(700, self._blink_step)
        except Exception:
            pass

    def _stop_all_animations(self):
        if self.pulse_job: self.after_cancel(self.pulse_job)
        if self.blink_job: self.after_cancel(self.blink_job)
        if hasattr(self, 'particle_system') and self.particle_system:
            self.particle_system.running = False

    def create_sidebar_buttons(self):
        menu_keys = [
            ("home", "#00FFFF"),
            ("settings", "#FF00FF"),
            ("strategies", "#00FFCC"),
            ("updates", "#FFFF00"),
            ("tools", "#FF5500")
        ]

        for page, accent in menu_keys:
            btn = ctk.CTkButton(
                self.sidebar, text="", anchor="w", fg_color="transparent",
                text_color="#AAAAAA", hover_color="#1A1C28",
                font=ctk.CTkFont(family="Courier New", size=16, weight="bold"),
                border_width=0, corner_radius=0,
                command=lambda p=page: self.show_page(p)
            )
            btn.pack(fill="x", padx=10, pady=5)
            self._add_neon_hover(btn, accent)
            self.nav_buttons[page] = btn

    def _add_neon_hover(self, button, color):
        def on_enter(e):
            button.configure(text_color=color, border_width=1, border_color=color)

        def on_leave(e):
            button.configure(text_color="#AAAAAA", border_width=0)

        button.bind("<Enter>", on_enter)
        button.bind("<Leave>", on_leave)

    def create_pages(self):
        for page_name in ("home", "settings", "strategies", "updates", "tools"):
            frame = ctk.CTkFrame(self.content_container, fg_color="#0D0E15", corner_radius=15, border_width=1,
                                 border_color="#333333")
            frame.place(relx=0.5, rely=0.5, anchor="center", relwidth=0.9, relheight=0.9)
            self.pages[page_name] = frame

        self._build_home_page()
        self._build_settings_page()
        self._build_strategies_page()
        self._build_updates_page()
        self._build_tools_page()

    def _build_home_page(self):
        home = self.pages["home"]
        home.grid_rowconfigure(0, weight=1)
        home.grid_rowconfigure(1, weight=0)
        home.grid_columnconfigure(0, weight=1)

        self.status_label = ctk.CTkLabel(home, text="", font=ctk.CTkFont(family="Courier New", size=20, weight="bold"),
                                         text_color="#555555")
        self.status_label.grid(row=0, column=0, pady=(60, 10))

        self.connect_btn = ctk.CTkButton(
            home, text="", width=280, height=80,
            font=ctk.CTkFont(family="Courier New", size=26, weight="bold"),
            corner_radius=10, border_width=2,
            command=self.connect_action, fg_color="#050505",
            border_color="#00FF00", text_color="#00FF00", hover_color="#113311"
        )
        self.connect_btn.grid(row=1, column=0, pady=40)
        self._add_pulse_animation(self.connect_btn)

        self.strategy_info_label = ctk.CTkLabel(
            home, textvariable=self.strategy_label_var,
            font=ctk.CTkFont(family="Courier New", size=14), text_color="#00FFFF"
        )
        self.strategy_info_label.grid(row=2, column=0, pady=20)

    def _build_settings_page(self):
        settings = self.pages["settings"]
        self.settings_title = ctk.CTkLabel(settings, text="", text_color="#FF00FF",
                                           font=ctk.CTkFont(family="Courier New", size=20, weight="bold"))
        self.settings_title.pack(pady=(20, 10))

        self._create_setting_row(settings, "game_filter", self.game_filter_var, self.toggle_game_filter_thread)
        self._create_setting_row(settings, "ip_override", self.ipset_filter_var, self.toggle_ipset_filter_thread)
        self._create_setting_row(settings, "auto_fetch", self.auto_update_var, self.toggle_auto_updates_thread)

        # Строка переключателя языка
        lang_frame = ctk.CTkFrame(settings, fg_color="#11131A", border_width=1, border_color="#333", corner_radius=5)
        lang_frame.pack(fill="x", padx=20, pady=10)

        self.setting_labels["lang_select"] = ctk.CTkLabel(lang_frame, text="",
                                                          font=ctk.CTkFont(family="Courier New", size=14,
                                                                           weight="bold"), text_color="#00FFFF")
        self.setting_labels["lang_select"].pack(side="left", padx=15, pady=10)

        self.lang_switch = ctk.CTkSegmentedButton(
            lang_frame, values=["RU", "EN"],
            font=ctk.CTkFont(family="Courier New", weight="bold"),
            selected_color="#FF00FF",
            unselected_color="#222",
            text_color="#FFFFFF",
            command=self.change_language_event
        )
        self.lang_switch.set("RU")
        self.lang_switch.pack(side="right", padx=15)

    def _create_setting_row(self, parent, key, var, cmd):
        frame = ctk.CTkFrame(parent, fg_color="#11131A", border_width=1, border_color="#333", corner_radius=5)
        frame.pack(fill="x", padx=20, pady=10)

        lbl = ctk.CTkLabel(frame, text="", font=ctk.CTkFont(family="Courier New", size=14, weight="bold"),
                           text_color="#00FFFF")
        lbl.pack(side="left", padx=15, pady=10)
        self.setting_labels[key] = lbl

        val_lbl = ctk.CTkLabel(frame, textvariable=var, font=ctk.CTkFont(family="Courier New", size=14),
                               text_color="#FFFFFF")
        val_lbl.pack(side="left", padx=10)

        btn = ctk.CTkButton(frame, text="", width=100, font=ctk.CTkFont(family="Courier New", weight="bold"),
                            fg_color="transparent", border_width=1, border_color="#FF00FF", text_color="#FF00FF",
                            hover_color="#330033", command=cmd)
        btn.pack(side="right", padx=15)
        self.setting_btns[key] = btn

    def _build_strategies_page(self):
        strat = self.pages["strategies"]
        strat.grid_columnconfigure(0, weight=1)
        strat.grid_rowconfigure(2, weight=1)

        self.strat_title = ctk.CTkLabel(strat, text="", text_color="#00FFCC",
                                        font=ctk.CTkFont(family="Courier New", size=20, weight="bold"))
        self.strat_title.grid(row=0, column=0, pady=(20, 10))

        self.strategy_source = ctk.StringVar(value="strategies")
        source_frame = ctk.CTkFrame(strat, fg_color="transparent")
        source_frame.grid(row=1, column=0, pady=5, sticky="ew")

        self.strat_radio_std = ctk.CTkRadioButton(source_frame, text="", variable=self.strategy_source,
                                                  value="strategies", font=ctk.CTkFont(family="Courier New"),
                                                  text_color="#FFF", command=self.refresh_strategy_list)
        self.strat_radio_std.pack(side="left", padx=20)

        self.strat_radio_spec = ctk.CTkRadioButton(source_frame, text="", variable=self.strategy_source,
                                                   value="specstrategies", font=ctk.CTkFont(family="Courier New"),
                                                   text_color="#FFF", command=self.refresh_strategy_list)
        self.strat_radio_spec.pack(side="left", padx=20)

        self.strategies_container = ctk.CTkScrollableFrame(strat, label_text="",
                                                           label_font=ctk.CTkFont(family="Courier New", weight="bold"),
                                                           label_text_color="#00FFCC", fg_color="#0A0B10",
                                                           border_width=1, border_color="#00FFCC")
        self.strategies_container.grid(row=2, column=0, pady=10, padx=20, sticky="nsew")
        self.strategy_buttons = {}

        ctrl_frame = ctk.CTkFrame(strat, fg_color="transparent")
        ctrl_frame.grid(row=3, column=0, pady=15)

        self.strat_ctrl_btns["purge"] = ctk.CTkButton(ctrl_frame, text="",
                                                      font=ctk.CTkFont(family="Courier New", weight="bold"),
                                                      fg_color="transparent", border_width=1, border_color="#FF5500",
                                                      text_color="#FF5500", hover_color="#331100",
                                                      command=self.remove_services_thread)
        self.strat_ctrl_btns["purge"].pack(side="left", padx=10)

        self.strat_ctrl_btns["halt"] = ctk.CTkButton(ctrl_frame, text="",
                                                     font=ctk.CTkFont(family="Courier New", weight="bold"),
                                                     fg_color="transparent", border_width=1, border_color="#FF0055",
                                                     text_color="#FF0055", hover_color="#330011",
                                                     command=self.stop_strategy)
        self.strat_ctrl_btns["halt"].pack(side="left", padx=10)

        self.strat_ctrl_btns["ping"] = ctk.CTkButton(ctrl_frame, text="",
                                                     font=ctk.CTkFont(family="Courier New", weight="bold"),
                                                     fg_color="transparent", border_width=1, border_color="#00FFFF",
                                                     text_color="#00FFFF", hover_color="#003333",
                                                     command=self.check_status_thread)
        self.strat_ctrl_btns["ping"].pack(side="left", padx=10)

        self.refresh_strategy_list()

    def _build_updates_page(self):
        upd = self.pages["updates"]
        self.updates_title = ctk.CTkLabel(upd, text="", text_color="#FFFF00",
                                          font=ctk.CTkFont(family="Courier New", size=20, weight="bold"))
        self.updates_title.pack(pady=(20, 10))
        btn_frame = ctk.CTkFrame(upd, fg_color="transparent")
        btn_frame.pack(pady=20)

        self.update_btns["ipset"] = self._create_hacker_button(btn_frame, "btn_fetch_ipset", "#FFFF00",
                                                               self.update_ipset_thread)
        self.update_btns["hosts"] = self._create_hacker_button(btn_frame, "btn_patch_hosts", "#FFFF00",
                                                               self._ask_update_hosts)
        self.update_btns["core"] = self._create_hacker_button(btn_frame, "btn_check_updates", "#FFFF00",
                                                              self.check_updates_thread)

    def _build_tools_page(self):
        tools = self.pages["tools"]
        self.tools_title = ctk.CTkLabel(tools, text="", text_color="#FF5500",
                                        font=ctk.CTkFont(family="Courier New", size=20, weight="bold"))
        self.tools_title.pack(pady=(20, 10))
        btn_frame = ctk.CTkFrame(tools, fg_color="transparent")
        btn_frame.pack(pady=20)

        self.tools_btns["diag"] = self._create_hacker_button(btn_frame, "btn_run_diag", "#FF5500",
                                                             self.run_diagnostics_thread)
        self.tools_btns["tests"] = self._create_hacker_button(btn_frame, "btn_exec_tests", "#555555",
                                                              self.run_tests_thread)

    def _create_hacker_button(self, parent, string_key, color, cmd):
        btn = ctk.CTkButton(parent, text="", anchor="w", width=350,
                            font=ctk.CTkFont(family="Courier New", size=14, weight="bold"),
                            fg_color="transparent", border_width=1, border_color=color, text_color=color,
                            hover_color="#1A1A1A", command=cmd)
        btn.pack(pady=8)
        return btn

    def _add_pulse_animation(self, button):
        def pulse(step=0):
            try:
                if not self.winfo_exists() or not button.winfo_exists(): return
                strings = LANGUAGES[self.current_lang]
                if not self.connect_btn_pulsing and button.cget("text") == strings['btn_init']:
                    alpha = 0.5 + 0.5 * math.sin(step * 0.2)
                    color = f"#{0:02x}{int(255 * alpha):02x}{0:02x}"
                    button.configure(border_color=color, text_color=color)
                    self.after(50, lambda: pulse(step + 1))
            except Exception:
                pass

        self.after(100, pulse)

    def update_ui_language(self):
        lang = self.current_lang
        strings = LANGUAGES[lang]

        # Обновление заголовка окна
        self.title(f"{strings['title']} [v{LOCAL_VERSION}]_")
        self.header_label.configure(text=f"ZAPRETMODDED // SYSTEM_MANAGER_v{LOCAL_VERSION}")
        self.sidebar_title.configure(text=strings['main_menu'])

        # Боковое меню
        self.nav_buttons["home"].configure(text=strings['nav_home'])
        self.nav_buttons["settings"].configure(text=strings['nav_config'])
        self.nav_buttons["strategies"].configure(text=strings['nav_strategy'])
        self.nav_buttons["updates"].configure(text=strings['nav_update'])
        self.nav_buttons["tools"].configure(text=strings['nav_tools'])

        # Логи / Терминал
        self.terminal_title_label.configure(text=strings['terminal_title'])
        self.copy_log_btn.configure(text=strings['copy_log'])

        # Страница Настроек
        self.settings_title.configure(text=strings['sys_config'])
        self.setting_labels["game_filter"].configure(text=strings['game_filter'])
        self.setting_labels["ip_override"].configure(text=strings['ip_override'])
        self.setting_labels["auto_fetch"].configure(text=strings['auto_fetch'])
        self.setting_labels["lang_select"].configure(text=strings['lang_select'])

        for k in self.setting_btns:
            self.setting_btns[k].configure(text=strings['toggle_btn'])

        self.update_game_filter_status()
        self.update_ipset_status()
        self.update_auto_update_status()

        # Страница Стратегий
        self.strat_title.configure(text=strings['strat_deployment'])
        self.strat_radio_std.configure(text=strings['strat_standard'])
        self.strat_radio_spec.configure(text=strings['strat_special'])
        self.strategies_container.configure(label_text=strings['avail_payloads'])
        self.strat_ctrl_btns["purge"].configure(text=strings['btn_purge'])
        self.strat_ctrl_btns["halt"].configure(text=strings['btn_halt'])
        self.strat_ctrl_btns["ping"].configure(text=strings['btn_ping'])

        # Страница Обновлений
        self.updates_title.configure(text=strings['sys_updates'])
        self.update_btns["ipset"].configure(text=f"> {strings['btn_fetch_ipset']}")
        self.update_btns["hosts"].configure(text=f"> {strings['btn_patch_hosts']}")
        self.update_btns["core"].configure(text=f"> {strings['btn_check_updates']}")

        # Страница Диагностики
        self.tools_title.configure(text=strings['diag_tools'])
        self.tools_btns["diag"].configure(text=f"> {strings['btn_run_diag']}")
        self.tools_btns["tests"].configure(text=f"> {strings['btn_exec_tests']}")

        # Обновление динамического статуса на главной
        self.update_connect_button_state()
        self.update_strategy_status()

    def change_language_event(self, value):
        if value == "RU":
            self.current_lang = "ru"
        else:
            self.current_lang = "en"
        self.update_ui_language()
        self.log(f"Language changed to / Язык изменен на: {value}", "cyan")

    def refresh_strategy_list(self):
        for widget in self.strategies_container.winfo_children():
            widget.destroy()
        self.strategy_buttons.clear()

        source = self.strategy_source.get()
        path = self.strategies_path if source == "strategies" else self.spec_strategies_path
        strings = LANGUAGES[self.current_lang]

        if not path.exists():
            ctk.CTkLabel(self.strategies_container, text=strings['err_path_not_found'].format(path=path.name),
                         text_color="#FF0055", font=ctk.CTkFont(family="Courier New")).pack(pady=20)
            return

        bat_files = [f for f in path.glob("*.bat") if not f.name.lower().startswith("service")]
        if not bat_files:
            ctk.CTkLabel(self.strategies_container, text=strings['err_no_payloads'], text_color="#FFFF00",
                         font=ctk.CTkFont(family="Courier New")).pack(pady=20)
            return

        bat_files.sort(key=lambda x: int(re.findall(r'\d+', x.stem)[0]) if re.findall(r'\d+', x.stem) else 0)

        for bat_file in bat_files:
            btn = ctk.CTkButton(
                self.strategies_container, text=f"> {bat_file.name}", anchor="w",
                font=ctk.CTkFont(family="Courier New", size=13),
                fg_color="#11131A", hover_color="#1A2B2B", text_color="#00FFFF",
                border_width=1, border_color="#005555",
                command=lambda f=bat_file: self.install_selected_strategy(f)
            )
            btn.pack(fill="x", padx=5, pady=3)
            self.strategy_buttons[bat_file.name] = bat_file

    def install_selected_strategy(self, bat_file):
        self.run_in_thread(self._install_service_thread, args=(bat_file,))

    def create_log_area(self):
        self.terminal_title_label = ctk.CTkLabel(self.log_frame, text="",
                                                 font=ctk.CTkFont(family="Courier New", size=12, weight="bold"),
                                                 text_color="#00FFCC")
        self.terminal_title_label.pack(anchor="w", padx=10, pady=(5, 0))

        self.log_textbox = ctk.CTkTextbox(self.log_frame, wrap="word", fg_color="#000000",
                                          font=ctk.CTkFont(family="Courier New", size=12), border_width=0)
        self.log_textbox.pack(fill="both", expand=True, padx=5, pady=(2, 5))

        self.log_textbox.tag_config("green", foreground="#00FF00")
        self.log_textbox.tag_config("red", foreground="#FF0055")
        self.log_textbox.tag_config("yellow", foreground="#FFFF00")
        self.log_textbox.tag_config("white", foreground="#CCCCCC")
        self.log_textbox.tag_config("cyan", foreground="#00FFFF")

        self.copy_log_btn = ctk.CTkButton(self.log_frame, text="",
                                          font=ctk.CTkFont(family="Courier New", weight="bold"),
                                          command=self.copy_log_to_clipboard, width=130, height=25, fg_color="#111",
                                          border_width=1, border_color="#00FFCC", text_color="#00FFCC",
                                          hover_color="#003333")
        self.copy_log_btn.place(relx=1.0, rely=0.0, anchor="ne", x=-10, y=5)

    def show_page(self, page_name):
        for name, frame in self.pages.items():
            if name == page_name:
                frame.lift()

    def _on_closing(self):
        self._stop_all_animations()
        self._shake_window()

    def _shake_window(self, count=15, delay=20):
        if count == 0:
            self.destroy()
            return
        if self._original_geometry is None:
            geom = self.geometry()
            if '+' in geom:
                parts = geom.split('+')
                if len(parts) >= 3:
                    self._original_geometry = (int(parts[1]), int(parts[2]))
                else:
                    self._original_geometry = (100, 100)

        dx = random.randint(-15, 15)
        dy = random.randint(-10, 10)
        x = self._original_geometry[0] + dx
        y = self._original_geometry[1] + dy
        self.geometry(f"+{x}+{y}")
        self.after(delay, lambda: self._shake_window(count - 1, delay))

    def update_connect_button_state(self):
        strings = LANGUAGES[self.current_lang]
        rc, out, _ = run_cmd('tasklist /FI "IMAGENAME eq winws.exe"')
        is_running = "winws.exe" in out
        self.stop_pulse()
        if is_running:
            self.connect_btn.configure(text=strings['btn_terminate'], fg_color="#1A0505", border_color="#FF0055",
                                       text_color="#FF0055", hover_color="#330011")
            self.status_label.configure(text=strings['status_connected'], text_color="#00FF00")
        else:
            self.connect_btn.configure(text=strings['btn_init'], fg_color="#050505", border_color="#00FF00",
                                       text_color="#00FF00", hover_color="#113311")
            self.status_label.configure(text=strings['status_awaiting'], text_color="#555555")
            self.start_pulse()

    def start_pulse(self):
        if not self.connect_btn_pulsing and not self.pulse_job:
            self.connect_btn_pulsing = True
            self._pulse_step(True)

    def stop_pulse(self):
        if self.pulse_job:
            self.after_cancel(self.pulse_job)
            self.pulse_job = None
        self.connect_btn_pulsing = False
        self.connect_btn.configure(fg_color="#050505")

    def _pulse_step(self, light=True):
        if not self.connect_btn_pulsing: return
        try:
            if not self.winfo_exists() or not self.connect_btn.winfo_exists(): return
            strings = LANGUAGES[self.current_lang]
            if self.connect_btn.cget("text") == strings['btn_init']:
                color = "#00FF00" if light else "#005500"
                self.connect_btn.configure(border_color=color, text_color=color)
                self.pulse_job = self.after(700, self._pulse_step, not light)
        except tkinter.TclError:
            pass

    def connect_action(self):
        strings = LANGUAGES[self.current_lang]
        rc, out, _ = run_cmd('tasklist /FI "IMAGENAME eq winws.exe"')
        if "winws.exe" in out:
            self.stop_strategy()
        else:
            self.show_page("strategies")
            messagebox.showinfo(strings['msg_payload_req_title'], strings['msg_payload_req_body'])
        self.update_connect_button_state()

    def copy_log_to_clipboard(self):
        strings = LANGUAGES[self.current_lang]
        log_content = self.log_textbox.get("1.0", "end-1c")
        if not log_content.strip():
            self.log(strings['log_empty'], "yellow")
            return
        try:
            self.clipboard_clear()
            self.clipboard_append(log_content)
            self.log(strings['log_copied'], "cyan")
        except Exception as e:
            self.log(f"{strings['copy_failed']}{e}", "red")

    def log(self, message, color="white"):
        def _log():
            try:
                timestamp = time.strftime("[%H:%M:%S] ")
                self.log_textbox.insert("end", timestamp + message + "\n", color)
                self.log_textbox.see("end")
            except Exception as e:
                print(f"Log Error: {e}")

        self.after(0, _log)

    def update_strategy_status(self):
        strings = LANGUAGES[self.current_lang]
        rc, out, _ = run_cmd('tasklist /FI "IMAGENAME eq winws.exe"')
        if "winws.exe" in out:
            name = get_reg_str(winreg.HKEY_LOCAL_MACHINE, r"System\CurrentControlSet\Services\zapret",
                               "zapret-discord-youtube")
            if name:
                self.strategy_label_var.set(strings['payload_active'].format(name=name))
            else:
                self.strategy_label_var.set(strings['payload_active'].format(name="UNKNOWN"))
        else:
            self.strategy_label_var.set(strings['payload_none'])

    def update_game_filter_status(self):
        strings = LANGUAGES[self.current_lang]
        self.game_filter_var.set(strings['enabled'] if self.game_filter_flag.exists() else strings['disabled'])

    def update_ipset_status(self):
        strings = LANGUAGES[self.current_lang]
        if not self.ipset_file.exists():
            self.ipset_filter_var.set(strings['all_traffic'])
            return
        with open(self.ipset_file, 'r', encoding='utf-8', errors='ignore') as f:
            lines = [l.strip() for l in f if l.strip()]
        if len(lines) == 0:
            self.ipset_filter_var.set(strings['all_traffic'])
        elif len(lines) == 1 and lines[0] == "203.0.113.113/32":
            self.ipset_filter_var.set(strings['bypass_disabled'])
        else:
            self.ipset_filter_var.set(strings['loaded_only'])

    def update_auto_update_status(self):
        strings = LANGUAGES[self.current_lang]
        self.auto_update_var.set(strings['enabled'] if self.auto_update_flag.exists() else strings['disabled'])

    def run_in_thread(self, target, args=()):
        threading.Thread(target=target, args=args, daemon=True).start()

    def remove_services_thread(self):
        self.run_in_thread(self.remove_services)

    def check_status_thread(self):
        self.run_in_thread(self.check_status)

    def toggle_game_filter_thread(self):
        self.run_in_thread(self.toggle_game_filter)

    def toggle_ipset_filter_thread(self):
        self.run_in_thread(self.toggle_ipset_filter)

    def toggle_auto_updates_thread(self):
        self.run_in_thread(self.toggle_auto_updates)

    def update_ipset_thread(self):
        self.run_in_thread(self.update_ipset)

    def check_updates_thread(self):
        self.run_in_thread(self.check_updates)

    def run_diagnostics_thread(self):
        self.run_in_thread(self.run_diagnostics)

    def run_tests_thread(self):
        self.run_in_thread(self.run_tests)

    def remove_services(self):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['init_purge'], "yellow")
        if get_service_status("zapret") != "NOT_FOUND":
            stop_service("zapret")
            delete_service("zapret")
            self.log(strings['srv_deleted'], "green")
        else:
            self.log(strings['srv_not_found'], "yellow")
        run_cmd('taskkill /IM winws.exe /F', show_error=False)
        self.log(strings['windivert_keep'], "cyan")
        self.update_strategy_status()
        self.update_connect_button_state()

    def _install_service_thread(self, bat_file):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['deploy_payload'], "yellow")
        self.stop_strategy()

        wd_status = get_service_status("WinDivert")
        if wd_status == "NOT_FOUND":
            self.log(strings['wd_missing'], "yellow")
            windivert_sys = self.bin_path / "WinDivert64.sys"
            if windivert_sys.exists():
                run_cmd(f'sc create WinDivert binPath= "{windivert_sys}" type= kernel start= demand', show_error=False)
                run_cmd('sc start WinDivert', show_error=False)
                self.log(strings['wd_injected'], "green")
            else:
                self.log(strings['wd_err'], "red")
        elif wd_status != "RUNNING":
            self.log(strings['wd_halted'], "yellow")
            run_cmd('sc start WinDivert', show_error=False)
            time.sleep(1)
            if get_service_status("WinDivert") == "RUNNING":
                self.log(strings['wd_online'], "green")
            else:
                self.log(strings['wd_start_failed'], "yellow")

        game_filter_value = "1024-65535" if self.game_filter_flag.exists() else "12"
        install_script = self.tools_path / "install_via_service.bat"
        if not install_script.exists():
            self.log(strings['script_missing'], "red")
            return

        cmd = f'"{install_script}" "{bat_file}" {game_filter_value} "{self.bin_path}" "{self.lists_path}"'
        self.log(f"EXEC: {cmd}", "white")
        rc, out, err = run_cmd(cmd)
        if out: self.log(out, "cyan" if rc == 0 else "red")
        if err: self.log(err, "red")

        time.sleep(3)
        rc, out, _ = run_cmd('tasklist /FI "IMAGENAME eq winws.exe"')
        if "winws.exe" in out:
            self.log(strings['deploy_success'], "green")
        else:
            self.log(strings['deploy_failed'], "red")
        self.update_strategy_status()
        self.update_connect_button_state()

    def stop_strategy(self):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['halt_winws'], "yellow")
        run_cmd('taskkill /IM winws.exe /F', show_error=False)
        if self.winws_process:
            try:
                self.winws_process.terminate()
            except:
                pass
            self.winws_process = None
        self.log(strings['proc_terminated'], "green")
        self.update_strategy_status()
        self.update_connect_button_state()

    def check_status(self):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['ping_status'], "cyan")
        rc, out, _ = run_cmd('tasklist /FI "IMAGENAME eq winws.exe"')
        if "winws.exe" in out:
            self.log(f"STATUS: {strings['enabled']} [winws.exe RUNNING]", "green")
        else:
            self.log(f"STATUS: {strings['disabled']} [winws.exe HALTED]", "red")

    def toggle_game_filter(self):
        strings = LANGUAGES[self.current_lang]
        if self.game_filter_flag.exists():
            self.game_filter_flag.unlink()
            self.log(strings['game_filt_dis'], "yellow")
        else:
            self.game_filter_flag.write_text("ENABLED", encoding='utf-8')
            self.log(strings['game_filt_en'], "cyan")
        self.update_game_filter_status()

    def toggle_ipset_filter(self):
        strings = LANGUAGES[self.current_lang]
        current = self.ipset_filter_var.get()
        self.log(f"{strings['toggle_ip_filt']}{current}...", "yellow")

        if current == strings['all_traffic']:
            if self.ipset_backup.exists():
                shutil.copy2(self.ipset_backup, self.ipset_file)
                self.log(strings['restore_ipset'], "green")
            else:
                self.ipset_file.write_text("", encoding='utf-8')
                self.log(strings['backup_not_found'], "yellow")
        elif current == strings['loaded_only']:
            if not self.ipset_backup.exists() and self.ipset_file.exists():
                shutil.copy2(self.ipset_file, self.ipset_backup)
            self.ipset_file.write_text("203.0.113.113/32\n", encoding='utf-8')
            self.log(strings['mode_bypass_dis'], "cyan")
        elif current == strings['bypass_disabled']:
            self.ipset_file.write_text("", encoding='utf-8')
            self.log(strings['mode_all_traf'], "cyan")
        self.update_ipset_status()

    def toggle_auto_updates(self):
        strings = LANGUAGES[self.current_lang]
        if self.auto_update_flag.exists():
            self.auto_update_flag.unlink()
            self.log(strings['auto_upd_dis'], "yellow")
        else:
            self.auto_update_flag.write_text("ENABLED", encoding='utf-8')
            self.log(strings['auto_upd_en'], "cyan")
        self.update_auto_update_status()

    def update_ipset(self):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['fetch_ipset'], "yellow")
        try:
            req = urllib.request.Request(IPSET_URL, headers={'Cache-Control': 'no-cache'})
            with urllib.request.urlopen(req, timeout=15) as resp:
                content = resp.read().decode('utf-8')
            self.ipset_file.write_text(content, encoding='utf-8')
            self.log(strings['fetch_success'], "green")
        except Exception as e:
            self.log(f"{strings['fetch_failed']}{e}", "red")
        self.update_ipset_status()

    def _ask_update_hosts(self):
        strings = LANGUAGES[self.current_lang]
        if messagebox.askyesno(strings['hosts_patch_title'], strings['hosts_patch_body']):
            self.run_in_thread(self._update_hosts_auto)
        else:
            self.run_in_thread(self._update_hosts_manual)

    def _update_hosts_auto(self):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['auto_patch_hosts'], "yellow")
        temp_file = self.base_dir / "hosts_temp.txt"
        try:
            req = urllib.request.Request(HOSTS_URL, headers={'Cache-Control': 'no-cache'})
            with urllib.request.urlopen(req, timeout=15) as resp:
                content = resp.read().decode('utf-8')
            temp_file.write_text(content, encoding='utf-8')
        except Exception as e:
            self.log(f"{strings['download_failed']}{e}", "red")
            return
        hosts_path = Path(os.environ['SystemRoot']) / "System32/drivers/etc/hosts"
        try:
            run_cmd(f'attrib -r -s -h "{hosts_path}"')
            shutil.copy2(temp_file, hosts_path)
            self.log(strings['hosts_success'], "green")
        except Exception as e:
            self.log(strings['auto_write_failed'].format(e=e), "red")
            self._update_hosts_manual()
        finally:
            if temp_file.exists(): temp_file.unlink()

    def _update_hosts_manual(self):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['manual_hosts_init'], "yellow")
        temp_file = self.base_dir / "hosts_temp.txt"
        try:
            req = urllib.request.Request(HOSTS_URL, headers={'Cache-Control': 'no-cache'})
            with urllib.request.urlopen(req, timeout=15) as resp:
                content = resp.read().decode('utf-8')
            temp_file.write_text(content, encoding='utf-8')
        except Exception as e:
            self.log(f"{strings['download_failed']}{e}", "red")
            return
        hosts_path = Path(os.environ['SystemRoot']) / "System32/drivers/etc/hosts"
        try:
            import ctypes.wintypes
            CF_UNICODETEXT = 13
            GMEM_MOVEABLE = 0x0002
            kernel32 = ctypes.windll.kernel32
            user32 = ctypes.windll.user32
            user32.OpenClipboard(0)
            user32.EmptyClipboard()
            hMem = kernel32.GlobalAlloc(GMEM_MOVEABLE, (len(content) + 1) * 2)
            if hMem:
                ptr = kernel32.GlobalLock(hMem)
                ctypes.memmove(ptr, content.encode('utf-16le'), len(content) * 2 + 2)
                kernel32.GlobalUnlock(hMem)
                user32.SetClipboardData(CF_UNICODETEXT, hMem)
            user32.CloseClipboard()
            self.log(strings['hosts_clipboard'], "green")
        except Exception as e:
            self.log(f"{strings['clipboard_err']}{e}", "red")

        self.log(strings['opening_notepad'], "cyan")
        run_cmd(f'powershell -Command "Start-Process notepad.exe -ArgumentList \'{hosts_path}\' -Verb RunAs"',
                capture=False)
        messagebox.showinfo(strings['manual_patch_title'], strings['manual_patch_body'])
        temp_file.unlink()

    def check_updates(self):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['ping_server'], "yellow")
        try:
            req = urllib.request.Request(GITHUB_VERSION_URL, headers={'Cache-Control': 'no-cache'})
            with urllib.request.urlopen(req, timeout=10) as resp:
                new_version = resp.read().decode('utf-8').strip()
            if new_version == LOCAL_VERSION:
                self.log(strings['sys_up_to_date'].format(version=LOCAL_VERSION), "green")
            else:
                self.log(strings['new_ver_detect'].format(version=new_version), "cyan")
                self.after(0, lambda: self._ask_open_release_page())
        except Exception as e:
            self.log(f"UPDATE CHECK FAILED: {e}", "red")

    def _ask_open_release_page(self):
        strings = LANGUAGES[self.current_lang]
        if messagebox.askyesno(strings['new_ver_title'], strings['new_ver_body']):
            os.startfile(GITHUB_DOWNLOAD_URL)

    def check_updates_auto(self):
        self.run_in_thread(self.check_updates)

    def run_diagnostics(self):
        strings = LANGUAGES[self.current_lang]
        self.log(strings['run_diag_title'], "cyan")
        status = get_service_status("BFE")
        self.log(strings['bfe_status'] + ("ONLINE" if status == "RUNNING" else "OFFLINE [CRITICAL ERROR]"),
                 "green" if status == "RUNNING" else "red")
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                                r"Software\Microsoft\Windows\CurrentVersion\Internet Settings") as key:
                proxy_enable, _ = winreg.QueryValueEx(key, "ProxyEnable")
                if proxy_enable:
                    proxy_server, _ = winreg.QueryValueEx(key, "ProxyServer")
                    self.log(strings['proxy_detect'].format(proxy=proxy_server), "yellow")
                else:
                    self.log(strings['proxy_clear'], "green")
        except:
            pass

        rc, out, _ = run_cmd('netsh interface tcp show global')
        if "timestamps" in out and "enabled" in out:
            self.log(strings['tcp_ts_en'], "green")
        else:
            self.log(strings['tcp_ts_dis'], "yellow")
            run_cmd('netsh interface tcp set global timestamps=enabled')
        self.log(strings['diag_complete'], "green")

    def run_tests(self):
        messagebox.showinfo("WIP", "Feature in development.")

    def _ensure_install_bat(self):
        install_bat = self.tools_path / "install_via_service.bat"
        if install_bat.exists(): return
        content = r'''@echo off
setlocal EnableDelayedExpansion
set "FULL_BAT_PATH=%~1"
set "GameFilter=%~2"
set "BIN_PATH=%~3\"
set "LISTS_PATH=%~4\"
set "args_with_value=sni host altorder"
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="
if not exist "%FULL_BAT_PATH%" exit /b 1
for /f "usebackq tokens=*" %%a in ("%FULL_BAT_PATH%") do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"
    echo !line! | findstr /i "winws.exe" >nul
    if not errorlevel 1 set "capture=1"
    if !capture!==1 (
        if not defined args set "line=!line:*winws.exe"=!"
        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"
            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 set "mergeargs=0"
                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"
                    if "!arg:~0,5!"=="%%BIN%%" (set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\\!QUOTE!"
                    ) else set "arg=\!QUOTE!%~dp0!arg!\\!QUOTE!"
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" set "arg=%GameFilter%"
                if !mergeargs!==1 (set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (set "temp_args=!temp_args!=!arg!" & set "mergeargs=1"
                ) else set "temp_args=!temp_args! !arg!"
                if "!arg:~0,2!" EQU "--" (set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"
                    for %%x in (!args_with_value!) do if /i "%%x"=="!arg!" set "mergeargs=3"
                )
            )
        )
        if defined temp_args set "args=!args! !temp_args!"
    )
)
set "ARGS=%args%"
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
netsh interface tcp set global timestamps=enabled >nul 2>&1
sc stop zapret >nul 2>&1
sc delete zapret >nul 2>&1
sc create zapret binPath= "\"%BIN_PATH%winws.exe\" %ARGS%" DisplayName= "zapret" start= auto
sc description zapret "Zapret DPI bypass software"
sc start zapret
for %%F in ("%FULL_BAT_PATH%") do set "filename=%%~nF"
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f
exit /b 0
'''
        install_bat.write_text(content, encoding='utf-8')
        install_bat.chmod(0o755)


if __name__ == "__main__":
    if '--elevated-requested' in sys.argv:
        sys.argv.remove('--elevated-requested')
        if not is_admin():
            from tkinter import messagebox

            messagebox.showerror("ACCESS DENIED", "Failed to acquire Administrator privileges.")
            sys.exit(1)
    else:
        if not is_admin():
            run_as_admin()
            sys.exit(0)

    app = ZapretManagerApp()
    app.mainloop()