"""
Manual Drive Summary Dialog

Shows end-of-drive statistics for manual transmission driving with
encouraging or critical feedback based on performance.
"""

import json
import time
import pyray as rl
from typing import Optional, Callable

from openpilot.common.params import Params
from openpilot.system.ui.lib.application import gui_app, FontWeight, FONT_SCALE
from openpilot.system.ui.lib.wrap_text import wrap_text
from openpilot.system.ui.widgets import Widget


# Colors
GREEN = rl.Color(46, 204, 113, 255)
YELLOW = rl.Color(241, 196, 15, 255)
RED = rl.Color(231, 76, 60, 255)
GRAY = rl.Color(150, 150, 150, 255)
LIGHT_GRAY = rl.Color(200, 200, 200, 255)
BG_COLOR = rl.Color(30, 30, 30, 240)


class ManualDriveSummaryDialog(Widget):
  """Modal dialog showing end-of-drive manual transmission stats"""

  def __init__(self, dismiss_callback: Optional[Callable] = None):
    super().__init__()
    self._params = Params()
    self._dismiss_callback = dismiss_callback
    self._session_data: Optional[dict] = None
    self._overall_grade: str = "good"  # good, ok, poor
    self._card_rank: str = "10"  # Poker card rank: 10, J, Q, K, A
    self._show_time: float = 0.0
    self._auto_dismiss_after: float = 30.0  # Auto dismiss after 30 seconds

  def show_event(self):
    super().show_event()
    self._show_time = time.monotonic()
    self._load_session()

  def _load_session(self):
    """Load the last session data from Params"""
    try:
      data = self._params.get("ManualDriveLastSession")
      if data:
        self._session_data = json.loads(data)
        self._calculate_grade()
    except Exception:
      self._session_data = None

  def _calculate_grade(self):
    """Calculate overall grade based on session performance"""
    if not self._session_data:
      self._overall_grade = "ok"
      self._card_rank = "10"
      return

    # Calculate grade based on stalls, shifts, and launches
    stalls = self._session_data.get('stall_count', 0)
    lugs = self._session_data.get('lug_count', 0)

    # Shift quality
    upshift_total = self._session_data.get('upshift_count', 0)
    upshift_good = self._session_data.get('upshift_good', 0)
    downshift_total = self._session_data.get('downshift_count', 0)
    downshift_good = self._session_data.get('downshift_good', 0)

    # Launch quality
    launch_total = self._session_data.get('launch_count', 0)
    launch_good = self._session_data.get('launch_good', 0)
    launch_stalled = self._session_data.get('launch_stalled', 0)

    # Calculate scores
    total_shifts = upshift_total + downshift_total
    shift_score = ((upshift_good + downshift_good) / total_shifts * 100) if total_shifts > 0 else 100
    launch_score = (launch_good / launch_total * 100) if launch_total > 0 else 100

    # Penalties
    stall_penalty = stalls * 20
    lug_penalty = lugs * 5
    launch_stall_penalty = launch_stalled * 15

    overall_score = max(0, min(100, (shift_score + launch_score) / 2 - stall_penalty - lug_penalty - launch_stall_penalty))

    # Poker card ranking: 10, J, Q, K, A
    if overall_score >= 90 and stalls == 0:
      self._card_rank = "A"
      self._overall_grade = "good"
    elif overall_score >= 75 and stalls == 0:
      self._card_rank = "K"
      self._overall_grade = "good"
    elif overall_score >= 60 and stalls <= 1:
      self._card_rank = "Q"
      self._overall_grade = "ok"
    elif overall_score >= 40:
      self._card_rank = "J"
      self._overall_grade = "ok"
    else:
      self._card_rank = "10"
      self._overall_grade = "poor"

  def _get_header_text(self) -> tuple[str, rl.Color]:
    """Get header text and color based on grade"""
    if self._overall_grade == "good":
      return "Waddle Driver!", GREEN
    elif self._overall_grade == "ok":
      return "Decent Drive", YELLOW
    else:
      return "Jackets...", RED

  def _get_encouragement_text(self) -> str:
    """Get encouragement or criticism text based on performance"""
    if not self._session_data:
      return "No data available for this drive."

    stalls = self._session_data.get('stall_count', 0)
    lugs = self._session_data.get('lug_count', 0)
    launch_stalled = self._session_data.get('launch_stalled', 0)

    upshift_good = self._session_data.get('upshift_good', 0)
    upshift_total = self._session_data.get('upshift_count', 0)
    downshift_good = self._session_data.get('downshift_good', 0)
    downshift_total = self._session_data.get('downshift_count', 0)
    launch_good = self._session_data.get('launch_good', 0)
    launch_total = self._session_data.get('launch_count', 0)

    messages = []

    if self._overall_grade == "good":
      if self._card_rank == "A":
        messages.append("Ace drive! You're a true waddle master!")
      elif self._card_rank == "K":
        messages.append("King of the road! Waddling like a pro!")
      if stalls == 0 and launch_stalled == 0:
        messages.append("No stalls!")
      if upshift_total > 0 and upshift_good == upshift_total:
        messages.append("Perfect upshifts!")
      if downshift_total > 0 and downshift_good >= downshift_total * 0.8:
        messages.append("Great rev matching!")
      if launch_total > 0 and launch_good >= launch_total * 0.8:
        messages.append("Smooth launches!")
      if not messages:
        messages.append("Keep waddling!")

    elif self._overall_grade == "ok":
      if self._card_rank == "Q":
        messages.append("Queen-level driving - almost there!")
      else:
        messages.append("Jack of all gears - room to improve!")
      if stalls > 0:
        messages.append(f"Only {stalls} stall{'s' if stalls > 1 else ''} - improving!")
      if lugs > 0:
        messages.append(f"Watch RPMs - {lugs} lug{'s' if lugs > 1 else ''}.")
      if upshift_total > 0 and upshift_good < upshift_total:
        messages.append("Smoother upshifts needed.")

    else:  # poor - jackets
      messages.append("Time to hang up those jackets and try again!")
      if stalls > 2:
        messages.append(f"{stalls} stalls - more gas, slower clutch!")
      if launch_stalled > 0:
        messages.append(f"{launch_stalled} stalled launch{'es' if launch_stalled > 1 else ''} - find that bite point!")
      if lugs > 3:
        messages.append(f"Lugging {lugs} times - downshift sooner!")
      if not messages[1:]:
        messages.append("Every pro stalled at first. Keep at it!")

    return " ".join(messages)

  def _handle_mouse_release(self, _):
    """Dismiss on tap"""
    if self._dismiss_callback:
      self._dismiss_callback()
    gui_app.dismiss_modal()

  def _render(self, rect: rl.Rectangle):
    if not self._session_data:
      # Auto-dismiss if no data
      if self._dismiss_callback:
        self._dismiss_callback()
      gui_app.dismiss_modal()
      return

    # Auto-dismiss after timeout
    if time.monotonic() - self._show_time > self._auto_dismiss_after:
      if self._dismiss_callback:
        self._dismiss_callback()
      gui_app.dismiss_modal()
      return

    # Draw semi-transparent background
    rl.draw_rectangle(0, 0, gui_app.width, gui_app.height, rl.Color(0, 0, 0, 180))

    # Dialog dimensions
    dialog_w = min(500, gui_app.width - 40)
    dialog_h = min(600, gui_app.height - 40)
    dialog_x = (gui_app.width - dialog_w) // 2
    dialog_y = (gui_app.height - dialog_h) // 2

    # Draw dialog background
    rl.draw_rectangle_rounded(
      rl.Rectangle(dialog_x, dialog_y, dialog_w, dialog_h),
      0.03, 10, BG_COLOR
    )

    # Content area
    x = dialog_x + 30
    y = dialog_y + 25
    w = dialog_w - 60

    # Header
    header_text, header_color = self._get_header_text()
    font = gui_app.font(FontWeight.BOLD)
    rl.draw_text_ex(font, header_text, rl.Vector2(x, y), 48, 0, header_color)
    y += 55

    # Card rank display - poker hand style
    card_names = {"A": "Aces", "K": "Kings", "Q": "Queens", "J": "Jacks", "10": "10s"}
    card_color = GREEN if self._card_rank in ("A", "K") else (YELLOW if self._card_rank in ("Q", "J") else RED)
    card_text = f"Your hand: {card_names[self._card_rank]}"
    rl.draw_text_ex(gui_app.font(FontWeight.MEDIUM), card_text, rl.Vector2(x, y), 32, 0, card_color)
    y += 45

    # Duration
    duration = self._session_data.get('duration', 0)
    duration_min = int(duration // 60)
    duration_sec = int(duration % 60)
    rl.draw_text_ex(gui_app.font(FontWeight.ROMAN), f"Drive Duration: {duration_min}:{duration_sec:02d}",
                    rl.Vector2(x, y), 28, 0, GRAY)
    y += 45

    # Separator
    rl.draw_rectangle(x, y, w, 2, rl.Color(60, 60, 60, 255))
    y += 15

    # Stats sections
    y = self._draw_stat_section(x, y, w, "Stalls", self._session_data.get('stall_count', 0), target=0, lower_better=True)
    y = self._draw_stat_section(x, y, w, "Engine Lugs", self._session_data.get('lug_count', 0), target=0, lower_better=True)

    # Launches
    launch_total = self._session_data.get('launch_count', 0)
    launch_good = self._session_data.get('launch_good', 0)
    launch_stalled = self._session_data.get('launch_stalled', 0)
    if launch_total > 0:
      y = self._draw_stat_section(x, y, w, "Good Launches", f"{launch_good}/{launch_total}",
                                   target=launch_total, current=launch_good)
      if launch_stalled > 0:
        y = self._draw_stat_section(x, y, w, "Stalled Launches", launch_stalled, target=0, lower_better=True)

    # Upshifts
    upshift_total = self._session_data.get('upshift_count', 0)
    upshift_good = self._session_data.get('upshift_good', 0)
    if upshift_total > 0:
      y = self._draw_stat_section(x, y, w, "Good Upshifts", f"{upshift_good}/{upshift_total}",
                                   target=upshift_total, current=upshift_good)

    # Downshifts
    downshift_total = self._session_data.get('downshift_count', 0)
    downshift_good = self._session_data.get('downshift_good', 0)
    if downshift_total > 0:
      y = self._draw_stat_section(x, y, w, "Good Downshifts", f"{downshift_good}/{downshift_total}",
                                   target=downshift_total, current=downshift_good)

    y += 10

    # Encouragement/criticism text
    encouragement = self._get_encouragement_text()
    wrapped = wrap_text(gui_app.font(FontWeight.ROMAN), encouragement, 24, w)
    for line in wrapped:
      rl.draw_text_ex(gui_app.font(FontWeight.ROMAN), line, rl.Vector2(x, y), 24, 0, LIGHT_GRAY)
      y += int(24 * FONT_SCALE)

    # Tap to dismiss hint
    hint_text = "Tap to dismiss"
    hint_font = gui_app.font(FontWeight.ROMAN)
    hint_size = 20
    rl.draw_text_ex(hint_font, hint_text, rl.Vector2(dialog_x + dialog_w // 2 - 50, dialog_y + dialog_h - 35),
                    hint_size, 0, GRAY)

  def _draw_stat_section(self, x: int, y: int, w: int, label: str, value, target=None,
                          current=None, lower_better=False) -> int:
    """Draw a stat row with label and value, colored based on performance"""
    font = gui_app.font(FontWeight.MEDIUM)
    font_size = 28

    # Determine color based on target
    if target is not None:
      if lower_better:
        if value == 0:
          color = GREEN
        elif value <= 2:
          color = YELLOW
        else:
          color = RED
      else:
        if current is not None:
          ratio = current / target if target > 0 else 1
          if ratio >= 0.8:
            color = GREEN
          elif ratio >= 0.5:
            color = YELLOW
          else:
            color = RED
        else:
          color = LIGHT_GRAY
    else:
      color = LIGHT_GRAY

    # Draw label
    rl.draw_text_ex(font, label, rl.Vector2(x, y), font_size, 0, LIGHT_GRAY)

    # Draw value (right-aligned)
    value_str = str(value)
    value_width = rl.measure_text_ex(font, value_str, font_size, 0).x
    rl.draw_text_ex(font, value_str, rl.Vector2(x + w - value_width, y), font_size, 0, color)

    return y + 38
