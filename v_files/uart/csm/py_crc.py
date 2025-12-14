def crc32_bitwise(data_hex, print_steps=True):
    """
    Побитовый расчет CRC32 с выводом промежуточных значений
    """
    # Преобразуем hex строку в байты
    data_bytes = bytes.fromhex(data_hex)
    
    # Параметры CRC32
    POLYNOMIAL = 0xEDB88320
    INIT = 0xFFFFFFFF
    FINAL_XOR = 0xFFFFFFFF
    
    crc = INIT
    bit_counter = 0
    
    if print_steps:
        print(f"Расчет CRC32 для данных: {data_hex}")
        print(f"Начальное значение: 0x{crc:08X}")
        print("-" * 60)
    
    # Обрабатываем каждый байт
    for byte_index, byte in enumerate(data_bytes):
        if print_steps:
            print(f"Байт {byte_index}: 0x{byte:02X} ({byte:08b})")
        
        # Обрабатываем каждый бит (от старшего к младшему)
        for bit_pos in range(7, -1, -1):
            bit = (byte >> bit_pos) & 1
            crc_msb = (crc >> 31) & 1
            
            if print_steps:
                print(f"  Бит {bit_pos}: значение={bit}, CRC[31]={crc_msb}, ", end="")
            
            # XOR старшего бита CRC с текущим битом данных
            if crc_msb ^ bit:
                crc = (crc << 1) & 0xFFFFFFFF  # Сдвиг с маской 32 бита
                crc ^= POLYNOMIAL
                if print_steps:
                    print(f"XOR=1 → применяем полином")
            else:
                crc = (crc << 1) & 0xFFFFFFFF  # Сдвиг с маской 32 бита
                if print_steps:
                    print(f"XOR=0 → только сдвиг")
            
            if print_steps:
                print(f"        CRC = 0x{crc:08X}")
            
            bit_counter += 1
    
    # Финальный XOR
    crc_final = crc ^ FINAL_XOR
    
    if print_steps:
        print("-" * 60)
        print(f"После обработки всех битов: 0x{crc:08X}")
        print(f"После финального XOR: 0x{crc_final:08X}")
    
    return crc_final

# Тестирование
if __name__ == "__main__":
    print("=== Тест 1: Один байт 0x00 ===")
    result1 = crc32_bitwise("00")
    
    print("\n=== Тест 2: Один байт 0xA4 ===")
    result2 = crc32_bitwise("A4")
    
    print("\n=== Тест 3: Несколько байтов 0003AABB47 ===")
    result3 = crc32_bitwise("0003AABB47")
    
    print("\n=== Сравнение с binascii.crc32 ===")
    import binascii
    
    test_cases = ["00", "A4", "0003AABB47", "0300AABB47"]
    for test in test_cases:
        data = bytes.fromhex(test)
        expected = binascii.crc32(data) & 0xFFFFFFFF
        actual = crc32_bitwise(test, print_steps=False)
        status = "✓" if expected == actual else "✗"
        print(f"{test}: {status} ожидалось=0x{expected:08X}, получено=0x{actual:08X}")