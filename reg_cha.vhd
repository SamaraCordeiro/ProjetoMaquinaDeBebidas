 -- Cecília Rodrigues, Samara Cordeiro, Vitor Alencar
 -- Turma N3
 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reg_cha is
    Port (
        clk        : in  std_logic;
        cha_set    : in  std_logic;            -- seta quantidade inicial
        cha_en     : in  std_logic;            -- habilitar a subtração
        cha_atual  : out unsigned(1 downto 0); -- valor atualizado
        cha_prox   : in  unsigned(1 downto 0) -- entrada do próximo estado
    );
end reg_cha;

architecture arq of reg_cha is
    signal s_cha_reg : unsigned(1 downto 0) := (others => '0'); 
begin

    s_cha_reg <= "11"      when rising_edge(clk) and cha_set = '1' else
                  cha_prox when rising_edge(clk) and cha_en = '1';
                  
    -- Conecta o sinal interno à saída da entidade
    cha_atual <= s_cha_reg;

end arq;