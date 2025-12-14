
all:
	iverilog tx/uart_tx.v tx/uart_byte_tx.v test_uart.v csm/crc_32.v rx/uart_rx.v rx/sync_uart_rx.v rx/uart_byte_rx.v rx/uart_init_catcher.v
	vvp a.out
# 	gtkwave dump.vcd &


# 	iverilog tx/uart_tx.v tx/uart_byte_tx.v test_tx.v csm/crc_32.v 
# 	vvp a.out

master:
	iverilog test_master.v uart_master.v sram_dualport.v fifo_ram.v tx/uart_tx.v tx/uart_byte_tx.v csm/crc_32.v rx/uart_rx.v rx/sync_uart_rx.v rx/uart_byte_rx.v rx/uart_init_catcher.v
	vvp a.out
	