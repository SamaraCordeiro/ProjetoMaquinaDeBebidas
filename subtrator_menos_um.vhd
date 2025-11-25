-- Subtrator para controlar o estoque de sachês de cada bebida, ele recebe a quantidade atual (qnt_atual) e um comando de subtração.
-- Se subtr = '1' e houver estoque (qnt_atual > 0), decrementa 1 do estoque, caso contrário, mantém o valor atual.

-- A saída (qnt_nova) indica a nova quantidade de sachê

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity subtrator_menos_um is
    port(
        qnt_atual : in  unsigned(1 downto 0);
        subtr     : in  std_logic;
        qnt_nova  : out unsigned(1 downto 0)
    );
end entity;

architecture rtl of subtrator_menos_um is
begin
    process(qnt_atual, subtr)
    begin
        if subtr = '1' and qnt_atual > 0 then
            qnt_nova <= qnt_atual - 1;  -- decrementa 1
        else
            qnt_nova <= qnt_atual;      -- mantém valor
        end if;
    end process;
end architecture;
