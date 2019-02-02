//! An implementation of the FIPS-202-defined SHA-3 and SHAKE functions.

//! Implementor: David Leon Gil
//! Port to rust:
//! License: CC0, attribution kindly requested. Blame taken too,
//! but not liability.
//!
#![feature(specialization)]

extern crate pyo3;

use pyo3::prelude::*;
use pyo3::types::PyBytes;

/// This module is a python moudle implemented in Rust.
#[pymodule]
fn tiny_keccak(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_class::<Keccak>()?;

    Ok(())
}

/// Total number of lanes.
const NUM_LANES: usize = 25;
const NUM_ROUNDS: usize = 24;

const MY_RHO: [u32; NUM_LANES] = [
    0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14,
];

pub fn print_rho() {
    for i in 1..25 {
        println!("{:3} {}", MY_RHO[i] / 4, MY_RHO[i] % 4);
    }
    for i in 1..13 {
        print!(
            "12X\"{:03X}\", ",
            ((64 - MY_RHO[2 * i]) << 6) | (64 - MY_RHO[2 * i - 1])
        );
        if (i - 1) % 4 == 3 {
            print!("\n");
        }
    }
}

const RC: [u64; NUM_ROUNDS + 1] = [
    0x0000000000000000u64,
    0x0000000000000001u64,
    0x0000000000008082u64,
    0x800000000000808au64,
    0x8000000080008000u64,
    0x000000000000808bu64,
    0x0000000080000001u64,
    0x8000000080008081u64,
    0x8000000000008009u64,
    0x000000000000008au64,
    0x0000000000000088u64,
    0x0000000080008009u64,
    0x000000008000000au64,
    0x000000008000808bu64,
    0x800000000000008bu64,
    0x8000000000008089u64,
    0x8000000000008003u64,
    0x8000000000008002u64,
    0x8000000000000080u64,
    0x000000000000800au64,
    0x800000008000000au64,
    0x8000000080008081u64,
    0x8000000000008080u64,
    0x0000000080000001u64,
    0x8000000080008008u64,
];

fn setout(src: &[u8], dst: &mut [u8], len: usize) {
    dst[..len].copy_from_slice(&src[..len]);
}

#[pyclass]
pub struct Keccak {
    pub state: [u64; NUM_LANES],
    offset: usize,
    rate: usize,
    delim: u8,
    input: Vec<u8>,
}

impl Clone for Keccak {
    fn clone(&self) -> Self {
        let mut res = Keccak::new(self.rate, self.delim);
        res.state.copy_from_slice(&self.state);
        res.input.copy_from_slice(&self.input);
        res.offset = self.offset;
        res
    }
}

macro_rules! impl_constructor {
    ($name: ident, $alias: ident, $bits: expr, $delim: expr) => {
        pub fn $name() -> Keccak {
            Keccak::new(200 - $bits / 4, $delim)
        }

        pub fn $alias(data: &[u8], result: &mut [u8]) {
            let mut keccak = Keccak::$name();
            keccak.update(data);
            keccak.finalize(result);
        }
    };
}

macro_rules! impl_global_alias {
    ($alias: ident, $size: expr) => {
        pub fn $alias(data: &[u8]) -> [u8; $size / 8] {
            let mut result = [0u8; $size / 8];
            Keccak::$alias(data, &mut result);
            result
        }
    };
}

impl_global_alias!(shake128, 128);
impl_global_alias!(shake256, 256);
impl_global_alias!(keccak224, 224);
impl_global_alias!(keccak256, 256);
impl_global_alias!(keccak384, 384);
impl_global_alias!(keccak512, 512);
impl_global_alias!(sha3_224, 224);
impl_global_alias!(sha3_256, 256);
impl_global_alias!(sha3_384, 384);
impl_global_alias!(sha3_512, 512);

#[pymethods]
impl Keccak {
    #[new]
    pub fn __new__(obj: &PyRawObject, rate: usize, delim: u8) -> PyResult<()> {
        obj.init(|| Keccak::new(rate, delim))
    }

    pub fn py_update(&mut self, input: &PyBytes) -> PyResult<()> {
        self.update(input.as_bytes());
        Ok(())
    }

    pub fn py_finalize(&mut self, output_size: usize) -> PyResult<Vec<u8>> {
        let mut output = vec![0; output_size];
        self.finalize(output.as_mut_slice());
        Ok(output)
    }

    #[staticmethod]
    fn ij_to_linear(i: usize, j: usize) -> usize {
        (i % 5) * 5 + (j % 5)
    }

    pub fn theta(&mut self) -> PyResult<()> {
        let mut parity: [u64; 5] = [0; 5];
        for col in 0..5 {
            for row in 0..5 {
                parity[col] ^= self.state[Self::ij_to_linear(row, col)];
            }
        }

        for col in 0..5 {
            for row in 0..5 {
                self.state[Self::ij_to_linear(row, col)] ^=
                    parity[(col + 4) % 5] ^ parity[(col + 1) % 5].rotate_left(1);
            }
        }
        Ok(())
    }

    pub fn rho(&mut self) -> PyResult<()> {
        for x in 1..25 {
            // all lanes
            self.state[x] = self.state[x].rotate_left(MY_RHO[x]);
        }
        Ok(())
    }

    pub fn pi(&mut self) -> PyResult<()> {
        let state: [u64; 25] = self.state.clone();
        for row in 0..5 {
            for col in 0..5 {
                self.state[Self::ij_to_linear(row, col)] =
                    state[Self::ij_to_linear(col, 3 * row + col)];
            }
        }
        Ok(())
    }

    pub fn chi(&mut self) -> PyResult<()> {
        for row in 0..5 {
            let mut array: [u64; 5] = [0; 5];

            for col in 0..5 {
                array[col] = self.state[Self::ij_to_linear(row, col)];
            }

            for col in 0..5 {
                self.state[Self::ij_to_linear(row, col)] =
                    array[col] ^ ((!array[(col + 1) % 5]) & (array[(col + 2) % 5]));
            }
        }
        Ok(())
    }

    pub fn iota(&mut self, i: usize) -> PyResult<()> {
        self.state[0] ^= RC[i];
        Ok(())
    }

    pub fn dump_state(&self) -> PyResult<()> {
        for i in 0..NUM_LANES {
            println!("{:016X}", self.state[i]);
        }
        Ok(())
    }

    pub fn pad(&mut self) -> PyResult<()> {
        self.input.push(self.delim);
        let l = self.input.len();
        let r = self.rate as isize;
        let fill = (r - (l as isize % r)) - 1;
        for _ in 0..fill {
            self.input.push(0);
        }
        self.input.push(0x80);
        Ok(())
    }

    pub fn xorin(&mut self) -> PyResult<()> {
        for i in 0..self.rate {
            self.a_mut_bytes()[i] ^= self.input[i + self.offset];
        }
        self.offset += self.rate;
        Ok(())
    }

    pub fn slice_proc(&mut self, round: usize) -> PyResult<()> {
        if round != 0 {
            self.pi()?;
            self.chi()?;
            self.iota(round)?;
        }
        if round != NUM_ROUNDS {
            self.theta()?;
        }

        Ok(())
    }

    #[getter(state)]
    pub fn get_state(&self) -> PyResult<Vec<u64>> {
        Ok(self.state.to_vec())
    }

    pub fn keccakf(&mut self) -> PyResult<()> {

        let mut round_cntr = 0;
        loop {
            self.slice_proc(round_cntr)?;
            if round_cntr == NUM_ROUNDS {
                break;
            }
            self.rho()?;
            round_cntr += 1;
        }

        Ok(())
    }
}

impl Keccak {
    pub fn new(rate: usize, delim: u8) -> Keccak {
        Keccak {
            state: [0; NUM_LANES],
            offset: 0,
            rate: rate,
            delim: delim,
            input: Vec::new(),
        }
    }

    impl_constructor!(new_shake128, shake128, 128, 0x1f);
    impl_constructor!(new_shake256, shake256, 256, 0x1f);
    impl_constructor!(new_keccak224, keccak224, 224, 0x01);
    impl_constructor!(new_keccak256, keccak256, 256, 0x01);
    impl_constructor!(new_keccak384, keccak384, 384, 0x01);
    impl_constructor!(new_keccak512, keccak512, 512, 0x01);
    impl_constructor!(new_sha3_224, sha3_224, 224, 0x06);
    impl_constructor!(new_sha3_256, sha3_256, 256, 0x06);
    impl_constructor!(new_sha3_384, sha3_384, 384, 0x06);
    impl_constructor!(new_sha3_512, sha3_512, 512, 0x06);

    fn a_bytes(&self) -> &[u8; NUM_LANES * 8] {
        unsafe { core::mem::transmute(&self.state) }
    }

    fn a_mut_bytes(&mut self) -> &mut [u8; NUM_LANES * 8] {
        unsafe { core::mem::transmute(&mut self.state) }
    }

    pub fn update(&mut self, input: &[u8]) {
        self.input.extend_from_slice(input);
    }

    pub fn finalize(&mut self, output: &mut [u8]) {
        self.pad().unwrap();

        let mut l = self.input.len();
        let rate = self.rate;
        while l >= rate {
            self.xorin().unwrap();
            self.keccakf().unwrap();
            l -= rate;
        }
        assert_eq!(l, 0);

        // squeeze output
        self.squeeze(output);
    }

    // squeeze output
    pub fn squeeze(&mut self, output: &mut [u8]) {
        let mut op = 0;
        let mut l = output.len();
        while l >= self.rate {
            setout(self.a_bytes(), &mut output[op..], self.rate);
            self.keccakf().unwrap();
            op += self.rate;
            l -= self.rate;
        }

        setout(self.a_bytes(), &mut output[op..], l);
    }
}
