import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np
from golden_model import matmul_int8, random_matrix_int8

ROWS = 4
COLS = 4
K = 4
TOTAL_CYCLES = ROWS + COLS + K - 2

NUM_TESTS = 10000
MAX_FAIL_THRESHOLD = 5

async def reset(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.clear.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_matrices(dut, A, B):
    """Drive A_MAT and B_MAT ports from numpy arrays"""
    for i in range(ROWS):
        for k in range(K):
            dut.A[i][k].value = int(A[i][k])
    for k in range(K):
        for j in range(COLS):
            dut.B[k][j].value = int(B[k][j])

async def run_matmul(dut, A, B):
    """
    Drive one matmul, wait for done \n
    Return: C
    """
    # Clear accum
    dut.clear.value = 1
    await RisingEdge(dut.clk)
    dut.clear.value = 0
    await RisingEdge(dut.clk)

    await(load_matrices(dut, A, B))

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while True:
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break

    C = np.zeros((ROWS, COLS), dtype=np.int32)
    for i in range (ROWS):
        for j in range(COLS):
            C[i][j] = dut.C[i][j].value.to_signed()
    return C

@cocotb.test()
async def test_random_matmuls(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    fail_count = 0
    for n in range(NUM_TESTS):
        A = random_matrix_int8(ROWS, K, seed=n*2)
        B = random_matrix_int8(K, COLS, seed=n*2 + 1)
        expected = matmul_int8(A, B)
        actual = await run_matmul(dut, A, B)

        if not np.array_equal(actual, expected):
            fail_count += 1
            if (fail_count <= MAX_FAIL_THRESHOLD):
                dut._log.error(f"Test {n} FAILED")
                dut._log.error(f"A=\n{A}")
                dut._log.error(f"B=\n{B}")
                dut._log.error(f"Expected:\n{expected}\n Actual:\n{actual}")

    assert fail_count == 0, f"TESTS_FAILED= {fail_count}/{NUM_TESTS}"
    dut._log.info(f"{NUM_TESTS - fail_count} Tests PASSED.")