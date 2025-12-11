library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reg_cafe is -- Mude para reg_cha ou reg_agua nos outros arquivos
    Port (
        clk         : in  std_logic;
        cafe_set    : in  std_logic;            -- AGORA É O BOTÃO DE RECARGA (SW4, 5 ou 6)
        cafe_en     : in  std_logic;            -- Consumir
        cafe_atual  : out unsigned(1 downto 0); 
        cafe_prox   : in  unsigned(1 downto 0) 
    );
end reg_cafe;

architecture arq of reg_cafe is 
    -- MUDANÇA 1: Inicializa com "00" (APAGADO/VAZIO)
    signal s_cafe_reg : unsigned(1 downto 0) := "00"; 
    
begin
    process(clk, cafe_set)
    begin
        -- Se apertar o Switch de recarga, enche o tanque
        if cafe_set = '1' then
            s_cafe_reg <= "11"; -- Enche para 3
            
        elsif rising_edge(clk) then
            if cafe_en = '1' then
                s_cafe_reg <= cafe_prox;
            end if;
        end if;
    end process;
                  
    cafe_atual <= s_cafe_reg;
end arq;