library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Controladora is
    Port ( 
        clk, rst, ligar, interromper : in STD_LOGIC;
        ficha_detectada, sel_cafe, sel_cha, erro_estoque, pronto_timer : in STD_LOGIC;
        lcd_concluido : in STD_LOGIC; 
        cont_reset, cont_start, agua_en, cafe_en, cha_en, devolver_tudo, finalizado : out STD_LOGIC;
        troco_normal : out STD_LOGIC;
        
        -- NOVO SINAL: Avisa se a máquina está rodando
        sistema_ativo : out STD_LOGIC;
        
        seletor_lcd  : out STD_LOGIC_VECTOR(2 downto 0)
    );
end Controladora;

architecture Behavioral of Controladora is

    type tipo_estado is (
        S0_ESPERA,
        S1_INICIO,
        S2_SELECAO,
        S_PREPARAR,   
        S3_CAFE,      
        S4_CHA,       
        S5_FINAL, S5_RST_TIMER, S5_WAIT, -- Sucesso
        S6_CANCELAR, S6_RST_TIMER, S6_WAIT, -- Cancelar
        S7_ERRO, S7_RST_TIMER, S7_WAIT -- Erro
    );
    
    signal estado_atual, proximo_estado : tipo_estado;
    signal bebida_escolhida  : std_logic_vector(1 downto 0);
    
    signal ligar_sync1, ligar_sync2, ligar_anterior, ligar_pulso : std_logic; 
    signal inter_sync1, inter_sync2 : std_logic;

begin

    -- Sincronização
    process(clk, rst)
    begin
        if rst = '1' then
            ligar_sync1 <= '0'; ligar_sync2 <= '0'; ligar_anterior <= '0';
            inter_sync1 <= '0'; inter_sync2 <= '0';
        elsif rising_edge(clk) then
            ligar_sync1 <= ligar; inter_sync1 <= interromper;
            ligar_sync2 <= ligar_sync1; inter_sync2 <= inter_sync1;
            ligar_anterior <= ligar_sync2;
        end if;
    end process;
    ligar_pulso <= '1' when (ligar_sync2 = '1' and ligar_anterior = '0') else '0';

    -- Memória de Estado e Saídas Estáveis (LEDs)
    process(clk, rst)
    begin
        if rst = '1' then
            estado_atual <= S0_ESPERA;
            bebida_escolhida <= "00";
            troco_normal <= '0';
            sistema_ativo <= '0'; -- Começa apagado
            
        elsif rising_edge(clk) then
            estado_atual <= proximo_estado;
            
            -- LÓGICA DO LED 14 (SISTEMA ATIVO)
            -- Se estiver em QUALQUER estado que não seja o S0, o LED acende.
            if estado_atual = S0_ESPERA then
                sistema_ativo <= '0';
            else
                sistema_ativo <= '1';
            end if;

            -- LED Troco
            if estado_atual = S5_FINAL or estado_atual = S5_WAIT or 
               estado_atual = S6_CANCELAR or estado_atual = S6_WAIT or
               estado_atual = S7_ERRO or estado_atual = S7_WAIT then
                troco_normal <= '1';
            else
                troco_normal <= '0';
            end if;

            if estado_atual = S2_SELECAO then
                if sel_cafe = '1' then bebida_escolhida <= "01";
                elsif sel_cha = '1' then bebida_escolhida <= "10";
                end if;
            end if;
        end if;
    end process;

    -- Lógica de Decisão
    process(estado_atual, ligar_pulso, inter_sync2, ficha_detectada, erro_estoque, pronto_timer, 
            sel_cafe, sel_cha, bebida_escolhida)
    begin
        proximo_estado <= estado_atual;
        
        cont_reset    <= '0'; cont_start    <= '0';
        agua_en       <= '0'; cafe_en       <= '0'; cha_en        <= '0';
        devolver_tudo <= '0'; finalizado    <= '0';
        seletor_lcd   <= "000"; 

        case estado_atual is
            
            when S0_ESPERA =>
                if ligar_pulso = '1' then proximo_estado <= S1_INICIO; end if;

            when S1_INICIO =>
                cont_reset <= '1'; 
                if erro_estoque = '1' then proximo_estado <= S7_ERRO;
                elsif ficha_detectada = '1' then proximo_estado <= S2_SELECAO;
                end if;

            when S2_SELECAO =>
                cont_start <= '1';
                if inter_sync2 = '1' then proximo_estado <= S6_CANCELAR;
                elsif erro_estoque = '1' then proximo_estado <= S7_ERRO; 
                elsif (sel_cafe = '1' or sel_cha = '1') then proximo_estado <= S_PREPARAR; 
                end if;

            when S_PREPARAR =>
                cont_reset <= '1'; cont_start <= '1';
                agua_en    <= '1'; 
                if bebida_escolhida = "01" then
                    cafe_en <= '1'; proximo_estado <= S3_CAFE;
                elsif bebida_escolhida = "10" then
                    cha_en <= '1'; proximo_estado <= S4_CHA;
                else
                    proximo_estado <= S1_INICIO; 
                end if;

            when S3_CAFE =>
                cont_start <= '1';
                seletor_lcd <= "001"; 
                if inter_sync2 = '1' then proximo_estado <= S6_CANCELAR;
                elsif pronto_timer = '1' then proximo_estado <= S5_FINAL; 
                end if;

            when S4_CHA =>
                cont_start <= '1';
                seletor_lcd <= "001"; 
                if inter_sync2 = '1' then proximo_estado <= S6_CANCELAR;
                elsif pronto_timer = '1' then proximo_estado <= S5_FINAL;
                end if;

            -- SUCESSO
            when S5_FINAL =>
                seletor_lcd <= "010"; proximo_estado <= S5_RST_TIMER;
            when S5_RST_TIMER => 
                seletor_lcd <= "010"; cont_reset <= '1'; proximo_estado <= S5_WAIT;
            when S5_WAIT =>
                seletor_lcd <= "010"; cont_start <= '1';
                if pronto_timer = '1' then finalizado <= '1'; proximo_estado <= S0_ESPERA; end if;

            -- CANCELAR
            when S6_CANCELAR =>
                seletor_lcd <= "011"; devolver_tudo <= '1'; proximo_estado <= S6_RST_TIMER;
            when S6_RST_TIMER =>
                seletor_lcd <= "011"; devolver_tudo <= '1'; cont_reset <= '1'; proximo_estado <= S6_WAIT;
            when S6_WAIT =>
                seletor_lcd <= "011"; devolver_tudo <= '1'; cont_start <= '1';
                if pronto_timer = '1' then proximo_estado <= S0_ESPERA; end if;

            -- ERRO
            when S7_ERRO =>
                seletor_lcd <= "011"; devolver_tudo <= '1'; proximo_estado <= S7_RST_TIMER;
            when S7_RST_TIMER => 
                seletor_lcd <= "011"; devolver_tudo <= '1'; cont_reset <= '1'; proximo_estado <= S7_WAIT;
            when S7_WAIT =>
                seletor_lcd <= "011"; devolver_tudo <= '1'; cont_start <= '1';
                if pronto_timer = '1' then proximo_estado <= S0_ESPERA; end if;
                
        end case;
    end process;
end Behavioral;