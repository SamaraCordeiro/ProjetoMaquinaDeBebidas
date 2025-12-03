 -- Cecília Rodrigues, Samara Cordeiro, Vitor Alencar
 -- Turma N3
 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reg_troco is
    Port (
        clk      : in  std_logic;
        reset    : in  std_logic;                 -- zera o troco
        fichas_2 : in  unsigned(2 downto 0);      -- valor: fichas - 2
        troco    : out unsigned(2 downto 0)       -- troco armazenado
    );
end reg_troco;

architecture arq of reg_troco is
begin
    
    troco <= (others => '0') when reset = '1' else    -- Reset assíncrono (prioridade)
             fichas_2        when rising_edge(clk);   -- Carga síncrona na borda do clock

end arq;