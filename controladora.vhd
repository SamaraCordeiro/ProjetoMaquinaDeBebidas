library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Controladora is
    Port ( 
        -- Entradas de Controle
        clk             : in  STD_LOGIC;
        rst             : in  STD_LOGIC;
        
        -- Sinais Físicos
        ligar           : in  STD_LOGIC; 
        interromper     : in  STD_LOGIC; 
        
        -- Sinais Internos
        ficha_detectada : in  STD_LOGIC;
        sel_cafe        : in  STD_LOGIC;
        sel_cha         : in  STD_LOGIC;
        erro_estoque    : in  STD_LOGIC;
        pronto_timer    : in  STD_LOGIC;
        
        -- O LCD manda '1' quando terminar de escrever a mensagem
        lcd_concluido   : in  STD_LOGIC; 
        
        -- Saídas de Controle
        cont_reset      : out STD_LOGIC;
        cont_start      : out STD_LOGIC;
        agua_en         : out STD_LOGIC;
        cafe_en         : out STD_LOGIC;
        cha_en          : out STD_LOGIC;
        devolver_tudo   : out STD_LOGIC;
        finalizado      : out STD_LOGIC;
        
        -- Saída do LED
        troco_normal    : out STD_LOGIC; 

        -- NOVO: Barramento de comunicação com o LCD
        -- "000": Limpar
        -- "001": Preparando
        -- "010": Pronto
        -- "011": Erro de Água
        -- "100": Erro de Estoque
        seletor_lcd     : out STD_LOGIC_VECTOR(2 downto 0)
    );
end Controladora;

architecture Behavioral of Controladora is

    -- Definição dos Estados
    type tipo_estado is (
        S0_ESPERA,
        S1_INICIO,
        S2_SELECAO,
        S_PREPARAR,
        S3_CAFE, 
        S4_CHA,
        S5_FINAL,
        S6_CANCELAR,
        S7_ERRO
    );
    
    signal estado_atual, proximo_estado : tipo_estado;
    
    -- Registradores de Memória
    signal bebida_escolhida  : std_logic_vector(1 downto 0); -- Guarda a escolha da bebida
    signal memoria_tipo_erro : std_logic_vector(2 downto 0); -- Guarda qual erro aconteceu

    --=== SINAIS DE PROTEÇÃO BLINDAGEM ===
    -- Estes sinais servem para "limpar" a entrada dos botões físicos
    
    -- Flip-Flops para o botão ligar
    signal ligar_sync1, ligar_sync2 : std_logic; 
    signal ligar_anterior           : std_logic; 
    signal ligar_pulso              : std_logic;

    -- Flip-Flops para o switch interromper
    signal inter_sync1, inter_sync2 : std_logic;

begin

    -- PROCESS 1: LIMPEZA DOS SINAIS (SEGURANÇA DE HARDWARE)    
    -- Aqui transformamos os apertos de botão desordenados em sinais digitais
    
    process(clk, rst)
    begin
        if rst = '1' then
            ligar_sync1 <= '0'; ligar_sync2 <= '0'; ligar_anterior <= '0';
            inter_sync1 <= '0'; inter_sync2 <= '0';
        elsif rising_edge(clk) then
            -- Parte 1: Pega o sinal direto da placa
            ligar_sync1 <= ligar;
            inter_sync1 <= interromper;
            
            -- Parte 2: Estabiliza o sinal sincronizando com o clock
            ligar_sync2 <= ligar_sync1;
            inter_sync2 <= inter_sync1;
            
            -- Guarda o valor do botão no ciclo passado
            ligar_anterior <= ligar_sync2;
        end if;
    end process;
    
    -- Detector de Borda: Gera '1' apenas no exato instante que o botão é apertado.
    -- Mesmo que o usuário segure o botão, ele só manda um pulso
    ligar_pulso <= '1' when (ligar_sync2 = '1' and ligar_anterior = '0') else '0';


    -- PROCESS 2: ATUALIZAÇÃO DE ESTADO E SAÍDAS SÍNCRONAS
    -- Este processo funciona como a "memória" da máquina. A cada batida do clock, ele atualiza o estado atual e 
    -- garante que saídas críticas (como o LED) fiquem estáveis, sem piscar
    process(clk, rst)
    begin
        if rst = '1' then
            estado_atual <= S0_ESPERA;
            bebida_escolhida <= "00";
            memoria_tipo_erro <= "000";
            troco_normal <= '0'; -- Led começa desligado
            
        elsif rising_edge(clk) then
            -- Atualiza para o próximo estado da máquina
            estado_atual <= proximo_estado;
            
            -- LÓGICA DO LED (Troco):
            -- Colocamos aqui dentro para o LED ter um brilho sólido e não dar glitch
            if estado_atual = S5_FINAL then
                troco_normal <= '1';
            else
                troco_normal <= '0';
            end if;

            -- MEMÓRIA DA BEBIDA:
            -- Salva a opção que o usuário escolheu
            if estado_atual = S2_SELECAO then
                if sel_cafe = '1' then 
                    bebida_escolhida <= "01";
                elsif sel_cha = '1' then 
                    bebida_escolhida <= "10";
                end if;
            end if;

            -- MEMÓRIA DE ERRO:
            -- Descobre de onde veio o erro antes de ir para o estado S7
            if estado_atual = S2_SELECAO and erro_estoque = '1' then
                memoria_tipo_erro <= "011"; -- Código para o erro caso falte água
            elsif (estado_atual = S3_CAFE or estado_atual = S4_CHA) and erro_estoque = '1' then
                memoria_tipo_erro <= "100"; -- Código para o erro de falta de estoque (sachê de chá ou café)
            end if;
            
        end if;
    end process;

    -- PROCESS 3: LÓGICA DE DECISÃO
    -- Este processo é o "cérebro" da máquina. Ele analisa o estado atual e os sensores para decidir instantaneamente 
    -- para onde a máquina deve ir (próximo estado) e quais comandos enviar
    process(estado_atual, ligar_pulso, inter_sync2, ficha_detectada, erro_estoque, pronto_timer, 
            sel_cafe, sel_cha, bebida_escolhida, lcd_concluido, memoria_tipo_erro)
    begin
        proximo_estado <= estado_atual;
        
        cont_reset    <= '0';
        cont_start    <= '0';
        agua_en       <= '0';
        cafe_en       <= '0';
        cha_en        <= '0';
        devolver_tudo <= '0';
        finalizado    <= '0';
        seletor_lcd   <= "000"; -- Código padrão para o LCD não mostrar mensagem nova

        case estado_atual is
            
            -- Estado S0: Espera
            when S0_ESPERA =>
                if ligar_pulso = '1' then 
                    proximo_estado <= S1_INICIO; 
                end if;

            -- Estado S1: Verifica sensores iniciais
            when S1_INICIO =>
                cont_reset <= '1'; -- Garante que o timer fique zerado
                
                if erro_estoque = '1' then 
                    proximo_estado <= S7_ERRO;
                elsif ficha_detectada = '1' then 
                    proximo_estado <= S2_SELECAO;
                end if;

            -- Estado S2: Etapa para o usuário escolher a bebida
            when S2_SELECAO =>
                cont_start <= '1';
                
                -- Usamos a lógica do 'inter_sync2' para que a leitura do botão 'interromper' (que é assíncrono) seja sincronizada com o clock do sistema, 
                -- evitando que a máquina entre em um estado instável
                if inter_sync2 = '1' then 
                    proximo_estado <= S6_CANCELAR;
                elsif erro_estoque = '1' then 
                    proximo_estado <= S7_ERRO; 
                elsif (sel_cafe = '1' or sel_cha = '1') then
                    proximo_estado <= S_PREPARAR; 
                end if;

            -- ESTADO S_PREPARAR
            -- Este estado é transitorio e dura exatamente 1 ciclo de clock. Sua função é garantir que o reset do timer e a subtração 
            -- do estoque aconteçam apenas uma única vez antes de entrar na espera do preparo
            when S_PREPARAR =>
                cont_reset <= '1'; -- Pulso de reset no timer
                cont_start <= '1';
                agua_en    <= '1'; -- Pulso de gasto de água
                
                if bebida_escolhida = "01" then
                    cafe_en <= '1';       -- Gasta café
                    proximo_estado <= S3_CAFE;
                elsif bebida_escolhida = "10" then
                    cha_en <= '1';        -- Gasta chá
                    proximo_estado <= S4_CHA;
                else
                    proximo_estado <= S1_INICIO; -- Segurança
                end if;

            -- Estado S3: Fazendo Café
            when S3_CAFE =>
                cont_start <= '1';
                seletor_lcd <= "001"; -- Manda código "PREPARANDO" para o LCD
                
                if erro_estoque = '1' then proximo_estado <= S7_ERRO;
                elsif inter_sync2 = '1' then proximo_estado <= S6_CANCELAR;
                elsif pronto_timer = '1' then proximo_estado <= S5_FINAL;
                end if;

            -- Estado S4: Fazendo Chá
            when S4_CHA =>
                cont_start <= '1';
                seletor_lcd <= "001"; -- Manda código "PREPARANDO" (Igual ao café)
                
                if erro_estoque = '1' then proximo_estado <= S7_ERRO;
                elsif inter_sync2 = '1' then proximo_estado <= S6_CANCELAR;
                elsif pronto_timer = '1' then proximo_estado <= S5_FINAL;
                end if;

            -- Estado S5: Finalizado
            when S5_FINAL =>
                seletor_lcd <= "010"; -- Manda código "PRONTO" para o LCD
                
                -- BLINDAGEM DO LCD:
                -- A máquina só termina quando o LCD terminar de mostra a mensagem
                if lcd_concluido = '1' then
                    finalizado <= '1';
                    proximo_estado <= S0_ESPERA;
                end if;

            -- Estado S6: Cancelar
            when S6_CANCELAR =>
                devolver_tudo <= '1';
                proximo_estado <= S0_ESPERA;

            -- Estado S7: Erro
            when S7_ERRO =>
                -- Envia para o LCD o código específico do erro que foi guardado na memória
                seletor_lcd <= memoria_tipo_erro; 
                
                devolver_tudo <= '1';
                
                -- BLINDAGEM DO LCD NO ERRO:
                if lcd_concluido = '1' then
                    proximo_estado <= S0_ESPERA;
                end if;
                
        end case;
    end process;
end Behavioral;
