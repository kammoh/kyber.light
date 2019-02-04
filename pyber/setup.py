from setuptools import setup

setup(
    name="pyber",
    version="0.1",
    py_modules=["_pyber", "pyber"],
    setup_requires=["cffi>=1.11.0"],
    cffi_modules=["build_pyber.py:ffibuilder"],
    install_requires=["cffi>=1.11.0"],
)