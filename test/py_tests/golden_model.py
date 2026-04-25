import numpy as np

def matmul_int8(A, B):
    """
    `A`: (`ROWS`, `K`) int8 numpy array \n
    `B`: (`K`, `COLS`) int8 numpy array \n
    returns: (`ROWS`, `COLS`) int32 numpy array \n
    """
    return A.astype(np.int32) @ B.astype(np.int32)

def random_matrix_int8(rows, cols, seed=None):
    rng = np.random.default_rng(seed)
    return rng.integers(-128, 128, size=(rows, cols), dtype=np.int8)

if __name__ == "__main__":
    A = np.array([[1,2],[3,4]], dtype=np.int8)
    B = np.array([[5,6],[7,8]], dtype=np.int8)
    expected = np.array([[19,22],[43,50]], dtype=np.int32)
    result = matmul_int8(A, B)
    assert np.array_equal(result, expected), f"FAIL: expected {expected}, got {result}"
    print("Known-answer test PASSED")

    A = random_matrix_int8(4, 4, 74)
    B = random_matrix_int8(4, 4, 49)
    C = matmul_int8(A, B)
    print("Random A @ B =")
    print (C)