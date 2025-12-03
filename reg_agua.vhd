 -- Cecília Rodrigues, Samara Cordeiro, Vitor Alencar
 -- Turma N3
 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reg_agua is
    Port (
        clk         : in  std_logic;
        agua_set    : in  std_logic;            -- seta quantidade inicial
        agua_en     : in  std_logic;            -- habilitar a subtração
        agua_atual  : out unsigned(1 downto 0); -- valor atualizado
        agua_prox   : in  unsigned(1 downto 0) -- entrada do próximo estado
    );
end reg_agua;

architecture arq of reg_agua is
    signal s_agua_reg : unsigned(1 downto 0) := (others => '0'); 
    
begin

    s_agua_reg <= "11"      when rising_edge(clk) and agua_set = '1' else
                  agua_prox when rising_edge(clk) and agua_en = '1';
                  
    -- Conecta o sinal interno à saída da entidade
    agua_atual <= s_agua_reg;

end arq;
