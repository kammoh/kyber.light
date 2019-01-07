from cocotb.handle import ModifiableObject
from cocotb.result import *

def auto_gold(inputs, model, dut=None):
    from munch import Munch

    if not dut is None:
        for sig, val in inputs.items():
            
            try:
                dut_sig = getattr(dut, sig)
            except Exception as e:
#                 dut._log.warn(f"Caught {e}... \n Ignoring {sig}<-{val}")
                continue
            
            if type(dut_sig) is None:
                raise SimFailure(f"Signal {sig} not found in design")
            
            if type(dut_sig) is ModifiableObject:
                dut._log.debug(f"setting {dut_sig._path} <= {val}")
                dut_sig <= val
            else:
                dut_val = dut_sig.value
                try:
                    dut_val = int(dut_val)
                except:
                    dut_val = str(dut_val).lstrip(" 0")
                if val != dut_val and str(val) != str(dut_val):
                    dut._log.error(f"{dut_sig._path}.value == {dut_val}  !=  goleden.input.{sig}.value{val}")
                    raise TestFailure(f"value of {dut_sig._path} -> {val} does not match value in design -> {dut_val}")
                dut._log.debug(f"{dut_sig._path} == {dut_val}")
    
    return Munch(model(Munch(inputs)))


__all__ = ["auto_gold"]