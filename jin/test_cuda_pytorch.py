#!/usr/bin/env python3
"""Check whether PyTorch is installed and CUDA can run a small GPU op."""

from __future__ import annotations

import shutil
import subprocess
import sys


def _print_nvidia_smi() -> None:
    nvidia_smi = shutil.which("nvidia-smi")
    if nvidia_smi is None:
        print("[nvidia-smi] 未找到，跳过驱动信息。")
        return
    print("[nvidia-smi]")
    result = subprocess.run(
        [nvidia_smi, "--query-gpu=index,name,driver_version,memory.total", "--format=csv,noheader"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stderr.strip() or "nvidia-smi 执行失败。")
        return
    print(result.stdout.strip() or "(无 GPU)")


def main() -> int:
    print(f"Python: {sys.version.split()[0]} ({sys.executable})")
    _print_nvidia_smi()
    print()

    try:
        import torch
    except ImportError as exc:
        print(f"[PyTorch] 不可用：无法导入 torch ({exc})")
        return 1

    print(f"[PyTorch] 可用，版本 {torch.__version__}")
    print(f"[CUDA] torch.cuda.is_available() = {torch.cuda.is_available()}")
    print(f"[CUDA] torch.version.cuda = {torch.version.cuda}")
    print(f"[CUDA] device count = {torch.cuda.device_count()}")

    if not torch.cuda.is_available():
        print("[CUDA] 不可用。当前 PyTorch 可能是 CPU 版本，或驱动 / CUDA 运行时未就绪。")
        return 2

    for index in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(index)
        print(
            f"[GPU {index}] {props.name}, "
            f"compute capability {props.major}.{props.minor}, "
            f"memory {props.total_memory / (1024**3):.2f} GiB"
        )

    device = torch.device("cuda")
    a = torch.randn(1024, 1024, device=device)
    b = torch.randn(1024, 1024, device=device)
    c = a @ b
    torch.cuda.synchronize()
    print(f"[CUDA] 矩阵乘法成功，结果 shape={tuple(c.shape)}, device={c.device}, dtype={c.dtype}")
    print("[结果] PyTorch 可用，CUDA 可用。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
