-- Comparador para conferir se o contador de tempo atingiu 30 segundos que é o tempo de preparo da bebida.

-- A entrada tempo representa o tempo atual em binário (6 bits)
-- A saída = 1 quando tempo = 30 (011110 em binário), indicando que a bebida está pronta. Caso contrário, saida = 0, indicando que a bebida ainda está sendo produzida.


library IEEE;
use IEEE.std_logic_1164.all;

entity comp_tempo is
    port(
        tempo   : in  std_logic_vector(4 downto 0);
        saida   : out std_logic  -- igual a 1 quando o contador = 11110
    );
end entity;

architecture rtl of comp_tempo is
begin
    saida <= '1' when tempo = "11110" else '0';
end architecture;
