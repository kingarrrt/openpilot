"""
Manual Driving Stats Settings Page

Shows historical stats and trends for manual transmission driving.
"""

import json
import pyray as rl

from openpilot.common.params import Params
from openpilot.system.ui.lib.application import gui_app, FontWeight, FONT_SCALE
from openpilot.system.ui.lib.scroll_panel2 import GuiScrollPanel2
from openpilot.system.ui.lib.wrap_text import wrap_text
from openpilot.system.ui.widgets import Widget, NavWidget


# Colors
GREEN = rl.Color(46, 204, 113, 255)
YELLOW = rl.Color(241, 196, 15, 255)
RED = rl.Color(231, 76, 60, 255)
GRAY = rl.Color(100, 100, 100, 255)
LIGHT_GRAY = rl.Color(180, 180, 180, 255)
WHITE = rl.Color(255, 255, 255, 255)
BG_CARD = rl.Color(45, 45, 45, 255)


class ManualStatsLayout(NavWidget):
  """Settings page showing historical manual driving stats"""

  def __init__(self, back_callback):
    super().__init__()
    self._params = Params()
    self._scroll_panel = GuiScrollPanel2(horizontal=False)
    self._stats: dict = {}
    self.set_back_callback(back_callback)

  def show_event(self):
    super().show_event()
    self._scroll_panel.set_offset(0)
    self._load_stats()

  def _load_stats(self):
    """Load historical stats from Params"""
    try:
      data = self._params.get("ManualDriveStats")
      if data:
        # Params returns dict directly for JSON type
        self._stats = data if isinstance(data, dict) else json.loads(data)
      else:
        self._stats = {}
    except Exception:
      self._stats = {}

  def _render(self, rect: rl.Rectangle):
    content_height = self._measure_content_height(rect)
    scroll_offset = round(self._scroll_panel.update(rect, content_height))

    x = int(rect.x + 20)
    y = int(rect.y + 20 + scroll_offset)
    w = int(rect.width - 40)

    # Title
    font_bold = gui_app.font(FontWeight.BOLD)
    font_medium = gui_app.font(FontWeight.MEDIUM)
    font_roman = gui_app.font(FontWeight.ROMAN)

    rl.draw_text_ex(font_bold, "Manual Driving Stats", rl.Vector2(x, y), 48, 0, WHITE)
    y += 60

    if not self._stats or self._stats.get('total_drives', 0) == 0:
      rl.draw_text_ex(font_roman, "No driving data yet. Get out there and practice!",
                      rl.Vector2(x, y), 28, 0, GRAY)
      return

    # Overview card
    y = self._draw_card(x, y, w, "Overview", [
      ("Total Drives", str(self._stats.get('total_drives', 0)), WHITE),
      ("Total Drive Time", self._format_time(self._stats.get('total_drive_time', 0)), WHITE),
      ("Total Stalls", str(self._stats.get('total_stalls', 0)), self._stall_color(self._stats.get('total_stalls', 0))),
      ("Total Lugs", str(self._stats.get('total_lugs', 0)), LIGHT_GRAY),
    ])
    y += 15

    # Shift quality card
    total_up = self._stats.get('total_upshifts', 0)
    total_down = self._stats.get('total_downshifts', 0)
    up_good = self._stats.get('total_upshifts_good', 0)
    down_good = self._stats.get('total_downshifts_good', 0)

    up_pct = f"{int(up_good / total_up * 100)}%" if total_up > 0 else "N/A"
    down_pct = f"{int(down_good / total_down * 100)}%" if total_down > 0 else "N/A"

    y = self._draw_card(x, y, w, "Shift Quality", [
      ("Total Upshifts", str(total_up), WHITE),
      ("Good Upshifts", f"{up_good} ({up_pct})", self._pct_color(up_good, total_up)),
      ("Total Downshifts", str(total_down), WHITE),
      ("Good Downshifts", f"{down_good} ({down_pct})", self._pct_color(down_good, total_down)),
    ])
    y += 15

    # Launch quality card
    total_launches = self._stats.get('total_launches', 0)
    good_launches = self._stats.get('total_launches_good', 0)
    stalled_launches = self._stats.get('total_launches_stalled', 0)

    launch_pct = f"{int(good_launches / total_launches * 100)}%" if total_launches > 0 else "N/A"

    y = self._draw_card(x, y, w, "Launch Quality", [
      ("Total Launches", str(total_launches), WHITE),
      ("Good Launches", f"{good_launches} ({launch_pct})", self._pct_color(good_launches, total_launches)),
      ("Stalled Launches", str(stalled_launches), RED if stalled_launches > 0 else GREEN),
    ])
    y += 15

    # Trend card
    recent_stalls = self._stats.get('recent_stall_rates', [])
    recent_shifts = self._stats.get('recent_shift_scores', [])

    trend_items = []
    if len(recent_stalls) >= 2:
      trend = self._calculate_trend(recent_stalls)
      trend_text, trend_color = self._trend_text(trend, lower_better=True)
      trend_items.append(("Stall Trend", trend_text, trend_color))

    if len(recent_shifts) >= 2:
      trend = self._calculate_trend(recent_shifts)
      trend_text, trend_color = self._trend_text(trend, lower_better=False)
      trend_items.append(("Shift Score Trend", trend_text, trend_color))

    if recent_shifts:
      avg_score = sum(recent_shifts) / len(recent_shifts)
      trend_items.append(("Avg Shift Score (last 10)", f"{int(avg_score)}/100", self._score_color(avg_score)))

    if trend_items:
      y = self._draw_card(x, y, w, "Recent Trends", trend_items)
      y += 15

    # Encouragement based on progress (with text wrapping)
    y += 10
    encouragement = self._get_encouragement()
    wrapped_lines = wrap_text(font_roman, encouragement, 24, w - 10)
    for line in wrapped_lines:
      rl.draw_text_ex(font_roman, line, rl.Vector2(x, y), 24, 0, LIGHT_GRAY)
      y += 30

  def _draw_card(self, x: int, y: int, w: int, title: str, items: list) -> int:
    """Draw a card with title and stat items"""
    font_bold = gui_app.font(FontWeight.BOLD)
    font_medium = gui_app.font(FontWeight.MEDIUM)

    card_h = 50 + len(items) * 38
    rl.draw_rectangle_rounded(rl.Rectangle(x, y, w, card_h), 0.02, 10, BG_CARD)

    # Title
    rl.draw_text_ex(font_bold, title, rl.Vector2(x + 15, y + 12), 32, 0, WHITE)
    y += 50

    # Items
    for label, value, color in items:
      rl.draw_text_ex(font_medium, label, rl.Vector2(x + 15, y), 26, 0, LIGHT_GRAY)
      value_width = rl.measure_text_ex(font_medium, value, 26, 0).x
      rl.draw_text_ex(font_medium, value, rl.Vector2(x + w - 15 - value_width, y), 26, 0, color)
      y += 38

    return y

  def _measure_content_height(self, rect: rl.Rectangle) -> int:
    """Measure total content height for scrolling"""
    y = 20 + 60  # Title

    if not self._stats or self._stats.get('total_drives', 0) == 0:
      return y + 40

    # Overview card
    y += 50 + 4 * 38 + 15
    # Shift card
    y += 50 + 4 * 38 + 15
    # Launch card
    y += 50 + 3 * 38 + 15
    # Trend card (estimate)
    y += 50 + 3 * 38 + 15
    # Encouragement (estimate 2-3 lines wrapped)
    y += 100

    return y + 40  # padding

  def _format_time(self, seconds: float) -> str:
    """Format seconds as hours:minutes"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    if hours > 0:
      return f"{hours}h {minutes}m"
    return f"{minutes}m"

  def _stall_color(self, stalls: int) -> rl.Color:
    if stalls == 0:
      return GREEN
    elif stalls < 5:
      return YELLOW
    return RED

  def _pct_color(self, good: int, total: int) -> rl.Color:
    if total == 0:
      return GRAY
    pct = good / total
    if pct >= 0.8:
      return GREEN
    elif pct >= 0.5:
      return YELLOW
    return RED

  def _score_color(self, score: float) -> rl.Color:
    if score >= 80:
      return GREEN
    elif score >= 50:
      return YELLOW
    return RED

  def _calculate_trend(self, values: list) -> float:
    """Calculate trend as average change over recent values"""
    if len(values) < 2:
      return 0.0
    # Compare first half avg to second half avg
    mid = len(values) // 2
    first_half = sum(values[:mid]) / mid if mid > 0 else 0
    second_half = sum(values[mid:]) / (len(values) - mid) if len(values) - mid > 0 else 0
    return second_half - first_half

  def _trend_text(self, trend: float, lower_better: bool) -> tuple[str, rl.Color]:
    """Get trend text and color"""
    if abs(trend) < 0.5:
      return "Stable", LIGHT_GRAY

    if lower_better:
      if trend < 0:
        return "Improving!", GREEN
      return "Getting worse", RED
    else:
      if trend > 0:
        return "Improving!", GREEN
      return "Getting worse", RED

  def _get_encouragement(self) -> str:
    """Get encouragement based on overall progress"""
    total_drives = self._stats.get('total_drives', 0)
    total_stalls = self._stats.get('total_stalls', 0)
    recent_stalls = self._stats.get('recent_stall_rates', [])

    if total_drives == 0:
      return "Start driving to see your stats!"

    stall_rate = total_stalls / total_drives if total_drives > 0 else 0

    if len(recent_stalls) >= 3:
      recent_avg = sum(recent_stalls[-3:]) / 3
      if recent_avg == 0:
        return "No stalls in recent drives - you're getting the hang of it!"
      elif recent_avg < stall_rate:
        return "Your recent drives are better than average - keep it up!"

    if stall_rate < 0.5:
      return "Less than 1 stall per 2 drives on average - nice work!"
    elif stall_rate < 1:
      return "About 1 stall per drive - you're learning fast!"
    else:
      return "Keep practicing! Everyone stalls when learning manual."
