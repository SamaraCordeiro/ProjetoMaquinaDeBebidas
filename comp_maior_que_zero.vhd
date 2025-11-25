library IEEE;
use IEEE.std_logic_1164.all;

entity comp_maior_que_zero is
    port(
        qntd : in  std_logic_vector(1 downto 0);
        saida : out std_logic
    );
end entity;

architecture rtl of comp_maior_que_zero is
begin
    saida <= '1' when qntd /= "00" else '0';
end architecture;
