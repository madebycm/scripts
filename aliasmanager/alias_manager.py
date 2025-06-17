#!/usr/bin/env python3
# @author madebycm (2025-01-23)

import tkinter as tk
from tkinter import ttk, messagebox, filedialog, scrolledtext
import os
import shutil
from datetime import datetime
import re
import subprocess

class AliasManager:
    def __init__(self, root):
        self.root = root
        self.root.title("Alias Manager")
        self.root.geometry("800x600")
        
        self.zprofile_path = os.path.expanduser("~/.zprofile")
        self.aliases = {}
        
        self.setup_ui()
        self.load_aliases()
        
    def setup_ui(self):
        # Create menu
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)
        
        file_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Backup .zprofile", command=self.backup_zprofile)
        file_menu.add_command(label="Restore from backup", command=self.restore_backup)
        file_menu.add_separator()
        file_menu.add_command(label="Reload", command=self.load_aliases)
        file_menu.add_command(label="Save", command=self.save_aliases)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)
        
        # Main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(1, weight=1)
        
        # Search frame
        search_frame = ttk.Frame(main_frame)
        search_frame.grid(row=0, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(search_frame, text="Search:").grid(row=0, column=0, padx=(0, 5))
        self.search_var = tk.StringVar()
        self.search_var.trace_add('write', self.filter_aliases)
        search_entry = ttk.Entry(search_frame, textvariable=self.search_var, width=30)
        search_entry.grid(row=0, column=1, sticky=(tk.W, tk.E))
        search_frame.columnconfigure(1, weight=1)
        
        # Alias list
        list_frame = ttk.LabelFrame(main_frame, text="Aliases", padding="5")
        list_frame.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), padx=(0, 5))
        
        # Treeview for aliases
        self.tree = ttk.Treeview(list_frame, columns=("command",), show="tree headings", height=15)
        self.tree.heading("#0", text="Alias")
        self.tree.heading("command", text="Command")
        self.tree.column("#0", width=150)
        self.tree.column("command", width=400)
        
        # Scrollbar for treeview
        scrollbar = ttk.Scrollbar(list_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar.set)
        
        self.tree.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        scrollbar.grid(row=0, column=1, sticky=(tk.N, tk.S))
        
        list_frame.columnconfigure(0, weight=1)
        list_frame.rowconfigure(0, weight=1)
        
        # Bind selection event
        self.tree.bind('<<TreeviewSelect>>', self.on_select)
        
        # Editor frame
        editor_frame = ttk.LabelFrame(main_frame, text="Edit Alias", padding="5")
        editor_frame.grid(row=1, column=2, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Alias name
        ttk.Label(editor_frame, text="Alias:").grid(row=0, column=0, sticky=tk.W, pady=2)
        self.alias_entry = ttk.Entry(editor_frame, width=30)
        self.alias_entry.grid(row=0, column=1, sticky=(tk.W, tk.E), pady=2)
        
        # Command
        ttk.Label(editor_frame, text="Command:").grid(row=1, column=0, sticky=(tk.W, tk.N), pady=2)
        self.command_text = scrolledtext.ScrolledText(editor_frame, width=40, height=10)
        self.command_text.grid(row=1, column=1, sticky=(tk.W, tk.E, tk.N, tk.S), pady=2)
        
        editor_frame.columnconfigure(1, weight=1)
        editor_frame.rowconfigure(1, weight=1)
        
        # Buttons frame
        button_frame = ttk.Frame(editor_frame)
        button_frame.grid(row=2, column=0, columnspan=2, pady=(10, 0))
        
        ttk.Button(button_frame, text="Add/Update", command=self.add_update_alias).grid(row=0, column=0, padx=2)
        ttk.Button(button_frame, text="Delete", command=self.delete_alias).grid(row=0, column=1, padx=2)
        ttk.Button(button_frame, text="Clear", command=self.clear_editor).grid(row=0, column=2, padx=2)
        
        # Status bar
        self.status_var = tk.StringVar()
        self.status_var.set("Ready")
        status_bar = ttk.Label(main_frame, textvariable=self.status_var, relief=tk.SUNKEN)
        status_bar.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(10, 0))
        
    def load_aliases(self):
        """Load aliases from .zprofile"""
        self.aliases.clear()
        
        if not os.path.exists(self.zprofile_path):
            messagebox.showwarning("Warning", f"{self.zprofile_path} not found")
            return
            
        try:
            with open(self.zprofile_path, 'r') as f:
                content = f.read()
                
            # Match alias patterns
            # Handles: alias name="command" and alias name='command'
            alias_pattern = r'^\s*alias\s+([^=]+)=(["\'])(.+?)\2'
            
            for line in content.split('\n'):
                match = re.match(alias_pattern, line)
                if match:
                    alias_name = match.group(1).strip()
                    alias_command = match.group(3)
                    self.aliases[alias_name] = alias_command
                    
            self.update_tree()
            self.status_var.set(f"Loaded {len(self.aliases)} aliases")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load aliases: {str(e)}")
            
    def update_tree(self, filter_text=""):
        """Update the tree view with aliases"""
        self.tree.delete(*self.tree.get_children())
        
        for alias, command in sorted(self.aliases.items()):
            if filter_text.lower() in alias.lower() or filter_text.lower() in command.lower():
                self.tree.insert("", "end", text=alias, values=(command,))
                
    def filter_aliases(self, *args):
        """Filter aliases based on search text"""
        self.update_tree(self.search_var.get())
        
    def on_select(self, event):
        """Handle tree selection"""
        selection = self.tree.selection()
        if selection:
            item = self.tree.item(selection[0])
            alias = item['text']
            command = item['values'][0]
            
            self.alias_entry.delete(0, tk.END)
            self.alias_entry.insert(0, alias)
            
            self.command_text.delete('1.0', tk.END)
            self.command_text.insert('1.0', command)
            
    def add_update_alias(self):
        """Add or update an alias"""
        alias = self.alias_entry.get().strip()
        command = self.command_text.get('1.0', tk.END).strip()
        
        if not alias:
            messagebox.showwarning("Warning", "Alias name cannot be empty")
            return
            
        if not command:
            messagebox.showwarning("Warning", "Command cannot be empty")
            return
            
        self.aliases[alias] = command
        self.update_tree(self.search_var.get())
        self.status_var.set(f"Added/Updated alias: {alias}")
        
    def delete_alias(self):
        """Delete selected alias"""
        alias = self.alias_entry.get().strip()
        
        if not alias:
            messagebox.showwarning("Warning", "Select an alias to delete")
            return
            
        if alias in self.aliases:
            if messagebox.askyesno("Confirm", f"Delete alias '{alias}'?"):
                del self.aliases[alias]
                self.update_tree(self.search_var.get())
                self.clear_editor()
                self.status_var.set(f"Deleted alias: {alias}")
                
    def clear_editor(self):
        """Clear the editor fields"""
        self.alias_entry.delete(0, tk.END)
        self.command_text.delete('1.0', tk.END)
        
    def save_aliases(self):
        """Save aliases back to .zprofile"""
        try:
            # Read current .zprofile
            with open(self.zprofile_path, 'r') as f:
                lines = f.readlines()
                
            # Remove existing alias lines
            alias_pattern = r'^\s*alias\s+[^=]+=.*'
            non_alias_lines = [line for line in lines if not re.match(alias_pattern, line)]
            
            # Add aliases at the end
            alias_lines = []
            for alias, command in sorted(self.aliases.items()):
                # Escape quotes in command
                escaped_command = command.replace('"', '\\"')
                alias_lines.append(f'alias {alias}="{escaped_command}"\n')
                
            # Combine content
            new_content = non_alias_lines + ['\n'] + alias_lines
            
            # Write back
            with open(self.zprofile_path, 'w') as f:
                f.writelines(new_content)
                
            self.status_var.set(f"Saved {len(self.aliases)} aliases to {self.zprofile_path}")
            messagebox.showinfo("Success", "Aliases saved successfully")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save aliases: {str(e)}")
            
    def backup_zprofile(self):
        """Create a backup of .zprofile"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_path = os.path.expanduser(f"~/.zprofile.backup_{timestamp}")
            
            shutil.copy2(self.zprofile_path, backup_path)
            
            self.status_var.set(f"Backup created: {backup_path}")
            messagebox.showinfo("Success", f"Backup created at:\n{backup_path}")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to create backup: {str(e)}")
            
    def restore_backup(self):
        """Restore from a backup file"""
        backup_path = filedialog.askopenfilename(
            title="Select backup file",
            initialdir=os.path.expanduser("~"),
            filetypes=[("Backup files", ".zprofile.backup_*"), ("All files", "*")]
        )
        
        if backup_path:
            if messagebox.askyesno("Confirm", f"Restore from {os.path.basename(backup_path)}?\nThis will overwrite current .zprofile"):
                try:
                    shutil.copy2(backup_path, self.zprofile_path)
                    self.load_aliases()
                    self.status_var.set(f"Restored from: {backup_path}")
                    messagebox.showinfo("Success", "Backup restored successfully")
                except Exception as e:
                    messagebox.showerror("Error", f"Failed to restore backup: {str(e)}")


def main():
    root = tk.Tk()
    app = AliasManager(root)
    root.mainloop()


if __name__ == "__main__":
    main()