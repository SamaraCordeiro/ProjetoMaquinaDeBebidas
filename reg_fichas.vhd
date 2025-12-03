 -- Cecília Rodrigues, Samara Cordeiro, Vitor Alencar
 -- Turma N3
 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reg_ficha is
    Port (
        clk         : in  std_logic;
        ficha_reset : in  std_logic;               -- reset síncrono
        ficha_en    : in  std_logic;               -- enable
        fichas      : in  unsigned(2 downto 0);    -- fichas inseridas
        fichas_final: out unsigned(2 downto 0)     -- valor armazenado
    );
end reg_ficha;

architecture arq of reg_fichas is
    signal s_fichas_reg : unsigned(1 downto 0) := (others => '0'); 
begin

    s_fichas_reg <= '0'      when rising_edge(clk) and fichas_set = '1' else
                  fichas_prox when rising_edge(clk) and fichas_en = '1';
                  
    -- Conecta o sinal interno à saída da entidade
    fichas_atual <= s_fichas_reg;

end arq;
