"""
Live Manual Stats Widget

Small onroad overlay showing current drive statistics and shift suggestions.
"""

import json
import pyray as rl

from openpilot.common.params import Params
from openpilot.system.ui.lib.application import gui_app, FontWeight
from openpilot.system.ui.widgets import Widget


# Colors
GREEN = rl.Color(46, 204, 113, 220)
YELLOW = rl.Color(241, 196, 15, 220)
RED = rl.Color(231, 76, 60, 220)
CYAN = rl.Color(52, 152, 219, 220)
WHITE = rl.Color(255, 255, 255, 220)
GRAY = rl.Color(150, 150, 150, 200)
BG_COLOR = rl.Color(0, 0, 0, 160)


class ManualStatsWidget(Widget):
  """Small widget showing live manual driving stats and shift suggestions"""

  def __init__(self):
    super().__init__()
    self._params = Params()
    self._visible = False
    self._stats: dict = {}
    self._update_counter = 0

  def set_visible(self, visible: bool):
    self._visible = visible

  def _render(self, rect: rl.Rectangle):
    if not self._visible:
      return

    # Update stats every ~15 frames (0.25s at 60fps)
    self._update_counter += 1
    if self._update_counter >= 15:
      self._update_counter = 0
      self._load_stats()

    if not self._stats:
      return

    # Widget dimensions
    w = 140
    h = 130
    x = int(rect.x + rect.width - w - 10)
    y = int(rect.y + 10)

    # Background
    rl.draw_rectangle_rounded(rl.Rectangle(x, y, w, h), 0.1, 10, BG_COLOR)

    font = gui_app.font(FontWeight.MEDIUM)
    font_bold = gui_app.font(FontWeight.BOLD)
    px = x + 10
    py = y + 8

    # Current gear (big)
    gear = self._stats.get('gear', 0)
    gear_text = str(gear) if gear > 0 else "N"
    rl.draw_text_ex(font_bold, gear_text, rl.Vector2(px, py), 42, 0, WHITE)

    # Shift suggestion next to gear
    suggestion = self._stats.get('shift_suggestion', 'ok')
    reason = self._stats.get('shift_reason', '')
    if suggestion == 'upshift':
      rl.draw_text_ex(font_bold, "↑", rl.Vector2(px + 35, py + 5), 36, 0, GREEN)
    elif suggestion == 'downshift':
      rl.draw_text_ex(font_bold, "↓", rl.Vector2(px + 35, py + 5), 36, 0, YELLOW)

    py += 48

    # Stats in smaller text
    font_size = 20
    line_h = 24

    # Stalls
    stalls = self._stats.get('stalls', 0)
    color = GREEN if stalls == 0 else (YELLOW if stalls <= 2 else RED)
    rl.draw_text_ex(font, f"Stalls: {stalls}", rl.Vector2(px, py), font_size, 0, color)
    py += line_h

    # Lugging indicator
    is_lugging = self._stats.get('is_lugging', False)
    lugs = self._stats.get('lugs', 0)
    if is_lugging:
      rl.draw_text_ex(font, "LUGGING!", rl.Vector2(px, py), font_size, 0, RED)
    else:
      color = GREEN if lugs == 0 else GRAY
      rl.draw_text_ex(font, f"Lugs: {lugs}", rl.Vector2(px, py), font_size, 0, color)
    py += line_h

    # Shift quality
    shifts = self._stats.get('shifts', 0)
    good_shifts = self._stats.get('good_shifts', 0)
    if shifts > 0:
      pct = int(good_shifts / shifts * 100)
      color = GREEN if pct >= 80 else (YELLOW if pct >= 50 else RED)
      rl.draw_text_ex(font, f"Shifts: {pct}%", rl.Vector2(px, py), font_size, 0, color)
    else:
      rl.draw_text_ex(font, "Shifts: -", rl.Vector2(px, py), font_size, 0, GRAY)

  def _load_stats(self):
    """Load current session stats"""
    try:
      data = self._params.get("ManualDriveLiveStats")
      if data:
        self._stats = json.loads(data)
      else:
        self._stats = {}
    except Exception:
      self._stats = {}
