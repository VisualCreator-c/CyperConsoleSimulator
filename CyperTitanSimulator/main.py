import customtkinter as ctk
import os
import time
import threading
import random
import string
import socket
import psutil
import datetime
import platform
import webbrowser
import json
from tkinter import Canvas

# --- БЕЗОПАСНЫЙ ИМПОРТ ---
try:
    import requests

    WEB_AVAILABLE = True
except ImportError:
    WEB_AVAILABLE = False

try:
    from cryptography.fernet import Fernet

    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False

# --- КОНФИГУРАЦИЯ ---
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("green")

FONT_MONO = ("Consolas", 14)
FONT_HEADER = ("Impact", 26)
FONT_UI = ("Roboto Medium", 13)


# ==========================================
# CLASS: BOOT SCREEN (ЗАГРУЗКА)
# ==========================================
class BootSplash(ctk.CTkFrame):
    def __init__(self, parent, complete_callback):
        super().__init__(parent, fg_color="black")
        self.place(relx=0, rely=0, relwidth=1, relheight=1)
        self.complete_callback = complete_callback

        self.lbl_term = ctk.CTkLabel(self, text="", font=("Consolas", 16), text_color="#00FF00", anchor="nw",
                                     justify="left")
        self.lbl_term.place(relx=0.05, rely=0.05)

        self.progress = ctk.CTkProgressBar(self, width=600, height=15, progress_color="#00FF00")
        self.progress.place(relx=0.5, rely=0.8, anchor="center")
        self.progress.set(0)

        self.boot_sequence = [
            "Initializing Kernel...",
            "Loading Modules: [NET, CRYPTO, GUI]...",
            "Bypassing Firewalls...",
            "Connecting to Satellite Uplink...",
            "Mounting File System...",
            "SYSTEM READY."
        ]
        self.step = 0
        self.run_animation()

    def run_animation(self):
        if self.step < len(self.boot_sequence):
            txt = self.boot_sequence[self.step]
            current_text = self.lbl_term.cget("text")
            self.lbl_term.configure(text=current_text + f"> {txt}\n")

            prog = (self.step + 1) / len(self.boot_sequence)
            self.progress.set(prog)

            self.step += 1
            delay = random.randint(300, 800)
            self.after(delay, self.run_animation)
        else:
            self.after(1000, self.finish)

    def finish(self):
        self.place_forget()  # Удаляем экран загрузки
        self.complete_callback()  # Запускаем основное приложение


# ==========================================
# CLASS: MATRIX WINDOW
# ==========================================
class MatrixRain(ctk.CTkToplevel):
    def __init__(self):
        super().__init__()
        self.title("MATRIX LINK")
        self.geometry("600x400")
        self.attributes("-topmost", True)
        self.configure(fg_color="black")
        self.canvas = Canvas(self, bg="black", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.width = 600
        self.height = 400
        self.drops = [0 for _ in range(40)]
        self.is_running = True
        self.draw()

    def draw(self):
        if not self.is_running: return
        self.canvas.delete("all")
        for i in range(len(self.drops)):
            char = random.choice(string.printable)
            x = i * 15
            y = self.drops[i] * 15
            color = "#0F0" if random.random() > 0.1 else "#FFF"
            self.canvas.create_text(x, y, text=char, fill=color, font=("Consolas", 10))
            if self.drops[i] * 15 > self.height and random.random() > 0.975:
                self.drops[i] = 0
            self.drops[i] += 1
        self.after(30, self.draw)


# ==========================================
# MAIN APP: CYBER TITAN
# ==========================================
class CyberTitan(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("CYBER TITAN v5.0 — GLOBAL EDITION")
        self.geometry("1200x800")

        # Сетка
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # Боковое меню (скрыто до конца загрузки)
        self.sidebar = ctk.CTkFrame(self, width=220, corner_radius=0)
        self.frames = {}

        # Запуск анимации загрузки
        self.boot_screen = BootSplash(self, self.init_interface)

    def init_interface(self):
        """Вызывается после завершения загрузки"""
        self.setup_sidebar()
        self.setup_pages()
        self.show_dashboard()

    def setup_sidebar(self):
        self.sidebar.grid(row=0, column=0, sticky="nsew")
        self.sidebar.grid_rowconfigure(8, weight=1)

        logo = ctk.CTkLabel(self.sidebar, text="TITAN\nFRAMEWORK", font=("Impact", 30))
        logo.grid(row=0, column=0, padx=20, pady=(30, 20))

        # Кнопки
        self.add_menu_btn("DASHBOARD", 1, self.show_dashboard)
        self.add_menu_btn("TERMINAL", 2, self.show_terminal)
        self.add_menu_btn("NET SCANNER", 3, self.show_netscan)
        self.add_menu_btn("GEO TRACKER", 4, self.show_geoip)
        self.add_menu_btn("PASS GEN", 5, self.show_passgen)
        self.add_menu_btn("CRYPTO VAULT", 6, self.show_crypto)

        # Uptime
        self.start_time = time.time()
        self.lbl_uptime = ctk.CTkLabel(self.sidebar, text="UPTIME: 00:00:00", font=("Consolas", 11), text_color="gray")
        self.lbl_uptime.grid(row=9, column=0, pady=20)
        self.update_uptime()

    def add_menu_btn(self, text, row, cmd):
        btn = ctk.CTkButton(self.sidebar, text=text, command=cmd, fg_color="transparent",
                            hover_color="#27ae60", anchor="w", height=45, font=FONT_UI)
        btn.grid(row=row, column=0, padx=10, pady=5, sticky="ew")

    def setup_pages(self):
        # Создаем контейнеры для всех страниц
        for name in ["Dashboard", "Terminal", "Netscan", "GeoIP", "PassGen", "Crypto"]:
            frame = ctk.CTkFrame(self, corner_radius=0, fg_color="transparent")
            self.frames[name] = frame

            # Инициализация содержимого
            if name == "Dashboard":
                self.setup_dashboard_ui(frame)
            elif name == "Terminal":
                self.setup_terminal_ui(frame)
            elif name == "Netscan":
                self.setup_netscan_ui(frame)
            elif name == "GeoIP":
                self.setup_geoip_ui(frame)
            elif name == "PassGen":
                self.setup_passgen_ui(frame)
            elif name == "Crypto":
                self.setup_crypto_ui(frame)

    def switch_frame(self, name):
        for frame in self.frames.values():
            frame.grid_forget()
        self.frames[name].grid(row=0, column=1, sticky="nsew", padx=20, pady=20)

    # --- NAVIGATORS ---
    def show_dashboard(self):
        self.switch_frame("Dashboard")

    def show_terminal(self):
        self.switch_frame("Terminal")

    def show_netscan(self):
        self.switch_frame("Netscan")

    def show_geoip(self):
        self.switch_frame("GeoIP")

    def show_passgen(self):
        self.switch_frame("PassGen")

    def show_crypto(self):
        self.switch_frame("Crypto")

    # ==========================================
    # 1. DASHBOARD
    # ==========================================
    def setup_dashboard_ui(self, parent):
        # Хардварная инфа
        row1 = ctk.CTkFrame(parent)
        row1.pack(fill="x", pady=10)

        self.cpu_card = self.create_card(row1, "CPU CORE", "0%", 0)
        self.ram_card = self.create_card(row1, "RAM MEMORY", "0%", 1)
        self.disk_card = self.create_card(row1, "DISK SPACE", "0%", 2)

        # Детальная инфа
        row2 = ctk.CTkFrame(parent)
        row2.pack(fill="both", expand=True, pady=10)

        ctk.CTkLabel(row2, text="SYSTEM DIAGNOSTICS", font=FONT_HEADER).pack(pady=10)

        self.sys_info_log = ctk.CTkTextbox(row2, font=("Consolas", 12))
        self.sys_info_log.pack(fill="both", expand=True, padx=10, pady=10)

        uname = platform.uname()
        info = f"""
        OPERATING SYSTEM: {uname.system} {uname.release}
        VERSION: {uname.version}
        MACHINE: {uname.machine}
        PROCESSOR: {uname.processor}
        HOSTNAME: {socket.gethostname()}
        """
        self.sys_info_log.insert("0.0", info)

        self.update_monitor()

    def create_card(self, parent, title, value, col):
        frame = ctk.CTkFrame(parent)
        frame.grid(row=0, column=col, padx=5, pady=5, sticky="ew")
        parent.grid_columnconfigure(col, weight=1)
        ctk.CTkLabel(frame, text=title, font=("Arial", 11, "bold")).pack(pady=(10, 0))
        lbl = ctk.CTkLabel(frame, text=value, font=("Impact", 28), text_color="#2ecc71")
        lbl.pack(pady=(0, 10))
        return lbl

    def update_monitor(self):
        cpu = psutil.cpu_percent()
        ram = psutil.virtual_memory().percent
        disk = psutil.disk_usage('/').percent

        self.cpu_card.configure(text=f"{cpu}%")
        self.ram_card.configure(text=f"{ram}%")
        self.disk_card.configure(text=f"{disk}%")

        color = "red" if cpu > 70 else "#2ecc71"
        self.cpu_card.configure(text_color=color)

        self.after(2000, self.update_monitor)

    # ==========================================
    # 2. TERMINAL
    # ==========================================
    def setup_terminal_ui(self, parent):
        self.term_out = ctk.CTkTextbox(parent, font=FONT_MONO, fg_color="#1e1e1e", text_color="#ecf0f1")
        self.term_out.pack(fill="both", expand=True, pady=(0, 10))
        self.term_out._textbox.tag_config("sys", foreground="#2ecc71")
        self.term_out._textbox.tag_config("err", foreground="#e74c3c")

        self.term_in = ctk.CTkEntry(parent, font=FONT_MONO, placeholder_text="Execute command...")
        self.term_in.pack(fill="x")
        self.term_in.bind("<Return>", self.run_terminal_cmd)
        self.term_log("Titan Shell Ready. Commands - .clear, .matrix, .hash", "sys")

    def term_log(self, text, tag=""):
        t = datetime.datetime.now().strftime("[%H:%M:%S]")
        self.term_out.insert("end", f"{t} {text}\n", tag)
        self.term_out.see("end")

    def run_terminal_cmd(self, event):
        cmd = self.term_in.get().strip()
        self.term_in.delete(0, 'end')
        if not cmd: return
        self.term_log(f"> {cmd}")

        if cmd == ".clear":
            self.term_out.delete("1.0", "end")
        elif cmd == ".matrix":
            MatrixRain()
        elif cmd.startswith(".hash"):
            import hashlib
            try:
                self.term_log(f"SHA: {hashlib.sha256(cmd[6:].encode()).hexdigest()}", "sys")
            except:
                pass
        else:
            self.term_log(f"Command not found: {cmd}", "err")

    # ==========================================
    # 3. GEO TRACKER (NEW)
    # ==========================================
    def setup_geoip_ui(self, parent):
        ctk.CTkLabel(parent, text="IP GEOLOCATION TRACKER", font=FONT_HEADER).pack(pady=20)

        frame_input = ctk.CTkFrame(parent)
        frame_input.pack(pady=10)
        self.geo_entry = ctk.CTkEntry(frame_input, width=300, placeholder_text="Enter IP (e.g. 8.8.8.8)")
        self.geo_entry.pack(side="left", padx=10)
        ctk.CTkButton(frame_input, text="LOCATE TARGET", command=self.run_geoip).pack(side="left")

        self.geo_result = ctk.CTkTextbox(parent, font=("Consolas", 14), height=200)
        self.geo_result.pack(fill="x", padx=20, pady=20)

        self.btn_map = ctk.CTkButton(parent, text="OPEN IN GOOGLE MAPS", state="disabled", fg_color="#d35400",
                                     command=self.open_map)
        self.btn_map.pack(pady=10)
        self.last_coords = None

    def run_geoip(self):
        ip = self.geo_entry.get().strip()
        if not ip: return
        self.geo_result.delete("1.0", "end")
        self.geo_result.insert("end", f"Scanning {ip}...\n")

        threading.Thread(target=self.fetch_geoip, args=(ip,), daemon=True).start()

    def fetch_geoip(self, ip):
        try:
            if not WEB_AVAILABLE:
                self.geo_result.insert("end", "Error: 'requests' lib not installed.")
                return

            response = requests.get(f"http://ip-api.com/json/{ip}")
            data = response.json()

            if data['status'] == 'fail':
                self.geo_result.insert("end", f"FAILED: {data['message']}")
                return

            txt = f"""
            STATUS: SUCCESS
            ------------------
            COUNTRY:  {data.get('country')}
            CITY:     {data.get('city')}
            ISP:      {data.get('isp')}
            LATITUDE: {data.get('lat')}
            LONGITUDE:{data.get('lon')}
            TIMEZONE: {data.get('timezone')}
            """
            self.geo_result.insert("end", txt)
            self.last_coords = (data.get('lat'), data.get('lon'))
            self.btn_map.configure(state="normal")

        except Exception as e:
            self.geo_result.insert("end", f"Connection Error: {e}")

    def open_map(self):
        if self.last_coords:
            url = f"https://www.google.com/maps/search/?api=1&query={self.last_coords[0]},{self.last_coords[1]}"
            webbrowser.open(url)

    # ==========================================
    # 4. PASSWORD GENERATOR (NEW)
    # ==========================================
    def setup_passgen_ui(self, parent):
        ctk.CTkLabel(parent, text="SECURE PASSWORD GENERATOR", font=FONT_HEADER).pack(pady=20)

        self.pass_len = ctk.CTkSlider(parent, from_=8, to=64, number_of_steps=56)
        self.pass_len.pack(pady=20)
        self.pass_len.set(16)

        self.lbl_len = ctk.CTkLabel(parent, text="Length: 16")
        self.lbl_len.pack()
        self.pass_len.configure(command=lambda v: self.lbl_len.configure(text=f"Length: {int(v)}"))

        self.btn_gen = ctk.CTkButton(parent, text="GENERATE", command=self.gen_pass, height=50, font=FONT_UI)
        self.btn_gen.pack(pady=20)

        self.pass_out = ctk.CTkEntry(parent, width=500, font=("Consolas", 18), justify="center")
        self.pass_out.pack(pady=10)

    def gen_pass(self):
        length = int(self.pass_len.get())
        chars = string.ascii_letters + string.digits + "!@#$%^&*()"
        pwd = "".join(random.choice(chars) for _ in range(length))
        self.pass_out.delete(0, 'end')
        self.pass_out.insert(0, pwd)

    # ==========================================
    # 5. NETSCANNER & CRYPTO (Simplified)
    # ==========================================
    def setup_netscan_ui(self, parent):
        ctk.CTkLabel(parent, text="NETWORK PORT SCANNER", font=FONT_HEADER).pack(pady=20)
        self.ns_ip = ctk.CTkEntry(parent, placeholder_text="Target IP (127.0.0.1)");
        self.ns_ip.pack(pady=5)
        ctk.CTkButton(parent, text="SCAN", command=self.run_scan).pack(pady=10)
        self.ns_log = ctk.CTkTextbox(parent);
        self.ns_log.pack(fill="both", expand=True, padx=20, pady=20)

    def run_scan(self):
        ip = self.ns_ip.get() or "127.0.0.1"
        self.ns_log.insert("end", f"Scanning {ip}...\n")

        def scan():
            for p in [21, 22, 80, 443, 3306, 8080]:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(0.5)
                if s.connect_ex((ip, p)) == 0: self.ns_log.insert("end", f"[+] Port {p} OPEN\n")
                s.close()
            self.ns_log.insert("end", "Scan done.\n")

        threading.Thread(target=scan, daemon=True).start()

    def setup_crypto_ui(self, parent):
        ctk.CTkLabel(parent, text="AES-256 VAULT", font=FONT_HEADER).pack(pady=20)
        if not CRYPTO_AVAILABLE:
            ctk.CTkLabel(parent, text="Cryptography lib missing", text_color="red").pack();
            return

        self.key = Fernet.generate_key()
        self.cipher = Fernet(self.key)

        self.enc_in = ctk.CTkEntry(parent, width=400, placeholder_text="Secret Message...")
        self.enc_in.pack(pady=10)

        ctk.CTkButton(parent, text="ENCRYPT LOGS", command=self.do_enc).pack(pady=5)

        self.enc_out = ctk.CTkLabel(parent, text="...", text_color="#2ecc71", font=("Consolas", 12), wraplength=600)
        self.enc_out.pack(pady=20)

    def do_enc(self):
        txt = self.enc_in.get()
        if txt:
            enc = self.cipher.encrypt(txt.encode())
            self.enc_out.configure(text=f"ENCRYPTED BYTES:\n{enc}")

    # ==========================================
    # UTILS
    # ==========================================
    def update_uptime(self):
        el = int(time.time() - self.start_time)
        self.lbl_uptime.configure(text=f"UPTIME: {datetime.timedelta(seconds=el)}")
        self.after(1000, self.update_uptime)


if __name__ == "__main__":
    app = CyberTitan()
    app.mainloop()