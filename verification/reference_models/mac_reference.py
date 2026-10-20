def mac(a, b, acc):
    return acc + (a * b)

# test vectors
tests = [
    (2, 3, 0),
    (5, 4, 10),
    (-2, 3, 0),
    (7, -1, 5)
]

for a, b, acc in tests:
    print(f"a={a}, b={b}, acc={acc} => {mac(a,b,acc)}")