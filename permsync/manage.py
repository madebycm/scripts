#!/usr/bin/env python3
# @author madebycm (2025)

import json
import os
import sys
import curses
from typing import List, Dict, Optional
from enum import Enum

class Mode(Enum):
    ALLOWED = "allowed"
    BLACKLIST = "blacklist"

class PermsyncManager:
    def __init__(self):
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.allowed_file = os.path.join(self.script_dir, "allowed.json")
        self.blacklist_file = os.path.join(self.script_dir, "blacklist.json")
        self.mode = Mode.ALLOWED
        self.selected_index = 0
        self.editing = False
        self.edit_buffer = ""
        self.adding_new = False
        
    def load_allowed(self) -> List[str]:
        """Load allowed permissions from allowed.json"""
        try:
            with open(self.allowed_file, 'r') as f:
                data = json.load(f)
                return sorted(data.get('permissions', {}).get('allow', []))
        except:
            return []
    
    def load_blacklist(self) -> List[str]:
        """Load blacklisted permissions from blacklist.json"""
        try:
            with open(self.blacklist_file, 'r') as f:
                data = json.load(f)
                return sorted(data.get('permissions', {}).get('blacklist', []))
        except:
            return []
    
    def save_allowed(self, permissions: List[str]):
        """Save allowed permissions to allowed.json"""
        data = {
            "permissions": {
                "allow": sorted(permissions),
                "deny": []
            }
        }
        with open(self.allowed_file, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
    
    def save_blacklist(self, permissions: List[str]):
        """Save blacklisted permissions to blacklist.json"""
        data = {
            "permissions": {
                "blacklist": sorted(permissions)
            }
        }
        with open(self.blacklist_file, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
    
    def get_current_list(self) -> List[str]:
        """Get the current list based on mode"""
        if self.mode == Mode.ALLOWED:
            return self.load_allowed()
        else:
            return self.load_blacklist()
    
    def delete_item(self, index: int):
        """Delete item at given index"""
        items = self.get_current_list()
        if 0 <= index < len(items):
            del items[index]
            if self.mode == Mode.ALLOWED:
                self.save_allowed(items)
            else:
                self.save_blacklist(items)
            return True
        return False
    
    def edit_item(self, index: int, new_value: str):
        """Edit item at given index"""
        items = self.get_current_list()
        if 0 <= index < len(items):
            items[index] = new_value
            if self.mode == Mode.ALLOWED:
                self.save_allowed(items)
            else:
                self.save_blacklist(items)
            return True
        return False
    
    def add_item(self, value: str):
        """Add new item to current list"""
        items = self.get_current_list()
        if value not in items:
            items.append(value)
            if self.mode == Mode.ALLOWED:
                self.save_allowed(items)
            else:
                self.save_blacklist(items)
            return True
        return False
    
    def toggle_blacklist(self, index: int):
        """Move item between allowed and blacklist"""
        if self.mode == Mode.ALLOWED:
            # Move from allowed to blacklist
            allowed_items = self.load_allowed()
            if 0 <= index < len(allowed_items):
                item = allowed_items[index]
                # Remove from allowed
                del allowed_items[index]
                self.save_allowed(allowed_items)
                # Add to blacklist
                blacklist_items = self.load_blacklist()
                if item not in blacklist_items:
                    blacklist_items.append(item)
                    self.save_blacklist(blacklist_items)
                return True
        else:
            # Move from blacklist to allowed
            blacklist_items = self.load_blacklist()
            if 0 <= index < len(blacklist_items):
                item = blacklist_items[index]
                # Remove from blacklist
                del blacklist_items[index]
                self.save_blacklist(blacklist_items)
                # Add to allowed
                allowed_items = self.load_allowed()
                if item not in allowed_items:
                    allowed_items.append(item)
                    self.save_allowed(allowed_items)
                return True
        return False
    
    def draw_screen(self, stdscr):
        """Draw the main screen"""
        curses.curs_set(0)  # Hide cursor
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        
        # Title
        title = f"Permsync Manager - {self.mode.value.capitalize()} Rules"
        stdscr.addstr(0, (width - len(title)) // 2, title, curses.A_BOLD)
        
        # Instructions
        instructions = [
            "↑/↓: Navigate | TAB: Switch mode | a: Add | e: Edit | d: Delete | b: Toggle Blacklist | q: Quit",
            ""
        ]
        for i, inst in enumerate(instructions):
            if i + 1 < height:
                stdscr.addstr(i + 1, 0, inst[:width-1])
        
        # Get current list
        items = self.get_current_list()
        
        # Status line
        status_y = 3
        if self.adding_new:
            prompt = "New permission: "
            stdscr.addstr(status_y, 0, prompt)
            stdscr.addstr(status_y, len(prompt), self.edit_buffer)
            curses.curs_set(1)  # Show cursor when editing
            stdscr.move(status_y, len(prompt) + len(self.edit_buffer))
        elif self.editing:
            prompt = "Edit permission: "
            stdscr.addstr(status_y, 0, prompt)
            stdscr.addstr(status_y, len(prompt), self.edit_buffer)
            curses.curs_set(1)  # Show cursor when editing
            stdscr.move(status_y, len(prompt) + len(self.edit_buffer))
        else:
            status = f"Total: {len(items)} items"
            stdscr.addstr(status_y, 0, status)
        
        # List items
        list_start_y = 5
        max_items = height - list_start_y - 2
        
        # Calculate scroll position
        if len(items) > max_items:
            if self.selected_index < max_items // 2:
                start_idx = 0
            elif self.selected_index > len(items) - max_items // 2:
                start_idx = len(items) - max_items
            else:
                start_idx = self.selected_index - max_items // 2
        else:
            start_idx = 0
        
        # Draw items
        for i in range(max_items):
            y = list_start_y + i
            if y >= height - 1:
                break
                
            idx = start_idx + i
            if idx < len(items):
                item = items[idx]
                if len(item) > width - 5:
                    item = item[:width-8] + "..."
                
                if idx == self.selected_index:
                    stdscr.addstr(y, 2, f"> {item}", curses.A_REVERSE)
                else:
                    stdscr.addstr(y, 4, item)
        
        # Scroll indicators
        if start_idx > 0:
            stdscr.addstr(list_start_y - 1, width // 2, "↑ More above ↑")
        if start_idx + max_items < len(items):
            stdscr.addstr(height - 2, width // 2 - 6, "↓ More below ↓")
        
        stdscr.refresh()
    
    def handle_input(self, stdscr, key):
        """Handle keyboard input"""
        items = self.get_current_list()
        
        if self.editing or self.adding_new:
            if key == ord('\n'):  # Enter - save
                if self.adding_new:
                    if self.edit_buffer.strip():
                        self.add_item(self.edit_buffer.strip())
                    self.adding_new = False
                else:
                    if self.edit_buffer.strip():
                        self.edit_item(self.selected_index, self.edit_buffer.strip())
                    self.editing = False
                self.edit_buffer = ""
                curses.curs_set(0)
            elif key == 27:  # Escape - cancel
                self.editing = False
                self.adding_new = False
                self.edit_buffer = ""
                curses.curs_set(0)
            elif key == curses.KEY_BACKSPACE or key == 127:
                if self.edit_buffer:
                    self.edit_buffer = self.edit_buffer[:-1]
            elif 32 <= key <= 126:  # Printable characters
                self.edit_buffer += chr(key)
        else:
            if key == ord('q') or key == ord('Q'):
                return False
            elif key == curses.KEY_UP:
                if self.selected_index > 0:
                    self.selected_index -= 1
            elif key == curses.KEY_DOWN:
                if self.selected_index < len(items) - 1:
                    self.selected_index += 1
            elif key == ord('\t'):  # Tab - switch mode
                self.mode = Mode.BLACKLIST if self.mode == Mode.ALLOWED else Mode.ALLOWED
                self.selected_index = 0
            elif key == ord('a') or key == ord('A'):  # Add new
                self.adding_new = True
                self.edit_buffer = ""
            elif key == ord('e') or key == ord('E'):  # Edit
                if items and 0 <= self.selected_index < len(items):
                    self.editing = True
                    self.edit_buffer = items[self.selected_index]
            elif key == ord('d') or key == ord('D'):  # Delete
                if items and 0 <= self.selected_index < len(items):
                    # Confirm deletion
                    height, width = stdscr.getmaxyx()
                    confirm_msg = "Delete this item? (y/n)"
                    stdscr.addstr(height - 1, 0, confirm_msg)
                    stdscr.refresh()
                    confirm = stdscr.getch()
                    if confirm == ord('y') or confirm == ord('Y'):
                        self.delete_item(self.selected_index)
                        if self.selected_index >= len(self.get_current_list()) and self.selected_index > 0:
                            self.selected_index -= 1
            elif key == ord('b') or key == ord('B'):  # Toggle blacklist
                if items and 0 <= self.selected_index < len(items):
                    # Confirm toggle
                    height, width = stdscr.getmaxyx()
                    if self.mode == Mode.ALLOWED:
                        confirm_msg = "Move to blacklist? (y/n)"
                    else:
                        confirm_msg = "Remove from blacklist and allow? (y/n)"
                    stdscr.addstr(height - 1, 0, confirm_msg + " " * (width - len(confirm_msg) - 1))
                    stdscr.refresh()
                    confirm = stdscr.getch()
                    if confirm == ord('y') or confirm == ord('Y'):
                        self.toggle_blacklist(self.selected_index)
                        if self.selected_index >= len(self.get_current_list()) and self.selected_index > 0:
                            self.selected_index -= 1
        
        return True
    
    def run(self):
        """Main run loop"""
        def main(stdscr):
            # Set up colors
            curses.start_color()
            curses.use_default_colors()
            
            # Main loop
            while True:
                self.draw_screen(stdscr)
                key = stdscr.getch()
                if not self.handle_input(stdscr, key):
                    break
        
        curses.wrapper(main)

def main():
    manager = PermsyncManager()
    manager.run()

if __name__ == "__main__":
    main()