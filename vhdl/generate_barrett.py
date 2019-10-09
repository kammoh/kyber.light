#!/usr/bin/env python3


from math import floor, log2, ceil
from subprocess import run


def log2ceil(x): return ceil(log2(x))


M = 3329
n = log2ceil(M)

print(f"M={M} n={n} bits")

i = 0  # i >= 0
a = n + 1 + i
b = -2
mu = 2**(n+a) // M
mu_bits = log2ceil(mu)

uh_bits = 2*n - (n + b)
ul_bits = n + 1
q_hat_bits = uh_bits + mu_bits - (a - b)

entity_name = f'barrett_{M}'
vhdl = []

vhdl.append('''--===================================================================================================================--
-----------------------------------------------------------------------------------------------------------------------
--                                  
--                                    8"""""o   8"""""   8""""o    8"""""o 
--                                    8     "   8        8    8    8     " 
--                                    8e        8eeeee   8eeee8o   8o     
--                                    88        88       88    8   88   ee 
--                                    88    e   88       88    8   88    8 
--                                    68eeee9   888eee   88    8   888eee8 
--                                  
--                                  Cryptographic Engineering Research Group
--                                          George Mason University
--                                       https://cryptography.gmu.edu/
--                                  
-----------------------------------------------------------------------------------------------------------------------
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
''')

P_DIVIDER_PIPELINE_LEVELS = 3


vhdl.append(f'''
entity {entity_name} is
    port(clk, rst : in  std_logic;
        U         : in  std_logic_vector({2*n - 1} downto 0);
        U_valid   : in  std_logic;
        U_ready   : out std_logic;
        r         : out std_logic_vector({n-1} downto 0);
        q         : out std_logic_vector({n} downto 0);
        rq_valid  : out std_logic;
        rq_ready  : in  std_logic);
end entity;

architecture RTL of {entity_name} is
    signal Uh                : std_logic_vector({uh_bits - 1} downto 0);
    signal Ul                : std_logic_vector({ul_bits - 1} downto 0);
    signal Ul_reg_0          : std_logic_vector({ul_bits - 1} downto 0);
    signal Ul_reg            : std_logic_vector({ul_bits - 1} downto 0);
    signal Uh_times_mu       : std_logic_vector({uh_bits + mu_bits - 1} downto 0);
    signal q_hat             : std_logic_vector({q_hat_bits - 1} downto 0);
    signal q_reg             : std_logic_vector({n} downto 0);
    signal q_reg_in          : std_logic_vector({n} downto 0);
    signal q_hat_reg         : std_logic_vector({q_hat_bits - 1} downto 0);
    signal q_hat_reg_1       : std_logic_vector({q_hat_bits - 1} downto 0);
    signal q_hat_times_M     : std_logic_vector({q_hat_bits + n - 1} downto 0);
    signal q_hat_times_M_reg : std_logic_vector({q_hat_bits + n - 1} downto 0);
    signal r_hat             : unsigned({n} downto 0);
    signal r_hat_minus_M     : unsigned({n} downto 0);
    signal r_reg             : std_logic_vector({n-1} downto 0);
    signal r_reg_in          : std_logic_vector({n-1} downto 0);
    signal correction_n      : std_logic;
    signal valid_pipe        : std_logic_vector({P_DIVIDER_PIPELINE_LEVELS} - 1 downto 0);
    signal stall             : boolean;
begin
    const_mult_mu: entity work.IntConstMultOptTernary_{mu}_{n - b}
        port map(clk           => clk,
                 rst           => rst,
                 x_in0         => Uh,
                 x_out0_c{mu:-5} => Uh_times_mu);
    const_mult_M: entity work.IntConstMultOptTernary_{M}_{q_hat_bits}
        port map(clk          => clk,
                 rst          => rst,
                 x_in0        => q_hat_reg,
                 x_out0_c{M:-4} => q_hat_times_M);
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                valid_pipe <= (others => '0');
            else
                if not stall then
                    valid_pipe        <= valid_pipe(valid_pipe'length - 2 downto 0) & U_valid;
                    -- data registers
                    Ul_reg_0          <= Ul;
                    Ul_reg            <= Ul_reg_0;
                    q_hat_reg         <= q_hat;
                    q_hat_reg_1       <= q_hat_reg;
                    q_hat_times_M_reg <= q_hat_times_M;
                    r_reg             <= r_reg_in;
                    q_reg             <= q_reg_in;
                end if;
            end if;
        end if;
    end process;

    stall         <= valid_pipe({P_DIVIDER_PIPELINE_LEVELS - 1}) = '1' and rq_ready = '0';
    Uh            <= U({2*n - 1} downto {n+b});
    Ul            <= U({ul_bits - 1} downto 0);
    q_hat         <= Uh_times_mu({q_hat_bits + (a-b) - 1} downto {a-b});
    r_hat         <= resize(unsigned(Ul_reg) - unsigned(q_hat_times_M_reg), r_hat'length);
    r_hat_minus_M <= r_hat - {M};
    correction_n  <= r_hat_minus_M(r_hat_minus_M'length - 1); -- sign bit
    q_reg_in      <= std_logic_vector(unsigned(q_hat_reg_1) + 1) when correction_n = '0' else q_hat_reg_1;
    r_reg_in      <= std_logic_vector(r_hat_minus_M({n-1} downto 0)) when correction_n = '0' else std_logic_vector(r_hat({n-1} downto 0));
    
    q        <= q_reg;
    r        <= r_reg;
    rq_valid <= valid_pipe({P_DIVIDER_PIPELINE_LEVELS - 1});
    U_ready  <= '0' when stall else '1';
end architecture;
''')

flopoco = f'/src/vhdl/arith/flopoco/build/flopoco'
flopoco_mult = 'IntConstMultOptTernary'  # 'IntConstMultOpt'


with open(f'{entity_name}.vhdl', 'w') as outfile:
    outfile.write('\n'.join(vhdl))


# Uh * mu
run([flopoco, flopoco_mult, f'constant={mu}', f'wIn={uh_bits}', f'outputFile=IntConstMultOptTernary_{mu}_{n - b}.vhdl'])
# q_hat * M
run([flopoco, flopoco_mult, f'constant={M}',
     f'wIn={q_hat_bits}', f'outputFile=IntConstMultOptTernary_{M}_{q_hat_bits}.vhdl'])
