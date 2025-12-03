 -- Cecília Rodrigues, Samara Cordeiro, Vitor Alencar
 -- Turma N3
 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity contador is
    Port (
        clk    : in  std_logic;
        reset  : in  std_logic;            -- zerar quando chegar em 30
        enable : in  std_logic;            -- começar a contar
        tempo  : out unsigned(4 downto 0)  -- 5 bits contam até 31
    );
end contador;

architecture arq of contador is
    signal s_tempo : unsigned(4 downto 0) := (others => '0');

begin

    -- 1. Reset externo (zera tudo imediatamente)
    -- 2. Borda de Clock:
    --    a. Se enable ativo E chegou em 30 -> Volta para 0
    --    b. Se enable ativo -> Incrementa + 1
    --    c. Se enable inativo -> Mantém valor (implícito)

    s_tempo <= (others => '0') when reset = '1' else
               (others => '0') when rising_edge(clk) and enable = '1' and s_tempo = 30 else
               s_tempo + 1     when rising_edge(clk) and enable = '1';

    -- Conecta o sinal interno à saída
    tempo <= s_tempo;

end arq;