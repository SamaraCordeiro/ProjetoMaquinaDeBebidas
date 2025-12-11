library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reg_cha is -- Mude para reg_cha ou reg_agua nos outros arquivos
    Port (
        clk         : in  std_logic;
        cha_set    : in  std_logic;            -- AGORA É O BOTÃO DE RECARGA (SW4, 5 ou 6)
        cha_en     : in  std_logic;            -- Consumir
        cha_atual  : out unsigned(1 downto 0); 
        cha_prox   : in  unsigned(1 downto 0) 
    );
end reg_cha;

architecture arq of reg_cha is 
    -- MUDANÇA 1: Inicializa com "00" (APAGADO/VAZIO)
    signal s_cha_reg : unsigned(1 downto 0) := "00"; 
    
begin
    process(clk, cha_set)
    begin
        -- Se apertar o Switch de recarga, enche o tanque
        if cha_set = '1' then
            s_cha_reg <= "11"; -- Enche para 3
            
        elsif rising_edge(clk) then
            if cha_en = '1' then
                s_cha_reg <= cha_prox;
            end if;
        end if;
    end process;
                  
    cha_atual <= s_cha_reg;
end arq;