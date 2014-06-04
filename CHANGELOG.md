v1.0.1:
- Make Performer::Queue#enq re-entrant, allows scheduling tasks from
  object finalizers (at least in MRI) [868f8ca0]
- Keep track of currently executing tasks internally. No public API,
  but should help with debugging. [d35438f4]

v1.0.0:
- First release!
