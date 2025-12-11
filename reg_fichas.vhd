library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_fichas is
    port (
        clk         : in std_logic;
        reset       : in std_logic;
        
        fichas_set  : in std_logic; -- Sinal de controle (set/load)
        fichas_en   : in std_logic; -- Enable (habilita escrita)
        fichas_prox : in unsigned(3 downto 0); -- O próximo valor (ajuste os bits se necessário)
        
        -- Saída do registrador
        fichas_q    : out unsigned(3 downto 0)
    );
end entity;

architecture rtl of reg_fichas is
begin

    process(clk, reset)
    begin
        if reset = '1' then
            fichas_q <= (others => '0'); 
            
        elsif rising_edge(clk) then
            
            -- Lógica sugerida baseada nos nomes das suas variáveis
            if fichas_set = '1' then
                -- Se 'set' for ativo, talvez você queira carregar um valor fixo ou específico
                fichas_q <= (others => '0'); -- Exemplo: reseta
            elsif fichas_en = '1' then
                -- Se 'en' for ativo, carrega o próximo valor (fichas_prox)
                fichas_q <= fichas_prox;
            end if;
            
        end if;
    end process;

end architecture;