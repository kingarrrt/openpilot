"""Pure Python CAN capnp serialization helpers."""
import cereal.messaging as messaging
from cereal import log


def can_list_to_can_capnp(can_msgs, msgtype='can', valid=True):
  """Convert list of (address, data, src) tuples to serialized capnp bytes."""
  msg = messaging.new_message(msgtype, len(can_msgs))
  msg.valid = valid
  cans = getattr(msg, msgtype)
  for i, (address, dat, src) in enumerate(can_msgs):
    cans[i].address = address
    cans[i].dat = dat
    cans[i].src = src
  return msg.to_bytes()


def can_capnp_to_list(strings, msgtype='can'):
  """Convert list of capnp byte strings to list of (nanos, frames) tuples."""
  result = []
  for s in strings:
    with log.Event.from_bytes(s) as msg:
      nanos = msg.logMonoTime
      cans = getattr(msg, msgtype)
      frames = [(c.address, bytes(c.dat), c.src) for c in cans]
      result.append((nanos, frames))
  return result
