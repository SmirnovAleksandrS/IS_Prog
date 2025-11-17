
all: tx

tx:
	iverilog uart_tx.v uart_byte_tx.v test_tx.v crc_32.v uart_rx.v uart_byte_rx.v uart_init_catcher.v
	vvp a.out
# 	gtkwave dump.vcd &
