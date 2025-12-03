 -- Cecília Rodrigues, Samara Cordeiro, Vitor Alencar
 -- Turma N3
 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reg_cafe is
    Port (
        clk         : in  std_logic;
        cafe_set    : in  std_logic;            -- seta quantidade inicial
        cafe_en     : in  std_logic;            -- habilitar a subtração
        cafe_atual  : out unsigned(1 downto 0); -- valor atualizado
        cafe_prox   : in  unsigned(1 downto 0) -- entrada do próximo estado
    );
end reg_cafe;

architecture arq of reg_cafe is
    -- Precisamos de um sinal interno para armazenar o estado,
    -- pois não podemos ler a porta 'cafe_atual' (mode out).
    signal s_cafe_reg : unsigned(1 downto 0) := (others => '0'); 
    
begin

    -- Atribuição Condicional Síncrona
    -- Prioridade: 
    -- 1. cafe_set: Inicializa a máquina (Assumindo "11" = 3 = Cheio)
    -- 2. cafe_en:  Atualiza com o próximo valor (subtração vinda de fora)
    -- 3. Implicitamente: Mantém o valor anterior se nada acontecer na borda
    
    s_cafe_reg <= "11"      when rising_edge(clk) and cafe_set = '1' else
                  cafe_prox when rising_edge(clk) and cafe_en = '1';
                  
    -- Conecta o sinal interno à saída da entidade
    cafe_atual <= s_cafe_reg;

end arq;