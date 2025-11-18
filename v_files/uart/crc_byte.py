def crc32_single_byte(byte_value, print_steps=True):
    """
    Побитовый расчет CRC32 для одного байта
    """
    POLYNOMIAL = 0xEDB88320
    INIT = 0xFFFFFFFF
    FINAL_XOR = 0xFFFFFFFF
    
    crc = INIT
    
    if print_steps:
        print(f"Расчет CRC32 для байта: 0x{byte_value:02X} ({byte_value:08b})")
        print(f"Начальное значение: 0x{INIT:08X}")
        print("-" * 50)
    
    # Обрабатываем биты от старшего к младшему
    for bit_pos in range(7, -1, -1):
        bit = (byte_value >> bit_pos) & 1
        crc_msb = (crc >> 31) & 1
        
        if print_steps:
            print(f"Бит {bit_pos}: данные={bit}, CRC[31]={crc_msb}, XOR={crc_msb ^ bit}, ", end="")
        
        if crc_msb ^ bit:
            crc = ((crc << 1) & 0xFFFFFFFF) ^ POLYNOMIAL
            if print_steps:
                print("применяем полином")
        else:
            crc = (crc << 1) & 0xFFFFFFFF
            if print_steps:
                print("только сдвиг")
        
        if print_steps:
            print(f"  CRC = 0x{crc:08X} ({crc:032b})")
    
    # Финальный XOR
    crc_final = crc ^ FINAL_XOR
    
    if print_steps:
        print("-" * 50)
        print(f"Промежуточный CRC: 0x{crc:08X}")
        print(f"Финальный CRC: 0x{crc_final:08X}")
    
    return crc_final

# Пример использования
if __name__ == "__main__":
    print("=== Детальный расчет для 0x00 ===")
    result = crc32_single_byte(0x00)
    
    print("\n=== Детальный расчет для 0xA4 ===")
    result = crc32_single_byte(0xA4)