# Interrupts

Interrupts are handled by modifying the return instruction.
I call this method "lazy interrupts".

IRQs in a lazy-interrupt system trade latency time for overhead.
Since an interrupt only happens upon a return,
registers (such as carry flags) are free to be trashed.
Critical sections don't need interrupt disabling.
There is no need to disable ISRs while they are being serviced because the next
ISR won’t be serviced until the next return.
Multiple interrupts are naturally chained, with a priority encoder deciding who’s next.

An interrupt request is serviced by modifying the PC instead of popping it from
the return stack. This avoids excess return stack usage, which is important in a system
that uses a hardware return stack.
It also greatly simplifies verification compared to interrupts that can happen anytime.

Interrupt vectors are fixed. An active interrupt has a jump to code.
An inactive interrupt has a return instruction, which costs one cycle. 
Processor ports are `irq`, `ivec`, and `iack`.
When `iack` = `1`, the return is being decoded and `irq` is being used to form
the jump address. The priority encoder should decode `irq` and use `iack`
to clear the corresponding request.

Classic Forth systems have often used an ISR to handle time-critical data and then
awakened a cooperative task to handle clean-up so as not to burden the interrupt system.
The same idea applies to lazy interrupts.
Once the time-critical part of the interrupt is taken care of, you can call
non-time-critical parts of the ISR whose return instructions service the interrupt system.
Admittedly, this costs a little return stack, so you need to make sure there's enough
hardware stack to handle it.
You could think of return instructions as an analog of Forth’s PAUSE.

The maximum interrupt latency is easy enough to instrument in HDL simulation.
A timer could track the maximum time between rising `irq` and `iack`.
Since Forth executes `return` quite often, it's usually pretty low.

## mcu.v interrupt assignments

- 1 = Raw cycle count overflow. ISR should increment the upper cell(s) of the cycle count.
- 2 = UART transmitter is ready for another byte.
Loading the next byte within one character period prevents any dead time in the output.
- 3 = UART receiver is full. You have one character period to process it before overflow.
