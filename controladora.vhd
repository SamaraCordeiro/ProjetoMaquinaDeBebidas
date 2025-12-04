library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Controladora is
    Port ( 
        clk             : in  STD_LOGIC;
        rst             : in  STD_LOGIC;
        ligar           : in  STD_LOGIC;
        interromper     : in  STD_LOGIC;
        ficha_detectada : in  STD_LOGIC;
        sel_cafe        : in  STD_LOGIC;
        sel_cha         : in  STD_LOGIC;
        erro_estoque    : in  STD_LOGIC;
        pronto_timer    : in  STD_LOGIC;
        
        cont_reset      : out STD_LOGIC;
        cont_start      : out STD_LOGIC;
        agua_en         : out STD_LOGIC;
        cafe_en         : out STD_LOGIC;
        cha_en          : out STD_LOGIC;
        troco_normal    : out STD_LOGIC;
        devolver_tudo   : out STD_LOGIC;
        msg_erro        : out STD_LOGIC;
        finalizado      : out STD_LOGIC
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
    
    -- Sinais internos para controle da máquina de estados 
    signal estado_atual, proximo_estado : tipo_estado;
    
    -- Registrador para guardar qual bebida foi escolhida 
    signal bebida_escolhida : std_logic_vector(1 downto 0); 

begin

    -- PROCESS 1: Responsável por atualizar o estado da borda de subida do clock 
    process(clk, rst)
    begin
        -- Reset Assíncrono: Se rst for 1, a máquina volta para o início imediatamente
        if rst = '1' then
            estado_atual <= S0_ESPERA;
            bebida_escolhida <= "00";
            
        elsif rising_edge(clk) then
            -- O estado atual assume o valor que foi calculado pelo "proximo_estado"
            estado_atual <= proximo_estado;
            
            -- Lógica para memorizar a bebida escolhida durante a transição do segundo estado
            if estado_atual = S2_SELECAO then
                if sel_cafe = '1' then
                    bebida_escolhida <= "01";
                elsif sel_cha = '1' then
                    bebida_escolhida <= "10";
                end if;
            end if;
        end if;
    end process;


    -- PROCESS 2: Analisa o estado_atual e as entradas para decidir as saídas e o proximo_estado
    process(estado_atual, ligar, ficha_detectada, erro_estoque, interromper, pronto_timer, sel_cafe, sel_cha, bebida_escolhida)
    begin

       -- Define todas as saídas e o próximo estado 
        proximo_estado <= estado_atual;
        
        cont_reset    <= '0';
        cont_start    <= '0';
        agua_en       <= '0';
        cafe_en       <= '0';
        cha_en        <= '0';
        troco_normal  <= '0';
        devolver_tudo <= '0';
        msg_erro      <= '0';
        finalizado    <= '0';

        -- MÁQUINA DE ESTADOS
        case estado_atual is
            
            -- Estado S0: aguarda o sinal de ligar
            when S0_ESPERA =>
                if ligar = '1' then 
                    proximo_estado <= S1_INICIO; 
                end if;

            -- Estado S1: verifica estoque e ficha
            when S1_INICIO =>
                cont_reset <= '1';
                
                if erro_estoque = '1' then 
                    proximo_estado <= S7_ERRO;
                elsif ficha_detectada = '1' then 
                    proximo_estado <= S2_SELECAO;
                end if;

            -- Estado S2: usuário escolhe a bebida
            when S2_SELECAO =>
                cont_start <= '1';
                
                if interromper = '1' then 
                    proximo_estado <= S6_CANCELAR;
                elsif erro_estoque = '1' then 
                    proximo_estado <= S7_ERRO;
                elsif (sel_cafe = '1' or sel_cha = '1') then
                    proximo_estado <= S_PREPARAR; 
                end if;


            -- ESTADO PARA O PREPARO DAS BEBIDAS
            -- Nesse estado irá resetar o timer para 30s e subtrair uma unidade do estoque 
            when S_PREPARAR =>
                cont_reset <= '1'; -- Reseta o contador
                cont_start <= '1'; -- Mantém o contador habilitado
                
                -- Pulso de subtração 
                agua_en <= '1'; 
                
                if bebida_escolhida = "01" then
                    cafe_en <= '1';          -- Gasta uma unidade de café
                    proximo_estado <= S3_CAFE;
                elsif bebida_escolhida = "10" then
                    cha_en <= '1';           -- Gasta uma unidade de chá
                    proximo_estado <= S4_CHA;
                else
                -- Caso a bebida for outro valor inválido, a máquina voltará para o estado inicial
                    proximo_estado <= S1_INICIO;
                end if;
                

            -- Estado S3: Esperando o café ficar pronto 
            when S3_CAFE =>
                cont_start <= '1'; -- Habilita o timer
                
                if erro_estoque = '1' then proximo_estado <= S7_ERRO;
                elsif interromper = '1' then proximo_estado <= S6_CANCELAR;
                elsif pronto_timer = '1' then proximo_estado <= S5_FINAL;
                end if;

            -- Estado S4: Esperando o chá ficar pronto 
            when S4_CHA =>
                cont_start <= '1'; -- Habilita o timer
                
                if erro_estoque = '1' then proximo_estado <= S7_ERRO;
                elsif interromper = '1' then proximo_estado <= S6_CANCELAR;
                elsif pronto_timer = '1' then proximo_estado <= S5_FINAL;
                end if;

            -- Estado S5: Finalização
            when S5_FINAL =>
                troco_normal   <= '1'; -- Entrega troco 
                finalizado     <= '1'; -- Avisa que já foi finalizado
                proximo_estado <= S0_ESPERA;

            -- Estado S6: Cancelamento 
            when S6_CANCELAR =>
                devolver_tudo  <= '1';
                proximo_estado <= S0_ESPERA;

            -- Estado S7: Estado de tratamento de erro
            when S7_ERRO =>
                msg_erro      <= '1'; -- Mostra "ERRO"
                devolver_tudo <= '1'; -- Devolve dinheiro
                
                -- Se o erro for corrigido (estoque abastecido), reseta a máquina
                if erro_estoque = '0' then 
                    proximo_estado <= S0_ESPERA; 
                end if;
                
        end case;
    end process;
end Behavioral;