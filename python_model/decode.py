import numpy as np

FS = 2_000_000  # 2 MHz sample rate

def load_iq(path):
    """
    Load a raw capture file with data for processing. The file consists of interleaved 8-bit unsigned I/Q samples
    The return value is an array with complex numbers as entries to represent I/Q Values
    """
    raw = np.fromfile(path, dtype = np.uint8) # This creates an array from the modes1.bin file. Each element is one byte, with a value of unsigned numbers between 0-255
    i_vals = raw[0::2] # Even values for I
    q_vals = raw[1::2] # Odd values for Q

    # I/Q values should actually be centered around 0, rather than the midpoint of the 0-255 range which is 127.5
    i_centered = i_vals - 127.5 
    q_centered = q_vals - 127.5

    # Combine the I/Q values for further processing
    combined = i_centered + 1j * q_centered
    
    return combined

def compute_magnitude(iq):
    """
    Simply turn the complex I/Q array values into magnitudes
    """
    magnitude = np.abs(iq)
    return magnitude

def find_preambles(mag):
    """
    Scan the magnitude signal for the ADS-B preamble pattern (pulses at 0, 1.0, 3.5, 4.5 microseconds within an
    8us window). Store these signals into a list and Return a list of sample indices where a preamble was found.
    """
    pattern = [1, 0, 1, 0, 0 , 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0]

    working_indicies = []
    total = []

    for i in range(0, len(mag)-15):
        product_list = pattern * mag[i:i+16] # Compute element-wise multiplication of the pattern and current magnitude 16-element set
        total.append(sum(product_list)) # List of sums of all products in the current 16-element array

    threshold = np.mean(total) + 5 * np.std(total)

    for i in range(0, len(total)):
        if total[i] > threshold:
            working_indicies.append(i)

        
    return working_indicies

def demod_ppm(mag, working_indicies):
    """
    Given a magnitude signal and the index where the data bits begin (right after a detected preamble),
    decode 112 bits using PPM: for each 1us window, compare the first half vs second half.
    Return a list of 112 bits (0s and 1s).
    """

    all_messages = [] # List containing lists for all PPM converted bit messages
    

    for i in range(0, len(working_indicies)):
        data_start = working_indicies[i] + 16
        PPM_bits = [] # Sublists containing information for a single aircraft

        for j in range(0, 112):
            if (mag[data_start + 2*j] > mag[data_start + 2*j + 1]):
                PPM_bits.append(1)
            else:
                PPM_bits.append(0)

        all_messages.append(PPM_bits)

    return all_messages

def check_crc(bits):
    """
    The every valid message (112-bits total) consists of a 24-bit password at the end.
    This password can be computed using a special algorithm specifically used for ADS-B confirmation, where a set 
    "check" array is used to compare and do XOR operations with a copy of the bits list. At the end of all the 
    checks, the last 24-bits should all be 0, meaning that the message is valid.
    """

    check = [1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,0,0,0,0,0,0,1,0,0,1] # 24-bit CRC check for ADS-B
    bits_copy = bits.copy()
    total = 0

    for i in range(len(bits) - 24):
        if bits_copy[i] == 1:
            for j in range(len(check)):
                bits_copy[i+j] = bits_copy[i+j] ^ check[j]

    for i in range(88,112):
        total += bits_copy[i]

    if total == 0:
        return True
    else:
        return False


def parse_message(bits):
    """
    Given a CRC-verified 112-bit message, extract DF, ICAO address, Type Code, and (depending on TC) 
    callsign / position / velocity. Return a dictionary of decoded fields.
    """

    message = {}
    message["DF"] = bits_to_integer(bits[0:5])
    message["CA"] = bits_to_integer(bits[5:8])
    message["ICAO"] = bits_to_integer(bits[8:32])
    message["TC"] = bits_to_integer(bits[32:37])
    message["CRC"] = bits_to_integer(bits[88:112])

    if message["TC"] == 19:
        message["Status"] = bits_to_integer(bits[40:45])

        if bits[45] == 1:
            ew_velocity = (bits_to_integer(bits[46:56]) - 1) * -1
        else:
            ew_velocity = (bits_to_integer(bits[46:56]) - 1)

        if bits[56] == 1:
            ns_velocity = (bits_to_integer(bits[57:67]) - 1) * -1
        else:
            ns_velocity = (bits_to_integer(bits[57:67]) - 1)

        message["Ground_Speed"] = np.sqrt(ew_velocity ** 2 + ns_velocity ** 2)

        raw_angle = np.degrees(np.arctan2(ew_velocity, ns_velocity))
        if raw_angle < 0:
            raw_angle = raw_angle + 360

        message["Heading"] = raw_angle

    return message


def bits_to_integer(bits):
    value = 0
    for bit in bits:
        value = value * 2 + bit
    return value
    
    

if __name__ == "__main__":
    iq = load_iq("../data/modes1.bin")
    print(f"Loaded {len(iq)} samples")
    print(iq[:5])

    mag = compute_magnitude(iq)
    print(f"Max magnitude: {mag.max():.2f}")
    print(f"Mean magnitude: {mag.mean():.2f}")
    print(mag[:5])