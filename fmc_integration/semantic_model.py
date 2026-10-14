"""Independent address/command expectations for the verification contract."""
def byte_offset(bank, row, column):
    return bank * (8192 * 256 * 2) + row * (256 * 2) + column * 2

def sample_count(milliseconds):
    if not 1 <= milliseconds <= 200:
        raise ValueError('duration outside supported acquisition range')
    return milliseconds * 100_000

assert byte_offset(0, 16, 0) == 0x2000
assert byte_offset(0, 31, 255) == 0x3ffe
assert byte_offset(1, 0, 0) == 0x400000
assert sample_count(200) == 20_000_000
print('Address and acquisition semantic contract checks passed.')
