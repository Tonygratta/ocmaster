import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import paramiko
import threading
import os

class SSHApp:
    def __init__(self, root):
        self.root = root
        self.root.title("SSH Client")
        self.root.geometry("600x550")
        
        # Основной скрипт, который будет выполняться на сервере
        self.bash_script = """#!/bin/bash
echo "=== System info ==="
uname -a
echo ""
echo "=== Disk space ==="
df -h
echo ""
echo "=== Memory usage ==="
free -h
echo ""
echo "=== First 10 processes ==="
ps aux | head -n 10
"""
        
        self.setup_ui()
        
        
    def setup_ui(self):
        # Фрейм для ввода данных
        input_frame = ttk.LabelFrame(self.root, text="Connection to server", padding=10)
        input_frame.pack(fill="x", padx=10, pady=5)
        
        # Поле для ввода хоста
        ttk.Label(input_frame, text="Host:").grid(row=0, column=0, sticky="w", pady=2)
        self.host_entry = ttk.Entry(input_frame, width=40)
        self.host_entry.grid(row=0, column=1, padx=5, pady=2)
        self.host_entry.insert(0, "192.168.1.54")  # Пример значения
        
        # Поле для ввода логина
        ttk.Label(input_frame, text="Login:").grid(row=1, column=0, sticky="w", pady=2)
        self.username_entry = ttk.Entry(input_frame, width=40)
        self.username_entry.grid(row=1, column=1, padx=5, pady=2)
        self.username_entry.insert(0, "root")  # Пример значения
        
        # Поле для ввода пароля
        ttk.Label(input_frame, text="password:").grid(row=2, column=0, sticky="w", pady=2)
        self.password_entry = ttk.Entry(input_frame, width=40, show="*")
        self.password_entry.grid(row=2, column=1, padx=5, pady=2)
        self.password_entry.insert(0, "pass1234")  # Пример значения
        
        # Порт (опционально)
        ttk.Label(input_frame, text="SSH port:").grid(row=3, column=0, sticky="w", pady=2)
        self.port_entry = ttk.Entry(input_frame, width=10)
        self.port_entry.grid(row=3, column=1, sticky="w", padx=5, pady=2)
        self.port_entry.insert(0, "22")
        
        # Фрейм для кнопок
        button_frame = ttk.Frame(self.root)
        button_frame.pack(fill="x", padx=10, pady=5)
        
        # Кнопка Deploy
        self.start_button1 = ttk.Button(button_frame, text="Deploy ocserver", command=self.start_ssh1)
        self.start_button1.pack(side="left", padx=5)

        # Кнопка Info
        self.start_button2 = ttk.Button(button_frame, text="Server info", command=self.start_ssh2)
        self.start_button2.pack(side="left", padx=5)

        # Кнопка Refresh-passwords
        self.start_button3 = ttk.Button(button_frame, text="Refresh-passwords", command=self.start_ssh3)
        self.start_button3.pack(side="left", padx=5)
        
        # Кнопка для очистки вывода
        ttk.Button(button_frame, text="Clear output", command=self.clear_output).pack(side="left", padx=5)
        
        # Область вывода
        output_frame = ttk.LabelFrame(self.root, text="Result", padding=10)
        output_frame.pack(fill="both", expand=True, padx=10, pady=5)
        
        # Текстовое поле для вывода
        self.output_text = scrolledtext.ScrolledText(output_frame, height=15, width=60)
        self.output_text.pack(fill="both", expand=True)
        
        # Статус бар
        self.status_var = tk.StringVar()
        self.status_var.set("Ready to connect")
        self.status_bar = ttk.Label(self.root, textvariable=self.status_var, relief="sunken")
        self.status_bar.pack(side="bottom", fill="x")
        
    def load_script(self, scriptname):
        """Загрузка скрипта из файла"""
        try:
            if os.path.exists(scriptname):
                with open(scriptname, 'r', encoding='utf-8') as f:
                    self.bash_script = f.read()
                              
        except Exception as e:
            messagebox.showerror("Error", f"Error when reading file: {str(e)}")

    def start_ssh1(self):
        choice = messagebox.askquestion("WARNING", "This action will rewrite the current server settings and user passwords. Proceed?", icon='warning')
        if choice == 'no':
            return
        self.start_ssh("scripts/ocdeploy.sh")
    def start_ssh2(self):
        self.start_ssh("scripts/ocstatus.sh")
    def start_ssh3(self):
        choice = messagebox.askquestion("WARNING", "This action will change the user passwords. Proceed?", icon='warning')
        if choice == 'no':
            return
        self.start_ssh("scripts/pass-reload.sh")      
    def start_ssh(self,scriptname):
        """Запуск SSH-подключения в отдельном потоке"""
        # Получаем данные из полей ввода
        host = self.host_entry.get().strip()
        username = self.username_entry.get().strip()
        password = self.password_entry.get().strip()
        port = self.port_entry.get().strip()
        self.load_script(scriptname)
        # Проверка заполнения полей
        if not all([host, username, password]):
            messagebox.showerror("ERROR", "Fill in all the connection parameters")
            return
        
        # Преобразуем порт в число
        try:
            port = int(port) if port else 22
        except ValueError:
            messagebox.showerror("Error", "SSH port is not number")
            return
        
        # Блокируем кнопку на время выполнения
        self.start_button1.config(state="disabled")
        self.start_button2.config(state="disabled")
        self.start_button3.config(state="disabled")
        self.status_var.set("Connecting...")
        
        # Запускаем подключение в отдельном потоке
        thread = threading.Thread(
            target=self.execute_ssh_command,
            args=(host, port, username, password),
            daemon=True
        )
        thread.start()
        
    def execute_ssh_command(self, host, port, username, password):
        """Выполнение SSH-команды"""
        try:
            # Создаем SSH-клиент
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Подключаемся к серверу
            client.connect(
                hostname=host,
                port=port,
                username=username,
                password=password,
                timeout=10
            )
            
            self.update_status("Connected. Running script...")
            
            # Выполняем скрипт
            stdin, stdout, stderr = client.exec_command(self.bash_script)
            
            # Читаем вывод
            output = stdout.read().decode('utf-8', errors='ignore')
            error = stderr.read().decode('utf-8', errors='ignore')
            
            # Закрываем соединение
            client.close()
            
            # Выводим результат в GUI
            self.root.after(0, self.show_output, output, error)
            self.root.after(0, self.update_status, "Finished")
            
        except paramiko.AuthenticationException:
            self.root.after(0, self.show_error, "Auth error. Check login/password")
        except paramiko.SSHException as e:
            self.root.after(0, self.show_error, f"SSH error: {str(e)}")
        except Exception as e:
            self.root.after(0, self.show_error, f"Connection error: {str(e)}")
        finally:
            self.root.after(0, self.enable_start_button)
    
    def show_output(self, output, error):
        """Отображение вывода в текстовом поле"""
        self.output_text.insert(tk.END, "="*30 + "\n")
        self.output_text.insert(tk.END, "STDOUT:\n")
        self.output_text.insert(tk.END, "="*30 + "\n")
        self.output_text.insert(tk.END, output)
        
        if error:
            self.output_text.insert(tk.END, "\n" + "="*30 + "\n")
            self.output_text.insert(tk.END, "STDERR:\n")
            self.output_text.insert(tk.END, "="*30 + "\n")
            self.output_text.insert(tk.END, error)
            
        self.output_text.insert(tk.END, "\n" + "="*30 + "\n")
        self.output_text.see(tk.END)
    
    def show_error(self, message):
        """Отображение ошибки"""
        messagebox.showerror("ERROR", message)
        self.update_status("Connection error")
    
    def update_status(self, message):
        """Обновление статус-бара"""
        self.status_var.set(message)
    
    def enable_start_button(self):
        """Активация кнопки Start"""
        self.start_button1.config(state="normal")
        self.start_button2.config(state="normal")
        self.start_button3.config(state="normal")
    
    def clear_output(self):
        """Очистка текстового поля вывода"""
        self.output_text.delete(1.0, tk.END)

if __name__ == "__main__":
    root = tk.Tk()
    app = SSHApp(root)
    root.mainloop()
