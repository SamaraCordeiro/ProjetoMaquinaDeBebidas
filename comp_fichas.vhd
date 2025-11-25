-- Comparador para verificar se a quantidade de fichas inseridas na máquina é =2. Caso seja, a saída será 1, caso contrário, será 0 indicando que a quantidade de fichas é insuficiente.

library IEEE;
use IEEE.std_logic_1164.all;

entity comp_fichas is
    port(
        fichas_inseridas  : in  std_logic_vector(1 downto 0);
        saida             : out std_logic
    );
end entity;

architecture rtl of comp_fichas is
begin
    saida <= '1' when fichas_inseridas = "10" else '0';
end architecture;
